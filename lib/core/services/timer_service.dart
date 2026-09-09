import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show Value;

import '../database/database.dart';
import 'app_prefs.dart';

/// One stopwatch session: a task, a clock, and whether it's currently ticking.
///
/// Several of these can exist at once (one per task) but only one is ever
/// unpaused — see [TimerService].
class ActiveTimer {
  /// Groups this session's ledger rows together.
  final String sessionId;

  final String taskId;

  /// Wall-clock start of the CURRENT run segment (reset on every resume).
  final DateTime startedAt;

  /// Banked seconds from run segments finished by earlier pauses.
  final int accumSeconds;
  final bool isPaused;

  const ActiveTimer({
    required this.sessionId,
    required this.taskId,
    required this.startedAt,
    this.accumSeconds = 0,
    this.isPaused = false,
  });

  ActiveTimer copyWith({
    DateTime? startedAt,
    int? accumSeconds,
    bool? isPaused,
  }) =>
      ActiveTimer(
        sessionId: sessionId,
        taskId: taskId,
        startedAt: startedAt ?? this.startedAt,
        accumSeconds: accumSeconds ?? this.accumSeconds,
        isPaused: isPaused ?? this.isPaused,
      );

  Map<String, Object?> toJson() => {
        'sessionId': sessionId,
        'taskId': taskId,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'accum': accumSeconds,
        'paused': isPaused,
      };

  /// Tolerant of junk: a malformed entry yields null and is dropped rather
  /// than taking the whole timer bar down.
  static ActiveTimer? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final taskId = raw['taskId'];
    final startedAt = raw['startedAt'];
    if (taskId is! String || startedAt is! int) return null;
    final accum = raw['accum'];
    return ActiveTimer(
      sessionId: raw['sessionId'] is String
          ? raw['sessionId'] as String
          : 'legacy-$startedAt',
      taskId: taskId,
      startedAt: DateTime.fromMillisecondsSinceEpoch(startedAt),
      accumSeconds: accum is int ? max(0, accum) : 0,
      isPaused: raw['paused'] == true,
    );
  }
}

/// One pending ledger row: what happened, to which session, when.
class _LedgerRow {
  final ActiveTimer session;
  final String kind;
  final int elapsedSeconds;
  final String? taskName;
  final DateTime at;

  _LedgerRow(this.session, this.kind, this.elapsedSeconds, this.taskName)
      : at = DateTime.now();
}

/// Single source of truth for stopwatch sessions.
///
/// State lives in one AppPrefs JSON array; elapsed time is ALWAYS recomputed
/// on read (banked seconds + wall clock since the last resume). That is the
/// entire persistence story: no background service, no alarms, nothing for an
/// aggressive OEM (Vivo/iQOO) to kill — a cold start after process death shows
/// the correct elapsed and paused state on the first frame via the sync cache.
///
/// **Invariant: at most one session is unpaused.** Starting or resuming a task
/// pauses whatever else was running, so "what am I doing right now?" always has
/// exactly one answer, while work you stepped away from stays banked instead of
/// being thrown out.
///
/// Pause is otherwise ALWAYS a user action. The app never auto-pauses on
/// backgrounding — timing off-screen work (reading, a workout) is legitimate.
/// Owner decision; do not "fix".
///
/// Every transition also appends a row to the `timer_events` ledger via
/// [attachLedger], so the history survives the live state.
class TimerService {
  TimerService._();

  /// Sanity cap: sessions longer than this are credited at the cap ("even
  /// legends sleep" — a forgotten overnight timer shouldn't log 14h).
  /// Applies to ACTIVE time; a paused timer banks nothing and is harmless
  /// to forget.
  static const int maxSessionSeconds = 12 * 3600;

  static final StreamController<List<ActiveTimer>> _controller =
      StreamController.broadcast();

  /// Set once at startup so transitions can write the ledger. Ledger writes
  /// are best-effort — a failure must never block the stopwatch itself.
  static AppDatabase? _ledgerDb;
  static void attachLedger(AppDatabase db) => _ledgerDb = db;

  static final Random _rand = Random();

