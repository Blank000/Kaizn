import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/change_log.dart';
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
/// Outcome of a completion insert, returned so callers/services can surface
/// points without a re-query. `clutchBonus` stays 0 until the last-call +
/// clutch feature (Wave 2 of the Atomic Habits plan) fills it in.
typedef DbCompletionOutcome = ({
  String completionId,
  int basePoints,
  int clutchBonus,
});

@DriftDatabase(tables: [
  Milestones,
  Tasks,
  TaskCompletions,
  PointsHistoryTable,
  Rewards,
  StreakTable,
  ChangeLog,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // 1 → 2 was the milestone-centric schema rewrite (destructive, pre-launch).
  // 2 → 3 adds `color_index` to milestones (non-destructive).
  // 3 → 4 adds `start_minute` + `duration_minutes` to tasks for timeline view.
  // 4 → 5 adds `reminder_enabled` + `reminder_minute` to tasks for per-task
  //        reminder notifications.
  // 5 → 6 adds `reminder_date` to tasks — when set, the reminder is a one-shot
  //        nudge on that specific date (ignoring recurrence).
  // 6 → 7 Atomic Habits wave batch: `stacked_after_task_id` on tasks (habit
  //        stacking), `duration_seconds` on task_completions (stopwatch),
  //        `identity` on milestones (identity-based habits), and the new
  //        `change_log` journal table (auto-backup/sync/outbox foundation).
  @override
  int get schemaVersion => 7;

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
        if (from < 4) {
          // v3 → v4: add scheduling columns to tasks.
          await m.addColumn(tasks, tasks.startMinute);
          await m.addColumn(tasks, tasks.durationMinutes);
        }
        if (from < 5) {
          // v4 → v5: add per-task reminder columns.
          await m.addColumn(tasks, tasks.reminderEnabled);
          await m.addColumn(tasks, tasks.reminderMinute);
        }
        if (from < 6) {
          // v5 → v6: add one-shot reminder date, nullable.
          await m.addColumn(tasks, tasks.reminderDate);
        }
        if (from < 7) {
          // v6 → v7: Atomic Habits wave — single batched migration.
          await m.addColumn(tasks, tasks.stackedAfterTaskId);
          await m.addColumn(taskCompletions, taskCompletions.durationSeconds);
          await m.addColumn(milestones, milestones.identity);
          await m.createTable(changeLog);
        }
      },
    );
  }

  // ============ Change log (append-only mutation journal) ============

  /// Record a mutation in the journal. Called inside the same transaction as
  /// the write it describes wherever one exists. See tables/change_log.dart
  /// for what this powers (auto-backup now; sync/outbox later).
  Future<void> _logChange(
    String entityType,
    String entityId,
    String op, {
    Map<String, Object?>? payload,
  }) {
    return into(changeLog).insert(ChangeLogCompanion.insert(
      entityType: entityType,
      entityId: entityId,
      op: op,
      payloadJson: Value(payload == null ? null : jsonEncode(payload)),
    ));
  }

  /// Newest journal sequence number, or 0 when empty. Cheap; lets callers
  /// (debounced auto-backup, future sync) detect "anything changed since X?".
  Future<int> latestChangeSeq() async {
    final query = selectOnly(changeLog)
      ..addColumns([changeLog.seq.max()]);
    final row = await query.getSingle();
    return row.read(changeLog.seq.max()) ?? 0;
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

  Future<int> insertMilestone(MilestonesCompanion milestone) async {
    final result = await into(milestones).insert(milestone);
    await _logChange('milestone', milestone.id.value, 'create',
        payload: {'name': milestone.name.value});
    return result;
  }

  Future<bool> updateMilestone(Milestone milestone) async {
    final result = await update(milestones).replace(milestone);
    await _logChange('milestone', milestone.id, 'update',
        payload: {'name': milestone.name});
    return result;
  }

  Future<int> deleteMilestone(String id) async {
    final result =
        await (delete(milestones)..where((m) => m.id.equals(id))).go();
    await _logChange('milestone', id, 'delete');
    return result;
  }

  /// Delete a milestone, all its tasks, and all completions of those tasks.
  /// Clears habit-stacking references pointing at any deleted task.
  Future<void> deleteMilestoneCascade(String id) {
    return transaction(() async {
      final tasksUnder = await (select(tasks)
            ..where((t) => t.milestoneId.equals(id)))
          .get();
      final taskIds = tasksUnder.map((t) => t.id).toList();
      if (taskIds.isNotEmpty) {
        await (update(tasks)
              ..where((t) => t.stackedAfterTaskId.isIn(taskIds)))
            .write(const TasksCompanion(stackedAfterTaskId: Value(null)));
      }
      for (final t in tasksUnder) {
        await (delete(taskCompletions)..where((c) => c.taskId.equals(t.id)))
            .go();
      }
      await (delete(tasks)..where((t) => t.milestoneId.equals(id))).go();
      await (delete(milestones)..where((m) => m.id.equals(id))).go();
      await _logChange('milestone', id, 'delete',
          payload: {'cascadedTasks': taskIds.length});
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

  /// Active tasks stacked after [anchorTaskId] (habit stacking). Single-level
  /// query — chains resolve stepwise as each link completes.
  Future<List<Task>> getTasksStackedAfter(String anchorTaskId) {
    return (select(tasks)
          ..where((t) =>
              t.stackedAfterTaskId.equals(anchorTaskId) &
              t.status.equals(TaskStatus.active.value)))
        .get();
  }

  Future<int> insertTask(TasksCompanion task) async {
    final result = await into(tasks).insert(task);
    await _logChange('task', task.id.value, 'create',
        payload: {'name': task.name.value});
    return result;
  }

  Future<bool> updateTask(Task task) async {
    final result = await update(tasks).replace(task);
    await _logChange('task', task.id, 'update', payload: {'name': task.name});
    return result;
  }

  Future<int> deleteTask(String id) {
    return (delete(tasks)..where((t) => t.id.equals(id))).go();
  }

  /// Set the timeline start time for a task. Pass null to unschedule (move
  /// to the Anytime tray).
  Future<void> setTaskStartMinute(String taskId, int? minute) {
    return (update(tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(startMinute: Value(minute)),
    );
  }

  /// Set the timeline duration for a task (in minutes).
  Future<void> setTaskDurationMinutes(String taskId, int minutes) {
    return (update(tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(durationMinutes: Value(minutes)),
    );
  }

  /// Delete a task and all its completions. Clears any habit-stacking
  /// references pointing at it so no dangling anchor ids survive.
  Future<void> deleteTaskCascade(String id) {
    return transaction(() async {
      await (update(tasks)..where((t) => t.stackedAfterTaskId.equals(id)))
          .write(const TasksCompanion(stackedAfterTaskId: Value(null)));
      await (delete(taskCompletions)..where((c) => c.taskId.equals(id))).go();
      await (delete(tasks)..where((t) => t.id.equals(id))).go();
      await _logChange('task', id, 'delete');
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
      final id = _generateId();
      await into(taskCompletions).insert(
        TaskCompletionsCompanion.insert(
          id: id,
          taskId: task.id,
          completedOn: today,
          isSkip: const Value(true),
        ),
      );
      await _logChange('completion', id, 'create',
          payload: {'taskId': task.id, 'kind': 'skip'});
    });
  }

  /// Mark a task as missed (Not Done) today: insert a `task_completion` row
  /// with `is_nd = true`. No points awarded, no streak update — ND is purely
  /// honest tracking, equivalent to "didn't do it" except the row exists.
  Future<void> markTaskMissed(Task task) {
    return transaction(() async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final id = _generateId();
      await into(taskCompletions).insert(
        TaskCompletionsCompanion.insert(
          id: id,
          taskId: task.id,
          completedOn: today,
          isNd: const Value(true),
        ),
      );
      await _logChange('completion', id, 'create',
          payload: {'taskId': task.id, 'kind': 'missed'});
    });
  }

  /// Mark a task as skipped on a specific date (retro-tagging via the
  /// per-day weekly chip row). No streak update — that day's streak history
  /// was already determined.
  Future<void> skipTaskOn(Task task, DateTime date) {
    return transaction(() async {
      final dayOnly = DateTime(date.year, date.month, date.day);
      final id = _generateId();
      await into(taskCompletions).insert(
        TaskCompletionsCompanion.insert(
          id: id,
          taskId: task.id,
          completedOn: dayOnly,
          isSkip: const Value(true),
        ),
      );
      await _logChange('completion', id, 'create',
          payload: {'taskId': task.id, 'kind': 'skip'});
    });
  }

  /// Mark a task as missed (Not Done) on a specific date.
  Future<void> markTaskMissedOn(Task task, DateTime date) {
    return transaction(() async {
      final dayOnly = DateTime(date.year, date.month, date.day);
      final id = _generateId();
      await into(taskCompletions).insert(
        TaskCompletionsCompanion.insert(
          id: id,
          taskId: task.id,
          completedOn: dayOnly,
          isNd: const Value(true),
        ),
      );
      await _logChange('completion', id, 'create',
          payload: {'taskId': task.id, 'kind': 'missed'});
    });
  }

  /// Mark a task complete on a specific date (for retro-logging via the
  /// per-day weekly chip row). Awards points, but does NOT flip one-shot
  /// status (per-day chips don't apply to one-shots) and does not touch the
  /// streak (the caller decides whether to advance for today specifically).
  Future<DbCompletionOutcome> completeTaskOn(Task task, DateTime date,
      {int? durationSeconds}) {
    return transaction(() async {
      final dayOnly = DateTime(date.year, date.month, date.day);
      final completionId = _generateId();
      await into(taskCompletions).insert(
        TaskCompletionsCompanion.insert(
          id: completionId,
          taskId: task.id,
          completedOn: dayOnly,
          pointsEarned: Value(task.pointsPerCompletion),
          durationSeconds: Value.absentIfNull(durationSeconds),
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
      await _logChange('completion', completionId, 'create', payload: {
        'taskId': task.id,
        'on': dayOnly.toIso8601String(),
        'points': task.pointsPerCompletion,
      });
      return (
        completionId: completionId,
        basePoints: task.pointsPerCompletion,
        clutchBonus: 0,
      );
    });
  }

  /// Bonus for completing a task inside the clutch zone of its window.
  static const int clutchBonusPoints = 5;

  /// Whether completing [task] at [now] lands in the "clutch zone" — the
  /// last 20% of its scheduled window, never after the window closes.
  /// Windowless tasks never clutch (v1: honest beat-the-buzzer only; an
  /// anytime-evening rule would inflate points for night loggers).
  static bool isClutchTime(Task task, DateTime now) {
    final start = task.startMinute;
    if (start == null) return false;
    final duration = task.durationMinutes;
    if (duration <= 0) return false;
    final nowMin = now.hour * 60 + now.minute;
    final end = start + duration;
    final clutchStart = start + (duration * 0.8).floor();
    return nowMin >= clutchStart && nowMin <= end;
  }

  /// Mark a task complete now: insert a completion, award points (+clutch
  /// bonus when earned), and for one-shot tasks flip status → completed.
  /// Single transaction. The bonus row carries taskCompletionId, so
  /// [undoCompletion]'s delete-by-completion refunds it automatically.
  Future<DbCompletionOutcome> completeTaskNow(Task task,
      {int? durationSeconds}) {
    return transaction(() async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final completionId = _generateId();
      final clutch = isClutchTime(task, now) ? clutchBonusPoints : 0;

      await into(taskCompletions).insert(
        TaskCompletionsCompanion.insert(
          id: completionId,
          taskId: task.id,
          completedOn: today,
          pointsEarned: Value(task.pointsPerCompletion),
          durationSeconds: Value.absentIfNull(durationSeconds),
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

      if (clutch > 0) {
        await into(pointsHistoryTable).insert(
          PointsHistoryTableCompanion.insert(
            id: _generateId(),
            points: clutch,
            reason: PointsReason.clutchBonus,
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

      await _logChange('completion', completionId, 'create', payload: {
        'taskId': task.id,
        'on': today.toIso8601String(),
        'points': task.pointsPerCompletion,
        if (clutch > 0) 'clutchBonus': clutch,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
      });

      return (
        completionId: completionId,
        basePoints: task.pointsPerCompletion,
        clutchBonus: clutch,
      );
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
      await _logChange('completion', completionId, 'delete',
          payload: {'taskId': taskId});
    });
  }

  /// Add stopwatch seconds to an existing completion (stop-timer sheet's
  /// "ADD TIME" path when the task was already completed today). Accumulates
  /// on top of any previously-attached duration.
  Future<void> addDurationToCompletion(String completionId, int seconds) {
    return transaction(() async {
      final existing = await (select(taskCompletions)
            ..where((c) => c.id.equals(completionId)))
          .getSingleOrNull();
      if (existing == null) return;
      final total = (existing.durationSeconds ?? 0) + seconds;
      await (update(taskCompletions)
            ..where((c) => c.id.equals(completionId)))
          .write(TaskCompletionsCompanion(durationSeconds: Value(total)));
      await _logChange('completion', completionId, 'update',
          payload: {'durationSeconds': total});
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
      await _logChange('milestone', milestoneId, 'update',
          payload: {'completed': true, 'bonus': bonusPoints});
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

  Future<int> insertReward(RewardsCompanion reward) async {
    final result = await into(rewards).insert(reward);
    await _logChange('reward', reward.id.value, 'create',
        payload: {'name': reward.name.value});
    return result;
  }

  Future<bool> updateReward(Reward reward) async {
    final result = await update(rewards).replace(reward);
    await _logChange('reward', reward.id, 'update',
        payload: {'name': reward.name, 'claimed': reward.isClaimed});
    return result;
  }

  Future<int> deleteReward(String id) async {
    final result = await (delete(rewards)..where((r) => r.id.equals(id))).go();
    await _logChange('reward', id, 'delete');
    return result;
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

  /// Real (non-skip, non-ND) completions ever logged for one task. The
  /// identity-vote cadence counter — deliberately an all-time running tally,
  /// not per-period, so vote moments land on stable multiples.
  Future<int> getRealCompletionCountForTask(String taskId) async {
    final query = selectOnly(taskCompletions)
      ..addColumns([taskCompletions.id.count()])
      ..where(
        taskCompletions.taskId.equals(taskId) &
            taskCompletions.isSkip.equals(false) &
            taskCompletions.isNd.equals(false),
      );
    final row = await query.getSingle();
    return row.read(taskCompletions.id.count()) ?? 0;
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

  // ============ Reactive streams (Drift .watch) ============
  //
  // These are the read paths the UI subscribes to. Each returns a Drift
  // stream that emits ONLY when its underlying table(s) change — no polling.
  // Previously the app polled every 1-2s per provider (~5 queries/second on
  // Home), which was the main source of lag; these eliminate that entirely.
  //
  // Aggregate streams (int, Map) are derived from the base row-list streams
  // in Dart via `map()` instead of watching a separate SQL aggregate — keeps
  // the code simple and avoids extra queries when the same rows already flow
  // through another provider (Drift dedupes at the query layer).

  Stream<List<Milestone>> watchActiveMilestones() {
    return (select(milestones)
          ..where((m) => m.status.equals(MilestoneStatus.active.value))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .watch();
  }

  Stream<List<Task>> watchAllActiveTasks() {
    return (select(tasks)
          ..where((t) => t.status.equals(TaskStatus.active.value))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Stream<List<Task>> watchAllTasks() {
    return (select(tasks)
          ..where((t) => t.status.equals(TaskStatus.archived.value).not())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Stream<List<Task>> watchAllTasksForMilestone(String milestoneId) {
    return (select(tasks)
          ..where((t) =>
              t.milestoneId.equals(milestoneId) &
              t.status.equals(TaskStatus.archived.value).not())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Stream<Streak?> watchStreak() =>
      (select(streakTable)..where((s) => s.id.equals(1))).watchSingleOrNull();

  Stream<List<Reward>> watchUnclaimedRewards() {
    return (select(rewards)
          ..where((r) => r.isClaimed.equals(false))
          ..orderBy([(r) => OrderingTerm.asc(r.pointsThreshold)]))
        .watch();
  }

  Stream<List<Reward>> watchClaimedRewards() {
    return (select(rewards)
          ..where((r) => r.isClaimed.equals(true))
          ..orderBy([(r) => OrderingTerm.desc(r.claimedAt)]))
        .watch();
  }

  Stream<List<TaskCompletion>> watchRecentCompletions(Duration window) {
    final cutoff = DateTime.now().subtract(window);
    return (select(taskCompletions)
          ..where((c) => c.completedOn.isBiggerOrEqualValue(cutoff)))
        .watch();
  }

  Stream<List<TaskCompletion>> watchRecentCompletionsForMilestone(
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
        .watch();
  }

  /// Points balance: sum(points_history.points) - sum(claimed reward
  /// thresholds). Watches both underlying tables via customSelect so it
  /// re-fires whenever either changes.
  Stream<int> watchTotalPoints() {
    return customSelect(
      "SELECT "
      "COALESCE((SELECT SUM(points) FROM points_history), 0) - "
      "COALESCE((SELECT SUM(points_threshold) FROM rewards WHERE is_claimed = 1), 0) "
      "AS balance",
      readsFrom: {pointsHistoryTable, rewards},
    ).watchSingle().map((r) => r.read<int>('balance'));
  }

  Stream<int> watchTodayPoints() {
    return customSelect(
      "SELECT COALESCE(SUM(points), 0) AS total FROM points_history "
      "WHERE earned_at >= :start AND earned_at < :end",
      variables: [
        Variable.withDateTime(_dayStart(DateTime.now())),
        Variable.withDateTime(_dayEnd(DateTime.now())),
      ],
      readsFrom: {pointsHistoryTable},
    ).watchSingle().map((r) => r.read<int>('total'));
  }

  Stream<int> watchLifetimeEarnedPoints() {
    return customSelect(
      "SELECT COALESCE(SUM(points), 0) AS total FROM points_history",
      readsFrom: {pointsHistoryTable},
    ).watchSingle().map((r) => r.read<int>('total'));
  }

  Stream<int> watchThisWeekPoints() {
    final now = DateTime.now();
    final monday = _dayStart(now).subtract(Duration(days: now.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));
    return customSelect(
      "SELECT COALESCE(SUM(points), 0) AS total FROM points_history "
      "WHERE earned_at >= :start AND earned_at < :end",
      variables: [
        Variable.withDateTime(monday),
        Variable.withDateTime(nextMonday),
      ],
      readsFrom: {pointsHistoryTable},
    ).watchSingle().map((r) => r.read<int>('total'));
  }

  Stream<int> watchThisWeekCompletionCount() {
    final now = DateTime.now();
    final monday = _dayStart(now).subtract(Duration(days: now.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));
    return customSelect(
      "SELECT COUNT(*) AS c FROM task_completions "
      "WHERE completed_on >= :start AND completed_on < :end "
      "AND is_skip = 0 AND is_nd = 0",
      variables: [
        Variable.withDateTime(monday),
        Variable.withDateTime(nextMonday),
      ],
      readsFrom: {taskCompletions},
    ).watchSingle().map((r) => r.read<int>('c'));
  }

  /// Live version of [getTaskIdsCompletedToday]. Emits a fresh set whenever a
  /// completion is inserted/deleted.
  Stream<Set<String>> watchTaskIdsCompletedToday() {
    final now = DateTime.now();
    return (select(taskCompletions)
          ..where((c) =>
              c.completedOn.isBiggerOrEqualValue(_dayStart(now)) &
              c.completedOn.isSmallerThanValue(_dayEnd(now)) &
              c.isSkip.equals(false) &
              c.isNd.equals(false)))
        .watch()
        .map((rows) => rows.map((r) => r.taskId).toSet());
  }

  Stream<Set<String>> watchTaskIdsCompletedThisWeek() {
    final now = DateTime.now();
    final monday = _dayStart(now).subtract(Duration(days: now.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));
    return (select(taskCompletions)
          ..where((c) =>
              c.completedOn.isBiggerOrEqualValue(monday) &
              c.completedOn.isSmallerThanValue(nextMonday) &
              c.isSkip.equals(false) &
              c.isNd.equals(false)))
        .watch()
        .map((rows) => rows.map((r) => r.taskId).toSet());
  }

  Stream<Map<DateTime, int>> watchDailyPointsLastNDays(int days) {
    final startDate =
        _dayStart(DateTime.now()).subtract(Duration(days: days - 1));
    return (select(pointsHistoryTable)
          ..where((ph) => ph.earnedAt.isBiggerOrEqualValue(startDate)))
        .watch()
        .map((rows) {
      final byDay = <DateTime, int>{};
      for (final r in rows) {
        final day = DateTime(r.earnedAt.year, r.earnedAt.month, r.earnedAt.day);
        byDay[day] = (byDay[day] ?? 0) + r.points;
      }
      return byDay;
    });
  }

  Stream<Map<DateTime, int>> watchDailyCompletionsLastNDays(int days) {
    final startDate =
        _dayStart(DateTime.now()).subtract(Duration(days: days - 1));
    return (select(taskCompletions)
          ..where((c) =>
              c.completedOn.isBiggerOrEqualValue(startDate) &
              c.isSkip.equals(false) &
              c.isNd.equals(false)))
        .watch()
        .map((rows) {
      final byDay = <DateTime, int>{};
      for (final r in rows) {
        final day = DateTime(
            r.completedOn.year, r.completedOn.month, r.completedOn.day);
        byDay[day] = (byDay[day] ?? 0) + 1;
      }
      return byDay;
    });
  }

  Stream<Map<int, int>> watchCompletionsByHour(Duration window) {
    final cutoff = DateTime.now().subtract(window);
    return (select(taskCompletions)
          ..where((c) =>
              c.createdAt.isBiggerOrEqualValue(cutoff) &
              c.isSkip.equals(false) &
              c.isNd.equals(false)))
        .watch()
        .map((rows) {
      final byHour = <int, int>{};
      for (final r in rows) {
        byHour[r.createdAt.hour] = (byHour[r.createdAt.hour] ?? 0) + 1;
      }
      return byHour;
    });
  }

  static DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _dayEnd(DateTime d) =>
      _dayStart(d).add(const Duration(days: 1));
}

String _generateId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random.secure();
  return List.generate(20, (_) => chars[random.nextInt(chars.length)]).join();
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'habit_reward_tracker');
}
