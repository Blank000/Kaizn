import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/services/app_event_bus.dart';
import '../../core/services/app_prefs.dart';
import '../../core/services/streak_service.dart';
import '../../core/services/task_completion_service.dart';
import '../../core/services/timer_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';
import '../models/recurrence_rule.dart';
import '../models/task_stack.dart';
import '../providers/active_timer_provider.dart';
import '../providers/database_provider.dart';
import 'achievement_snackbar.dart';
import 'miss_check_in_sheet.dart';
import 'moment_celebrations.dart';
import 'queue_sheet.dart';
import 'reward_unlock_snackbar.dart';
import 'stop_timer_sheet.dart';

/// State of a task row at the time it's rendered. The four "active" states
/// are mutually exclusive in practice — priority is `checked > missed >
/// skipped > unchecked` if multiple completions coexist due to history.
class TaskRowState {
  final TaskCompletion? checkedCompletion;
  final TaskCompletion? skipCompletion;
  final TaskCompletion? ndCompletion;

  const TaskRowState({
    this.checkedCompletion,
    this.skipCompletion,
    this.ndCompletion,
  });

  bool get isChecked => checkedCompletion != null;
  bool get isMissed => !isChecked && ndCompletion != null;
  bool get isSkipped =>
      !isChecked && !isMissed && skipCompletion != null;
  bool get isUnchecked => !isChecked && !isMissed && !isSkipped;
}

