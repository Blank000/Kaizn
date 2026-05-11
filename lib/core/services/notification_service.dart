import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _dailyReminderId = 1;
  static const _streakAlertId = 2;
  static const _weeklyRecapId = 3;

  static const _dailyDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_reminder',
      'Daily Reminder',
      channelDescription: 'Daily habit logging reminder',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
  );

  static const _streakDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'streak_alert',
      'Streak Alert',
      channelDescription: 'Streak-at-risk notifications',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
    ),
  );

  static Future<void> init() async {
    tz.initializeTimeZones();
    final localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz.identifier));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    // Request permission on Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Schedule the daily reminder to fire every day at [hour]:[minute].
  static Future<void> scheduleDailyReminder(int hour, int minute) async {
    await _plugin.zonedSchedule(
      _dailyReminderId,
      'Time to log! 📋',
      'Keep your streak alive — takes less than a minute.',
      _nextInstanceOf(hour, minute),
      _dailyDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedule the streak-at-risk alert to fire every day at 9 PM.
  static Future<void> scheduleStreakAlert() async {
    await _plugin.zonedSchedule(
      _streakAlertId,
      "🔥 Don't break your streak!",
      "You haven't logged today. 30 seconds is all it takes.",
      _nextInstanceOf(21, 0),
      _streakDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelDailyReminder() async {
    await _plugin.cancel(_dailyReminderId);
  }

  static Future<void> cancelStreakAlert() async {
    await _plugin.cancel(_streakAlertId);
  }

  /// Schedule a weekly recap every Sunday at 8 PM.
  static Future<void> scheduleWeeklyRecap() async {
    await _plugin.zonedSchedule(
      _weeklyRecapId,
      '📊 Your weekly recap is ready',
      'Tap to see how your week went — streaks, points & more.',
      _nextSundayAt(20, 0),
      _dailyDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelWeeklyRecap() async {
    await _plugin.cancel(_weeklyRecapId);
  }

  // ── Per-metric reminders ──────────────────────────────────────────────────

  static int _metricNotificationId(String metricId) =>
      1000 + metricId.hashCode.abs() % 8000;

  static Future<void> scheduleMetricReminder({
    required String metricId,
    required String metricName,
    required String projectName,
    required int hour,
    required int minute,
  }) async {
    await _plugin.zonedSchedule(
      _metricNotificationId(metricId),
      'Time to log $metricName ⏰',
      '$projectName — tap to open the app.',
      _nextInstanceOf(hour, minute),
      _dailyDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelMetricReminder(String metricId) async {
    await _plugin.cancel(_metricNotificationId(metricId));
  }

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static tz.TZDateTime _nextSundayAt(int hour, int minute) {
    var candidate = _nextInstanceOf(hour, minute);
    // Advance until Sunday (weekday == 7 in Dart)
    while (candidate.weekday != DateTime.sunday) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }
}
