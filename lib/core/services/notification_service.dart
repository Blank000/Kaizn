import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'notification_actions.dart';

/// The kind of notification — selects the Android channel it lands on.
enum NotificationKind { morning, evening, task, weekly, feedback }

/// Low-level wrapper around `flutter_local_notifications`.
///
/// Local notifications are scheduled ahead of time and cannot run any code
/// (including DB queries) when they fire, so content-aware and conditional
/// notifications are built by [NotificationScheduler] scheduling a rolling
/// window of one-shot notifications and refreshing it whenever the app opens
/// or data changes. This class only knows how to fire/cancel a single
/// notification at an exact time, and to expose inline action buttons whose
/// taps are handled in [notification_actions].
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  // ── ID scheme (kept in sync with NotificationScheduler) ───────────────────
  // 1, 2                  legacy repeating daily/streak reminders (cancelled)
  // 3                     weekly recap
  // 100..199              morning briefing, one per day-offset
  // 200..299              evening nudge, one per day-offset
  // 50000                 transient action-confirmation toast (unmanaged)
  // 60000..69999          snooze re-fires (see notification_actions)
  // 300000..369999        per-task reminders (offset*10000 + hash%10000)
  // 1300000..1309999      one-shot reminder-date reminders (offset slot 100)
  // 2300000..2369999      last-call alerts (offset slot 200) — deliberately
  //                       >= taskBase so _isManagedId sweeps them for free.
  static const _weeklyRecapId = 3;
  static const morningBase = 100;
  static const eveningBase = 200;
  static const confirmId = 50000;
  static const taskBase = 300000;
  static const lastCallBase = 2300000;

  // ── Action button ids (matched in notification_actions) ───────────────────
  static const actionDone = 'task_done';
  static const actionSkip = 'task_skip';
  static const actionSnooze = 'task_snooze';
  static const actionUndo = 'undo_complete';

  static const _morningDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_reminder',
      'Daily Reminder',
      channelDescription: 'Morning summary of what to do today',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
  );

  static const _eveningDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'streak_alert',
      'Streak Alert',
      channelDescription: 'Evening nudge when nothing has been logged',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
    ),
  );

  // Task reminders carry the Done / Skip / Snooze inline actions. Buttons open
  // the app so the tap handler runs in the foreground isolate — silent
  // background isolates are unreliable on aggressive OEMs (Vivo/iQOO/Xiaomi)
  // where the OS kills the isolate before the DB write lands. Tap → app opens
  // → action processed → in-app snackbar (see AppEventBus).
  //
  // Built on demand via [taskDetailsFor] so we can bake per-task point value
  // into the Done button label ("Done (+10 pts)"). Also uses a larger
  // launcher-color icon and BigTextStyle so the body wraps cleanly.
  static NotificationDetails taskDetailsFor({required int points}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'task_reminder',
        'Task Reminders',
        channelDescription: 'Reminders for individual tasks',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        largeIcon:
            const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        color: const Color(0xFF58CC02), // Duolingo-style primary green
        colorized: true,
        styleInformation: const BigTextStyleInformation(''),
        actions: [
          AndroidNotificationAction(
            actionDone,
            points > 0 ? '✅ Done (+$points)' : '✅ Done',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          const AndroidNotificationAction(
            actionSkip,
            'Skip',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          const AndroidNotificationAction(
            actionSnooze,
            'Snooze 15m',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      ),
    );
  }

  // Fallback for callers that don't know the point value (e.g. the diagnostic
  // "Schedule in 30s" button). Keeps generic labels.
  static const _taskDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'task_reminder',
      'Task Reminders',
      channelDescription: 'Reminders for individual tasks',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
      color: Color(0xFF58CC02),
      colorized: true,
      actions: [
        AndroidNotificationAction(
          actionDone,
          '✅ Done',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          actionSkip,
          'Skip',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          actionSnooze,
          'Snooze 15m',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    ),
  );

  // Low-key confirmation "toast" shown after a background action, with an Undo
  // button. Auto-dismisses after 10s.
  static const _feedbackDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'task_action_feedback',
      'Task Action Feedback',
      channelDescription: 'Confirmations for actions taken from notifications',
      importance: Importance.low,
      priority: Priority.low,
      icon: '@mipmap/ic_launcher',
      timeoutAfter: 10000,
      actions: [
        AndroidNotificationAction(
          actionUndo,
          'Undo',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    ),
  );

  static NotificationDetails _detailsFor(NotificationKind kind) {
    switch (kind) {
      case NotificationKind.morning:
      case NotificationKind.weekly:
        return _morningDetails;
      case NotificationKind.evening:
        return _eveningDetails;
      case NotificationKind.task:
        return _taskDetails;
      case NotificationKind.feedback:
        return _feedbackDetails;
    }
  }

  /// Full init for the main isolate: timezone, plugin, response callbacks, and
  /// the Android 13+ permission prompt.
  static Future<void> init() => _configure(requestPermission: true);

  /// Lighter init used inside the background-action isolate, which has its own
  /// fresh plugin instance and must re-initialize before it can show/schedule.
  /// Skips the permission prompt (there's no UI to grant it from).
  static Future<void> initForBackground() =>
      _configure(requestPermission: false);

  static Future<void> _configure({required bool requestPermission}) async {
    tz.initializeTimeZones();
    final localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz.identifier));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: notificationTapForeground,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    if (requestPermission) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      // Android 12+ also gates exact alarms behind a separate user grant; without
      // this the OS silently downgrades our exactAllowWhileIdle to inexact and
      // task reminders drift by tens of minutes.
      await android?.requestExactAlarmsPermission();
    }
  }

  /// Schedule a one-shot notification at the exact local time [when].
  /// Past times are ignored (no notification is scheduled).
  ///
  /// Pass [overrideDetails] when the caller needs per-notification content
  /// (e.g. a Done button labelled with the task's specific point value); the
  /// scheduler uses it for task reminders. When null, falls back to the
  /// channel-default details for [kind].
  static Future<void> scheduleAt({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    required NotificationKind kind,
    String? payload,
    NotificationDetails? overrideDetails,
  }) async {
    final scheduled = tz.TZDateTime.from(when, tz.local);
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) return;
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      overrideDetails ?? _detailsFor(kind),
      // alarmClock mode: routes through AlarmManager.setAlarmClock() — the
      // same API the built-in Clock app uses. Aggressive OEM battery managers
      // (Vivo/iQOO/Xiaomi/Oppo) silently drop `exactAllowWhileIdle` alarms
      // when the app is idle, but they respect `alarmClock` because dropping
      // it would break literal alarm clocks. Trade-off: a small ⏰ icon
      // appears in the status bar while any alarm is queued.
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
      // No matchDateTimeComponents → fires once, then is forgotten.
    );
  }

  /// Show a notification immediately (used for action confirmations).
  static Future<void> show({
    required int id,
    required String title,
    required String body,
    required NotificationKind kind,
    String? payload,
  }) async {
    await _plugin.show(id, title, body, _detailsFor(kind), payload: payload);
  }

  static Future<void> cancel(int id) => _plugin.cancel(id);

  /// Everything currently queued in the OS. Used by the in-app notification
  /// diagnostic to confirm task reminders were actually scheduled.
  static Future<List<PendingNotificationRequest>> pending() =>
      _plugin.pendingNotificationRequests();

  static bool _isManagedId(int id) =>
      id == 1 ||
      id == 2 ||
      (id >= morningBase && id < morningBase + 100) ||
      (id >= eveningBase && id < eveningBase + 100) ||
      id >= taskBase;

  /// Cancel every notification the scheduler owns (morning, evening, task, and
  /// legacy repeating reminders), leaving the independently-managed weekly
  /// recap and the transient confirmation toast untouched.
  static Future<void> cancelManaged() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final r in pending) {
      if (_isManagedId(r.id)) {
        await _plugin.cancel(r.id);
      }
    }
  }

  /// Cancel only STALE managed notifications — pending managed alarms whose id
  /// is not in [keepIds]. Preserves alarms we're about to re-schedule so we
  /// don't race with a pending fire (the OS may hold an alarm briefly past its
  /// scheduled time, and pre-cancelling a not-yet-fired alarm and then trying
  /// to reschedule it for a past time drops it silently).
  static Future<void> cancelStaleManaged(Set<int> keepIds) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final r in pending) {
      if (_isManagedId(r.id) && !keepIds.contains(r.id)) {
        await _plugin.cancel(r.id);
      }
    }
  }

  // ── Weekly recap (independent of the scheduler) ───────────────────────────

  /// Schedule a weekly recap every Sunday at 8 PM.
  static Future<void> scheduleWeeklyRecap() async {
    await _plugin.zonedSchedule(
      _weeklyRecapId,
      '📊 Your weekly recap is ready',
      'Tap to see how your week went — streaks, points & more.',
      _nextSundayAt(20, 0),
      _morningDetails,
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelWeeklyRecap() async {
    await _plugin.cancel(_weeklyRecapId);
  }

  static tz.TZDateTime _nextSundayAt(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var candidate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    while (candidate.weekday != DateTime.sunday) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }
}
