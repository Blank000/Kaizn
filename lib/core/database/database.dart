import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/milestones.dart';
import 'tables/tasks.dart';
import 'tables/task_completions.dart';
import 'tables/points_history.dart';
import 'tables/rewards.dart';
import 'tables/streak.dart';

// Re-export the hand-written enums so callers only need one import.
export 'tables/milestones.dart' show MilestoneStatus;
export 'tables/tasks.dart' show TaskRecurrence, TaskStatus;
export 'tables/points_history.dart' show PointsReason;

part 'database.g.dart';

/// Main database class for the Habit Reward Tracker app.
/// Uses Drift (SQLite) for local storage.
@DriftDatabase(tables: [
  Milestones,
  Tasks,
  TaskCompletions,
  PointsHistoryTable,
  Rewards,
  StreakTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // 1 → 2 was the milestone-centric schema rewrite (destructive, pre-launch).
  // 2 → 3 adds `color_index` to milestones (non-destructive).
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _initStreakSingleton();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Pre-launch v1 → v2: destructive wipe (no real users had data).
          for (final table in allTables.toList().reversed) {
            await m.deleteTable(table.actualTableName);
          }
          await m.createAll();
          await _initStreakSingleton();
          return;
        }
        if (from < 3) {
          // v2 → v3: add the color_index column to milestones, default 0.
          await m.addColumn(milestones, milestones.colorIndex);
        }
      },
    );
  }

  Future<void> _initStreakSingleton() async {
    await into(streakTable).insert(
      StreakTableCompanion.insert(id: const Value(1)),
    );
  }

  // ============ Milestones ============

  Future<List<Milestone>> getActiveMilestones() {
    return (select(milestones)
          ..where((m) => m.status.equals(MilestoneStatus.active.value))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .get();
  }

  Future<Milestone?> getMilestoneById(String id) {
    return (select(milestones)..where((m) => m.id.equals(id)))
        .getSingleOrNull();
  }

  Future<int> insertMilestone(MilestonesCompanion milestone) {
    return into(milestones).insert(milestone);
  }

  Future<bool> updateMilestone(Milestone milestone) {
    return update(milestones).replace(milestone);
  }

  Future<int> deleteMilestone(String id) {
    return (delete(milestones)..where((m) => m.id.equals(id))).go();
  }

  /// Delete a milestone, all its tasks, and all completions of those tasks.
  Future<void> deleteMilestoneCascade(String id) {
    return transaction(() async {
      final tasksUnder = await (select(tasks)
            ..where((t) => t.milestoneId.equals(id)))
          .get();
      for (final t in tasksUnder) {
        await (delete(taskCompletions)..where((c) => c.taskId.equals(t.id)))
            .go();
      }
      await (delete(tasks)..where((t) => t.milestoneId.equals(id))).go();
      await (delete(milestones)..where((m) => m.id.equals(id))).go();
    });
  }

  // ============ Tasks ============

  Future<List<Task>> getTasksForMilestone(String milestoneId) {
    return (select(tasks)
          ..where((t) =>
              t.milestoneId.equals(milestoneId) &
              t.status.equals(TaskStatus.active.value))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Like [getTasksForMilestone] but includes completed tasks too (excludes
  /// archived). Used by the milestone detail screen so completed one-shot
  /// tasks remain visible (rendered as checked).
  Future<List<Task>> getAllTasksForMilestone(String milestoneId) {
    return (select(tasks)
          ..where((t) =>
              t.milestoneId.equals(milestoneId) &
              t.status.equals(TaskStatus.archived.value).not())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// All non-archived tasks across every milestone (active + completed).
  /// Used by the Stats screen for name lookups in heatmap day-detail and
  /// top-tasks aggregation, where one-shot tasks the user has completed
  /// would otherwise be invisible.
  Future<List<Task>> getAllTasks() {
    return (select(tasks)
          ..where((t) =>
              t.status.equals(TaskStatus.archived.value).not())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<List<Task>> getAdhocTasks() {
    return (select(tasks)
          ..where((t) =>
              t.milestoneId.isNull() &
              t.status.equals(TaskStatus.active.value))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<List<Task>> getAllActiveTasks() {
    return (select(tasks)
          ..where((t) => t.status.equals(TaskStatus.active.value))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<Task?> getTaskById(String id) {
    return (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertTask(TasksCompanion task) {
    return into(tasks).insert(task);
  }

  Future<bool> updateTask(Task task) {
    return update(tasks).replace(task);
  }

  Future<int> deleteTask(String id) {
    return (delete(tasks)..where((t) => t.id.equals(id))).go();
  }

  /// Delete a task and all its completions.
  Future<void> deleteTaskCascade(String id) {
    return transaction(() async {
      await (delete(taskCompletions)..where((c) => c.taskId.equals(id))).go();
      await (delete(tasks)..where((t) => t.id.equals(id))).go();
    });
  }

  // ============ Task Completions ============

  Future<List<TaskCompletion>> getCompletionsForTask(String taskId) {
    return (select(taskCompletions)
          ..where((c) => c.taskId.equals(taskId))
          ..orderBy([(c) => OrderingTerm.desc(c.completedOn)]))
        .get();
  }

  Future<List<TaskCompletion>> getCompletionsForDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(taskCompletions)
          ..where((c) =>
              c.completedOn.isBiggerOrEqualValue(start) &
              c.completedOn.isSmallerThanValue(end)))
        .get();
  }

  /// Task IDs that have a real (non-skip, non-ND) completion logged today.
  Future<Set<String>> getTaskIdsCompletedToday() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final query = selectOnly(taskCompletions, distinct: true)
      ..addColumns([taskCompletions.taskId])
      ..where(
        taskCompletions.completedOn.isBiggerOrEqualValue(start) &
            taskCompletions.completedOn.isSmallerThanValue(end) &
            taskCompletions.isSkip.equals(false) &
            taskCompletions.isNd.equals(false),
      );
    final rows = await query.get();
    return rows.map((r) => r.read(taskCompletions.taskId)!).toSet();
  }

  /// Task IDs with a real (non-skip, non-ND) completion logged this calendar
  /// week (Mon–Sun). Used for the per-task "completed this week" check on
  /// weekly-recurring tasks.
  Future<Set<String>> getTaskIdsCompletedThisWeek() async {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));
    final query = selectOnly(taskCompletions, distinct: true)
      ..addColumns([taskCompletions.taskId])
      ..where(
        taskCompletions.completedOn.isBiggerOrEqualValue(monday) &
            taskCompletions.completedOn.isSmallerThanValue(nextMonday) &
            taskCompletions.isSkip.equals(false) &
            taskCompletions.isNd.equals(false),
      );
    final rows = await query.get();
    return rows.map((r) => r.read(taskCompletions.taskId)!).toSet();
  }

  /// Find the completion for [taskId] on the calendar day containing [day],
  /// if any. Returns null if not completed that day.
  Future<TaskCompletion?> getCompletionForTaskOn(
      String taskId, DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (select(taskCompletions)
          ..where((c) =>
              c.taskId.equals(taskId) &
              c.completedOn.isBiggerOrEqualValue(start) &
              c.completedOn.isSmallerThanValue(end) &
              c.isSkip.equals(false) &
              c.isNd.equals(false))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Find a non-skip completion for [taskId] in the half-open range
  /// [start, end). Used for rule-based period lookups (daily/weekly/monthly).
  Future<TaskCompletion?> getCompletionForTaskInRange(
    String taskId,
    DateTime start,
    DateTime end,
  ) {
    return (select(taskCompletions)
          ..where((c) =>
              c.taskId.equals(taskId) &
              c.completedOn.isBiggerOrEqualValue(start) &
              c.completedOn.isSmallerThanValue(end) &
              c.isSkip.equals(false) &
              c.isNd.equals(false))
          ..orderBy([(c) => OrderingTerm.desc(c.completedOn)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// All recent completions across every task. Used by the home (Today) view.
  Future<List<TaskCompletion>> getRecentCompletions(Duration window) {
    final cutoff = DateTime.now().subtract(window);
    return (select(taskCompletions)
          ..where((c) => c.completedOn.isBiggerOrEqualValue(cutoff)))
        .get();
  }

  /// Recent completions for every task that belongs to [milestoneId]. Used
  /// by the milestone detail screen to compute "checked-this-period" per task
  /// in one DB hit instead of N.
  Future<List<TaskCompletion>> getRecentCompletionsForMilestone(
    String milestoneId,
    Duration window,
  ) {
    final cutoff = DateTime.now().subtract(window);
    final tasksInMilestone = selectOnly(tasks)
      ..addColumns([tasks.id])
      ..where(tasks.milestoneId.equals(milestoneId));
    return (select(taskCompletions)
          ..where((c) =>
              c.completedOn.isBiggerOrEqualValue(cutoff) &
              c.taskId.isInQuery(tasksInMilestone)))
        .get();
  }

  /// Most recent completion for [taskId], if any. Used for undoing one-shot
  /// completions where the completion may not be in today's window.
  Future<TaskCompletion?> getLatestCompletionForTask(String taskId) {
    return (select(taskCompletions)
          ..where((c) =>
              c.taskId.equals(taskId) &
              c.isSkip.equals(false) &
              c.isNd.equals(false))
          ..orderBy([(c) => OrderingTerm.desc(c.completedOn)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Find the completion for [taskId] in the calendar week (Mon–Sun) containing
  /// [anyDayInWeek], if any.
  Future<TaskCompletion?> getCompletionForTaskInWeek(
      String taskId, DateTime anyDayInWeek) {
    final monday = DateTime(
            anyDayInWeek.year, anyDayInWeek.month, anyDayInWeek.day)
        .subtract(Duration(days: anyDayInWeek.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));
    return (select(taskCompletions)
          ..where((c) =>
              c.taskId.equals(taskId) &
              c.completedOn.isBiggerOrEqualValue(monday) &
              c.completedOn.isSmallerThanValue(nextMonday) &
              c.isSkip.equals(false) &
              c.isNd.equals(false))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Mark a task as skipped today: insert a `task_completion` row with
  /// `is_skip = true`. No points awarded; streak update is the caller's job
  /// (via `StreakService.recordSkipDay`).
  Future<void> skipTaskNow(Task task) {
    return transaction(() async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await into(taskCompletions).insert(
        TaskCompletionsCompanion.insert(
          id: _generateId(),
          taskId: task.id,
          completedOn: today,
          isSkip: const Value(true),
        ),
      );
    });
  }

  /// Mark a task as missed (Not Done) today: insert a `task_completion` row
  /// with `is_nd = true`. No points awarded, no streak update — ND is purely
  /// honest tracking, equivalent to "didn't do it" except the row exists.
  Future<void> markTaskMissed(Task task) {
    return transaction(() async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await into(taskCompletions).insert(
        TaskCompletionsCompanion.insert(
          id: _generateId(),
          taskId: task.id,
          completedOn: today,
          isNd: const Value(true),
        ),
      );
    });
  }

  /// Mark a task as skipped on a specific date (retro-tagging via the
  /// per-day weekly chip row). No streak update — that day's streak history
  /// was already determined.
  Future<void> skipTaskOn(Task task, DateTime date) {
    return transaction(() async {
      final dayOnly = DateTime(date.year, date.month, date.day);
      await into(taskCompletions).insert(
        TaskCompletionsCompanion.insert(
          id: _generateId(),
          taskId: task.id,
          completedOn: dayOnly,
          isSkip: const Value(true),
        ),
      );
    });
  }

  /// Mark a task as missed (Not Done) on a specific date.
  Future<void> markTaskMissedOn(Task task, DateTime date) {
    return transaction(() async {
      final dayOnly = DateTime(date.year, date.month, date.day);
      await into(taskCompletions).insert(
        TaskCompletionsCompanion.insert(
          id: _generateId(),
          taskId: task.id,
          completedOn: dayOnly,
          isNd: const Value(true),
        ),
      );
    });
  }

  /// Mark a task complete on a specific date (for retro-logging via the
  /// per-day weekly chip row). Awards points, but does NOT flip one-shot
  /// status (per-day chips don't apply to one-shots) and does not touch the
  /// streak (the caller decides whether to advance for today specifically).
  Future<void> completeTaskOn(Task task, DateTime date) {
    return transaction(() async {
      final dayOnly = DateTime(date.year, date.month, date.day);
      final completionId = _generateId();
      await into(taskCompletions).insert(
        TaskCompletionsCompanion.insert(
          id: completionId,
          taskId: task.id,
          completedOn: dayOnly,
          pointsEarned: Value(task.pointsPerCompletion),
        ),
      );
      if (task.pointsPerCompletion > 0) {
        await into(pointsHistoryTable).insert(
          PointsHistoryTableCompanion.insert(
            id: _generateId(),
            points: task.pointsPerCompletion,
            reason: PointsReason.taskCompletion,
            taskCompletionId: Value(completionId),
            taskId: Value(task.id),
          ),
        );
      }
    });
  }

  /// Mark a task complete now: insert a completion, award points, and for
  /// one-shot tasks flip status → completed. Single transaction.
  Future<void> completeTaskNow(Task task) {
    return transaction(() async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final completionId = _generateId();

      await into(taskCompletions).insert(
        TaskCompletionsCompanion.insert(
          id: completionId,
          taskId: task.id,
          completedOn: today,
          pointsEarned: Value(task.pointsPerCompletion),
        ),
      );

      if (task.pointsPerCompletion > 0) {
        await into(pointsHistoryTable).insert(
          PointsHistoryTableCompanion.insert(
            id: _generateId(),
            points: task.pointsPerCompletion,
            reason: PointsReason.taskCompletion,
            taskCompletionId: Value(completionId),
            taskId: Value(task.id),
          ),
        );
      }

      if (task.recurrence == TaskRecurrence.none) {
        await (update(tasks)..where((t) => t.id.equals(task.id))).write(
          TasksCompanion(
            status: const Value(TaskStatus.completed),
            completedAt: Value(now),
          ),
        );
      }
    });
  }

  /// Reverse a completion: delete its points_history rows, delete the
  /// completion, and (for one-shot tasks) flip status back to active.
  Future<void> undoCompletion(String completionId, String taskId) {
    return transaction(() async {
      await (delete(pointsHistoryTable)
            ..where((p) => p.taskCompletionId.equals(completionId)))
          .go();
      await (delete(taskCompletions)..where((c) => c.id.equals(completionId)))
          .go();
      final task = await (select(tasks)..where((t) => t.id.equals(taskId)))
          .getSingleOrNull();
      if (task != null && task.recurrence == TaskRecurrence.none) {
        await (update(tasks)..where((t) => t.id.equals(task.id))).write(
          const TasksCompanion(
            status: Value(TaskStatus.active),
            completedAt: Value(null),
          ),
        );
      }
    });
  }

  /// Insert a completion + record the corresponding point event in one txn.
  Future<int> insertCompletionWithPoints({
    required TaskCompletionsCompanion completion,
    required String taskId,
    required int points,
  }) {
    return transaction(() async {
      final completionId = completion.id.value;
      await into(taskCompletions).insert(
        completion.copyWith(pointsEarned: Value(points)),
      );
      if (points > 0) {
        await into(pointsHistoryTable).insert(
          PointsHistoryTableCompanion.insert(
            id: _generateId(),
            points: points,
            reason: PointsReason.taskCompletion,
            taskCompletionId: Value(completionId),
            taskId: Value(taskId),
          ),
        );
      }
      return points;
    });
  }

  /// Award a milestone-completion bonus and mark the milestone completed.
  Future<int> awardMilestoneBonus({
    required String milestoneId,
    required int bonusPoints,
  }) {
    return transaction(() async {
      final now = DateTime.now();
      await (update(milestones)..where((m) => m.id.equals(milestoneId))).write(
        MilestonesCompanion(
          status: const Value(MilestoneStatus.completed),
          completedAt: Value(now),
        ),
      );
      if (bonusPoints > 0) {
        await into(pointsHistoryTable).insert(
          PointsHistoryTableCompanion.insert(
            id: _generateId(),
            points: bonusPoints,
            reason: PointsReason.milestoneBonus,
            milestoneId: Value(milestoneId),
          ),
        );
      }
      return bonusPoints;
    });
  }

  // ============ Points History ============

  Future<int> getTotalPoints() async {
    final earnedQuery = selectOnly(pointsHistoryTable)
      ..addColumns([pointsHistoryTable.points.sum()]);
    final earned = await earnedQuery.getSingle();
    final earnedPoints = earned.read(pointsHistoryTable.points.sum()) ?? 0;

    final spentQuery = selectOnly(rewards)
      ..addColumns([rewards.pointsThreshold.sum()])
      ..where(rewards.isClaimed.equals(true));
    final spent = await spentQuery.getSingle();
    final spentPoints = spent.read(rewards.pointsThreshold.sum()) ?? 0;

    return earnedPoints - spentPoints;
  }

  Future<List<PointsHistory>> getPointsHistory({int? limit}) {
    final query = select(pointsHistoryTable)
      ..orderBy([(ph) => OrderingTerm.desc(ph.earnedAt)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  Future<int> getTodayPoints() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final query = selectOnly(pointsHistoryTable)
      ..addColumns([pointsHistoryTable.points.sum()])
      ..where(
        pointsHistoryTable.earnedAt.isBiggerOrEqualValue(start) &
            pointsHistoryTable.earnedAt.isSmallerThanValue(end),
      );
    final result = await query.getSingle();
    return result.read(pointsHistoryTable.points.sum()) ?? 0;
  }

  Future<int> getThisWeekPoints() async {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));
    final query = selectOnly(pointsHistoryTable)
      ..addColumns([pointsHistoryTable.points.sum()])
      ..where(
        pointsHistoryTable.earnedAt.isBiggerOrEqualValue(monday) &
            pointsHistoryTable.earnedAt.isSmallerThanValue(nextMonday),
      );
    final result = await query.getSingle();
    return result.read(pointsHistoryTable.points.sum()) ?? 0;
  }

  /// Lifetime cumulative points earned (sum of every points_history row).
  /// Unlike [getTotalPoints] this does NOT subtract reward spending — it's the
  /// "all-time earned" stat shown on the Stats screen.
  Future<int> getLifetimeEarnedPoints() async {
    final query = selectOnly(pointsHistoryTable)
      ..addColumns([pointsHistoryTable.points.sum()]);
    final result = await query.getSingle();
    return result.read(pointsHistoryTable.points.sum()) ?? 0;
  }

  /// Map of hour-of-day (0–23) → count of non-skip, non-ND completions
  /// recorded in that hour over the given window. Used by the Stats time-of-day
  /// chart. Hour comes from `createdAt` (the actual log timestamp, in local
  /// time), not `completedOn` which is date-only.
  Future<Map<int, int>> getCompletionsByHour(Duration window) async {
    final cutoff = DateTime.now().subtract(window);
    final rows = await (select(taskCompletions)
          ..where((c) =>
              c.createdAt.isBiggerOrEqualValue(cutoff) &
              c.isSkip.equals(false) &
              c.isNd.equals(false)))
        .get();
    final byHour = <int, int>{};
    for (final r in rows) {
      final hour = r.createdAt.hour;
      byHour[hour] = (byHour[hour] ?? 0) + 1;
    }
    return byHour;
  }

  /// Map of day → number of non-skip, non-ND completions on that day for the
  /// last [days] calendar days. Used by the activity heatmap.
  Future<Map<DateTime, int>> getDailyCompletionsLastNDays(int days) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));

    final rows = await (select(taskCompletions)
          ..where((c) =>
              c.completedOn.isBiggerOrEqualValue(startDate) &
              c.isSkip.equals(false) &
              c.isNd.equals(false)))
        .get();

    final byDay = <DateTime, int>{};
    for (final r in rows) {
      final day =
          DateTime(r.completedOn.year, r.completedOn.month, r.completedOn.day);
      byDay[day] = (byDay[day] ?? 0) + 1;
    }
    return byDay;
  }

  /// Map of day → points earned for the last [days] calendar days.
  Future<Map<DateTime, int>> getDailyPointsLastNDays(int days) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final rows = await (select(pointsHistoryTable)
          ..where((ph) => ph.earnedAt.isBiggerOrEqualValue(startDate)))
        .get();
    final byDay = <DateTime, int>{};
    for (final r in rows) {
      final day = DateTime(r.earnedAt.year, r.earnedAt.month, r.earnedAt.day);
      byDay[day] = (byDay[day] ?? 0) + r.points;
    }
    return byDay;
  }

  // ============ Rewards ============

  Future<List<Reward>> getAllRewards() {
    return (select(rewards)..orderBy([(r) => OrderingTerm.asc(r.createdAt)]))
        .get();
  }

  Future<List<Reward>> getUnclaimedRewards() {
    return (select(rewards)
          ..where((r) => r.isClaimed.equals(false))
          ..orderBy([(r) => OrderingTerm.asc(r.pointsThreshold)]))
        .get();
  }

  Future<List<Reward>> getClaimedRewards() {
    return (select(rewards)
          ..where((r) => r.isClaimed.equals(true))
          ..orderBy([(r) => OrderingTerm.desc(r.claimedAt)]))
        .get();
  }

  Future<int> insertReward(RewardsCompanion reward) {
    return into(rewards).insert(reward);
  }

  Future<bool> updateReward(Reward reward) {
    return update(rewards).replace(reward);
  }

  Future<int> deleteReward(String id) {
    return (delete(rewards)..where((r) => r.id.equals(id))).go();
  }

  // ============ Streak ============

  Future<Streak?> getStreak() {
    return (select(streakTable)..where((s) => s.id.equals(1)))
        .getSingleOrNull();
  }

  Future<bool> updateStreak(Streak streak) {
    return update(streakTable).replace(streak);
  }

  // ============ Stats / counts ============

  /// Real (non-skip, non-ND) completions ever logged.
  Future<int> getTotalCompletionCount() async {
    final query = selectOnly(taskCompletions)
      ..addColumns([taskCompletions.id])
      ..where(
        taskCompletions.isSkip.equals(false) &
            taskCompletions.isNd.equals(false),
      );
    final results = await query.get();
    return results.length;
  }

  Future<int> getTodayCompletionCount() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final query = selectOnly(taskCompletions)
      ..addColumns([taskCompletions.id])
      ..where(
        taskCompletions.isSkip.equals(false) &
            taskCompletions.isNd.equals(false) &
            taskCompletions.completedOn.isBiggerOrEqualValue(start) &
            taskCompletions.completedOn.isSmallerThanValue(end),
      );
    final results = await query.get();
    return results.length;
  }

  Future<int> getThisWeekCompletionCount() async {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));
    final query = selectOnly(taskCompletions)
      ..addColumns([taskCompletions.id])
      ..where(
        taskCompletions.completedOn.isBiggerOrEqualValue(monday) &
            taskCompletions.completedOn.isSmallerThanValue(nextMonday) &
            taskCompletions.isSkip.equals(false) &
            taskCompletions.isNd.equals(false),
      );
    final results = await query.get();
    return results.length;
  }
}

String _generateId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random.secure();
  return List.generate(20, (_) => chars[random.nextInt(chars.length)]).join();
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'habit_reward_tracker');
}
