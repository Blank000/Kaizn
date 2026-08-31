import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show NotificationDetails;

import '../../shared/models/recurrence_rule.dart';
import '../database/database.dart';
import 'app_prefs.dart';
import 'notification_prefs.dart';
import 'notification_service.dart';

/// Turns the user's notification preferences and their live task data into a
/// concrete set of scheduled notifications.
///
/// Because local notifications can't query the DB when they fire, this
/// schedules a rolling [_windowDays]-day window of one-shot notifications and
/// re-runs whenever the app starts, resumes, or the user changes settings —
/// each run cancels the previous window and rebuilds it from current state.
///
/// Three families are produced:
///   • Morning briefing — fires at the user's chosen time (default 8 AM) with
///     content reflecting that day's due tasks, or a "log something" nudge when
///     there are none. (Requirements 3 & 4.)
///   • Evening nudge — fires at 9 PM, but only on days nothing has been logged.
///     For today this is checked against real completions; future days are
///     scheduled optimistically and corrected on the next run. (Requirement 1.)
///   • Per-task reminders — fire at each task's reminder time on days it's due.
///     (Requirement 2.)
class NotificationScheduler {
  NotificationScheduler._();

  /// How many days ahead to schedule. Future due-tasks are deterministic from
  /// recurrence rules, so the morning briefing stays correct even if the app
  /// isn't opened for several days.
  static const _windowDays = 7;

  static const _eveningHour = 21; // 9 PM

  static AppDatabase? _db;
  static Timer? _ticker;
  static bool _running = false;

  /// The live app database, exposed so the foreground notification-action
  /// handler can reuse it instead of opening a second connection.
  static AppDatabase? get database => _db;

  /// Wire the scheduler to the database and start a defensive periodic refresh.
  /// Safe to call multiple times.
  static Future<void> init(AppDatabase db) async {
    _db = db;
    await reschedule();
    _ticker?.cancel();
    // Catches day-rollover and data mutated while the app sits in the
    // foreground (e.g. a task logged, so today's evening nudge can be dropped).
    _ticker = Timer.periodic(const Duration(minutes: 15), (_) => reschedule());
  }

