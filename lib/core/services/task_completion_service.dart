import 'dart:async';

import '../../features/rewards/reward_unlock_service.dart';
import '../../shared/models/recurrence_rule.dart';
import '../database/database.dart';
import 'achievement_service.dart';
import 'identity_voice.dart';
import 'notification_scheduler.dart';
import 'streak_service.dart';
import 'timer_service.dart';

/// Everything a completion produced, so call sites can render their own
/// surfaces (haptics, floater, snackbar choice stay with the caller — each
/// surface presents differently on purpose).
///
/// Fields for not-yet-shipped features (clutchBonus, stackedNext,
/// identityLine) are wired now so the shape never changes underneath the
/// call sites: they hold neutral values until their feature lands.
class CompletionResult {
  final String completionId;
  final int basePoints;
  final int clutchBonus;
  final int? attachedDurationSeconds;
  final List<Task> stackedNext;
  final List<AchievementBadge> streakBadges;
  final List<AchievementBadge> completionBadges;
  final List<Reward> unlockedRewards;
  final String? identityLine;

  const CompletionResult({
    required this.completionId,
    required this.basePoints,
    this.clutchBonus = 0,
    this.attachedDurationSeconds,
    this.stackedNext = const [],
    this.streakBadges = const [],
    this.completionBadges = const [],
    this.unlockedRewards = const [],
    this.identityLine,
  });

  /// Whether a celebration surface (badge / reward snackbar) should win over
  /// the plain "Logged X + UNDO" feedback. Mirrors the celebration-beats-UNDO
  /// rule documented in app.dart.
  bool get hasCelebration =>
      streakBadges.isNotEmpty ||
      completionBadges.isNotEmpty ||
      unlockedRewards.isNotEmpty;
}

/// Single choke point for the post-completion ritual
/// (architecture_vision.md §2, decision 1).
///
/// Every "task done" mutation flows through here — tile tap, weekly chip,
/// timeline card, notification Done button, and (later) the stop-timer
/// sheet. Feature hooks (stack trigger, identity vote, clutch surfacing)
/// attach HERE exactly once instead of at every call site.
class TaskCompletionService {
  TaskCompletionService._();

  /// Complete [task] for today. Runs, in order: DB insert (points inside the
  /// same transaction) → streak advance → optional achievement/reward checks.
  ///
  /// [celebrationChecks] false preserves the notification-path behavior
  /// (background Done taps advance the streak but never surface celebration
  /// snackbars — the app may not have UI up yet).
  static Future<CompletionResult> completeToday(
    AppDatabase db,
    Task task, {
    bool celebrationChecks = true,
    int? durationSeconds,
  }) async {
    // Timer auto-attach: if THIS task's stopwatch is running, completing it
    // by any means (tile tap, chip, timeline, notification Done, stop sheet)
    // stops the timer and credits the session. Solved once here instead of
    // being five bug reports.
    var attachSeconds = durationSeconds;
    final timer = TimerService.current;
    if (attachSeconds == null && timer != null && timer.taskId == task.id) {
      attachSeconds = TimerService.cappedElapsedSeconds(timer);
      await TimerService.clear();
    }

    final outcome =
        await db.completeTaskNow(task, durationSeconds: attachSeconds);
    final streakBadges = await StreakService.recordDayLogged(db);

    var completionBadges = const <AchievementBadge>[];
    var unlockedRewards = const <Reward>[];
    if (celebrationChecks) {
      completionBadges = await AchievementService.checkAfterCompletion(db);
      unlockedRewards = await RewardUnlockService.checkAfterPointsChange(db);
    }

    final hasCelebration = streakBadges.isNotEmpty ||
        completionBadges.isNotEmpty ||
        unlockedRewards.isNotEmpty;
    final identityLine =
        await IdentityVoice.voteLineFor(db, task, masked: hasCelebration);

    final stackedNext = await _stackedNextFor(db, task);

    // Fire-and-forget: promptly retire this task's now-stale alarms (its
    // pending last-call, today's reminder) instead of waiting for the next
    // periodic tick. No-ops safely in the notification background isolate.
    unawaited(NotificationScheduler.reschedule());

    return CompletionResult(
      completionId: outcome.completionId,
      basePoints: outcome.basePoints,
      clutchBonus: outcome.clutchBonus,
      attachedDurationSeconds: attachSeconds,
      streakBadges: streakBadges,
      completionBadges: completionBadges,
      unlockedRewards: unlockedRewards,
      identityLine: identityLine,
      stackedNext: stackedNext,
    );
  }

  /// Habit stacking: tasks anchored on [task] that are surfaced by its
  /// completion — due today per their own recurrence (undated one-shots ride
  /// the anchor's schedule) and not already really done today. Single-level
  /// query, so a data-level cycle (A after B after A) can't loop: completing
  /// A surfaces B only while B is unresolved, and vice versa.
  static Future<List<Task>> _stackedNextFor(AppDatabase db, Task task) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final stacked = await db.getTasksStackedAfter(task.id);
    final out = <Task>[];
    for (final s in stacked) {
      final bool eligible;
      if (s.recurrence == TaskRecurrence.none) {
        final due = s.dueDate;
        eligible = due == null ||
            !DateTime(due.year, due.month, due.day).isAfter(today);
      } else {
        eligible = RecurrenceRule.fromTask(s).isDueOn(today);
      }
      if (!eligible) continue;
      final already = await db.getCompletionForTaskOn(s.id, now);
      if (already != null) continue;
      out.add(s);
    }
    return out;
  }

  /// Retro-log [task] on a past (or future) [date] via the weekly chip row.
  /// Points + celebration checks, but NO streak advance (that day's streak
  /// history was already determined) and no timer/stack/identity hooks.
  static Future<CompletionResult> completeOn(
    AppDatabase db,
    Task task,
    DateTime date,
  ) async {
    final outcome = await db.completeTaskOn(task, date);
    final completionBadges =
        await AchievementService.checkAfterCompletion(db);
    final unlockedRewards =
        await RewardUnlockService.checkAfterPointsChange(db);

    // Retro logs count toward the identity-vote cadence too.
    final hasCelebration =
        completionBadges.isNotEmpty || unlockedRewards.isNotEmpty;
    final identityLine =
        await IdentityVoice.voteLineFor(db, task, masked: hasCelebration);

    return CompletionResult(
      completionId: outcome.completionId,
      basePoints: outcome.basePoints,
      clutchBonus: outcome.clutchBonus,
      completionBadges: completionBadges,
      unlockedRewards: unlockedRewards,
      identityLine: identityLine,
    );
  }
}
