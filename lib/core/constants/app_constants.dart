/// App-wide constants
class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  // App Info
  static const String appName = 'Habit Reward Tracker';
  static const String appVersion = '1.0.0';

  // Database
  static const String databaseName = 'habit_reward_tracker.db';
  static const int databaseVersion = 1;

  // Spacing (based on 8dp grid)
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing48 = 48.0;

  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;

  // Animation Durations
  static const int animationFast = 200; // milliseconds
  static const int animationNormal = 400; // milliseconds
  static const int animationSlow = 600; // milliseconds
  static const int animationCelebration = 1500; // milliseconds

  // Streak Milestones
  static const List<int> streakMilestones = [7, 14, 30, 60, 100, 365];

  // Points
  static const int defaultBasePoints = 10;
  static const int defaultBonusPoints = 5;
  static const double defaultMultiplier = 1.0;

  // Habit Routine
  static const int maxSkipDaysPerWeek = 2;

  // UI
  static const double bottomNavHeight = 64.0;
  static const int maxQuickLogHistoryItems = 5;
}