  static String _newSessionId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final suffix =
        List.generate(8, (_) => chars[_rand.nextInt(chars.length)]).join();
    return 's${DateTime.now().millisecondsSinceEpoch}$suffix';
  }

  // ── Reads ────────────────────────────────────────────────────────────────

  /// Every live session, running one first. Reads the AppPrefs sync cache —
  /// callers in a background isolate must AppPrefs.hydrate() first.
  static List<ActiveTimer> get sessions {
    final out = _parse(AppPrefs.timerSessionsJsonSync);
    out.sort((a, b) {
      if (a.isPaused != b.isPaused) return a.isPaused ? 1 : -1;
      return b.startedAt.compareTo(a.startedAt);
    });
    return out;
  }

  /// The one ticking session, or null.
  static ActiveTimer? get running {
    for (final t in sessions) {
      if (!t.isPaused) return t;
    }
    return null;
  }

  /// Backwards-compatible alias for [running].
  static ActiveTimer? get current => running;

  /// Sessions the user stepped away from.
  static List<ActiveTimer> get pausedSessions =>
      sessions.where((t) => t.isPaused).toList();

  /// This task's session, running or paused.
  static ActiveTimer? forTask(String taskId) {
    for (final t in sessions) {
      if (t.taskId == taskId) return t;
    }
    return null;
  }

  /// Emits the full session list immediately on listen, then on every
  /// transition — mirrors the AppEventBus static-bus pattern so non-widget
  /// callers can consume it too.
  static Stream<List<ActiveTimer>> watchAll() async* {
    yield sessions;
    yield* _controller.stream;
  }

  // ── Writes ───────────────────────────────────────────────────────────────
  //
  // Every mutation runs inside [_serial] and follows the same shape:
  //   load (reload prefs → parse → normalise) → mutate a local list →
  //   persist once → flush ledger rows.
  //
  // Nothing reads the prefs cache again mid-transition. That matters: the
  // previous version awaited a database round trip between reading and
  // writing the session list, so two quick taps could leave two sessions
  // running at once (one of them invisible, quietly banking hours) or drop
  // one entirely. Serialising the whole transition is what makes the
  // one-running invariant actually hold.

  /// Tail of the mutation queue. Every write chains onto it, so transitions
  /// never interleave.
  static Future<void> _queue = Future<void>.value();

  static Future<T> _serial<T>(Future<T> Function() op) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await op());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  /// Reads sessions from disk (not just the cache) and repairs anything
  /// impossible: duplicate task ids, or more than one unpaused session.
  static Future<List<ActiveTimer>> _load() async {
    final raw = await AppPrefs.reloadTimerSessionsJson();
    return _normalise(_parse(raw));
  }

  static List<ActiveTimer> _parse(String raw) {
    if (raw.isEmpty || raw == '[]') return [];
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return [];
    }
    if (decoded is! List) return [];
    final out = <ActiveTimer>[];
    for (final entry in decoded) {
      final t = ActiveTimer.tryFromJson(entry);
      if (t != null) out.add(t);
    }
    return out;
  }

  /// Self-heal. A list that already satisfies the invariants comes back
  /// unchanged; anything else is repaired by banking time rather than
  /// discarding it.
  static List<ActiveTimer> _normalise(List<ActiveTimer> list) {
    // One session per task — keep the one with the most time on it.
    final byTask = <String, ActiveTimer>{};
    for (final s in list) {
      final kept = byTask[s.taskId];
      if (kept == null || elapsedSeconds(s) > elapsedSeconds(kept)) {
        byTask[s.taskId] = s;
      }
    }
    final out = byTask.values.toList();

    // At most one unpaused — the most recently started one wins, the rest
    // are banked and paused.
    final live = out.where((s) => !s.isPaused).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    if (live.length > 1) {
      for (final loser in live.skip(1)) {
        final idx = out.indexWhere((s) => s.taskId == loser.taskId);
        out[idx] = _banked(loser);
      }
    }
    return out;
  }

  /// The paused form of [t]: live segment folded into the banked total,
  /// capped so a forgotten overnight timer can't bank 14 hours.
  static ActiveTimer _banked(ActiveTimer t) => t.copyWith(
        startedAt: DateTime.now(),
        accumSeconds: cappedElapsedSeconds(t),
        isPaused: true,
      );

  static Future<void> _persist(List<ActiveTimer> next) async {
    await AppPrefs.setTimerSessionsJson(
        jsonEncode(next.map((t) => t.toJson()).toList()));
    _controller.add(sessions);
  }

  /// Start timing [taskId]. Resumes an existing paused session for that task
  /// instead of starting a second one, and pauses whatever else was running
  /// (banked, not discarded).
  ///
  /// Returns the id of the task that got auto-paused, if any, so callers can
  /// say so out loud.
  static Future<String?> start(String taskId, {String? taskName}) {
    return _serial(() async {
      final list = await _load();
      final existing = _find(list, taskId);
      if (existing != null && !existing.isPaused) return null; // already on

      final pending = <_LedgerRow>[];
      final autoPausedId = _pauseRunningIn(list, taskId, pending);

      if (existing != null) {
        final resumed =
            existing.copyWith(startedAt: DateTime.now(), isPaused: false);
        _replace(list, resumed);
        pending.add(_LedgerRow(resumed, TimerEventKind.resume,
            resumed.accumSeconds, taskName));
      } else {
        final fresh = ActiveTimer(
          sessionId: _newSessionId(),
          taskId: taskId,
          startedAt: DateTime.now(),
        );
        list.add(fresh);
        pending.add(_LedgerRow(fresh, TimerEventKind.start, 0, taskName));
      }

      await _persist(list);
      _flush(pending);
      return autoPausedId;
    });
  }

  /// Restart a paused task's clock, pausing whatever else was running.
  /// Returns the auto-paused task's id, if any. No-op for a task with no
  /// session — use [start] for that.
  static Future<String?> resume(String taskId, {String? taskName}) {
    if (forTask(taskId) == null) return Future.value(null);
    return start(taskId, taskName: taskName);
  }

  /// Bank the current run segment and freeze. No-op when already paused or
  /// when the task has no session.
  static Future<void> pause(String taskId, {String? taskName}) {
    return _serial(() async {
      final list = await _load();
      final t = _find(list, taskId);
      if (t == null || t.isPaused) return;
      final pending = <_LedgerRow>[];
      final paused = _banked(t);
      _replace(list, paused);
      pending.add(_LedgerRow(
          paused, TimerEventKind.pause, paused.accumSeconds, taskName));
      await _persist(list);
      _flush(pending);
    });
  }

  /// Ends [taskId]'s session. Returns what was cleared (null if it had none).
  /// [kind] records WHY in the ledger — completed, stopped, discarded.
  static Future<ActiveTimer?> clear(
    String taskId, {
    String kind = TimerEventKind.stop,
    String? taskName,
  }) {
    return _serial(() async {
      final list = await _load();
      final was = _find(list, taskId);
      if (was == null) return null;
      list.removeWhere((s) => s.taskId == taskId);
      await _persist(list);
      _flush([
        _LedgerRow(was, kind, cappedElapsedSeconds(was), taskName),
      ]);
      return was;
    });
  }

  /// Ends every live session — the hook an "erase all data" flow needs.
  /// Each one still gets its terminal ledger row, so no run is left dangling.
  static Future<void> clearAll({String kind = TimerEventKind.stop}) {
    return _serial(() async {
      final list = await _load();
      if (list.isEmpty) return;
      final pending = [
        for (final s in list) _LedgerRow(s, kind, cappedElapsedSeconds(s), null)
      ];
      await _persist(const []);
      _flush(pending);
    });
  }

  /// Test hook — wipes live state and writes nothing.
  static Future<void> resetForTest() => _serial(() => _persist(const []));

  // ── List helpers (operate on a caller-owned list, never on prefs) ────────

  static ActiveTimer? _find(List<ActiveTimer> list, String taskId) {
    for (final s in list) {
      if (s.taskId == taskId) return s;
    }
    return null;
  }

  static void _replace(List<ActiveTimer> list, ActiveTimer updated) {
    final i = list.indexWhere((s) => s.taskId == updated.taskId);
    if (i >= 0) {
      list[i] = updated;
    } else {
      list.add(updated);
    }
  }

  /// Pauses the running session (unless it's [exceptTaskId]) inside [list]
  /// and returns its task id — the "only one at a time" enforcement point.
  static String? _pauseRunningIn(
    List<ActiveTimer> list,
    String exceptTaskId,
    List<_LedgerRow> pending,
  ) {
    for (final s in list) {
      if (s.isPaused || s.taskId == exceptTaskId) continue;
      final paused = _banked(s);
      _replace(list, paused);
      pending.add(_LedgerRow(
          paused, TimerEventKind.autoPause, paused.accumSeconds, null));
      return s.taskId;
    }
    return null;
  }

  // ── Ledger ───────────────────────────────────────────────────────────────

  /// Tail of the ledger-write queue. Chained so rows land in order, and so
  /// a caller that is about to close the database can wait for them.
  static Future<void> _ledgerQueue = Future<void>.value();

  /// Resolves once every queued ledger row has been written. Await this
  /// before closing a short-lived database (the notification background
  /// isolate does).
  static Future<void> ledgerSettled() => _ledgerQueue;

  /// Writes the rows without blocking the transition. Each row already
  /// carries the timestamp it happened at, so a slow database can't reorder
  /// the ledger.
  static void _flush(List<_LedgerRow> rows) {
    final db = _ledgerDb;
    if (db == null || rows.isEmpty) return;
    _ledgerQueue = _ledgerQueue.then((_) async {
      for (final r in rows) {
        try {
          final name =
              r.taskName ?? (await db.getTaskById(r.session.taskId))?.name;
          await db.insertTimerEvent(TimerEventsCompanion.insert(
            id: '${r.session.sessionId}-${r.at.microsecondsSinceEpoch}'
                '-${_rand.nextInt(1 << 20)}',
            sessionId: r.session.sessionId,
            taskId: r.session.taskId,
            taskName: name ?? 'Deleted task',
            kind: r.kind,
            elapsedSeconds: Value(r.elapsedSeconds),
            at: r.at,
          ));
        } catch (_) {
          // The ledger is a nice-to-have; the stopwatch is not.
        }
      }
    });
  }

  // ── Math ─────────────────────────────────────────────────────────────────

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