  /// Recompute and reschedule the whole notification window from current state.
  ///
  /// Diff-based: we compute the desired set of alarms first, THEN cancel only
  /// stale ones (pending IDs no longer in the desired set) and re-schedule the
  /// desired ones. Doing "cancel all + re-add" on every call races with alarms
  /// that are pending-but-not-yet-fired: cancelling one and then trying to
  /// re-add it with a past-time silently drops it, so the reminder is lost.
  /// zonedSchedule already replaces same-ID alarms in-place, so pre-cancelling
  /// buys us nothing except that race.
  static Future<void> reschedule() async {
    final db = _db;
    if (db == null) {
      debugPrint('🔔 reschedule: SKIPPED — _db is null');
      return;
    }
    if (_running) {
      debugPrint('🔔 reschedule: SKIPPED — already running');
      return;
    }
    _running = true;
    try {
      // Rest mode: the calm IS the feature — no pings of any kind while the
      // window covers today. Cancel everything; the first reschedule after
      // the window expires (app open/resume) restores the full set.
      if (AppPrefs.isRestingSync) {
        debugPrint('🔔 reschedule: rest mode — cancelling managed alarms');
        await NotificationService.cancelManaged();
        return;
      }

      final morningEnabled = await NotificationPrefs.isDailyEnabled();
      final morningTime = await NotificationPrefs.getDailyTime();
      final eveningEnabled = await NotificationPrefs.isStreakAlertEnabled();
      final taskRemindersEnabled =
          await NotificationPrefs.isTaskRemindersEnabled();
      final lastCallEnabled = await NotificationPrefs.isLastCallEnabled();

      debugPrint(
          '🔔 reschedule: morning=$morningEnabled evening=$eveningEnabled '
          'tasks=$taskRemindersEnabled lastCall=$lastCallEnabled');

      // Nothing to schedule — clear the whole managed queue.
      if (!morningEnabled &&
          !eveningEnabled &&
          !taskRemindersEnabled &&
          !lastCallEnabled) {
        await NotificationService.cancelManaged();
        debugPrint('🔔 reschedule: all notification kinds off, cleared queue');
        return;
      }

      final tasks = await db.getAllActiveTasks();
      final milestones = await db.getActiveMilestones();
      final milestoneNameById = {for (final m in milestones) m.id: m.name};
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      debugPrint(
          '🔔 reschedule: found ${tasks.length} active tasks, now=$now');

      final todayCompletions = await db.getCompletionsForDate(today);
      final loggedTodayIds = await db.getTaskIdsCompletedToday();
      final anyLoggedToday =
          todayCompletions.any((c) => !c.isSkip && !c.isNd);

      // 1. Compute the desired schedule — every alarm we want in the OS queue,
      //    keyed by id.
      final desired = <int, _DesiredAlarm>{};

      // ── One-shot task reminders (task.reminderDate set) ──
      // Bypass the day-loop entirely: fire ONCE on the exact date+time.
      if (taskRemindersEnabled) {
        for (final task in tasks) {
          if (!task.reminderEnabled) continue;
          if (task.reminderDate == null) continue;
          final minute = _reminderMinuteFor(task);
          if (minute == null) continue;
          final rd = task.reminderDate!;
          final when =
              DateTime(rd.year, rd.month, rd.day, minute ~/ 60, minute % 60);
          if (!when.isAfter(now)) {
            debugPrint(
                '🔔   one-shot "${task.name}" at $when is past — not scheduled');
            continue;
          }
          final milestone = milestoneNameById[task.milestoneId];
          desired[_oneShotReminderId(task.id)] = _DesiredAlarm(
            when: when,
            title: _catchyTitle(task.name, task.id),
            body: _catchyBody(
                milestone: milestone, points: task.pointsPerCompletion),
            kind: NotificationKind.task,
            payload: jsonEncode({'t': 'task', 'id': task.id, 'n': task.name}),
            overrideDetails: NotificationService.taskDetailsFor(
                points: task.pointsPerCompletion),
          );
          debugPrint(
              '🔔   one-shot "${task.name}" scheduled for $when');
        }
      }

      // Once tasks with reminderEnabled but NO reminderDate get a daily
      // reminder until completed. _isDueOn returns false for these when they
      // have no dueDate (or before the dueDate), so add them explicitly to
      // every day in the window.
      final onceDaily = tasks.where((t) =>
          t.recurrence == TaskRecurrence.none &&
          t.status == TaskStatus.active &&
          t.reminderEnabled &&
          t.reminderDate == null).toList();

      for (var offset = 0; offset < _windowDays; offset++) {
        final day = DateTime(today.year, today.month, today.day + offset);
        final due = tasks.where((t) => _isDueOn(t, day)).toList();

        if (morningEnabled) {
          final (title, body) = _morningContent(due);
          desired[NotificationService.morningBase + offset] = _DesiredAlarm(
            when: DateTime(day.year, day.month, day.day, morningTime.hour,
                morningTime.minute),
            title: title,
            body: body,
            kind: NotificationKind.morning,
          );
        }

        // ── Last-call alerts (opt-in): 20 min before a scheduled task's
        // window closes. Only for windows >= 45 min — shorter ones would
        // double-fire minutes after the start-time reminder. Computed before
        // the evening nudge so the nudge can yield to them.
        var lastCallInEveningBand = false;
        if (lastCallEnabled) {
          for (final task in due) {
            final start = task.startMinute;
            if (start == null) continue;
            if (task.durationMinutes < 45) continue;
            if (offset == 0 && loggedTodayIds.contains(task.id)) continue;
            final fireMinute = start + task.durationMinutes - 20;
            if (fireMinute >= 24 * 60) continue;
            // 8:30 PM – 10 PM band: this last-call replaces the evening
            // nudge (both mean "the day is ending" — one ping, not two).
            if (fireMinute >= 20 * 60 + 30 && fireMinute <= 22 * 60) {
              lastCallInEveningBand = true;
            }
            desired[_lastCallId(task.id, offset)] = _DesiredAlarm(
              when: DateTime(
                  day.year, day.month, day.day, fireMinute ~/ 60,
                  fireMinute % 60),
              title: _lastCallTitle(task.name, task.id),
              body: _lastCallBody(task.pointsPerCompletion, task.id),
              kind: NotificationKind.task,
              payload:
                  jsonEncode({'t': 'task', 'id': task.id, 'n': task.name}),
              overrideDetails: NotificationService.taskDetailsFor(
                  points: task.pointsPerCompletion),
            );
          }
        }

        if (eveningEnabled && !lastCallInEveningBand) {
          final alreadyLogged = offset == 0 && anyLoggedToday;
          if (!alreadyLogged) {
            desired[NotificationService.eveningBase + offset] = _DesiredAlarm(
              when: DateTime(day.year, day.month, day.day, _eveningHour, 0),
              // The Whisper: Ren invites, the old copy nagged.
              title: AppPrefs.renEnabledSync
                  ? '🦊 The scroll waits'
                  : "🔥 Don't break your streak!",
              body: AppPrefs.renEnabledSync
                  ? '“One line before moonrise?” — nothing logged yet today, '
                      'and 30 seconds still counts.'
                  : "You haven't logged anything today. 30 seconds is all it takes.",
              kind: NotificationKind.evening,
            );
          }
        }

        if (taskRemindersEnabled) {
          // Union of "due per recurrence" and "always-daily once tasks". The
          // set keeps ordering stable and eliminates duplicates when a once
          // task happens to also satisfy _isDueOn.
          final tasksForReminder = <Task>{...due, ...onceDaily};
          for (final task in tasksForReminder) {
            // One-shot reminder tasks were handled above the day-loop — don't
            // also schedule a per-recurrence-day alarm for them.
            if (task.reminderDate != null) continue;
            final minute = _reminderMinuteFor(task);
            if (minute == null) {
              if (offset == 0) {
                debugPrint(
                    '🔔   task "${task.name}" DUE today but reminder off '
                    '(reminderEnabled=${task.reminderEnabled}, '
                    'reminderMinute=${task.reminderMinute}, '
                    'startMinute=${task.startMinute})');
              }
              continue;
            }
            if (offset == 0 && loggedTodayIds.contains(task.id)) {
              debugPrint(
                  '🔔   task "${task.name}" skipped today (already logged)');
              continue;
            }
            final milestone = milestoneNameById[task.milestoneId];
            desired[_taskReminderId(task.id, offset)] = _DesiredAlarm(
              when: DateTime(
                  day.year, day.month, day.day, minute ~/ 60, minute % 60),
              title: _catchyTitle(task.name, task.id),
              body: _catchyBody(
                  milestone: milestone, points: task.pointsPerCompletion),
              kind: NotificationKind.task,
              payload:
                  jsonEncode({'t': 'task', 'id': task.id, 'n': task.name}),
              overrideDetails: NotificationService.taskDetailsFor(
                  points: task.pointsPerCompletion),
            );
          }
        }
      }

      // 2. Cancel only stale pending alarms — ones we no longer want. Pending
      //    alarms we DO still want stay put; scheduleAt below replaces them
      //    in-place if the content changed, or no-ops if it didn't.
      await NotificationService.cancelStaleManaged(desired.keys.toSet());

      final pendingAfterCancel = await NotificationService.pending();
      debugPrint(
          '🔔 after cancelStale: ${pendingAfterCancel.length} still pending — ids ${pendingAfterCancel.map((r) => r.id).toList()}');

      // 3. Schedule (or re-schedule) every desired alarm. If a same-id alarm is
      //    already queued and its time is now in the past, scheduleAt silently
      //    drops the new one — but the ORIGINAL still sits in the OS queue and
      //    will fire whenever the OS gets around to it.
      var actuallyScheduled = 0;
      var pastSkipped = 0;
      for (final e in desired.entries) {
        final isPast = !e.value.when.isAfter(now);
        debugPrint(
            '🔔   want id=${e.key} when=${e.value.when} '
            '${isPast ? '(PAST — not re-added)' : 'title=${e.value.title}'}');
        if (isPast) {
          pastSkipped++;
          continue;
        }
        await NotificationService.scheduleAt(
          id: e.key,
          when: e.value.when,
          title: e.value.title,
          body: e.value.body,
          kind: e.value.kind,
          payload: e.value.payload,
          overrideDetails: e.value.overrideDetails,
        );
        actuallyScheduled++;
      }
      final pendingFinal = await NotificationService.pending();
      debugPrint(
          '🔔 reschedule DONE: desired=${desired.length} '
          'scheduled=$actuallyScheduled pastSkipped=$pastSkipped '
          '→ ${pendingFinal.length} pending — ids ${pendingFinal.map((r) => r.id).toList()}');
    } catch (e, stack) {
      debugPrint('🔔 reschedule: FAILED — $e\n$stack');
    } finally {
      _running = false;
    }
  }

