import 'dart:convert';

import '../../core/database/database.dart';

/// How a monthly recurrence picks its day.
enum MonthlyKind {
  /// "Day N of every month" (e.g. day 1, day 15, day 31 → clamped to last).
  dayOfMonth,

  /// "1st/2nd/3rd/4th/last <weekday> of every month" (e.g. "1st Monday").
  weekdayPosition,
}

const _weekdayShortNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Parsed recurrence rule for a task. Encapsulates schedule logic and storage.
///
/// JSON shape stored in `tasks.recurrence_config`:
///   Daily   : {"interval": N, "anchor": "ISO"}
///   Weekly  : {"interval": N, "daysOfWeek": [1..7], "anchor": "ISO"}
///   Monthly : {"interval": N, "kind": "day", "dayOfMonth": 1..31, "anchor": "ISO"}
///         or  {"interval": N, "kind": "weekday", "weekdayOrdinal": 1..4|-1, "weekday": 1..7, "anchor": "ISO"}
class RecurrenceRule {
  final TaskRecurrence frequency;
  final int interval;
  final List<int> daysOfWeek;
  final MonthlyKind? monthlyKind;
  final int? dayOfMonth;
  final int? weekdayOrdinal;
  final int? weekday;
  final DateTime anchor;

  const RecurrenceRule._({
    required this.frequency,
    required this.interval,
    required this.anchor,
    this.daysOfWeek = const [],
    this.monthlyKind,
    this.dayOfMonth,
    this.weekdayOrdinal,
    this.weekday,
  });

  factory RecurrenceRule.once() => RecurrenceRule._(
        frequency: TaskRecurrence.none,
        interval: 1,
        anchor: DateTime.now(),
      );

  factory RecurrenceRule.daily({required int interval, DateTime? anchor}) =>
      RecurrenceRule._(
        frequency: TaskRecurrence.daily,
        interval: interval,
        anchor: anchor ?? DateTime.now(),
      );

  factory RecurrenceRule.weekly({
    required int interval,
    required List<int> daysOfWeek,
    DateTime? anchor,
  }) =>
      RecurrenceRule._(
        frequency: TaskRecurrence.weekly,
        interval: interval,
        daysOfWeek: List.unmodifiable(daysOfWeek..sort()),
        anchor: anchor ?? DateTime.now(),
      );

  factory RecurrenceRule.monthlyByDay({
    required int interval,
    required int dayOfMonth,
    DateTime? anchor,
  }) =>
      RecurrenceRule._(
        frequency: TaskRecurrence.monthly,
        interval: interval,
        anchor: anchor ?? DateTime.now(),
        monthlyKind: MonthlyKind.dayOfMonth,
        dayOfMonth: dayOfMonth,
      );

  factory RecurrenceRule.monthlyByWeekday({
    required int interval,
    required int weekdayOrdinal, // 1-4 or -1 for last
    required int weekday, // 1-7
    DateTime? anchor,
  }) =>
      RecurrenceRule._(
        frequency: TaskRecurrence.monthly,
        interval: interval,
        anchor: anchor ?? DateTime.now(),
        monthlyKind: MonthlyKind.weekdayPosition,
        weekdayOrdinal: weekdayOrdinal,
        weekday: weekday,
      );

