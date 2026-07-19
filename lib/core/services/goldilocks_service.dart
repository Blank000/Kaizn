import '../../shared/models/recurrence_rule.dart';
import '../database/database.dart';

enum GoldilocksKind { struggling, cruising }

/// One coach suggestion for the Home banner slot.
class GoldilocksSuggestion {
  final Task task;
  final GoldilocksKind kind;
  const GoldilocksSuggestion(this.task, this.kind);

  String get message => switch (kind) {
        GoldilocksKind.struggling => task.tinyName != null
            ? "'${task.name}' has slipped ${GoldilocksService.strugglingMisses} "
                "days — try the 2-minute version: '${task.tinyName}'"
            : "'${task.name}' keeps slipping — make it smaller? "
                'Add a 2-minute version',
        GoldilocksKind.cruising =>
          "'${task.name}': ${GoldilocksService.cruisingStreak} for "
              '${GoldilocksService.cruisingStreak} — ready to level it up?',
      };

  String get emoji =>
      kind == GoldilocksKind.struggling ? '⚡' : '🏆';
}

/// Goldilocks rule (Atomic Habits): habits should feel just-manageable.
/// Detects, from the user's own completion history:
///  - STRUGGLING: the last [strugglingMisses] scheduled days were all honest
///    misses (no completion, no intentional skip) → suggest shrinking via
///    the two-minute version.
///  - CRUISING: the last [cruisingStreak] scheduled days were all real
///    completions → suggest leveling up.
///
/// Pure and synchronous — computed from lists the Home screen already
/// watches; ships dormant and wakes up when the user's history triggers it.
class GoldilocksService {
  GoldilocksService._();

  static const strugglingMisses = 3;
  static const cruisingStreak = 14;
  static const _lookbackDays = 45;

  static GoldilocksSuggestion? evaluate(
    List<Task> tasks,
    List<TaskCompletion> completions,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);

    // Best status per (task, day): 'real' > 'skip' > 'nd'.
    final statusByTaskDay = <String, Map<DateTime, String>>{};
    for (final c in completions) {
      final day =
          DateTime(c.completedOn.year, c.completedOn.month, c.completedOn.day);
      final map = statusByTaskDay[c.taskId] ??= {};
      final s = !c.isSkip && !c.isNd ? 'real' : (c.isSkip ? 'skip' : 'nd');
      final cur = map[day];
      if (cur == 'real') continue;
      if (cur == 'skip' && s == 'nd') continue;
      map[day] = s;
    }

    GoldilocksSuggestion? cruising;
    for (final t in tasks) {
      if (t.status != TaskStatus.active) continue;
      if (t.recurrence == TaskRecurrence.none) continue;
      final rule = RecurrenceRule.fromTask(t);
      final dayStatus = statusByTaskDay[t.id] ?? const {};

      // Most-recent-first outcomes of scheduled days before today:
      // true = real completion, null = skip (neutral), false = honest miss.
      final outcomes = <bool?>[];
      var d = today.subtract(const Duration(days: 1));
      for (var back = 0;
          back < _lookbackDays && outcomes.length < cruisingStreak;
          back++) {
        if (rule.isDueOn(d)) {
          final s = dayStatus[d];
          outcomes.add(s == 'real' ? true : (s == 'skip' ? null : false));
        }
        d = d.subtract(const Duration(days: 1));
      }

      // Struggling wins over cruising — it's the intervention that matters.
      if (outcomes.length >= strugglingMisses &&
          outcomes.take(strugglingMisses).every((o) => o == false)) {
        return GoldilocksSuggestion(t, GoldilocksKind.struggling);
      }
      if (cruising == null &&
          outcomes.length >= cruisingStreak &&
          outcomes.every((o) => o == true)) {
        cruising = GoldilocksSuggestion(t, GoldilocksKind.cruising);
      }
    }
    return cruising;
  }
}
