import 'dart:convert';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../database/database.dart';
import 'app_event_bus.dart';
import 'notification_scheduler.dart';
import 'notification_service.dart';
import 'streak_service.dart';
import 'task_completion_service.dart';

/// Handlers for taps on notification action buttons (Done / Skip / Snooze /
/// Undo). These let the user update a task straight from the notification
/// without opening the app.
///
/// Action taps can arrive in two ways:
///   • Foreground — [notificationTapForeground] runs in the main isolate and
///     reuses the already-open app database.
///   • Background / terminated — [notificationTapBackground] runs in a separate
///     isolate that shares no memory with the app, so it re-initializes the
///     plugin and opens its own short-lived database connection.

/// Id used for the snoozed re-fire of a task reminder. Sits outside the range
/// [NotificationService.cancelManaged] sweeps, so the scheduler's periodic
/// refresh won't wipe a pending snooze.
const _snoozeBase = 60000;

/// Foreground tap — main isolate, reuse the live database.
void notificationTapForeground(NotificationResponse response) {
  handleNotificationAction(response, existingDb: NotificationScheduler.database);
}

/// Background/terminated tap — must run in its own isolate.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  handleNotificationAction(response);
}

/// Routes a notification action to the right side effect. When [existingDb] is
/// null we're in a background isolate: initialize plugins, open our own DB, and
/// close it when done.
Future<void> handleNotificationAction(
  NotificationResponse response, {
  AppDatabase? existingDb,
}) async {
  final actionId = response.actionId;
  final payload = response.payload;
  // A body tap (no actionId) just opens the app — nothing to do here.
  if (actionId == null || payload == null) return;

  Map<String, dynamic> data;
  try {
    data = jsonDecode(payload) as Map<String, dynamic>;
  } catch (_) {
    return;
  }

  final ownDb = existingDb == null;
  if (ownDb) {
    // Background isolate: register plugins and re-init notifications before we
    // can show/schedule anything.
    DartPluginRegistrant.ensureInitialized();
    await NotificationService.initForBackground();
  }
  final db = existingDb ?? AppDatabase();

  try {
    switch (actionId) {
      case NotificationService.actionDone:
        await _handleDone(db, data);
      case NotificationService.actionSkip:
        await _handleSkip(db, data);
      case NotificationService.actionSnooze:
        await _handleSnooze(data);
      case NotificationService.actionUndo:
        await _handleUndo(db, data);
    }
    // In the foreground/main isolate this refreshes the rest of the window
    // (e.g. drops today's evening nudge now that something is logged). In a
    // background isolate the scheduler has no DB attached, so it safely no-ops.
    await NotificationScheduler.reschedule();
  } catch (e) {
    debugPrint('handleNotificationAction($actionId) failed: $e');
  } finally {
    if (ownDb) await db.close();
  }
}

Future<void> _handleDone(AppDatabase db, Map<String, dynamic> data) async {
  final taskId = data['id'] as String?;
  if (taskId == null) return;
  final task = await db.getTaskById(taskId);
  if (task == null) return;

  // Idempotent: if it's already logged today, just re-confirm without
  // inserting a duplicate. celebrationChecks stays off on this path — the
  // app may not have UI up yet when the action fires.
  final existing = await db.getCompletionForTaskOn(taskId, DateTime.now());

  // App is already opening (showsUserInterface: true) — surface the result as
  // an in-app snackbar instead of stacking another notification on top.
  if (existing == null) {
    final result = await TaskCompletionService.completeToday(db, task,
        celebrationChecks: false);
    AppEventBus.post(TaskActionEvent(
      kind: TaskActionKind.done,
      taskId: taskId,
      taskName: task.name,
      points: result.basePoints,
      clutchBonus: result.clutchBonus,
      nextStackedTaskName: result.stackedNext.firstOrNull?.name,
      identityLine: result.identityLine,
      undoCompletionId: result.completionId,
    ));
  } else {
    AppEventBus.post(TaskActionEvent(
      kind: TaskActionKind.done,
      taskId: taskId,
      taskName: task.name,
      points: task.pointsPerCompletion,
      undoCompletionId: existing.id,
    ));
  }
}

Future<void> _handleSkip(AppDatabase db, Map<String, dynamic> data) async {
  final taskId = data['id'] as String?;
  if (taskId == null) return;
  final task = await db.getTaskById(taskId);
  if (task == null) return;

  await db.skipTaskNow(task);
  await StreakService.recordSkipDay(db);

  // Grab the skip row's id so Undo can remove exactly it.
  String? cid;
  for (final c in await db.getCompletionsForDate(DateTime.now())) {
    if (c.taskId == taskId && c.isSkip) {
      cid = c.id;
      break;
    }
  }

  AppEventBus.post(TaskActionEvent(
    kind: TaskActionKind.skip,
    taskId: taskId,
    taskName: task.name,
    undoCompletionId: cid,
  ));
}

Future<void> _handleSnooze(Map<String, dynamic> data) async {
  final taskId = data['id'] as String?;
  final name = data['n'] as String? ?? 'Task';
  if (taskId == null) return;

  final when = DateTime.now().add(const Duration(minutes: 15));

  await NotificationService.scheduleAt(
    id: _snoozeBase + taskId.hashCode.abs() % 10000,
    when: when,
    title: '⏰ $name — round two',
    body: "Snoozed 15 min. Ready when you are 💪",
    kind: NotificationKind.task,
    payload: jsonEncode({'t': 'task', 'id': taskId, 'n': name}),
  );

  AppEventBus.post(TaskActionEvent(
    kind: TaskActionKind.snooze,
    taskId: taskId,
    taskName: name,
    snoozedUntil: when,
  ));
}

Future<void> _handleUndo(AppDatabase db, Map<String, dynamic> data) async {
  final completionId = data['cid'] as String?;
  final taskId = data['id'] as String?;
  if (taskId != null && completionId != null) {
    await db.undoCompletion(completionId, taskId);
  }
  await NotificationService.cancel(NotificationService.confirmId);
}
