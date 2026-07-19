import 'package:shared_preferences/shared_preferences.dart';

/// Lifetime levels — the only progression in the app that can never be lost:
/// streaks reset, point balances drop when rewards are claimed, badges run
/// out (there are 9). Levels are computed over LIFETIME EARNED points
/// (db.getLifetimeEarnedPoints — never the spendable balance, so claiming a
/// reward can never de-level you) on an uncapped quadratic curve.
class LevelInfo {
  final int level;
  final String title;
  final int minPoints;
  final int nextPoints;
  final double progress; // 0.0–1.0 toward the next level

  const LevelInfo({
    required this.level,
    required this.title,
    required this.minPoints,
    required this.nextPoints,
    required this.progress,
  });
}

class LevelService {
  LevelService._();

  static const _key = 'last_known_level';

  /// Points needed to REACH level n: T(n) = 50·(n−1)².
  /// L2 = 50, L3 = 200, L5 = 800, L10 = 4,050, L15 = 9,800, L20 = 18,050.
  /// At ~200 pts/week: two levels in week one (endowed progress), L10 in
  /// roughly six months, L20 in about two years. Early-fast, late-slow,
  /// never capped.
  static int thresholdFor(int level) => 50 * (level - 1) * (level - 1);

  /// Title every 5 levels — keeps the original scaffold's names, extended.
  static const _titles = [
    'Novice', // 1–4
    'Consistent', // 5–9
    'Dedicated', // 10–14
    'Focused', // 15–19
    'Master', // 20–24
    'Grandmaster', // 25–29
    'Sage', // 30+
  ];

  static String titleFor(int level) =>
      _titles[((level - 1) ~/ 5).clamp(0, _titles.length - 1)];

  static LevelInfo getLevel(int lifetimePoints) {
    var level = 1;
    while (lifetimePoints >= thresholdFor(level + 1)) {
      level++;
    }
    final min = thresholdFor(level);
    final next = thresholdFor(level + 1);
    return LevelInfo(
      level: level,
      title: titleFor(level),
      minPoints: min,
      nextPoints: next,
      progress: ((lifetimePoints - min) / (next - min)).clamp(0.0, 1.0),
    );
  }

  /// Returns the new [LevelInfo] exactly once when the user levels up.
  static Future<LevelInfo?> checkAndSaveLevelUp(int lifetimePoints) async {
    final prefs = await SharedPreferences.getInstance();
    final lastLevel = prefs.getInt(_key) ?? 1;
    final info = getLevel(lifetimePoints);
    if (info.level == lastLevel) return null;
    await prefs.setInt(_key, info.level);
    // Only celebrate upward moves (downward is impossible on lifetime
    // points, but a restored backup could lower the number — stay quiet).
    return info.level > lastLevel ? info : null;
  }
}
