import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/services/app_event_bus.dart';
import '../../core/services/task_completion_service.dart';
import '../../core/services/timer_service.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';
import '../providers/database_provider.dart';
import 'achievement_snackbar.dart';
import 'moment_celebrations.dart';
import 'reward_unlock_snackbar.dart';
import 'time_ledger_sheet.dart';

/// Stop-flow for a stopwatch session. Completion surface #5 — the MARK
/// COMPLETE branch routes through TaskCompletionService like every other
/// call site, so stacking/identity/clutch hooks all fire here too.
///
/// Defaults to the running session; pass [taskId] to stop a specific one
/// (a paused session stopped from its own task row, for instance).
Future<void> showStopTimerSheet(BuildContext context, WidgetRef ref,
    {String? taskId}) async {
  // Re-read at open: the sheet can race a completion from another surface.
  final timer =
      taskId == null ? TimerService.running : TimerService.forTask(taskId);
  if (timer == null) return;

  final db = ref.read(databaseProvider);
  final task = await db.getTaskById(timer.taskId);
  if (!context.mounted) return;

  if (task == null) {
    // Task was deleted while its timer ran.
    await TimerService.clear(timer.taskId, kind: TimerEventKind.vanished);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That task vanished — timer cleared.')),
      );
    }
    return;
  }

  final elapsed = TimerService.elapsedSeconds(timer);
  final capped = TimerService.cappedElapsedSeconds(timer);
  final overCap = elapsed > capped;

  final existing =
      await db.getCompletionForTaskOn(task.id, DateTime.now());
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _StopTimerSheet(
      task: task,
      elapsedSeconds: elapsed,
      cappedSeconds: capped,
      overCap: overCap,
      isPaused: timer.isPaused,
      alreadyDoneToday: existing != null,
      existingCompletionId: existing?.id,
      hostContext: context,
      db: db,
    ),
  );
}

class _StopTimerSheet extends StatelessWidget {
  final Task task;
  final int elapsedSeconds;
  final int cappedSeconds;
  final bool overCap;
  final bool isPaused;
  final bool alreadyDoneToday;
  final String? existingCompletionId;

  /// Context of the SCREEN under the sheet — snackbars must outlive the
  /// sheet's own context.
  final BuildContext hostContext;

  /// The database itself, NOT the caller's WidgetRef: the tile that opened
  /// this sheet can be disposed while the sheet is up (list rebuild, one-shot
  /// completed elsewhere), and a `ref.read` after that throws.
  final AppDatabase db;

