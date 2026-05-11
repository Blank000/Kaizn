import 'package:drift/drift.dart';

import '../database/database.dart';
import 'achievement_service.dart';
import 'app_prefs.dart';

class StreakCheckResult {
  final int currentStreak;
  final int longestStreak;
  final int? milestoneHit;
  final bool wasReset;
  /// The streak value before it was reset. Only meaningful when wasReset = true.
  final int streakBeforeReset;

  const StreakCheckResult({
    required this.currentStreak,
    required this.longestStreak,
    this.milestoneHit,
    this.wasReset = false,
    this.streakBeforeReset = 0,
  });
}

class StreakService {
  /// Called on every app open. Checks for break, updates milestone.
  static Future<StreakCheckResult> checkOnAppOpen(AppDatabase db) async {
    final streak = await db.getStreak();
    if (streak == null) {
      return const StreakCheckResult(currentStreak: 0, longestStreak: 0);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    Streak current = streak;

    if (streak.lastLoggedDate != null) {
      final lastLogged = DateTime(
        streak.lastLoggedDate!.year,
        streak.lastLoggedDate!.month,
        streak.lastLoggedDate!.day,
      );
      if (today.difference(lastLogged).inDays >= 2) {
        final oldStreak = streak.currentStreak;
        current = streak.copyWith(
          currentStreak: 0,
          lastMilestoneCelebrated: 0,
        );
        await db.updateStreak(current);
        return StreakCheckResult(
          currentStreak: 0,
          longestStreak: streak.longestStreak,
          wasReset: true,
          streakBeforeReset: oldStreak,
        );
      }
    }

    // Check for uncelebrated milestone (highest first)
    int? milestoneHit;
    for (final m in [365, 100, 60, 30, 14, 7]) {
      if (current.currentStreak >= m && current.lastMilestoneCelebrated < m) {
        milestoneHit = m;
        await db.updateStreak(current.copyWith(lastMilestoneCelebrated: m));
        break;
      }
    }

    return StreakCheckResult(
      currentStreak: current.currentStreak,
      longestStreak: current.longestStreak,
      milestoneHit: milestoneHit,
    );
  }

  /// Restores streak after using a Streak Shield.
  /// Sets currentStreak back to [restoredValue] and lastLoggedDate to yesterday
  /// so the streak won't break again tomorrow (user still needs to log today).
  static Future<void> restoreStreakAfterShield(
      AppDatabase db, int restoredValue) async {
    final streak = await db.getStreak();
    if (streak == null) return;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await db.updateStreak(
      streak.copyWith(
        currentStreak: restoredValue,
        lastLoggedDate: Value(yesterday),
      ),
    );
  }

  /// Called after the first real log entry of the day.
  /// Uses `AppPrefs.lastStreakAdvanceDate` (not `streak.lastLoggedDate`) as
  /// the once-per-day guard, so that "skip first, real later same day" still
  /// advances the streak on the real completion. Returns any streak badges
  /// the advance unlocked (empty list if no advance happened today).
  static Future<List<AchievementBadge>> recordDayLogged(AppDatabase db) async {
    final streak = await db.getStreak();
    if (streak == null) return const [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final lastAdvance = await AppPrefs.getLastStreakAdvanceDate();
    if (lastAdvance != null && lastAdvance.isAtSameMomentAs(today)) {
      return const []; // Already advanced today
    }

    final newStreak = streak.currentStreak + 1;
    final newLongest =
        newStreak > streak.longestStreak ? newStreak : streak.longestStreak;

    await db.updateStreak(
      streak.copyWith(
        currentStreak: newStreak,
        longestStreak: newLongest,
        lastLoggedDate: Value(now),
      ),
    );
    await AppPrefs.setLastStreakAdvanceDate(today);
    return AchievementService.checkStreakBadges(newStreak);
  }

  /// Called when the user marks a task as a skip (intentional rest).
  /// Updates `lastLoggedDate` so the streak doesn't break tomorrow, but does
  /// NOT advance `currentStreak` — skipping is preservation, not progress.
  static Future<void> recordSkipDay(AppDatabase db) async {
    final streak = await db.getStreak();
    if (streak == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (streak.lastLoggedDate != null) {
      final lastLogged = DateTime(
        streak.lastLoggedDate!.year,
        streak.lastLoggedDate!.month,
        streak.lastLoggedDate!.day,
      );
      if (lastLogged.isAtSameMomentAs(today)) return; // Already updated today
    }

    await db.updateStreak(streak.copyWith(lastLoggedDate: Value(now)));
  }
}