  /// Morning briefing title/body for a day's due-task list.
  static (String, String) _morningContent(List<Task> due) {
    if (due.isEmpty) {
      return (
        'Nothing scheduled today 🗓️',
        'No tasks today — log an activity or add one to keep your streak going.',
      );
    }
    if (due.length == 1) {
      return ('1 task today ✅', due.first.name);
    }
    final preview = due.take(3).map((t) => t.name).join(', ');
    final extra = due.length > 3 ? ' +${due.length - 3} more' : '';
    return ('${due.length} tasks today ✅', '$preview$extra');
  }

  /// The minute-of-day a task's reminder should fire, or null if it has no
  /// reminder. Falls back to the timeline start time when no explicit
  /// reminder time is set.
  static int? _reminderMinuteFor(Task task) {
    if (!task.reminderEnabled) return null;
    return task.reminderMinute ?? task.startMinute;
  }

  static int _taskReminderId(String taskId, int offset) =>
      NotificationService.taskBase + offset * 10000 + taskId.hashCode.abs() % 10000;

  /// Distinct id space for one-shot (reminderDate-set) reminders so they can't
  /// collide with the recurrence-based ids. Offsets 100..: reserved for these.
  static int _oneShotReminderId(String taskId) =>
      NotificationService.taskBase + 100 * 10000 + taskId.hashCode.abs() % 10000;