  /// Parse from a Task. Falls back to sensible defaults if config is missing
  /// (existing tasks created before this feature shipped).
  factory RecurrenceRule.fromTask(Task task) {
    final raw = task.recurrenceConfig;
    final anchorFromTask = task.createdAt;

    if (task.recurrence == TaskRecurrence.none) return RecurrenceRule.once();

    Map<String, dynamic>? cfg;
    if (raw != null && raw.isNotEmpty) {
      try {
        cfg = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        cfg = null;
      }
    }

    DateTime parseAnchor(dynamic v) {
      if (v is String) {
        return DateTime.tryParse(v) ?? anchorFromTask;
      }
      return anchorFromTask;
    }

    final interval = (cfg?['interval'] as int?) ?? 1;
    final anchor = parseAnchor(cfg?['anchor']);

    switch (task.recurrence) {
      case TaskRecurrence.daily:
        return RecurrenceRule.daily(interval: interval, anchor: anchor);
      case TaskRecurrence.weekly:
        final days = (cfg?['daysOfWeek'] as List?)
                ?.cast<int>()
                .where((d) => d >= 1 && d <= 7)
                .toList() ??
            <int>[];
        return RecurrenceRule.weekly(
          interval: interval,
          daysOfWeek: days.isEmpty ? [anchor.weekday] : days,
          anchor: anchor,
        );
      case TaskRecurrence.monthly:
        final kind = cfg?['kind'] == 'weekday'
            ? MonthlyKind.weekdayPosition
            : MonthlyKind.dayOfMonth;
        if (kind == MonthlyKind.weekdayPosition) {
          return RecurrenceRule.monthlyByWeekday(
            interval: interval,
            weekdayOrdinal: (cfg?['weekdayOrdinal'] as int?) ?? 1,
            weekday: (cfg?['weekday'] as int?) ?? anchor.weekday,
            anchor: anchor,
          );
        }
        return RecurrenceRule.monthlyByDay(
          interval: interval,
          dayOfMonth: (cfg?['dayOfMonth'] as int?) ?? anchor.day,
          anchor: anchor,
        );
      case TaskRecurrence.none:
        return RecurrenceRule.once();
    }
  }

  /// Serialize for storage in `tasks.recurrence_config`. Returns null for
  /// one-shot tasks (the column is nullable).
  String? toJsonString() {
    if (frequency == TaskRecurrence.none) return null;
    final base = {
      'interval': interval,
      'anchor': anchor.toIso8601String(),
    };
    switch (frequency) {
      case TaskRecurrence.daily:
        return jsonEncode(base);
      case TaskRecurrence.weekly:
        return jsonEncode({...base, 'daysOfWeek': daysOfWeek});
      case TaskRecurrence.monthly:
        if (monthlyKind == MonthlyKind.weekdayPosition) {
          return jsonEncode({
            ...base,
            'kind': 'weekday',
            'weekdayOrdinal': weekdayOrdinal,
            'weekday': weekday,
          });
        }
        return jsonEncode({
          ...base,
          'kind': 'day',
          'dayOfMonth': dayOfMonth,
        });
      case TaskRecurrence.none:
        return null;
    }
  }

  /// Was this task scheduled to occur on [date] (date-only)?
  bool isDueOn(DateTime date) {
    final d = _dateOnly(date);
    final a = _dateOnly(anchor);
    if (d.isBefore(a)) return false;

    switch (frequency) {
      case TaskRecurrence.none:
        return false;
      case TaskRecurrence.daily:
        return d.difference(a).inDays % interval == 0;
      case TaskRecurrence.weekly:
        if (!daysOfWeek.contains(d.weekday)) return false;
        final weeksSince =
            _mondayOf(d).difference(_mondayOf(a)).inDays ~/ 7;
        return weeksSince % interval == 0;
      case TaskRecurrence.monthly:
        final monthsSince = (d.year - a.year) * 12 + (d.month - a.month);
        if (monthsSince < 0 || monthsSince % interval != 0) return false;
        if (monthlyKind == MonthlyKind.weekdayPosition) {
          if (d.weekday != weekday) return false;
          return _isNthWeekdayOfMonth(d, weekdayOrdinal!);
        }
        return d.day == _effectiveDayOfMonth(d.year, d.month, dayOfMonth!);
    }
  }

  /// True when this rule wants per-day tracking (multi-day weekly).
  /// Each scheduled day in the week becomes its own period; "did Monday"
  /// no longer satisfies "do Wednesday."
  bool get isMultiDayWeekly =>
      frequency == TaskRecurrence.weekly && daysOfWeek.length > 1;

