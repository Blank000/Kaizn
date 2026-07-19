import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/recurrence_rule.dart';
import '../database/database.dart';
import 'cosmetics_service.dart';
import 'goldilocks_service.dart';

/// One day's quest. De-fanged by design (gamification_plan.md §2):
///  - ONE quest per day, chosen by a feasibility filter so it is satisfiable
///    by tasks the user ALREADY planned — never "do an extra thing";
///  - an incomplete quest has NO missed state, no red, no failure history —
///    tomorrow is simply a different quest;
///  - quests never touch or reference the streak (one loss-aversion stake in
///    the app is enough).
class Quest {
  final String id;
  final String emoji;
  final String title;
  final int target;
  final int bonus;

  const Quest({
    required this.id,
    required this.emoji,
    required this.title,
    required this.target,
    required this.bonus,
  });
}

/// Live status for the quest row on Home.
class QuestStatus {
  final Quest quest;
  final int progress;
  final bool done;

  /// Daily quests completed this week (Mon–Sun), for the 5-of-7 chain dots.
  final int weekCount;

  /// Chain complete and the chest not yet opened.
  final bool chestReady;

  const QuestStatus({
    required this.quest,
    required this.progress,
    required this.done,
    required this.weekCount,
    required this.chestReady,
  });
}

/// The chest payout, surfaced by the UI after [claimChest].
class ChestReward {
  final int points;
  final Cosmetic? cosmetic;
  const ChestReward(this.points, this.cosmetic);
}

class QuestService {
  QuestService._();

  static const chestPoints = 50; // FIXED — never randomized.
  static const chestChainTarget = 5; // 5 of 7 days = 2 free misses.

  static const _dateKey = 'quest_date';
  static const _idKey = 'quest_id';
  static const _doneKey = 'quest_done';
  static const _weekStartKey = 'quest_week_start';
  static const _weekCountKey = 'quest_week_count';
  static const _chestClaimedKey = 'quest_chest_claimed_week';

  // ── Quest pool ─────────────────────────────────────────────────────────

  static const _completeThree = Quest(
      id: 'complete3',
      emoji: '✅',
      title: 'Complete 3 tasks',
      target: 3,
      bonus: 20);
  static const _completeTwo = Quest(
      id: 'complete2',
      emoji: '✅',
      title: 'Complete 2 tasks',
      target: 2,
      bonus: 15);
  static const _beforeNoon = Quest(
      id: 'beforeNoon',
      emoji: '🌅',
      title: 'Finish a task before noon',
      target: 1,
      bonus: 15);
  static const _timer30 = Quest(
      id: 'timer30',
      emoji: '⏱',
      title: 'Track 30 timer minutes',
      target: 30,
      bonus: 20);
  static const _clearMilestone = Quest(
      id: 'clearMilestone',
      emoji: '🎯',
      title: "Clear one milestone's tasks today",
      target: 1,
      bonus: 25);
  static const _struggler = Quest(
      id: 'struggler',
      emoji: '⚡',
      title: 'Do the habit that slipped',
      target: 1,
      bonus: 25);
  static const _justShowUp = Quest(
      id: 'justShowUp',
      emoji: '🌱',
      title: 'Just show up — complete anything',
      target: 1,
      bonus: 10);

  // ── Selection ──────────────────────────────────────────────────────────

