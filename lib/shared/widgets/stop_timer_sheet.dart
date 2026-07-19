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

/// Stop-flow for the running stopwatch. Completion surface #5 — the MARK
/// COMPLETE branch routes through TaskCompletionService like every other
/// call site, so stacking/identity/clutch hooks all fire here too.
Future<void> showStopTimerSheet(BuildContext context, WidgetRef ref) async {
  // Re-read at open: the sheet can race a completion from another surface.
  final timer = TimerService.current;
  if (timer == null) return;

  final db = ref.read(databaseProvider);
  final task = await db.getTaskById(timer.taskId);
  if (!context.mounted) return;

  if (task == null) {
    // Task was deleted while its timer ran.
    await TimerService.clear();
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
      alreadyDoneToday: existing != null,
      existingCompletionId: existing?.id,
      hostContext: context,
      dbRef: ref,
    ),
  );
}

class _StopTimerSheet extends StatelessWidget {
  final Task task;
  final int elapsedSeconds;
  final int cappedSeconds;
  final bool overCap;
  final bool alreadyDoneToday;
  final String? existingCompletionId;

  /// Context/ref of the SCREEN under the sheet — snackbars must outlive the
  /// sheet's own context.
  final BuildContext hostContext;
  final WidgetRef dbRef;

  const _StopTimerSheet({
    required this.task,
    required this.elapsedSeconds,
    required this.cappedSeconds,
    required this.overCap,
    required this.alreadyDoneToday,
    required this.existingCompletionId,
    required this.hostContext,
    required this.dbRef,
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
              alreadyDoneToday ? 'Already done today ✅' : 'Nice session! ⏱',
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
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('KEEP TIMING'),
              ),
            ],
            const SizedBox(height: 4),
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
    // Double-tap / stale-sheet guard: the timer may already be gone.
    if (TimerService.current?.taskId != task.id) return;

    final db = dbRef.read(databaseProvider);
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
    if (TimerService.current?.taskId != task.id) return;
    final cid = existingCompletionId;
    final db = dbRef.read(databaseProvider);
    if (cid != null) {
      await db.addDurationToCompletion(cid, cappedSeconds);
    }
    await TimerService.clear();
    HapticFeedback.lightImpact();
    if (hostContext.mounted) {
      // No UNDO — undoing would nuke the whole completion, not just the time.
      ScaffoldMessenger.of(hostContext).showSnackBar(SnackBar(
        content: Text(
            'Added ${TimerService.formatElapsed(cappedSeconds)} to ${task.name} ⏱'),
      ));
    }
  }

  Future<void> _discard(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    await TimerService.clear();
    HapticFeedback.lightImpact();
    if (hostContext.mounted) {
      ScaffoldMessenger.of(hostContext).showSnackBar(
        const SnackBar(
            content: Text('Session discarded. The effort still counts. 💪')),
      );
    }
  }
}

/// "One timer at a time" — shown when starting a timer while another runs.
Future<void> showTimerConflictDialog(
  BuildContext context,
  WidgetRef ref, {
  required Task newTask,
}) async {
  final running = TimerService.current;
  if (running == null) {
    await TimerService.start(newTask.id);
    return;
  }
  final db = ref.read(databaseProvider);
  final runningTask = await db.getTaskById(running.taskId);
  if (!context.mounted) return;

  final choice = await showDialog<String>(
    context: context,
    builder: (dctx) => AlertDialog(
      title: const Text('One timer at a time ⏱'),
      content: Text(runningTask == null
          ? "You're already timing another task."
          : "You're already timing '${runningTask.name}'."),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dctx).pop('finish'),
          child: const Text('FINISH THAT ONE'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dctx).pop('discard'),
          child: const Text('DISCARD IT'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dctx).pop(null),
          child: const Text('CANCEL'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;

  switch (choice) {
    case 'finish':
      await showStopTimerSheet(context, ref);
      // Start the new timer only if the sheet actually resolved the old one.
      if (TimerService.current == null) {
        await TimerService.start(newTask.id);
      }
    case 'discard':
      await TimerService.clear();
      await TimerService.start(newTask.id);
    default:
      break; // cancelled — old timer keeps running
  }
}