  const _StopTimerSheet({
    required this.task,
    required this.elapsedSeconds,
    required this.cappedSeconds,
    required this.overCap,
    required this.isPaused,
    required this.alreadyDoneToday,
    required this.existingCompletionId,
    required this.hostContext,
    required this.db,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = TimerService.formatElapsed(cappedSeconds);
    return Container(
      decoration: BoxDecoration(
        color: context.appCardSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              alreadyDoneToday
                  ? 'Already done today ✅'
                  : isPaused
                      ? 'Paused session ⏸'
                      : 'Nice session! ⏱',
              style: AppTypography.heading2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              alreadyDoneToday
                  ? "Add $fmt to today's log?"
                  : '$fmt on ${task.name}.',
              style: AppTypography.body
                  .copyWith(color: context.appTextSecondary),
              textAlign: TextAlign.center,
            ),
            if (overCap) ...[
              const SizedBox(height: 4),
              Text(
                "Whoa — ${TimerService.formatElapsed(elapsedSeconds)}! "
                "We'll credit ${TimerService.formatElapsed(cappedSeconds)}. "
                "Even legends sleep. 😴",
                style: AppTypography.caption
                    .copyWith(color: context.appTextTertiary),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              // Estimate calibration: neutral fact, no judgment color —
              // seeing planned-vs-actual is how time estimates get honest.
              const SizedBox(height: 4),
              Text(
                'Planned ~${task.durationMinutes}m · '
                'took ${TimerService.formatElapsed(cappedSeconds)}',
                style: AppTypography.caption
                    .copyWith(color: context.appTextTertiary),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            if (alreadyDoneToday)
              ElevatedButton(
                onPressed: () => _addTime(context),
                child: const Text('ADD TIME'),
              )
            else ...[
              ElevatedButton(
                onPressed: () => _markComplete(context),
                child: Text(task.pointsPerCompletion > 0
                    ? 'MARK COMPLETE · +${task.pointsPerCompletion} PTS'
                    : 'MARK COMPLETE'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  if (isPaused) {
                    await TimerService.resume(task.id, taskName: task.name);
                  }
                },
                child: Text(isPaused ? 'RESUME TIMER' : 'KEEP TIMING'),
              ),
            ],
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => _showLedger(context),
              child: const Text('Time log for this task'),
            ),
            TextButton(
              onPressed: () => _discard(context),
              child: const Text('Discard session'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markComplete(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    // Stale-sheet guard: another surface finished this session while the
    // sheet was open. Say so instead of doing nothing at all.
    if (TimerService.forTask(task.id) == null) {
      if (hostContext.mounted) {
        ScaffoldMessenger.of(hostContext).showSnackBar(const SnackBar(
          content: Text('That session was already wrapped up elsewhere.'),
        ));
      }
      return;
    }

    // Timer auto-attach inside the service stamps the duration + clears.
    final result = await TaskCompletionService.completeToday(db, task);
    HapticFeedback.mediumImpact();

    if (hostContext.mounted) {
      await surfaceDialogMoments(hostContext, result);
    }

    if (hostContext.mounted && result.hasCelebration) {
      showAchievementSnackbar(
        hostContext,
        [...result.completionBadges, ...result.streakBadges],
      );
      showRewardUnlockSnackbar(hostContext, result.unlockedRewards);
    } else {
      // Global bus — the UNDO snackbar must show even if the host screen
      // rebuilt away under the sheet.
      AppEventBus.post(TaskActionEvent(
        kind: TaskActionKind.done,
        taskId: task.id,
        taskName: task.name,
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

  Future<void> _addTime(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    // Re-read the clock at press time. The sheet has no ticker, so its
    // snapshot goes stale the moment it opens — crediting that would quietly
    // lose however long the user sat looking at it.
    final live = TimerService.forTask(task.id);
    if (live == null) {
      if (hostContext.mounted) {
        ScaffoldMessenger.of(hostContext).showSnackBar(const SnackBar(
          content: Text('That session was already wrapped up elsewhere.'),
        ));
      }
      return;
    }
    final seconds = TimerService.cappedElapsedSeconds(live);
    final cid = existingCompletionId;
    // The completion may have been undone under us; only credit a row that
    // is still there.
    final stillThere =
        cid == null ? null : await db.getCompletionForTaskOn(task.id, DateTime.now());
    if (stillThere != null) {
      await db.addDurationToCompletion(stillThere.id, seconds);
    }
    await TimerService.clear(task.id,
        kind: stillThere != null
            ? TimerEventKind.complete
            : TimerEventKind.stop,
        taskName: task.name);
    HapticFeedback.lightImpact();
    if (hostContext.mounted) {
      // No UNDO — undoing would nuke the whole completion, not just the time.
      ScaffoldMessenger.of(hostContext).showSnackBar(SnackBar(
        content: Text(stillThere == null
            ? "That completion is gone, so the time wasn't added. "
                'Session closed.'
            : 'Added ${TimerService.formatElapsed(seconds)} to ${task.name} ⏱'),
      ));
    }
  }

  Future<void> _showLedger(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    if (hostContext.mounted) {
      await showTimeLedgerSheet(hostContext, db, task);
    }
  }

  Future<void> _discard(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    await TimerService.clear(task.id,
        kind: TimerEventKind.discard, taskName: task.name);
    HapticFeedback.lightImpact();
    if (hostContext.mounted) {
      ScaffoldMessenger.of(hostContext).showSnackBar(
        const SnackBar(
            content: Text('Session discarded. The effort still counts. 💪')),
      );
    }
  }
}

/// The one timer gesture, shared by every surface that shows a task.
///
/// - No session → start one. Anything already running is paused and banked,
///   never discarded, and we say whose clock we just stopped.
/// - Paused session → resume it (same auto-pause rule).
/// - Running session → open the stop sheet.
///
/// This replaced the old "One timer at a time" conflict dialog: switching
/// tasks is a normal thing to do, not an error to arbitrate.
Future<void> handleTaskTimerTap(
  BuildContext context,
  WidgetRef ref,
  Task task,
) async {
  final existing = TimerService.forTask(task.id);

  if (existing != null && !existing.isPaused) {
    await showStopTimerSheet(context, ref, taskId: task.id);
    return;
  }

  final resuming = existing != null;
  final autoPausedId = resuming
      ? await TimerService.resume(task.id, taskName: task.name)
      : await TimerService.start(task.id, taskName: task.name);
  HapticFeedback.lightImpact();
  if (!context.mounted) return;

  var line = resuming
      ? "▶ Back on '${task.name}'."
      : "⏱ Timer on! Go get '${task.name}'.";
  if (autoPausedId != null) {
    final paused = await ref.read(databaseProvider).getTaskById(autoPausedId);
    if (paused != null) {
      line = "$line '${paused.name}' paused — its time is safe.";
    }
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(line)));
}