  /// Today's quest, selecting one on the first call of the day. Returns null
  /// when there is nothing due today (no quest on an empty day — quests are
  /// a byproduct of the user's own plan, never extra homework).
  static Future<QuestStatus?> today(
    AppDatabase db,
    List<Task> tasks,
    List<TaskCompletion> completions,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final p = await SharedPreferences.getInstance();

    await _rollWeekIfNeeded(p, today);

    final dueToday = _dueToday(tasks, today);
    Quest? quest;
    final storedDate = p.getString(_dateKey);
    if (storedDate == today.toIso8601String()) {
      quest = _byId(p.getString(_idKey));
    }
    if (quest == null) {
      quest = _select(now, tasks, completions, dueToday);
      if (quest == null) return null;
      await p.setString(_dateKey, today.toIso8601String());
      await p.setString(_idKey, quest.id);
      await p.setBool(_doneKey, false);
    }

    final progress = _progress(quest, tasks, completions, now);
    final done = p.getBool(_doneKey) ?? false;
    final weekCount = p.getInt(_weekCountKey) ?? 0;
    final chestClaimed =
        p.getString(_chestClaimedKey) == _mondayOf(today).toIso8601String();

    return QuestStatus(
      quest: quest,
      progress: progress.clamp(0, quest.target),
      done: done,
      weekCount: weekCount,
      chestReady: weekCount >= chestChainTarget && !chestClaimed,
    );
  }

  /// Called by TaskCompletionService after every real completion. When the
  /// quest crosses its target for the first time today: marks it done, bumps
  /// the weekly chain, banks the FIXED bonus. Returns the completed quest
  /// (for the snackbar) or null.
  static Future<Quest?> onCompletion(
    AppDatabase db,
    List<Task> tasks,
    List<TaskCompletion> completions,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final p = await SharedPreferences.getInstance();

    if (p.getString(_dateKey) != today.toIso8601String()) return null;
    if (p.getBool(_doneKey) ?? false) return null;
    final quest = _byId(p.getString(_idKey));
    if (quest == null) return null;

    if (_progress(quest, tasks, completions, now) < quest.target) return null;

    await p.setBool(_doneKey, true);
    await _rollWeekIfNeeded(p, today);
    await p.setInt(_weekCountKey, (p.getInt(_weekCountKey) ?? 0) + 1);
    await db.insertBonusPoints(quest.bonus, PointsReason.questBonus);
    return quest;
  }

  /// Open the weekly chest: fixed points + the next cosmetic on the track.
  static Future<ChestReward?> claimChest(AppDatabase db) async {
    final now = DateTime.now();
    final monday = _mondayOf(DateTime(now.year, now.month, now.day));
    final p = await SharedPreferences.getInstance();
    if ((p.getInt(_weekCountKey) ?? 0) < chestChainTarget) return null;
    if (p.getString(_chestClaimedKey) == monday.toIso8601String()) return null;

    await p.setString(_chestClaimedKey, monday.toIso8601String());
    await db.insertBonusPoints(chestPoints, PointsReason.chestBonus);
    final cosmetic = await CosmeticsService.unlockNext();
    return ChestReward(chestPoints, cosmetic);
  }