/// Returns the row state for [task] given the recent [completions] list,
/// scoped to the task's current rule-defined period (or to the latest
/// completion for one-shot tasks).
TaskRowState taskRowStateFor(Task task, List<TaskCompletion> completions) {
  if (task.recurrence == TaskRecurrence.none) {
    if (task.status == TaskStatus.completed) {
      TaskCompletion? best;
      for (final c in completions) {
        if (c.taskId != task.id || c.isSkip || c.isNd) continue;
        if (best == null || c.completedOn.isAfter(best.completedOn)) best = c;
      }
      return TaskRowState(checkedCompletion: best);
    }
    // Active one-shot — surface today's skip / nd if any.
    final today = _dateOnly(DateTime.now());
    TaskCompletion? skip;
    TaskCompletion? nd;
    for (final c in completions) {
      if (c.taskId != task.id) continue;
      if (!_dateOnly(c.completedOn).isAtSameMomentAs(today)) continue;
      if (c.isSkip) skip ??= c;
      else if (c.isNd) nd ??= c;
    }
    return TaskRowState(skipCompletion: skip, ndCompletion: nd);
  }

  // Recurring task: scan the current rule period.
  final rule = RecurrenceRule.fromTask(task);
  final now = DateTime.now();
  final start = rule.currentPeriodStart(now);
  final end = rule.currentPeriodEnd(now);
  TaskCompletion? real;
  TaskCompletion? skip;
  TaskCompletion? nd;
  for (final c in completions) {
    if (c.taskId != task.id) continue;
    if (c.completedOn.isBefore(start) || !c.completedOn.isBefore(end)) {
      continue;
    }
    if (c.isSkip) {
      skip ??= c;
    } else if (c.isNd) {
      nd ??= c;
    } else {
      real ??= c;
    }
  }
  return TaskRowState(
    checkedCompletion: real,
    skipCompletion: skip,
    ndCompletion: nd,
  );
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// One day-chip in a multi-day weekly task's chip row.
class DayChip {
  final int weekday; // 1-7 (Mon-Sun)
  final DateTime date; // the specific date this week corresponding to [weekday]
  final TaskCompletion? real;
  final TaskCompletion? skip;
  final TaskCompletion? nd;
  final bool isFuture;
  final bool isToday;

  const DayChip({
    required this.weekday,
    required this.date,
    this.real,
    this.skip,
    this.nd,
    required this.isFuture,
    required this.isToday,
  });
}

/// Returns chip data for a multi-day weekly task, or null for any other kind
/// (single-day weekly, daily, monthly, one-shot). Caller passes the result
/// to [TaskTile.weeklyChips].
List<DayChip>? weeklyChipsFor(
    Task task, List<TaskCompletion> completions) {
  if (task.recurrence != TaskRecurrence.weekly) return null;
  final rule = RecurrenceRule.fromTask(task);
  if (rule.daysOfWeek.length <= 1) return null;

  final today = _dateOnly(DateTime.now());
  final monday = today.subtract(Duration(days: today.weekday - 1));

  return rule.daysOfWeek.map((wd) {
    final date = monday.add(Duration(days: wd - 1));
    TaskCompletion? real;
    TaskCompletion? skip;
    TaskCompletion? nd;
    for (final c in completions) {
      if (c.taskId != task.id) continue;
      if (!_isSameDay(c.completedOn, date)) continue;
      if (c.isSkip) {
        skip = c;
      } else if (c.isNd) {
        nd = c;
      } else {
        real ??= c;
      }
    }
    return DayChip(
      weekday: wd,
      date: date,
      real: real,
      skip: skip,
      nd: nd,
      isFuture: date.isAfter(today),
      isToday: _isSameDay(date, today),
    );
  }).toList();
}

/// Shared task tile rendering. Tap toggles the active state. Long-press on an
/// unchecked tile opens a "Skip today" action sheet. Caller provides the
/// meta-line string and an optional trailing widget.
class TaskTile extends ConsumerStatefulWidget {
  final Task task;
  final TaskRowState rowState;
  final String meta;
  final Widget? trailing;

  /// For multi-day weekly tasks: per-day chips (Mon/Wed/Fri etc.). When
  /// non-null, replaces the round main check button with a chip row.
  final List<DayChip>? weeklyChips;

  /// When true, tapping a checked/missed/skipped tile immediately toggles it
  /// back (the classic in-app tap-toggle). When false (default — Home, Timeline,
  /// "quick log" surfaces), a completed tile is locked and can only be
  /// reversed via the 6-second SnackBar UNDO or by navigating into the
  /// milestone detail screen. See conversation for the "Option B" design.
  final bool allowInlineUndo;

  /// Show the compact ▶ start-timer affordance on unchecked tiles. The
  /// long-press sheet remains the full action menu; this button exists so
  /// the stopwatch is discoverable without knowing the gesture.
  final bool showTimerButton;

  /// Habit-stack queue behind this task (queue heads only — callers that
  /// computed the chain pass its size). When > 0 the tile shows a tappable
  /// "🔗 N · ~45m" chip that opens the queue sheet.
  final int queueCount;

  /// Total minutes for this task + its queue (the chip's "~45m" part).
  final int? queueMinutes;

  /// The Duolingo-START-button invite: the check button of THE next task
  /// breathes gently (first unchecked tile only — one attention cue, ever).
  final bool breathe;

  const TaskTile({
    super.key,
    required this.task,
    required this.rowState,
    required this.meta,
    this.trailing,
    this.weeklyChips,
    this.allowInlineUndo = false,
    this.showTimerButton = false,
    this.queueCount = 0,
    this.queueMinutes,
    this.breathe = false,
  });

  @override
  ConsumerState<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends ConsumerState<TaskTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floaterCtrl;
  bool _showFloater = false;
  // Points shown by the +N floater — the ACTUAL award (tiny wins are half).
  int _floaterPoints = 0;
  // Gold-tint the floater when the completion earned a clutch bonus.
  bool _floaterClutch = false;

  bool get _isChecked => widget.rowState.isChecked;
  bool get _isMissed => widget.rowState.isMissed;
  bool get _isSkipped => widget.rowState.isSkipped;
  bool get _isUnchecked => widget.rowState.isUnchecked;
  bool get _isOneShot => widget.task.recurrence == TaskRecurrence.none;

  @override
  void initState() {
    super.initState();
    _floaterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _floaterCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) setState(() => _showFloater = false);
      }
    });
  }

  @override
  void dispose() {
    _floaterCtrl.dispose();
    super.dispose();
  }

  void _triggerFloater() {
    _floaterCtrl.reset();
    setState(() => _showFloater = true);
    _floaterCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final hasChips = widget.weeklyChips != null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: _toggle,
            onLongPress: _isUnchecked ? _showActions : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: hasChips
                  ? const EdgeInsets.fromLTRB(14, 12, 4, 12)
                  : const EdgeInsets.fromLTRB(8, 8, 4, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!hasChips) ...[
                    _MaybeBreathing(
                      active: widget.breathe && _isUnchecked,
                      child: _CheckButton(
                          rowState: widget.rowState, onTap: _toggle),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.task.name,
                          style: AppTypography.body.copyWith(
                            decoration: _isChecked && _isOneShot
                                ? TextDecoration.lineThrough
                                : null,
                            color: (_isChecked || _isSkipped)
                                ? context.appTextSecondary
                                : context.appTextPrimary,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            widget.meta,
                            style: AppTypography.caption.copyWith(
                              color: _isChecked
                                  ? AppColors.primary
                                  : _isMissed
                                      ? Colors.red.shade400
                                      : _isSkipped
                                          ? context.appTextTertiary
                                          : context.appTextSecondary,
                              fontWeight:
                                  (_isChecked || _isMissed)
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (hasChips) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: widget.weeklyChips!
                                .map((c) => _DayChipWidget(
                                      chip: c,
                                      onTap: () => _toggleChip(c),
                                      onLongPress: () => _showChipActions(c),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.queueCount > 0) _buildQueueChip(),
                  if (widget.showTimerButton && _isUnchecked)
                    _buildTimerButton(),
                  if (widget.trailing != null) widget.trailing!,
                ],
              ),
            ),
          ),
        ),
        if (_showFloater)
          Positioned(
            left: 12,
            top: 8,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _floaterCtrl,
                builder: (_, __) {
                  final t = _floaterCtrl.value;
                  final opacity = t < 0.15
                      ? t / 0.15
                      : t > 0.7
                          ? ((1 - t) / 0.3).clamp(0.0, 1.0)
                          : 1.0;
                  // Ease-out rise (energy released by the tap) + a quick
                  // scale pop in the first ~120ms — linear motion reads as
                  // mechanical; this reads as earned.
                  final rise = Curves.easeOutCubic.transform(t);
                  final pop = t < 0.13
                      ? 0.7 + 0.3 * Curves.easeOut.transform(t / 0.13)
                      : 1.0;
                  final isClutch = _floaterClutch;
                  return Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(0, -34 * rise),
                      child: Transform.scale(
                        scale: pop,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isClutch
                                ? AppColors.rewardsGold
                                : AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '+$_floaterPoints${isClutch ? ' ⚡' : ''}',
                            style: AppTypography.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _toggle() async {
    final db = ref.read(databaseProvider);
    final isCompleted = _isChecked || _isMissed || _isSkipped;

    // Locked-completion policy: on Home / Timeline (allowInlineUndo=false),
    // tapping a completed tile is a no-op. The 6-second UNDO snackbar is the
    // only fast-path recovery; deeper reversal happens in Milestone Detail.
    if (isCompleted && !widget.allowInlineUndo) {
      HapticFeedback.selectionClick();
      return;
    }

    if (_isChecked && widget.rowState.checkedCompletion != null) {
      await db.undoCompletion(
          widget.rowState.checkedCompletion!.id, widget.task.id);
      HapticFeedback.lightImpact();
    } else if (_isMissed && widget.rowState.ndCompletion != null) {
      await db.undoCompletion(
          widget.rowState.ndCompletion!.id, widget.task.id);
      HapticFeedback.lightImpact();
    } else if (_isSkipped && widget.rowState.skipCompletion != null) {
      await db.undoCompletion(
          widget.rowState.skipCompletion!.id, widget.task.id);
      HapticFeedback.lightImpact();
    } else if (_isUnchecked) {
      await _completeNow();
    }
  }

  /// Complete this task for today (optionally its 2-minute version) and
  /// surface the result.
  Future<void> _completeNow({bool tiny = false}) async {
    final db = ref.read(databaseProvider);
    final result =
        await TaskCompletionService.completeToday(db, widget.task, tiny: tiny);
    HapticFeedback.mediumImpact();
    if (result.basePoints > 0 && mounted) {
      _floaterPoints = result.basePoints + result.clutchBonus;
      _floaterClutch = result.clutchBonus > 0;
      _triggerFloater();
    }

    // Priority for the resulting snackbar:
    //   - Badges/rewards unlocked → celebration snackbars win.
    //   - Otherwise → the "Logged X + UNDO" snackbar for the 6s grace.
    // We deliberately don't stack the UNDO snackbar with the celebration
    // ones — they'd shove each other around and lose the moment.
    // Celebration snackbars need this tile's context; the feedback event
    // does NOT (global bus → root messenger). No `mounted` gate on the
    // event post: completing a one-shot removes it from the active-tasks
    // stream and disposes this tile before we get here — the UNDO snackbar
    // must survive that.
    // Dialog-tier moments first (streak milestone / PB / level-up) — they
    // outrank every snackbar.
    if (mounted) await surfaceDialogMoments(context, result);

    if (mounted && result.hasCelebration) {
      showAchievementSnackbar(
        context,
        [...result.completionBadges, ...result.streakBadges],
      );
      showRewardUnlockSnackbar(context, result.unlockedRewards);
    } else {
      AppEventBus.post(TaskActionEvent(
        kind: TaskActionKind.done,
        taskId: widget.task.id,
        taskName: tiny
            ? '${widget.task.tinyName ?? widget.task.name} ⚡'
            : widget.task.name,
        points: result.basePoints,
        clutchBonus: result.clutchBonus,
        durationSeconds: result.attachedDurationSeconds,
        nextStackedTaskName: result.stackedNext.firstOrNull?.name,
        identityLine: result.identityLine,
        undoCompletionId: result.completionId,
        streakDay: result.streakDay,
        questBonus: result.questCompleted?.bonus ?? 0,
      ));
    }
  }

  void _showActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      // The sheet can carry up to 6 rows (queue/tiny/timer/skip/missed/
      // cancel) — let it grow past the default half-screen cap.
      isScrollControlled: true,
      builder: (ctx) {
        final ownsTimer =
            TimerService.current?.taskId == widget.task.id;
        final tiny = widget.task.tinyName;
        final base = widget.task.pointsPerCompletion;
        final tinyPts = base > 0 ? (base + 1) ~/ 2 : 0;
        final inChain = widget.queueCount > 0 ||
            widget.task.stackedAfterTaskId != null;
        return _SkipActionsSheet(
          taskName: widget.task.name,
          queueTitle: inChain ? 'See the queue' : null,
          queueSubtitle: !inChain
              ? null
              : widget.queueCount > 0
                  ? '${widget.queueCount + 1} tasks'
                      '${widget.queueMinutes == null ? '' : ' · ~${formatQueueMinutes(widget.queueMinutes!)}'}'
                  : 'The full chain this task is part of',
          onQueue: !inChain
              ? null
              : () {
                  Navigator.of(ctx).pop();
                  showQueueSheet(context, widget.task);
                },
          tinyTitle: tiny == null ? null : 'Do the 2-minute version',
          tinySubtitle: tiny == null
              ? null
              : "'$tiny'${tinyPts > 0 ? ' · +$tinyPts pts' : ''} · full streak credit",
          onTiny: tiny == null
              ? null
              : () {
                  Navigator.of(ctx).pop();
                  _completeNow(tiny: true);
                },
          timerTitle: ownsTimer ? 'Stop timer' : 'Start timer',
          timerSubtitle: ownsTimer
              ? '${TimerService.formatElapsed(TimerService.elapsedSeconds(TimerService.current!))} on the clock'
              : 'Time this session. Stop anytime from Home.',
          onTimer: () {
            Navigator.of(ctx).pop();
            _handleTimerAction();
          },
          onSkip: () {
            Navigator.of(ctx).pop();
            _skipToday();
          },
          onMissed: () {
            Navigator.of(ctx).pop();
            _markMissed();
          },
        );
      },
    );
  }

  /// Tappable "🔗 N · ~45m" pill on queue-head tiles — the one-tap answer to
  /// "what am I committing to if I start this?" Opens the queue sheet.
  Widget _buildQueueChip() {
    final label = widget.queueMinutes == null
        ? '🔗 ${widget.queueCount}'
        : '🔗 ${widget.queueCount} · ~${formatQueueMinutes(widget.queueMinutes!)}';
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        onTap: () => showQueueSheet(context, widget.task),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.infoBlue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.infoBlue.withValues(alpha: 0.35)),
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.infoBlue,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  /// Compact ▶ / ⏱ affordance. Plain outline when idle; filled primary when
  /// THIS task's stopwatch is running (the Home banner shows the elapsed).
  Widget _buildTimerButton() {
    final ownsTimer =
        ref.watch(activeTimerProvider).valueOrNull?.taskId == widget.task.id;
    return IconButton(
      icon: Icon(
        ownsTimer ? Icons.timer_rounded : Icons.play_circle_outline_rounded,
        size: 22,
        color: ownsTimer ? AppColors.primary : context.appTextTertiary,
      ),
      tooltip: ownsTimer ? 'Stop timer' : 'Start timer',
      visualDensity: VisualDensity.compact,
      onPressed: _handleTimerAction,
    );
  }

  Future<void> _handleTimerAction() async {
    final current = TimerService.current;
    if (current?.taskId == widget.task.id) {
      if (mounted) await showStopTimerSheet(context, ref);
    } else if (current != null) {
      if (mounted) {
        await showTimerConflictDialog(context, ref, newTask: widget.task);
      }
    } else {
      await TimerService.start(widget.task.id);
      HapticFeedback.lightImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("⏱ Timer on! Go get '${widget.task.name}'."),
        ));
      }
    }
  }

  Future<void> _skipToday() async {
    final db = ref.read(databaseProvider);
    await db.skipTaskNow(widget.task);
    await StreakService.recordSkipDay(db);
    HapticFeedback.lightImpact();
    // Ren blesses the intentional rest (Chapter Four, skip branch).
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppPrefs.renEnabledSync
            ? '🦊 “Rest chosen is rest earned.” Skip logged, streak safe.'
            : 'Skip logged — intentional rest, streak safe.'),
      ));
    }
  }

  Future<void> _markMissed() async {
    final db = ref.read(databaseProvider);
    final completionId = await db.markTaskMissed(widget.task);
    HapticFeedback.lightImpact();
    // Self-compassion check-in: kind line + "what got in the way?" chips,
    // routing to the tool that fixes THAT kind of miss. Fully dismissible.
    if (mounted) {
      await showMissCheckInSheet(context, ref, widget.task, completionId);
    }
  }

  /// Long-press on a day chip: surface skip/missed options for that
  /// specific date. Only opens when the chip is empty (no completion yet)
  /// and not in the future.
  void _showChipActions(DayChip chip) {
    if (!_isChipEmpty(chip)) return;
    final dateLabel = _formatChipDate(chip.date);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SkipActionsSheet(
        taskName: widget.task.name,
        subtitle: dateLabel,
        onSkip: () async {
          Navigator.of(ctx).pop();
          final db = ref.read(databaseProvider);
          await db.skipTaskOn(widget.task, chip.date);
          HapticFeedback.lightImpact();
        },
        onMissed: () async {
          Navigator.of(ctx).pop();
          final db = ref.read(databaseProvider);
          await db.markTaskMissedOn(widget.task, chip.date);
          HapticFeedback.lightImpact();
        },
      ),
    );
  }

  bool _isChipEmpty(DayChip chip) =>
      chip.real == null && chip.skip == null && chip.nd == null;

  String _formatChipDate(DateTime date) {
    const weekdayNames = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdayNames[date.weekday - 1]}, '
        '${monthNames[date.month - 1]} ${date.day}';
  }

  Future<void> _toggleChip(DayChip chip) async {
    final db = ref.read(databaseProvider);

    // Existing completion on this chip's date → undo path. Locked on Home /
    // Timeline (allowInlineUndo=false); passable via SnackBar UNDO or milestone
    // detail. See TaskTile.allowInlineUndo docs.
    final existing = chip.real ?? chip.nd ?? chip.skip;
    if (existing != null) {
      if (!widget.allowInlineUndo) {
        HapticFeedback.selectionClick();
        return;
      }
      await db.undoCompletion(existing.id, widget.task.id);
      HapticFeedback.lightImpact();
      return;
    }

    // Empty chip → log a real completion. Two paths depending on whether it's
    // today (streak-relevant) or a past/future date (retro-log).
    final CompletionResult result;
    if (chip.isToday) {
      result = await TaskCompletionService.completeToday(db, widget.task);
    } else {
      result = await TaskCompletionService.completeOn(
          db, widget.task, chip.date);
    }
    HapticFeedback.mediumImpact();
    // Retro chips earn the floater too — points are points.
    if (result.basePoints > 0 && mounted) {
      _floaterPoints = result.basePoints + result.clutchBonus;
      _floaterClutch = result.clutchBonus > 0;
      _triggerFloater();
    }

    if (mounted) await surfaceDialogMoments(context, result);

    if (mounted && result.hasCelebration) {
      showAchievementSnackbar(
        context,
        [...result.completionBadges, ...result.streakBadges],
      );
      showRewardUnlockSnackbar(context, result.unlockedRewards);
    } else {
      // Global bus — no context/mounted needed; see _toggle.
      AppEventBus.post(TaskActionEvent(
        kind: TaskActionKind.done,
        taskId: widget.task.id,
        taskName: widget.task.name,
        points: result.basePoints,
        clutchBonus: result.clutchBonus,
        durationSeconds: result.attachedDurationSeconds,
        nextStackedTaskName: result.stackedNext.firstOrNull?.name,
        identityLine: result.identityLine,
        undoCompletionId: result.completionId,
        streakDay: result.streakDay,
        questBonus: result.questCompleted?.bonus ?? 0,
      ));
    }
  }
}

