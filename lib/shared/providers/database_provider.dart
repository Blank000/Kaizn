import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';
import '../../core/services/app_prefs.dart';
import '../../core/services/shield_service.dart';

/// Global provider for the app database
/// Singleton instance accessed throughout the app
final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(() {
    database.close();
  });
  // One-time: seed an "Inbox" milestone for quick captures, but only if the
  // user has no milestones yet (don't add clutter for established users).
  Future.microtask(() => _seedInboxIfNeeded(database));
  return database;
});

Future<void> _seedInboxIfNeeded(AppDatabase db) async {
  if (await AppPrefs.isInboxSeeded()) return;
  final existing = await db.getActiveMilestones();
  if (existing.isEmpty) {
    await db.insertMilestone(MilestonesCompanion.insert(
      id: 'm${_seedRandom20()}',
      name: 'Inbox',
      description: const Value('Quick captures and miscellaneous tasks'),
    ));
  }
  await AppPrefs.markInboxSeeded();
}

String _seedRandom20() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final r = Random.secure();
  return List.generate(19, (_) => chars[r.nextInt(chars.length)]).join();
}

/// Total points balance (after reward claims and shield deductions).
final totalPointsProvider = StreamProvider<int>((ref) {
  final database = ref.watch(databaseProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) async {
    final dbTotal = await database.getTotalPoints();
    final shieldSpent = await ShieldService.getTotalSpent();
    return dbTotal - shieldSpent;
  }).asyncMap((future) => future);
});

/// All active milestones.
final activeMilestonesProvider = StreamProvider<List<Milestone>>((ref) {
  final database = ref.watch(databaseProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) async {
    return await database.getActiveMilestones();
  }).asyncMap((future) => future);
});

/// All active tasks (sub-tasks of any milestone, plus adhoc tasks).
final activeTasksProvider = StreamProvider<List<Task>>((ref) {
  final database = ref.watch(databaseProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) async {
    return await database.getAllActiveTasks();
  }).asyncMap((future) => future);
});

/// All non-archived tasks (active + completed, across milestones). Used by
/// the Stats screen so completed one-shots resolve to their names.
final allTasksProvider = StreamProvider<List<Task>>((ref) {
  final database = ref.watch(databaseProvider);
  return Stream.periodic(const Duration(seconds: 5), (_) async {
    return await database.getAllTasks();
  }).asyncMap((future) => future);
});

/// Current streak singleton.
final currentStreakProvider = StreamProvider<Streak?>((ref) {
  final database = ref.watch(databaseProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) async {
    return await database.getStreak();
  }).asyncMap((future) => future);
});

/// Unclaimed rewards.
final unclaimedRewardsProvider = StreamProvider<List<Reward>>((ref) {
  final database = ref.watch(databaseProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) async {
    return await database.getUnclaimedRewards();
  }).asyncMap((future) => future);
});

/// Claimed rewards.
final claimedRewardsProvider = StreamProvider<List<Reward>>((ref) {
  final database = ref.watch(databaseProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) async {
    return await database.getClaimedRewards();
  }).asyncMap((future) => future);
});

/// Points earned today.
final todayPointsProvider = StreamProvider<int>((ref) {
  final database = ref.watch(databaseProvider);
  return Stream.periodic(const Duration(seconds: 2), (_) async {
    return await database.getTodayPoints();
  }).asyncMap((future) => future);
});

/// Task IDs that have a real (non-skip, non-ND) completion logged today.
final todayCompletedTaskIdsProvider = StreamProvider<Set<String>>((ref) {
  final database = ref.watch(databaseProvider);
  return Stream.periodic(const Duration(seconds: 2), (_) async {
    return await database.getTaskIdsCompletedToday();
  }).asyncMap((future) => future);
});

/// Task IDs completed this calendar week (Mon–Sun). Used for weekly tasks.
final thisWeekCompletedTaskIdsProvider = StreamProvider<Set<String>>((ref) {
  final database = ref.watch(databaseProvider);
  return Stream.periodic(const Duration(seconds: 2), (_) async {
    return await database.getTaskIdsCompletedThisWeek();
  }).asyncMap((future) => future);
});

