import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/calendar_service.dart';

/// Google Calendar events for a (date-only) day. Pull-based with a 15-min
/// service-side cache; invalidate the family after edits/reconnects.
final gcalEventsProvider =
    FutureProvider.family<List<GcalEvent>, DateTime>((ref, day) {
  return CalendarService.eventsForDay(day);
});
