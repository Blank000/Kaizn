import 'package:shared_preferences/shared_preferences.dart';

/// Persists notification toggle states and reminder time.
class NotificationPrefs {
  static const _dailyEnabledKey = 'notif_daily_enabled';
  static const _dailyHourKey = 'notif_daily_hour';
  static const _dailyMinuteKey = 'notif_daily_minute';
  static const _streakAlertEnabledKey = 'notif_streak_alert_enabled';

  static Future<bool> isDailyEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_dailyEnabledKey) ?? false;
  }

  static Future<void> setDailyEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_dailyEnabledKey, value);
  }

  static Future<({int hour, int minute})> getDailyTime() async {
    final p = await SharedPreferences.getInstance();
    return (hour: p.getInt(_dailyHourKey) ?? 8, minute: p.getInt(_dailyMinuteKey) ?? 0);
  }

  static Future<void> setDailyTime(int hour, int minute) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_dailyHourKey, hour);
    await p.setInt(_dailyMinuteKey, minute);
  }

  static Future<bool> isStreakAlertEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_streakAlertEnabledKey) ?? false;
  }

  static Future<void> setStreakAlertEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_streakAlertEnabledKey, value);
  }

  static const _weeklyRecapEnabledKey = 'notif_weekly_recap_enabled';

  static Future<bool> isWeeklyRecapEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_weeklyRecapEnabledKey) ?? false;
  }

  static Future<void> setWeeklyRecapEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_weeklyRecapEnabledKey, value);
  }

  // ── Last-call alerts (opt-in) ─────────────────────────────────────────────

  static const _lastCallEnabledKey = 'notif_last_call_enabled';

  /// One final nudge ~20 min before a scheduled task's window closes.
  /// Default OFF — unlike per-task reminders there is no per-task gate, so
  /// this family is globally opt-in.
  static Future<bool> isLastCallEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_lastCallEnabledKey) ?? false;
  }

  static Future<void> setLastCallEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_lastCallEnabledKey, value);
  }

  // ── Per-task reminders (master switch) ────────────────────────────────────

  static const _taskRemindersEnabledKey = 'notif_task_reminders_enabled';

  /// Master switch for per-task reminders. On by default — individual tasks
  /// opt in via their own `reminderEnabled` flag, so this just lets the user
  /// silence all of them at once.
  static Future<bool> isTaskRemindersEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_taskRemindersEnabledKey) ?? true;
  }

  static Future<void> setTaskRemindersEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_taskRemindersEnabledKey, value);
  }

  // ── Per-metric reminders ──────────────────────────────────────────────────

  static String _metricEnabledKey(String id) => 'metric_reminder_${id}_enabled';
  static String _metricHourKey(String id) => 'metric_reminder_${id}_hour';
  static String _metricMinuteKey(String id) => 'metric_reminder_${id}_minute';

  static Future<bool> isMetricReminderEnabled(String metricId) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_metricEnabledKey(metricId)) ?? false;
  }

  static Future<({int hour, int minute})?> getMetricReminderTime(
      String metricId) async {
    final p = await SharedPreferences.getInstance();
    final hour = p.getInt(_metricHourKey(metricId));
    if (hour == null) return null;
    return (hour: hour, minute: p.getInt(_metricMinuteKey(metricId)) ?? 0);
  }

  static Future<void> setMetricReminder(
      String metricId, int hour, int minute) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_metricEnabledKey(metricId), true);
    await p.setInt(_metricHourKey(metricId), hour);
    await p.setInt(_metricMinuteKey(metricId), minute);
  }

  static Future<void> clearMetricReminder(String metricId) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_metricEnabledKey(metricId));
    await p.remove(_metricHourKey(metricId));
    await p.remove(_metricMinuteKey(metricId));
  }
}
