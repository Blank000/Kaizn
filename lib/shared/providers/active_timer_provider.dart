import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/timer_service.dart';

/// Thin Riverpod bridge over TimerService's broadcast stream so widgets
/// react to start/pause/resume/stop. Kept out of database_provider.dart —
/// that file is purely Drift-stream providers.
///
/// Emits EVERY live session. At most one is unpaused (TimerService owns that
/// invariant); the rest are work the user stepped away from.
final timerSessionsProvider = StreamProvider<List<ActiveTimer>>((ref) {
  return TimerService.watchAll();
});

/// The one ticking session, or null. This is what the Home banner shows —
/// paused sessions deliberately live in their own task row instead, so the
/// top of the app answers exactly one question: what am I doing right now?
final runningTimerProvider = Provider<ActiveTimer?>((ref) {
  final all = ref.watch(timerSessionsProvider).valueOrNull;
  if (all == null) return null;
  for (final t in all) {
    if (!t.isPaused) return t;
  }
  return null;
});

/// This task's session (running or paused), or null.
final timerForTaskProvider =
    Provider.family<ActiveTimer?, String>((ref, taskId) {
  final all = ref.watch(timerSessionsProvider).valueOrNull;
  if (all == null) return null;
  for (final t in all) {
    if (t.taskId == taskId) return t;
  }
  return null;
});
