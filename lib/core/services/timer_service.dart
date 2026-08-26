import 'dart:async';
import 'dart:math';

import 'app_prefs.dart';

/// The one running stopwatch session (stopwatch-lite allows exactly one at a
/// time — starting a second prompts to finish/discard the first).
class ActiveTimer {
  final String taskId;

  /// Wall-clock start of the CURRENT run segment (reset on every resume).
  final DateTime startedAt;

  /// Banked seconds from run segments finished by earlier pauses.
  final int accumSeconds;
  final bool isPaused;

  const ActiveTimer({
    required this.taskId,
    required this.startedAt,
    this.accumSeconds = 0,
    this.isPaused = false,
  });
}

/// Single source of truth for the active timer.
///
/// State is four AppPrefs values (task id, segment start, banked seconds,
/// paused flag); elapsed time is ALWAYS recomputed on read: banked seconds
/// plus wall clock since the last resume. That is the entire persistence
/// story: no background service, no alarms, nothing for an aggressive OEM
/// (Vivo/iQOO) to kill — a cold start after process death shows the correct
/// elapsed (and paused state) on the first frame via the sync caches.
///
/// Pause is ALWAYS a user action. The app never auto-pauses on backgrounding
/// — timing off-screen work (reading, a workout) is legitimate. Owner
/// decision; do not "fix".
class TimerService {
  TimerService._();

  /// Sanity cap: sessions longer than this are credited at the cap ("even
  /// legends sleep" — a forgotten overnight timer shouldn't log 14h).
  /// Applies to ACTIVE time; a paused timer banks nothing and is harmless
  /// to forget.
  static const int maxSessionSeconds = 12 * 3600;

  static final StreamController<ActiveTimer?> _controller =
      StreamController.broadcast();

  /// The running timer, or null. Reads the AppPrefs sync caches — callers in
  /// a background isolate must AppPrefs.hydrate() first.
  static ActiveTimer? get current {
    final taskId = AppPrefs.activeTimerTaskIdSync;
    final startedAt = AppPrefs.activeTimerStartedAtMillisSync;
    if (taskId == null || startedAt == null) return null;
    return ActiveTimer(
      taskId: taskId,
      startedAt: DateTime.fromMillisecondsSinceEpoch(startedAt),
      accumSeconds: AppPrefs.activeTimerAccumSecondsSync,
      isPaused: AppPrefs.activeTimerPausedSync,
    );
  }

  /// Emits [current] immediately on listen, then on every start/clear/
  /// pause/resume — mirrors the AppEventBus static-bus pattern so
  /// non-widget callers can consume it too.
  static Stream<ActiveTimer?> watch() async* {
    yield current;
    yield* _controller.stream;
  }

  static Future<void> start(String taskId) async {
    await AppPrefs.setActiveTimer(
        taskId, DateTime.now().millisecondsSinceEpoch);
    _controller.add(current);
  }

  /// Bank the current run segment and freeze. No-op when already paused.
  static Future<void> pause() async {
    final t = current;
    if (t == null || t.isPaused) return;
    await AppPrefs.setActiveTimerRunState(
      startedAtMillis: DateTime.now().millisecondsSinceEpoch,
      accumSeconds: elapsedSeconds(t),
      paused: true,
    );
    _controller.add(current);
  }

  /// Restart the wall clock on top of the banked seconds. No-op unless
  /// paused.
  static Future<void> resume() async {
    final t = current;
    if (t == null || !t.isPaused) return;
    await AppPrefs.setActiveTimerRunState(
      startedAtMillis: DateTime.now().millisecondsSinceEpoch,
      accumSeconds: t.accumSeconds,
      paused: false,
    );
    _controller.add(current);
  }

  /// Stops the timer. Returns what was cleared (null if nothing ran).
  static Future<ActiveTimer?> clear() async {
    final was = current;
    await AppPrefs.clearActiveTimer();
    _controller.add(null);
    return was;
  }

  /// Banked seconds plus the live segment (zero while paused), clamped at
  /// zero so a backwards clock change never yields negative time.
  static int elapsedSeconds(ActiveTimer t) {
    final live = t.isPaused
        ? 0
        : max(0, DateTime.now().difference(t.startedAt).inSeconds);
    return max(0, t.accumSeconds + live);
  }

  /// Elapsed, capped at [maxSessionSeconds] — what actually gets credited.
  static int cappedElapsedSeconds(ActiveTimer t) =>
      min(elapsedSeconds(t), maxSessionSeconds);

  /// 'mm:ss' under an hour, 'h:mm:ss' above.
  static String formatElapsed(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }
}