/// All non-archived tasks for a milestone (active + completed). Used by the
/// milestone detail screen so completed one-shot tasks remain visible (rendered
/// as checked).
final tasksForMilestoneProvider =
    StreamProvider.family<List<Task>, String>((ref, milestoneId) {
  final database = ref.watch(databaseProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) async {
    return await database.getAllTasksForMilestone(milestoneId);
  }).asyncMap((future) => future);
});

/// Recent (last year) completions for every task in a milestone. Used by the
/// detail screen to compute rule-based "checked this period" per task without
/// a per-task DB roundtrip on every rebuild.
final recentCompletionsForMilestoneProvider =
    StreamProvider.family<List<TaskCompletion>, String>((ref, milestoneId) {
  final database = ref.watch(databaseProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) async {
    return await database.getRecentCompletionsForMilestone(
      milestoneId,
      const Duration(days: 365),
    );
  }).asyncMap((future) => future);
});

/// Lifetime points earned (all-time, no subtraction for spending).
/// Used by the Stats screen.
final lifetimeEarnedPointsProvider = StreamProvider<int>((ref) {
  final database = ref.watch(databaseProvider);
  return Stream.periodic(const Duration(seconds: 2), (_) async {
    return await database.getLifetimeEarnedPoints();
  }).asyncMap((future) => future);
});

/// Real (non-skip, non-ND) completions logged this calendar week.
final thisWeekCompletionCountProvider = StreamProvider<int>((ref) {
  final database = ref.watch(databaseProvider);
  return Stream.periodic(const Duration(seconds: 2), (_) async {
    return await database.getThisWeekCompletionCount();
  }).asyncMap((future) => future);
});

/// Points earned this calendar week.
final thisWeekPointsProvider = StreamProvider<int>((ref) {
  final database = ref.watch(databaseProvider);
  return Stream.periodic(const Duration(seconds: 2), (_) async {
    return await database.getThisWeekPoints();
  }).asyncMap((future) => future);
});

/// Map of day → points earned for the last N days. Used by the daily-points
/// chart on the Stats screen.
final dailyPointsLastNDaysProvider =
    StreamProvider.family<Map<DateTime, int>, int>((ref, days) {
  final database = ref.watch(databaseProvider);
  return Stream.periodic(const Duration(seconds: 5), (_) async {
    return await database.getDailyPointsLastNDays(days);
  }).asyncMap((future) => future);
});

/// Map of day → completion count for the last N days. Used by the activity
/// heatmap.
final dailyCompletionsLastNDaysProvider =
    StreamProvider.family<Map<DateTime, int>, int>((ref, days) {
  final database = ref.watch(databaseProvider);
  return Stream.periodic(const Duration(seconds: 5), (_) async {
    return await database.getDailyCompletionsLastNDays(days);
  }).asyncMap((future) => future);
});

/// Map of hour-of-day (0-23) → completion count over the last N days. Used
/// by the Stats time-of-day distribution chart.
final completionsByHourProvider =
    StreamProvider.family<Map<int, int>, int>((ref, days) {
  final database = ref.watch(databaseProvider);
  return Stream.periodic(const Duration(seconds: 5), (_) async {
    return await database.getCompletionsByHour(Duration(days: days));
  }).asyncMap((future) => future);
});

/// Recent (last year) completions across all milestones. Used by the home
/// "Today" view to determine which tasks are done today and to support undo.
final recentCompletionsAllProvider =
    StreamProvider<List<TaskCompletion>>((ref) {
  final database = ref.watch(databaseProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) async {
    return await database.getRecentCompletions(const Duration(days: 365));
  }).asyncMap((future) => future);
});

/// Rewards currently claimable (balance >= threshold).
final claimableRewardsProvider = Provider<List<Reward>>((ref) {
  final unclaimed = ref.watch(unclaimedRewardsProvider).valueOrNull ?? [];
  final totalPoints = ref.watch(totalPointsProvider).valueOrNull ?? 0;
  return unclaimed.where((r) => totalPoints >= r.pointsThreshold).toList();
});
