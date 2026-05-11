import 'package:shared_preferences/shared_preferences.dart';

import '../database/database.dart';

class AchievementBadge {
  final String id;
  final String emoji;
  final String name;
  final String description;
  final DateTime? unlockedAt;

  const AchievementBadge({
    required this.id,
    required this.emoji,
    required this.name,
    required this.description,
    this.unlockedAt,
  });

  bool get isUnlocked => unlockedAt != null;
}

class AchievementService {
  // ── Badge definitions ──────────────────────────────────────────────────────

  static const _allBadgeIds = [
    'first_log',
    'century',
    'grand',
    'early_bird',
    'night_owl',
    'completionist',
    'streak_7',
    'streak_30',
    'reward_claimed',
  ];

  static AchievementBadge _def(String id, {DateTime? unlockedAt}) {
    final defs = {
      'first_log': ('📝', 'First Log', 'Made your very first task completion'),
      'century': ('💯', 'Century', 'Earned 100 total points'),
      'grand': ('🏆', 'Grand', 'Earned 1,000 total points'),
      'early_bird': ('🌅', 'Early Bird', 'Logged a task before 7am'),
      'night_owl': ('🦉', 'Night Owl', 'Logged a task after 10pm'),
      'completionist': (
        '✅',
        'Completionist',
        "Completed all of today's tasks"
      ),
      'streak_7': ('🔥', 'Week Warrior', 'Reached a 7-day streak'),
      'streak_30': ('🌟', 'Monthly Master', 'Reached a 30-day streak'),
      'reward_claimed': ('🎁', 'Treat Yourself', 'Claimed your first reward'),
    };
    final d = defs[id]!;
    return AchievementBadge(
      id: id,
      emoji: d.$1,
      name: d.$2,
      description: d.$3,
      unlockedAt: unlockedAt,
    );
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  static String _unlockedKey(String id) => 'achievement_${id}_unlocked';
  static String _dateKey(String id) => 'achievement_${id}_date';

  static Future<bool> isUnlocked(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_unlockedKey(id)) ?? false;
  }

  /// Unlocks a badge. Returns the badge if it was newly unlocked, null if
  /// already had it.
  static Future<AchievementBadge?> unlock(String id) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_unlockedKey(id)) == true) return null;
    final now = DateTime.now();
    await prefs.setBool(_unlockedKey(id), true);
    await prefs.setString(_dateKey(id), now.toIso8601String());
    return _def(id, unlockedAt: now);
  }

  static Future<List<AchievementBadge>> getAllBadges() async {
    final prefs = await SharedPreferences.getInstance();
    return _allBadgeIds.map((id) {
      final dateStr = prefs.getString(_dateKey(id));
      return _def(
        id,
        unlockedAt: dateStr != null ? DateTime.tryParse(dateStr) : null,
      );
    }).toList();
  }

  // ── Condition checks ───────────────────────────────────────────────────────

  /// Called after a real (non-skip, non-ND) task completion. Returns any
  /// newly unlocked badges so the caller can surface them.
  static Future<List<AchievementBadge>> checkAfterCompletion(
      AppDatabase db) async {
    final newly = <AchievementBadge>[];
    Future<void> tryUnlock(String id) async {
      final b = await unlock(id);
      if (b != null) newly.add(b);
    }

    final totalCompletions = await db.getTotalCompletionCount();
    final lifetimePoints = await db.getLifetimeEarnedPoints();
    final hour = DateTime.now().hour;

    if (totalCompletions == 1) await tryUnlock('first_log');
    if (lifetimePoints >= 100) await tryUnlock('century');
    if (lifetimePoints >= 1000) await tryUnlock('grand');
    if (hour < 7) await tryUnlock('early_bird');
    if (hour >= 22) await tryUnlock('night_owl');

    return newly;
  }

  /// Called after the streak counter advances.
  static Future<List<AchievementBadge>> checkStreakBadges(
      int currentStreak) async {
    final newly = <AchievementBadge>[];
    if (currentStreak >= 7) {
      final b = await unlock('streak_7');
      if (b != null) newly.add(b);
    }
    if (currentStreak >= 30) {
      final b = await unlock('streak_30');
      if (b != null) newly.add(b);
    }
    return newly;
  }

  /// Called when the user finishes every scheduled task today.
  static Future<AchievementBadge?> checkCompletionist() =>
      unlock('completionist');

  /// Called after a reward is claimed.
  static Future<AchievementBadge?> checkAfterRewardClaim() =>
      unlock('reward_claimed');
}