  /// Daily quests completed this week — persisted into league_weeks at
  /// close-out.
  static Future<int> questsThisWeek() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_weekCountKey) ?? 0;
  }

  // ── Internals ──────────────────────────────────────────────────────────

  static Quest? _byId(String? id) => [
        _completeThree,
        _completeTwo,
        _beforeNoon,
        _timer30,
        _clearMilestone,
        _struggler,
        _justShowUp,
      ].where((q) => q.id == id).firstOrNull;

  static DateTime _mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  static Future<void> _rollWeekIfNeeded(
      SharedPreferences p, DateTime today) async {
    final monday = _mondayOf(today).toIso8601String();
    if (p.getString(_weekStartKey) != monday) {
      await p.setString(_weekStartKey, monday);
      await p.setInt(_weekCountKey, 0);
    }
  }

  static List<Task> _dueToday(List<Task> tasks, DateTime today) {
    return tasks.where((t) {
      if (t.status != TaskStatus.active) return false;
      if (t.recurrence == TaskRecurrence.none) {
        final due = t.dueDate;
        return due == null ||
            !DateTime(due.year, due.month, due.day).isAfter(today);
      }
      return RecurrenceRule.fromTask(t).isDueOn(today);
    }).toList();
  }

  /// Feasibility-filtered deterministic pick. Every offered quest is
  /// satisfiable by the day's EXISTING plan.
  static Quest? _select(
    DateTime now,
    List<Task> tasks,
    List<TaskCompletion> completions,
    List<Task> dueToday,
  ) {
    if (dueToday.isEmpty) return null;
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    bool isReal(TaskCompletion c) => !c.isSkip && !c.isNd;
    DateTime dayOf(TaskCompletion c) =>
        DateTime(c.completedOn.year, c.completedOn.month, c.completedOn.day);

    final yesterdayHadNothing = !completions
        .any((c) => isReal(c) && dayOf(c).isAtSameMomentAs(yesterday));

    // Recovery day: the gentlest quest, always.
    if (yesterdayHadNothing) return _justShowUp;

    final feasible = <Quest>[
      if (dueToday.length >= 3) _completeThree,
      if (dueToday.length == 2) _completeTwo,
      // Only fair if the day still has a morning left when selected.
      if (now.hour < 11) _beforeNoon,
      // Only offered to users who actually use the timer.
      if (completions.any((c) =>
          (c.durationSeconds ?? 0) > 0 &&
          c.completedOn.isAfter(today.subtract(const Duration(days: 14)))))
        _timer30,
      // A milestone with a small, clearable set due today.
      if (_clearableMilestoneId(tasks, dueToday) != null) _clearMilestone,
      if (GoldilocksService.evaluate(tasks, completions, now)?.kind ==
          GoldilocksKind.struggling)
        _struggler,
    ];
    if (feasible.isEmpty) return _justShowUp;

    // Deterministic per-day rotation — no randomness in what's asked of you.
    final seed = today.day + today.month * 31;
    return feasible[seed % feasible.length];
  }

  static String? _clearableMilestoneId(
      List<Task> tasks, List<Task> dueToday) {
    final byMilestone = <String, int>{};
    for (final t in dueToday) {
      final m = t.milestoneId;
      if (m != null) byMilestone[m] = (byMilestone[m] ?? 0) + 1;
    }
    for (final e in byMilestone.entries) {
      if (e.value >= 1 && e.value <= 4) return e.key;
    }
    return null;
  }

  static int _progress(
    Quest quest,
    List<Task> tasks,
    List<TaskCompletion> completions,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    bool isReal(TaskCompletion c) => !c.isSkip && !c.isNd;
    bool onToday(TaskCompletion c) =>
        c.completedOn.year == today.year &&
        c.completedOn.month == today.month &&
        c.completedOn.day == today.day;
    final todayReals =
        completions.where((c) => isReal(c) && onToday(c)).toList();

    switch (quest.id) {
      case 'complete3':
      case 'complete2':
        return todayReals.length;
      case 'beforeNoon':
        return todayReals.any((c) => c.createdAt.hour < 12) ? 1 : 0;
      case 'timer30':
        final secs = todayReals.fold<int>(
            0, (sum, c) => sum + (c.durationSeconds ?? 0));
        return secs ~/ 60;
      case 'clearMilestone':
        final dueToday = _dueToday(tasks, today);
        final doneIds = todayReals.map((c) => c.taskId).toSet();
        final byMilestone = <String, List<Task>>{};
        for (final t in dueToday) {
          final m = t.milestoneId;
          if (m != null) (byMilestone[m] ??= []).add(t);
        }
        for (final group in byMilestone.values) {
          if (group.isNotEmpty &&
              group.every((t) => doneIds.contains(t.id))) {
            return 1;
          }
        }
        return 0;
      case 'struggler':
        final suggestion =
            GoldilocksService.evaluate(tasks, completions, now);
        if (suggestion == null ||
            suggestion.kind != GoldilocksKind.struggling) {
          // The struggling task was completed today → Goldilocks no longer
          // flags it → quest satisfied if anything was completed.
          return todayReals.isNotEmpty ? 1 : 0;
        }
        return todayReals
                .any((c) => c.taskId == suggestion.task.id)
            ? 1
            : 0;
      case 'justShowUp':
        return todayReals.isNotEmpty ? 1 : 0;
    }
    return 0;
  }
}