  /// Start of the completion period containing [today] (inclusive).
  /// Daily/once → today; weekly single-day → Monday of this week (or aligned
  /// anchor week for interval > 1); weekly multi-day → today (strict per-day);
  /// monthly → first of this month (or aligned anchor month).
  DateTime currentPeriodStart(DateTime today) {
    final t = _dateOnly(today);
    switch (frequency) {
      case TaskRecurrence.none:
      case TaskRecurrence.daily:
        return t;
      case TaskRecurrence.weekly:
        if (isMultiDayWeekly) return t;
        final monday = _mondayOf(t);
        if (interval == 1) return monday;
        final anchorMonday = _mondayOf(anchor);
        final weeksSince = monday.difference(anchorMonday).inDays ~/ 7;
        final periodOffsetWeeks = weeksSince - (weeksSince % interval);
        return anchorMonday.add(Duration(days: periodOffsetWeeks * 7));
      case TaskRecurrence.monthly:
        final firstOfMonth = DateTime(t.year, t.month, 1);
        if (interval == 1) return firstOfMonth;
        final anchorFirst = DateTime(anchor.year, anchor.month, 1);
        final monthsSince =
            (firstOfMonth.year - anchorFirst.year) * 12 +
                (firstOfMonth.month - anchorFirst.month);
        final offsetMonths = monthsSince - (monthsSince % interval);
        return DateTime(
            anchorFirst.year, anchorFirst.month + offsetMonths, 1);
    }
  }

  /// End of the completion period containing [today] (exclusive).
  DateTime currentPeriodEnd(DateTime today) {
    final start = currentPeriodStart(today);
    switch (frequency) {
      case TaskRecurrence.none:
      case TaskRecurrence.daily:
        return start.add(const Duration(days: 1));
      case TaskRecurrence.weekly:
        if (isMultiDayWeekly) return start.add(const Duration(days: 1));
        return start.add(Duration(days: 7 * interval));
      case TaskRecurrence.monthly:
        return DateTime(start.year, start.month + interval, 1);
    }
  }

  /// Human-readable summary, e.g. "Mon · Wed · Fri", "Every 2 weeks · Mon",
  /// "Day 1 of every month", "Last Friday of every month".
  String summary() {
    switch (frequency) {
      case TaskRecurrence.none:
        return 'One-time';
      case TaskRecurrence.daily:
        return interval == 1 ? 'Every day' : 'Every $interval days';
      case TaskRecurrence.weekly:
        return _weeklySummary();
      case TaskRecurrence.monthly:
        return _monthlySummary();
    }
  }

  String _weeklySummary() {
    final dayLabels = daysOfWeek.map((d) => _weekdayShortNames[d - 1]).toList();
    final dayPart = _weekdayCondensed(daysOfWeek, dayLabels);
    if (interval == 1) {
      // Single day → "Every Mon"; multiple → just "Mon · Wed · Fri".
      if (daysOfWeek.length == 1) return 'Every $dayPart';
      return dayPart;
    }
    return 'Every $interval weeks · $dayPart';
  }

  String _weekdayCondensed(List<int> days, List<String> labels) {
    if (days.length == 7) return 'Every day';
    if (_listEquals(days, [1, 2, 3, 4, 5])) return 'Weekdays';
    if (_listEquals(days, [6, 7])) return 'Weekends';
    return labels.join(' · ');
  }

  String _monthlySummary() {
    if (monthlyKind == MonthlyKind.weekdayPosition) {
      final ord = _ordinalLabel(weekdayOrdinal!);
      final wk = _weekdayShortNames[weekday! - 1];
      return interval == 1
          ? '$ord $wk of every month'
          : '$ord $wk every $interval months';
    }
    final dom = dayOfMonth == 31 ? 'Last day' : 'Day $dayOfMonth';
    return interval == 1
        ? '$dom of every month'
        : '$dom every $interval months';
  }

  String _ordinalLabel(int n) {
    if (n == -1) return 'Last';
    return ['1st', '2nd', '3rd', '4th'][n - 1];
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _mondayOf(DateTime d) =>
      _dateOnly(d).subtract(Duration(days: d.weekday - 1));

  /// Clamp a desired day-of-month to the actual last day of [year]/[month].
  static int _effectiveDayOfMonth(int year, int month, int desired) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return desired > lastDay ? lastDay : desired;
  }

  /// True if [date] is the [n]th occurrence of its weekday in its month.
  /// [n] is 1-4 for "Nth", or -1 for "last".
  static bool _isNthWeekdayOfMonth(DateTime date, int n) {
    if (n == -1) {
      // Is this the last <weekday> in this month?
      final next = date.add(const Duration(days: 7));
      return next.month != date.month;
    }
    // Count occurrences of this weekday from the 1st through date.
    final occurrence = ((date.day - 1) ~/ 7) + 1;
    return occurrence == n;
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
