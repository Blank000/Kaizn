import '../database/database.dart';
import '../../shared/models/recurrence_rule.dart';

/// Habit strength: a forgiving, long-horizon consistency score (0–100).
///
/// Loop-Habit-Tracker-style exponential smoothing over SCHEDULED days:
/// `S = S·(1−α) + α·done`, α ≈ 0.052 (≈13-occurrence half-life). Unlike a
/// streak, one miss after sixty good days barely dents it — which is the
/// point: it models the research finding (Lally 2010) that single lapses
/// don't destroy automaticity. Skipped days are excluded entirely (not
/// counted, no decay), consistent with the app's skip-vs-missed honesty.
class HabitStrength {
  HabitStrength._();

  static const double _alpha = 0.052;

  /// How many days of history to consider. Enough for the score to mature
  /// (~2 half-lives for a daily habit) without scanning years.
  static const int _windowDays = 120;

  /// 0–100 strength for a recurring task, or null when there's nothing to
  /// score yet (one-shot task, or no scheduled day has passed).
  static int? scoreFor(
    Task task,
    List<TaskCompletion> completions, {
    DateTime? now,
  }) {
    if (task.recurrence == TaskRecurrence.none) return null;
    final rule = RecurrenceRule.fromTask(task);

    final today = _dateOnly(now ?? DateTime.now());
    final windowStart = today.subtract(const Duration(days: _windowDays));

    // Index this task's completions by date for O(1) lookups.
    final realDays = <DateTime>{};
    final skipDays = <DateTime>{};
    for (final c in completions) {
      if (c.taskId != task.id) continue;
      final d = _dateOnly(c.completedOn);
      if (c.isSkip) {
        skipDays.add(d);
      } else if (!c.isNd) {
        realDays.add(d);
      }
    }

    var s = 0.0;
    var scheduledSeen = 0;
    for (var day = windowStart;
        !day.isAfter(today);
        day = day.add(const Duration(days: 1))) {
      if (!rule.isDueOn(day)) continue;
      final isToday = day.isAtSameMomentAs(today);
      final done = realDays.contains(day);
      // Today only counts once it's actually done — an unfinished today is
      // pending, not a miss.
      if (isToday && !done) continue;
      if (skipDays.contains(day) && !done) continue; // intentional rest
      scheduledSeen++;
      s = s * (1 - _alpha) + (done ? _alpha : 0);
    }

    if (scheduledSeen == 0) return null;
    return (s * 100).round().clamp(0, 100);
  }

  /// Average strength across a milestone's active recurring tasks, or null
  /// when none of them has a score yet.
  static int? milestoneAverage(
    List<Task> tasks,
    List<TaskCompletion> completions,
  ) {
    final scores = <int>[];
    for (final t in tasks) {
      if (t.status != TaskStatus.active) continue;
      final score = scoreFor(t, completions);
      if (score != null) scores.add(score);
    }
    if (scores.isEmpty) return null;
    return (scores.reduce((a, b) => a + b) / scores.length).round();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
