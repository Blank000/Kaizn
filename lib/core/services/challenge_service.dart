import 'package:shared_preferences/shared_preferences.dart';

class DailyChallenge {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final int bonusPoints;

  const DailyChallenge({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.bonusPoints,
  });
}

/// Context passed when checking if today's challenge condition is met.
class ChallengeCheckContext {
  final int logHour;
  final int distinctProjectsLoggedToday;
  final bool thresholdMetOnThisLog;
  final int totalLogsToday;
  final int currentStreak;

  const ChallengeCheckContext({
    required this.logHour,
    required this.distinctProjectsLoggedToday,
    required this.thresholdMetOnThisLog,
    required this.totalLogsToday,
    required this.currentStreak,
  });
}

class ChallengeService {
  // Challenges rotate by day of week (1=Mon … 7=Sun)
  static const _challenges = [
    DailyChallenge(
      id: 'log_before_noon',
      emoji: '🌅',
      title: 'Early Riser',
      description: 'Log any habit before noon',
      bonusPoints: 20,
    ),
    DailyChallenge(
      id: 'log_3_metrics',
      emoji: '📊',
      title: 'Triple Threat',
      description: 'Log 3 or more metrics today',
      bonusPoints: 30,
    ),
    DailyChallenge(
      id: 'hit_threshold',
      emoji: '🎯',
      title: 'On Target',
      description: 'Hit your goal threshold on any metric',
      bonusPoints: 25,
    ),
    DailyChallenge(
      id: 'log_evening',
      emoji: '🌙',
      title: 'Night Shift',
      description: 'Log any habit after 6pm',
      bonusPoints: 15,
    ),
    DailyChallenge(
      id: 'log_2_projects',
      emoji: '🔀',
      title: 'Multitasker',
      description: 'Log from 2 different projects today',
      bonusPoints: 20,
    ),
    DailyChallenge(
      id: 'log_any',
      emoji: '💪',
      title: 'Just Show Up',
      description: 'Log anything today',
      bonusPoints: 10,
    ),
    DailyChallenge(
      id: 'streak_builder',
      emoji: '🔥',
      title: 'Streak Builder',
      description: 'Maintain or grow your streak',
      bonusPoints: 15,
    ),
  ];

  static String _todayKey() {
    final now = DateTime.now();
    return 'challenge_completed_${now.year}-${now.month}-${now.day}';
  }

  static String _todayBonusKey() {
    final now = DateTime.now();
    return 'challenge_bonus_${now.year}-${now.month}-${now.day}';
  }

  /// Gets today's challenge (rotates by weekday: Mon=0 … Sun=6).
  static DailyChallenge getDailyChallenge() {
    final idx = (DateTime.now().weekday - 1) % _challenges.length;
    return _challenges[idx];
  }

  static Future<bool> isCompletedToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_todayKey()) ?? false;
  }

  /// Checks if today's challenge condition is met by this log.
  /// If newly completed, marks it done and returns bonus points earned.
  /// Returns 0 if already completed or condition not met.
  static Future<int> checkAndReward(ChallengeCheckContext ctx) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_todayKey()) == true) return 0; // already done today

    final challenge = getDailyChallenge();
    bool conditionMet = false;

    switch (challenge.id) {
      case 'log_before_noon':
        conditionMet = ctx.logHour < 12;
        break;
      case 'log_3_metrics':
        conditionMet = ctx.totalLogsToday >= 3;
        break;
      case 'hit_threshold':
        conditionMet = ctx.thresholdMetOnThisLog;
        break;
      case 'log_evening':
        conditionMet = ctx.logHour >= 18;
        break;
      case 'log_2_projects':
        conditionMet = ctx.distinctProjectsLoggedToday >= 2;
        break;
      case 'log_any':
        conditionMet = true;
        break;
      case 'streak_builder':
        conditionMet = ctx.currentStreak >= 1;
        break;
    }

    if (!conditionMet) return 0;

    await prefs.setBool(_todayKey(), true);
    await prefs.setInt(_todayBonusKey(), challenge.bonusPoints);
    return challenge.bonusPoints;
  }
}
