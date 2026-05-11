import 'package:shared_preferences/shared_preferences.dart';

class LevelInfo {
  final int level;
  final String title;
  final int minPoints;
  final int? maxPoints; // null at max level
  final double progress; // 0.0–1.0 within this level

  const LevelInfo({
    required this.level,
    required this.title,
    required this.minPoints,
    required this.maxPoints,
    required this.progress,
  });
}

class LevelService {
  static const _key = 'last_known_level';

  // (minPoints, title)
  static const _thresholds = [
    (0, 'Novice'),
    (500, 'Consistent'),
    (1500, 'Dedicated'),
    (3000, 'Focused'),
    (6000, 'Master'),
  ];

  static LevelInfo getLevel(int points) {
    int idx = 0;
    for (int i = 0; i < _thresholds.length; i++) {
      if (points >= _thresholds[i].$1) idx = i;
    }
    final min = _thresholds[idx].$1;
    final max = idx < _thresholds.length - 1 ? _thresholds[idx + 1].$1 : null;
    final double progress = max == null
        ? 1.0
        : ((points - min) / (max - min)).clamp(0.0, 1.0);
    return LevelInfo(
      level: idx + 1,
      title: _thresholds[idx].$2,
      minPoints: min,
      maxPoints: max,
      progress: progress,
    );
  }

  /// Returns the new [LevelInfo] if the user just leveled up, otherwise null.
  static Future<LevelInfo?> checkAndSaveLevelUp(int totalPoints) async {
    final prefs = await SharedPreferences.getInstance();
    final lastLevel = prefs.getInt(_key) ?? 1;
    final info = getLevel(totalPoints);
    await prefs.setInt(_key, info.level);
    if (info.level > lastLevel) return info;
    return null;
  }

  /// Level accent colors (index = level - 1).
  static const levelColors = [
    0xFF9B9B9B, // Novice — grey
    0xFF1CB0F6, // Consistent — blue
    0xFF58CC02, // Dedicated — green
    0xFFFF9600, // Focused — orange
    0xFFFFD700, // Master — gold
  ];

  static int colorForLevel(int level) =>
      levelColors[(level - 1).clamp(0, levelColors.length - 1)];
}