/// Gentle 1.0→1.06 pulse for the next actionable check button — an invite,
/// not an alarm. Inert (and controller-free) when inactive; still under
/// reduced motion.
class _MaybeBreathing extends StatefulWidget {
  final bool active;
  final Widget child;
  const _MaybeBreathing({required this.active, required this.child});

  @override
  State<_MaybeBreathing> createState() => _MaybeBreathingState();
}

// TickerProviderStateMixin (multi), NOT Single: the controller is disposed
// and re-created as `active` toggles, and the single-ticker mixin throws on
// the second Ticker it's ever asked to create.
class _MaybeBreathingState extends State<_MaybeBreathing>
    with TickerProviderStateMixin {
  AnimationController? _ctrl;

  void _sync() {
    final still = MediaQuery.of(context).disableAnimations;
    if (widget.active && !still) {
      _ctrl ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1300),
      )..repeat(reverse: true);
    } else {
      _ctrl?.dispose();
      _ctrl = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_MaybeBreathing old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    if (ctrl == null) return widget.child;
    // RepaintBoundary: the pulse repaints a 44px button, never the tile.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: ctrl,
        builder: (_, child) => Transform.scale(
          scale: 1.0 + 0.06 * Curves.easeInOut.transform(ctrl.value),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// The most-tapped widget in the app, so it gets real motion: tapDown squish
/// (instant, <16ms feedback), elastic overshoot on release, the icon scaling
/// in instead of popping, and a one-shot radial dot-burst on completion.
class _CheckButton extends StatefulWidget {
  final TaskRowState rowState;
  final VoidCallback onTap;
  const _CheckButton({required this.rowState, required this.onTap});

  @override
  State<_CheckButton> createState() => _CheckButtonState();
}

class _CheckButtonState extends State<_CheckButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burstCtrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _burstCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
  }

  @override
  void didUpdateWidget(_CheckButton old) {
    super.didUpdateWidget(old);
    // Fire the burst when the state BECOMES checked (from any surface — tap,
    // notification, timer — the stream update lands here either way).
    if (!old.rowState.isChecked && widget.rowState.isChecked) {
      _burstCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _burstCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rowState = widget.rowState;
    final Color fill;
    final Color border;
    final IconData? icon;
    if (rowState.isChecked) {
      fill = AppColors.primary;
      border = AppColors.primary;
      icon = Icons.check_rounded;
    } else if (rowState.isMissed) {
      fill = Colors.red.shade400;
      border = Colors.red.shade400;
      icon = Icons.close_rounded;
    } else if (rowState.isSkipped) {
      fill = context.appTextTertiary;
      border = context.appTextTertiary;
      icon = Icons.remove_rounded;
    } else {
      fill = Colors.transparent;
      border = context.appBorder;
      icon = null;
    }

    return SizedBox(
      width: 44,
      height: 44,
      child: InkWell(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _burstCtrl,
              builder: (_, __) => _burstCtrl.isAnimating
                  ? CustomPaint(
                      size: const Size(44, 44),
                      painter: _BurstPainter(
                        progress: _burstCtrl.value,
                        color: AppColors.primary,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            AnimatedScale(
              // Squish on press; elastic settle back with slight overshoot.
              scale: _pressed ? 0.85 : 1.0,
              duration: _pressed
                  ? const Duration(milliseconds: 60)
                  : const Duration(milliseconds: 350),
              curve: _pressed ? Curves.easeOut : Curves.elasticOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: fill,
                  border: Border.all(color: border, width: 2),
                  shape: BoxShape.circle,
                ),
                child: icon != null
                    ? AnimatedScale(
                        scale: 1.0,
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutBack,
                        child: Icon(icon, size: 18, color: Colors.white),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One-shot radial burst: 8 dots flying outward, shrinking and fading.
class _BurstPainter extends CustomPainter {
  final double progress;
  final Color color;
  _BurstPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final eased = Curves.easeOutCubic.transform(progress);
    final radius = 8.0 + 16.0 * eased;
    final dotR = 2.4 * (1 - progress);
    final paint = Paint()
      ..color = color.withValues(alpha: (1 - progress).clamp(0.0, 1.0));
    final gold = Paint()
      ..color = AppColors.rewardsGold
          .withValues(alpha: (1 - progress).clamp(0.0, 1.0));
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final p = center +
          Offset(radius * math.cos(angle), radius * math.sin(angle));
      canvas.drawCircle(p, dotR, i.isEven ? paint : gold);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.progress != progress || old.color != color;
}

class _DayChipWidget extends StatelessWidget {
  final DayChip chip;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _DayChipWidget({
    required this.chip,
    required this.onTap,
    this.onLongPress,
  });

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color textColor;
    if (chip.isFuture) {
      bg = context.appPageBackground;
      textColor = context.appTextTertiary;
    } else if (chip.real != null) {
      bg = AppColors.primary;
      textColor = Colors.white;
    } else if (chip.nd != null) {
      bg = Colors.red.shade400;
      textColor = Colors.white;
    } else if (chip.skip != null) {
      bg = context.appTextTertiary;
      textColor = Colors.white;
    } else {
      bg = context.appBorder.withValues(alpha: 0.4);
      textColor = context.appTextSecondary;
    }

    final letter = _letters[chip.weekday - 1];

    return InkWell(
      // Future chips are still tappable — user may want to log a task ahead
      // of its scheduled day. `completeTaskOn(task, chip.date)` stamps the
      // completion for the chip's actual date, so a Wed chip tapped on Mon
      // credits Wed correctly.
      onTap: onTap,
      onLongPress: onLongPress,
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: chip.isToday
              ? Border.all(color: AppColors.primary, width: 2)
              : null,
        ),
        child: Text(
          letter,
          style: AppTypography.caption.copyWith(
            color: textColor,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _SkipActionsSheet extends StatelessWidget {
  final String taskName;
  final String? subtitle; // e.g., "Mon, May 5" — set by chip long-press

  /// Stopwatch row (today-sheet only; retro chip sheets pass null — a timer
  /// is a now-action).
  final String? timerTitle;
  final String? timerSubtitle;
  final VoidCallback? onTimer;

  /// Two-minute-rule row: shown when the task has a tiny version defined.
  final String? tinyTitle;
  final String? tinySubtitle;
  final VoidCallback? onTiny;

  /// Habit-stack row: shown when the task heads or belongs to a queue.
  final String? queueTitle;
  final String? queueSubtitle;
  final VoidCallback? onQueue;

  final VoidCallback onSkip;
  final VoidCallback onMissed;

  const _SkipActionsSheet({
    required this.taskName,
    this.subtitle,
    this.timerTitle,
    this.timerSubtitle,
    this.onTimer,
    this.tinyTitle,
    this.tinySubtitle,
    this.onTiny,
    this.queueTitle,
    this.queueSubtitle,
    this.onQueue,
    required this.onSkip,
    required this.onMissed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appCardSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SafeArea(
        top: false,
        // Scrollable so the full row set (up to 6) never overflows on
        // short screens — the sheet grows to content, then scrolls.
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.appBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(taskName,
                style: AppTypography.heading2,
                textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: AppTypography.caption.copyWith(
                      color: context.appTextSecondary),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            if (onQueue != null) ...[
              _OptionRow(
                icon: Icons.link_rounded,
                iconColor: AppColors.infoBlue,
                title: queueTitle ?? 'See the queue',
                subtitle: queueSubtitle ?? 'The full chain, link by link',
                onTap: onQueue!,
              ),
              const SizedBox(height: 12),
            ],
            if (onTiny != null) ...[
              _OptionRow(
                icon: Icons.bolt_rounded,
                iconColor: AppColors.streakOrange,
                title: tinyTitle ?? 'Do the 2-minute version',
                subtitle: tinySubtitle ?? 'Half points, full streak credit',
                onTap: onTiny!,
              ),
              const SizedBox(height: 12),
            ],
            if (onTimer != null) ...[
              _OptionRow(
                icon: Icons.timer_rounded,
                iconColor: AppColors.primary,
                title: timerTitle ?? 'Start timer',
                subtitle:
                    timerSubtitle ?? 'Time this session. Stop anytime from Home.',
                onTap: onTimer!,
              ),
              const SizedBox(height: 12),
            ],
            _OptionRow(
              icon: Icons.do_not_disturb_alt_rounded,
              iconColor: context.appTextTertiary,
              title: 'Skip today',
              subtitle: 'Intentional rest. Streak preserved, no points.',
              onTap: onSkip,
            ),
            const SizedBox(height: 12),
            _OptionRow(
              icon: Icons.close_rounded,
              iconColor: Colors.red.shade400,
              title: 'Mark as missed',
              subtitle: "Honest miss. Doesn't credit your streak.",
              onTap: onMissed,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CANCEL'),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: context.appBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTypography.caption.copyWith(
                          color: context.appTextSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
