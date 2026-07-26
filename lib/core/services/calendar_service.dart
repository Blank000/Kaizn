import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;

import 'app_prefs.dart';
import 'auth_service.dart';

/// A Google Calendar event rendered on the timeline. Times are minutes into
/// the local day (grid coordinates), matching Task.startMinute semantics.
class GcalEvent {
  final String id;
  final String calendarId;
  final String title;
  final int startMinute;
  final int endMinute;
  final bool allDay;

  /// True when the app may move/resize this event: the calendar is writable
  /// AND the event has no other attendees (dragging a block here must never
  /// silently reschedule someone else's meeting).
  final bool editable;

  const GcalEvent({
    required this.id,
    required this.calendarId,
    required this.title,
    required this.startMinute,
    required this.endMinute,
    required this.allDay,
    required this.editable,
  });

  int get durationMinutes => endMinute - startMinute;
}

/// One row in the Settings calendar picker.
class GcalCalendarInfo {
  final String id;
  final String name;
  final bool writable;
  final bool primary;

  const GcalCalendarInfo({
    required this.id,
    required this.name,
    required this.writable,
    required this.primary,
  });
}

/// Read/write bridge to the user's Google Calendar. Pull-based: fetches are
/// per-day with a short in-memory TTL cache — no background sync, no server.
class CalendarService {
  CalendarService._();

  static const _cacheTtl = Duration(minutes: 15);

  // day (date-only) → fetch result
  static final _cache = <DateTime, ({DateTime at, List<GcalEvent> events})>{};
  static Map<String, String>? _writableAccess; // calendarId → accessRole

  static Future<gcal.CalendarApi?> _api() async {
    final user = AuthService.currentUser;
    if (user == null) return null;
    final headers = await user.authHeaders;
    return gcal.CalendarApi(_AuthClient(headers));
  }

  /// All calendars on the account (for the Settings picker).
  static Future<List<GcalCalendarInfo>> listCalendars() async {
    final api = await _api();
    if (api == null) return const [];
    final list = await api.calendarList.list();
    final out = <GcalCalendarInfo>[];
    for (final c in list.items ?? const <gcal.CalendarListEntry>[]) {
      final id = c.id;
      if (id == null) continue;
      out.add(GcalCalendarInfo(
        id: id,
        name: c.summaryOverride ?? c.summary ?? id,
        writable: c.accessRole == 'owner' || c.accessRole == 'writer',
        primary: c.primary ?? false,
      ));
    }
    return out;
  }

  /// Events across the user's SELECTED calendars for [day] (local time).
  /// Cached for [_cacheTtl]; pass [force] to bypass (pull-to-refresh).
  static Future<List<GcalEvent>> eventsForDay(DateTime day,
      {bool force = false}) async {
    if (!AppPrefs.gcalEnabledSync) return const [];
    final dayOnly = DateTime(day.year, day.month, day.day);
    final cached = _cache[dayOnly];
    if (!force &&
        cached != null &&
        DateTime.now().difference(cached.at) < _cacheTtl) {
      return cached.events;
    }

    final api = await _api();
    if (api == null) return const [];

    // Cache per-calendar access once per fetch round.
    if (_writableAccess == null || force) {
      final cals = await api.calendarList.list();
      _writableAccess = {
        for (final c in cals.items ?? const <gcal.CalendarListEntry>[])
          if (c.id != null) c.id!: c.accessRole ?? 'reader',
      };
    }

    final selected = AppPrefs.gcalCalendarIdsSync;
    if (selected.isEmpty) return const [];
    final dayStart = dayOnly;
    final dayEnd = dayOnly.add(const Duration(days: 1));

    final events = <GcalEvent>[];
    for (final calId in selected) {
      try {
        final res = await api.events.list(
          calId,
          timeMin: dayStart.toUtc(),
          timeMax: dayEnd.toUtc(),
          singleEvents: true, // expand recurring series into instances
          orderBy: 'startTime',
          maxResults: 100,
        );
        final calWritable = _writableAccess?[calId] == 'owner' ||
            _writableAccess?[calId] == 'writer';
        for (final e in res.items ?? const <gcal.Event>[]) {
          final ev = _toEvent(e, calId, calWritable, dayOnly);
          if (ev != null) events.add(ev);
        }
      } catch (_) {
        // One broken calendar (revoked share, deleted) never kills the
        // whole overlay.
        continue;
      }
    }
    events.sort((a, b) => a.startMinute.compareTo(b.startMinute));
    _cache[dayOnly] = (at: DateTime.now(), events: events);
    return events;
  }

  static GcalEvent? _toEvent(
      gcal.Event e, String calId, bool calWritable, DateTime day) {
    final id = e.id;
    if (id == null || e.status == 'cancelled') return null;

    final allDay = e.start?.date != null;
    var startMin = 0;
    var endMin = 24 * 60;
    if (!allDay) {
      final start = e.start?.dateTime?.toLocal();
      final end = e.end?.dateTime?.toLocal();
      if (start == null || end == null) return null;
      // Clamp multi-day/overnight events to the viewed day's window.
      final dayStart = day;
      final dayEnd = day.add(const Duration(days: 1));
      if (!end.isAfter(dayStart) || !start.isBefore(dayEnd)) return null;
      final s = start.isBefore(dayStart) ? dayStart : start;
      final en = end.isAfter(dayEnd) ? dayEnd : end;
      startMin = s.hour * 60 + s.minute;
      endMin = en.isAtSameMomentAs(dayEnd) ? 24 * 60 : en.hour * 60 + en.minute;
      if (endMin <= startMin) return null;
    }

    // Solo events only are editable — an event with other attendees must
    // never be silently rescheduled from a habit app.
    final attendees = e.attendees ?? const <gcal.EventAttendee>[];
    final others = attendees.where((a) => a.self != true).length;
    return GcalEvent(
      id: id,
      calendarId: calId,
      title: e.summary ?? '(busy)',
      startMinute: startMin,
      endMinute: endMin,
      allDay: allDay,
      editable: calWritable && others == 0,
    );
  }

  /// Move/resize an event (solo events on writable calendars only — the
  /// caller checks [GcalEvent.editable]). Times are minutes into [day].
  static Future<bool> moveEvent(
    GcalEvent ev,
    DateTime day, {
    required int newStartMinute,
    int? newDurationMinutes,
  }) async {
    final api = await _api();
    if (api == null) return false;
    final duration = newDurationMinutes ?? ev.durationMinutes;
    final start = DateTime(day.year, day.month, day.day)
        .add(Duration(minutes: newStartMinute));
    final end = start.add(Duration(minutes: duration));
    try {
      await api.events.patch(
        gcal.Event(
          start: gcal.EventDateTime(dateTime: start.toUtc()),
          end: gcal.EventDateTime(dateTime: end.toUtc()),
        ),
        ev.calendarId,
        ev.id,
      );
      invalidate();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Drop all cached days (after edits, reconnects, pull-to-refresh).
  static void invalidate() {
    _cache.clear();
    _writableAccess = null;
  }
}

class _AuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _AuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}
