import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../../shared/models/recurrence_rule.dart';
import '../../shared/widgets/task_tile.dart'
    show TaskRowState, taskRowStateFor;
import '../database/database.dart';
import '../theme/app_colors.dart';

/// Writes today's timeline to shared storage so the OS launcher widget
/// (Android AppWidget / iOS WidgetKit) can render it. Best-effort — failures
/// are logged and swallowed.
class WidgetService {
  WidgetService._();

  // Names matched by the native widget code.
  static const _androidWidgetName = 'TimelineWidgetProvider';
  static const _iOSWidgetName = 'TimelineWidget';

  // App Group enables the iOS widget extension to read the same UserDefaults
  // as the main app. Android ignores this. Must match the entitlement set in
  // Xcode (Signing & Capabilities → App Groups).
  static const _appGroupId = 'group.com.alokraj.habit_reward_tracker';

  // Shared key for the JSON blob.
  static const dataKey = 'timeline_today';

  static AppDatabase? _db;
  static Timer? _ticker;

  /// Wire the service to the database and start periodic + lifecycle-driven
  /// refreshes. Safe to call multiple times.
  static Future<void> init(AppDatabase db) async {
    _db = db;
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
    } catch (e) {
      // Older Android / desktop will throw — ignore, the package is no-op
      // there.
      debugPrint('WidgetService.setAppGroupId failed: $e');
    }
    await refresh();
    _ticker?.cancel();
    // Cheap defensive periodic refresh so the widget catches day-rollover and
    // anything mutated outside the app's notice (e.g. via Drive restore).
    _ticker = Timer.periodic(const Duration(minutes: 5), (_) => refresh());
  }

  /// Recompute today's timeline and push it to the widget.
  static Future<void> refresh() async {
    final db = _db;
    if (db == null) return;
    try {
      final tasks = await db.getAllActiveTasks();
      final completions =
          await db.getRecentCompletions(const Duration(days: 7));
      final milestones = await db.getActiveMilestones();
      final milestoneById = {for (final m in milestones) m.id: m};
      final now = DateTime.now();

      final today = <Map<String, dynamic>>[];
      for (final task in tasks) {
        if (!_isDueToday(task, now)) continue;
        final state = taskRowStateFor(task, completions);
        final ms = milestoneById[task.milestoneId];
        today.add({
          'id': task.id,
          'name': task.name,
          'startMin': task.startMinute,
          'duration': task.durationMinutes,
          'state': _stateString(state),
          'milestoneName': ms?.name,
          'colorHex': _hex(AppColors.milestoneColor(ms?.colorIndex ?? 0)),
        });
      }
      today.sort((a, b) {
        final ax = a['startMin'] as int?;
        final bx = b['startMin'] as int?;
        if (ax == null && bx == null) return 0;
        if (ax == null) return 1;
        if (bx == null) return -1;
        return ax.compareTo(bx);
      });

      final payload = jsonEncode({
        'updatedAt': now.toIso8601String(),
        'tasks': today,
      });
      await HomeWidget.saveWidgetData<String>(dataKey, payload);
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        iOSName: _iOSWidgetName,
      );
    } catch (e) {
      debugPrint('WidgetService.refresh failed: $e');
    }
  }

  static String _stateString(TaskRowState s) {
    if (s.isChecked) return 'checked';
    if (s.isMissed) return 'missed';
    if (s.isSkipped) return 'skipped';
    return 'unchecked';
  }

  static bool _isDueToday(Task task, DateTime today) {
    if (task.recurrence == TaskRecurrence.none) {
      if (task.status != TaskStatus.active) return false;
      if (task.dueDate == null) return false;
      final due = DateTime(
        task.dueDate!.year,
        task.dueDate!.month,
        task.dueDate!.day,
      );
      final t = DateTime(today.year, today.month, today.day);
      return !due.isAfter(t);
    }
    return RecurrenceRule.fromTask(task).isDueOn(today);
  }

  static String _hex(Color c) {
    final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }
}
