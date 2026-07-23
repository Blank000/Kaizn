import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/database/database.dart';
import '../../core/services/app_event_bus.dart';
import '../../core/services/streak_service.dart';
import '../../core/services/task_completion_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';
import '../../shared/models/recurrence_rule.dart';
import '../../shared/models/task_stack.dart';
import '../../shared/providers/database_provider.dart';
import '../../shared/widgets/achievement_snackbar.dart';
import '../../shared/widgets/celebration_dialog.dart';
import '../../shared/widgets/moment_celebrations.dart';
import '../../shared/widgets/reward_unlock_snackbar.dart';

/// The routine player (Routinery-style "guided stack execution"): runs a
/// habit-stack chain one step at a time — big countdown from the step's
/// duration, DONE / SKIP / +5, auto-advance — so working memory never has to
/// carry the sequence. Completions fire the normal TaskCompletionService
/// pipeline, so points, streaks, quests and celebrations all behave exactly
/// like a tile tap.
///
/// The countdown hitting zero NEVER auto-completes — it asks. Honesty beats
/// convenience.
class StackRunnerScreen extends ConsumerStatefulWidget {
  final String taskId;
  const StackRunnerScreen({super.key, required this.taskId});

  @override
  ConsumerState<StackRunnerScreen> createState() =>
      _StackRunnerScreenState();
}

class _StackRunnerScreenState extends ConsumerState<StackRunnerScreen> {
  /// Chain snapshot, frozen at entry so mid-run edits can't reorder steps.
  List<Task>? _steps;
  int _index = 0;

  // Per-step wall-clock timing (survives backgrounding, like TimerService).
  DateTime _stepStartedAt = DateTime.now();
  int _pausedAccumSeconds = 0;
  bool _paused = false;
  int _timedForIndex = -1;