  /// Last-call alerts live at 2,300,000+ (slot 200) — inside the
  /// `id >= taskBase` sweep arm of _isManagedId, clear of every other family.
  static int _lastCallId(String taskId, int offset) =>
      NotificationService.lastCallBase +
      offset * 10000 +
      taskId.hashCode.abs() % 10000;

  // Urgent-but-calm copy (voice sheet: max one emoji, urgency through
  // brevity). Deterministic per-task rotation like _catchyTitle.
  static const _lastCallTitles = <String>[
    '⏳ 20 min left: %s',
    'Final stretch — %s',
    '🏁 Last call: %s',
  ];

  static const _lastCallBodies = <String>[
    'Still time to land it. +%p pts on the line.',
    'The window closes soon — one tap when done.',
    'Beat the buzzer for +%p pts.',
  ];

  static String _lastCallTitle(String taskName, String taskId) =>
      _lastCallTitles[taskId.hashCode.abs() % _lastCallTitles.length]
          .replaceAll('%s', taskName);

  static String _lastCallBody(int points, String taskId) =>
      _lastCallBodies[taskId.hashCode.abs() % _lastCallBodies.length]
          .replaceAll('%p', '$points');

  /// Whether [task] is due on the calendar day [day]. Mirrors the logic used by
  /// the home timeline and launcher widget.
  static bool _isDueOn(Task task, DateTime day) {
    if (task.recurrence == TaskRecurrence.none) {
      if (task.status != TaskStatus.active) return false;
      if (task.dueDate == null) return false;
      final due =
          DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
      final d = DateTime(day.year, day.month, day.day);
      return !due.isAfter(d);
    }
    return RecurrenceRule.fromTask(task).isDueOn(day);
  }
}

/// One alarm we intend to have queued in the OS. Assembled in-memory by
/// [NotificationScheduler.reschedule] before it decides what to cancel and
/// what to schedule.
class _DesiredAlarm {
  final DateTime when;
  final String title;
  final String body;
  final NotificationKind kind;
  final String? payload;

  /// Optional per-notification details override (e.g. task-reminder details
  /// with the exact point value baked into the Done button).
  final NotificationDetails? overrideDetails;

  const _DesiredAlarm({
    required this.when,
    required this.title,
    required this.body,
    required this.kind,
    this.payload,
    this.overrideDetails,
  });
}

// ── Duolingo-style catchy copy ─────────────────────────────────────────────

/// Rotating pool of catchy titles. The chosen line is deterministic per-task
/// (task id hash) so a user sees the same voice on each reminder for the same
/// task, but different lines across different tasks. Each entry uses `%s` as
/// the task name placeholder.
const _catchyTitles = <String>[
  '⏰ %s is up',
  '💪 Time to shine — %s',
  '🎯 Quick win: %s',
  "🔥 Don't break the chain — %s",
  '✨ %s is calling',
  '⚡ 2 minutes, big momentum — %s',
  '🚀 Let\'s go: %s',
];

/// Rotating body copy — deterministic per-task like titles. `%m` is milestone,
/// `%p` is points. Milestone segment is dropped if null.
const _catchyBodyTemplates = <String>[
  'Tap ✅ Done for +%p pts.',
  '+%p pts waiting. Future you will thank you 👑',
  'Small step, big streak. +%p pts on the table.',
  'One tap and you\'re done. +%p pts 🔥',
  'Momentum > motivation. +%p pts.',
];

String _catchyTitle(String taskName, String taskId) {
  final template = _catchyTitles[taskId.hashCode.abs() % _catchyTitles.length];
  return template.replaceAll('%s', taskName);
}

String _catchyBody({required String? milestone, required int points}) {
  final template = _catchyBodyTemplates[
      (milestone ?? '').hashCode.abs() % _catchyBodyTemplates.length];
  final base = template.replaceAll('%p', '$points');
  return milestone == null ? base : 'From $milestone · $base';
}
