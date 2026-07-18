import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/timer_service.dart';

/// Thin Riverpod bridge over TimerService's broadcast stream so widgets
/// react to start/stop. Kept out of database_provider.dart — that file is
/// purely Drift-stream providers.
final activeTimerProvider = StreamProvider<ActiveTimer?>((ref) {
  return TimerService.watch();
});