  Timer? _ticker;
  bool _completing = false;
  bool _finished = false;
  int _doneCount = 0;
  int _totalSeconds = 0;
  bool _timeUpBuzzed = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_paused) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  bool _resolvedToday(Task t, List<TaskCompletion> completions) {
    final now = DateTime.now();
    return completions.any((c) =>
        c.taskId == t.id &&
        c.completedOn.year == now.year &&
        c.completedOn.month == now.month &&
        c.completedOn.day == now.day);
  }

  bool _runsToday(Task t) {
    if (t.recurrence != TaskRecurrence.none) {
      return RecurrenceRule.fromTask(t).isDueOn(DateTime.now());
    }
    return t.status == TaskStatus.active;
  }

  int _elapsedSeconds() {
    if (_paused) return _pausedAccumSeconds;
    return _pausedAccumSeconds +
        DateTime.now().difference(_stepStartedAt).inSeconds;
  }

  void _resetStepTimer(int index) {
    _timedForIndex = index;
    _stepStartedAt = DateTime.now();
    _pausedAccumSeconds = 0;
    _paused = false;
    _timeUpBuzzed = false;
  }

  Future<void> _completeStep(Task task, {bool tiny = false}) async {
    if (_completing) return;
    _completing = true;
    final elapsed = _elapsedSeconds();
    _totalSeconds += elapsed;
    _doneCount++;
    final db = ref.read(databaseProvider);
    final result = await TaskCompletionService.completeToday(
      db,
      task,
      durationSeconds: elapsed > 0 ? elapsed : null,
      tiny: tiny,
    );
    HapticFeedback.mediumImpact();
    if (mounted) await surfaceDialogMoments(context, result);
    if (mounted && result.hasCelebration) {
      showAchievementSnackbar(
        context,
        [...result.completionBadges, ...result.streakBadges],
      );
      showRewardUnlockSnackbar(context, result.unlockedRewards);
    } else {
      // No UNDO snackbar mid-run — the runner IS the feedback surface; the
      // event still reaches the bus for listeners that care.
      AppEventBus.post(TaskActionEvent(
        kind: TaskActionKind.done,
        taskId: task.id,
        taskName: task.name,
        points: result.basePoints,
        clutchBonus: result.clutchBonus,
        durationSeconds: result.attachedDurationSeconds,
        identityLine: result.identityLine,
        undoCompletionId: result.completionId,
        streakDay: result.streakDay,
        questBonus: result.questCompleted?.bonus ?? 0,
      ));
    }
    _completing = false;
  }

  Future<void> _skipStep(Task task) async {
    if (_completing) return;
    _completing = true;
    final db = ref.read(databaseProvider);
    await db.skipTaskNow(task);
    await StreakService.recordSkipDay(db);
    HapticFeedback.lightImpact();
    _completing = false;
  }

  Future<void> _finishRun(String rootName) async {
    if (_finished) return;
    _finished = true;
    _ticker?.cancel();
    if (_doneCount > 0 && mounted) {
      final mins = (_totalSeconds / 60).round();
      await showCelebrationDialog(
        context,
        emoji: '🔗',
        title: 'QUEUE CLEARED!',
        subtitle: rootName,
        body:
            '$_doneCount task${_doneCount == 1 ? '' : 's'} done${mins > 0 ? ' · ~${formatQueueMinutes(mins)}' : ''}',
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(allTasksProvider).valueOrNull;
    final completions =
        ref.watch(recentCompletionsAllProvider).valueOrNull;
    if (tasks == null || completions == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    // Freeze the chain on first data.
    if (_steps == null) {
      final self = tasks.where((t) => t.id == widget.taskId).firstOrNull;
      if (self == null) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => Navigator.of(context).maybePop());
        return const Scaffold(body: SizedBox.shrink());
      }
      _steps = chainFor(self, tasks);
    }
    final steps = _steps!;

    // Advance past anything already resolved today or not scheduled today —
    // this also moves us forward when OUR completion echoes back through the
    // stream, keeping DB state the single source of truth.
    while (_index < steps.length &&
        (_resolvedToday(steps[_index], completions) ||
            !_runsToday(steps[_index]))) {
      _index++;
    }

    if (_index >= steps.length) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _finishRun(steps.first.name));
      return Scaffold(
          backgroundColor: context.appPageBackground,
          body: const SizedBox.shrink());
    }

    if (_timedForIndex != _index) _resetStepTimer(_index);

    final task = steps[_index];
    final plannedSeconds = task.durationMinutes * 60;
    final elapsed = _elapsedSeconds();
    final remaining = plannedSeconds - elapsed;
    final timeUp = remaining <= 0;
    if (timeUp && !_timeUpBuzzed) {
      _timeUpBuzzed = true;
      HapticFeedback.heavyImpact();
    }
    final progress =
        plannedSeconds == 0 ? 1.0 : (elapsed / plannedSeconds).clamp(0.0, 1.0);
    final stepsLeft = steps.length - _index;
    final next = _index + 1 < steps.length ? steps[_index + 1] : null;

    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(
        title: Text('🔗 ${steps.first.name}',
            style: AppTypography.heading2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Exit run',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              Text(
                'Step ${_index + 1} of ${steps.length}'
                '${stepsLeft > 1 ? ' · $stepsLeft to go' : ' · last one!'}',
                style: AppTypography.caption
                    .copyWith(color: context.appTextSecondary),
              ),
              const Spacer(),
              Text(
                task.name,
                style: AppTypography.display,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 10,
                        backgroundColor:
                            context.appBorder.withValues(alpha: 0.4),
                        color: timeUp
                            ? AppColors.streakOrange
                            : AppColors.primary,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeUp
                              ? '+${_fmtClock(-remaining)}'
                              : _fmtClock(remaining),
                          style: AppTypography.display.copyWith(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: timeUp
                                ? AppColors.streakOrange
                                : context.appTextPrimary,
                          ),
                        ),
                        Text(
                          timeUp
                              ? 'Time! Done?'
                              : _paused
                                  ? 'Paused'
                                  : '~${task.durationMinutes}m planned',
                          style: AppTypography.caption.copyWith(
                              color: context.appTextSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (next != null)
                Text(
                  'Next: ${next.name} · ~${next.durationMinutes}m',
                  style: AppTypography.caption
                      .copyWith(color: context.appTextTertiary),
                ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        if (_paused) {
                          _stepStartedAt = DateTime.now();
                          _paused = false;
                        } else {
                          _pausedAccumSeconds = _elapsedSeconds();
                          _paused = true;
                        }
                      }),
                      child: Text(_paused ? 'RESUME' : 'PAUSE'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        // +5 borrows from the planned time, not the clock.
                        _pausedAccumSeconds = _elapsedSeconds() - 300;
                        _stepStartedAt = DateTime.now();
                        _timeUpBuzzed = false;
                      }),
                      child: const Text('+5 MIN'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _completeStep(task),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor:
                        timeUp ? AppColors.streakOrange : null,
                  ),
                  child: Text(task.pointsPerCompletion > 0
                      ? 'DONE · +${task.pointsPerCompletion} PTS'
                      : 'DONE'),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (task.tinyName != null)
                    TextButton(
                      onPressed: () => _completeStep(task, tiny: true),
                      child: Text('⚡ 2-min: ${task.tinyName}'),
                    ),
                  TextButton(
                    onPressed: () => _skipStep(task),
                    child: const Text('SKIP STEP'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtClock(int seconds) {
    final s = seconds.abs();
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}
