import 'package:drift/drift.dart' show Value;
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/recurrence_rule.dart';
import '../database/database.dart';
import 'quest_service.dart';

/// Aggregates for one closed week — the pure-function output that a future
/// backend can compute identically for cohort scoring.
class WeekAggregates {
  final DateTime weekStart;
  final int points;
  final int completions;
  final int activeDays;
  final double completionRatio;
  final int questsCompleted;

  const WeekAggregates({
    required this.weekStart,
    required this.points,
    required this.completions,
    required this.activeDays,
    required this.completionRatio,
    required this.questsCompleted,
  });
}

/// Weekly close-out: lazily, on the first app open after a week ends,
/// aggregate last week and persist it to league_weeks. Tier-free by design —
/// docs/gamification_plan.md defers tiers until real cohorts exist; the solo
/// value (trend legibility) is delivered by the recap line on Stats.
class LeagueService {
  LeagueService._();

  static const _lastCloseKey = 'league_last_closed_week';

  /// The pure aggregation — no I/O beyond the passed-in lists. A server can
  /// run the identical logic over synced change-log data later.
  static WeekAggregates aggregateWeek(
    DateTime weekStart,
    List<Task> tasks,
    List<TaskCompletion> completions,
    List<PointsHistory> pointRows,
    int questsCompleted,
  ) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    bool inWeek(DateTime d) => !d.isBefore(weekStart) && d.isBefore(weekEnd);
    bool isReal(TaskCompletion c) => !c.isSkip && !c.isNd;

    final weekReals = completions
        .where((c) => isReal(c) && inWeek(c.completedOn))
        .toList();
    final points = pointRows
        .where((r) => inWeek(r.earnedAt))
        .fold<int>(0, (sum, r) => sum + r.points);
    final activeDays = weekReals
        .map((c) => DateTime(
            c.completedOn.year, c.completedOn.month, c.completedOn.day))
        .toSet()
        .length;

    // Scheduled occurrences across the week (recurring tasks only — one-shot
    // "dueness" isn't meaningfully historical).
    var scheduled = 0;
    for (final t in tasks) {
      if (t.recurrence == TaskRecurrence.none) continue;
      final rule = RecurrenceRule.fromTask(t);
      for (var i = 0; i < 7; i++) {
        if (rule.isDueOn(weekStart.add(Duration(days: i)))) scheduled++;
      }
    }
    final ratio = scheduled == 0
        ? 0.0
        : (weekReals.length / scheduled).clamp(0.0, 1.0);

    return WeekAggregates(
      weekStart: weekStart,
      points: points,
      completions: weekReals.length,
      activeDays: activeDays,
      completionRatio: ratio,
      questsCompleted: questsCompleted,
    );
  }

  /// Close out the previous week if it hasn't been. Safe to call on every
  /// app open; runs at most once per week.
  static Future<void> maybeCloseOutLastWeek(AppDatabase db) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));
    final lastMonday = thisMonday.subtract(const Duration(days: 7));

    final p = await SharedPreferences.getInstance();
    if (p.getString(_lastCloseKey) == lastMonday.toIso8601String()) return;
    if (await db.getLeagueWeek(lastMonday) != null) {
      await p.setString(_lastCloseKey, lastMonday.toIso8601String());
      return;
    }

    final tasks = await db.getAllTasks();
    final completions =
        await db.getRecentCompletions(const Duration(days: 21));
    final pointRows = await db.getPointsSince(lastMonday);
    // Quest week counter already rolled to this week — last week's count is
    // only knowable if we closed promptly; default 0 otherwise. Good enough
    // for a tier-free recap; the future backend recomputes from its journal.
    final quests = await QuestService.questsThisWeek();

    final agg = aggregateWeek(
        lastMonday, tasks, completions, pointRows, quests);
    await db.upsertLeagueWeek(LeagueWeeksCompanion(
      weekStart: Value(agg.weekStart),
      points: Value(agg.points),
      completions: Value(agg.completions),
      activeDays: Value(agg.activeDays),
      completionRatio: Value(agg.completionRatio),
      questsCompleted: Value(agg.questsCompleted),
    ));
    await p.setString(_lastCloseKey, lastMonday.toIso8601String());
  }
}
