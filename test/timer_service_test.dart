import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:habit_reward_tracker/core/database/database.dart';
import 'package:habit_reward_tracker/core/services/app_prefs.dart';
import 'package:habit_reward_tracker/core/services/timer_service.dart';
import 'package:habit_reward_tracker/shared/widgets/time_ledger_sheet.dart';

Future<void> _freshPrefs([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(Map<String, Object>.from(initial));
  await AppPrefs.hydrate();
}

TimerEvent _event(
  String sessionId,
  String kind,
  DateTime at, {
  int elapsed = 0,
  String taskId = 't1',
  String taskName = 'Deep work',
}) =>
    TimerEvent(
      id: '$sessionId-$kind-${at.microsecondsSinceEpoch}',
      sessionId: sessionId,
      taskId: taskId,
      taskName: taskName,
      kind: kind,
      elapsedSeconds: elapsed,
      at: at,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('multi-session stopwatch', () {
    test('two tasks can hold sessions, but only one ever runs', () async {
      await _freshPrefs();

      await TimerService.start('taskA');
      expect(TimerService.running?.taskId, 'taskA');

      final autoPaused = await TimerService.start('taskB');

      expect(autoPaused, 'taskA',
          reason: 'starting B must report whose clock it stopped');
      expect(TimerService.running?.taskId, 'taskB');
      expect(TimerService.sessions.length, 2,
          reason: 'A is kept, banked, not discarded');
      expect(TimerService.forTask('taskA')!.isPaused, isTrue);
      expect(TimerService.sessions.where((s) => !s.isPaused).length, 1);
    });

    test('resuming a paused task pauses the running one', () async {
      await _freshPrefs();
      await TimerService.start('taskA');
      await TimerService.start('taskB');

      final autoPaused = await TimerService.resume('taskA');

      expect(autoPaused, 'taskB');
      expect(TimerService.running?.taskId, 'taskA');
      expect(TimerService.forTask('taskB')!.isPaused, isTrue);
    });

    test('start on a task that already has a paused session resumes it',
        () async {
      await _freshPrefs();
      await TimerService.start('taskA');
      await TimerService.pause('taskA');
      final sessionId = TimerService.forTask('taskA')!.sessionId;

      await TimerService.start('taskA');

      expect(TimerService.sessions.length, 1, reason: 'no duplicate session');
      expect(TimerService.forTask('taskA')!.sessionId, sessionId);
      expect(TimerService.running?.taskId, 'taskA');
    });

    test('pause banks elapsed time and freezes the clock', () async {
      await _freshPrefs();
      await TimerService.start('taskA');

      // Backdate the segment by 90s, the way wall clock would.
      final t = TimerService.forTask('taskA')!;
      await AppPrefs.setTimerSessionsJson(
        '[{"sessionId":"${t.sessionId}","taskId":"taskA",'
        '"startedAt":${t.startedAt.millisecondsSinceEpoch - 90000},'
        '"accum":0,"paused":false}]',
      );
      expect(TimerService.elapsedSeconds(TimerService.forTask('taskA')!),
          greaterThanOrEqualTo(90));

      await TimerService.pause('taskA');
      final paused = TimerService.forTask('taskA')!;

      expect(paused.isPaused, isTrue);
      expect(paused.accumSeconds, greaterThanOrEqualTo(90));
      expect(TimerService.elapsedSeconds(paused), paused.accumSeconds,
          reason: 'a paused clock must not keep counting');
    });

    test('clear removes only the named session', () async {
      await _freshPrefs();
      await TimerService.start('taskA');
      await TimerService.start('taskB');

      await TimerService.clear('taskB');

      expect(TimerService.forTask('taskB'), isNull);
      expect(TimerService.forTask('taskA'), isNotNull);
      expect(await TimerService.clear('nope'), isNull);
    });

    test('elapsed never goes negative on a backwards clock', () async {
      await _freshPrefs();
      final future = DateTime.now().add(const Duration(hours: 2));
      await AppPrefs.setTimerSessionsJson(
        '[{"sessionId":"s1","taskId":"taskA",'
        '"startedAt":${future.millisecondsSinceEpoch},'
        '"accum":0,"paused":false}]',
      );
      expect(TimerService.elapsedSeconds(TimerService.forTask('taskA')!), 0);
    });

    test('malformed session entries are dropped, not thrown', () async {
      await _freshPrefs({
        'timer_sessions_json':
            '[{"taskId":123},{"sessionId":"s1","taskId":"taskA",'
                '"startedAt":1000,"accum":5,"paused":true},"junk"]',
      });
      expect(TimerService.sessions.length, 1);
      expect(TimerService.forTask('taskA')!.accumSeconds, 5);
    });

    test('concurrent starts cannot leave two clocks running', () async {
      await _freshPrefs();
      await TimerService.start('taskC');

      // Fire both without awaiting between them — the old unserialised
      // version left A and B both unpaused here, one of them invisible and
      // banking hours nobody worked.
      final results = await Future.wait([
        TimerService.start('taskA'),
        TimerService.start('taskB'),
      ]);

      final live = TimerService.sessions.where((s) => !s.isPaused).toList();
      expect(live.length, 1, reason: 'the invariant must survive a race');
      expect(TimerService.sessions.length, 3,
          reason: 'no session is dropped, none is duplicated');
      expect(results.whereType<String>().isNotEmpty, isTrue,
          reason: 'at least one start reports whom it paused');
    });

    test('starting the same task twice at once makes one session', () async {
      await _freshPrefs();

      await Future.wait([
        TimerService.start('taskA'),
        TimerService.start('taskA'),
      ]);

      expect(TimerService.sessions.length, 1);
      expect(TimerService.running?.taskId, 'taskA');
    });

    test('a corrupt list with two running sessions self-heals on load',
        () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _freshPrefs({
        'timer_sessions_json': '['
            '{"sessionId":"s1","taskId":"A","startedAt":${now - 60000},'
            '"accum":0,"paused":false},'
            '{"sessionId":"s2","taskId":"B","startedAt":${now - 10000},'
            '"accum":0,"paused":false}]',
      });

      // Any mutation runs the repair.
      await TimerService.pause('B');

      final live = TimerService.sessions.where((s) => !s.isPaused);
      expect(live, isEmpty);
      // A's minute was banked, not thrown away.
      expect(TimerService.forTask('A')!.accumSeconds, greaterThanOrEqualTo(59));
    });

    test('banked time is capped, so a forgotten timer cannot bank 18h',
        () async {
      final eighteenHoursAgo = DateTime.now()
          .subtract(const Duration(hours: 18))
          .millisecondsSinceEpoch;
      await _freshPrefs({
        'timer_sessions_json': '[{"sessionId":"s1","taskId":"A",'
            '"startedAt":$eighteenHoursAgo,"accum":0,"paused":false}]',
      });

      await TimerService.pause('A');

      expect(TimerService.forTask('A')!.accumSeconds,
          TimerService.maxSessionSeconds);
    });

    test('resume on a task with no session does nothing', () async {
      await _freshPrefs();
      expect(await TimerService.resume('ghost'), isNull);
      expect(TimerService.sessions, isEmpty);
    });

    test('a pre-multi-session timer survives the upgrade', () async {
      final startedAt = DateTime.now().millisecondsSinceEpoch - 30000;
      await _freshPrefs({
        'active_timer_task_id': 'oldTask',
        'active_timer_started_at_millis': startedAt,
        'active_timer_accum_seconds': 42,
        'active_timer_paused': false,
      });

      final t = TimerService.forTask('oldTask');
      expect(t, isNotNull);
      expect(t!.accumSeconds, 42);
      expect(t.isPaused, isFalse);

      // And the legacy keys are gone, so it can't be folded in twice.
      final p = await SharedPreferences.getInstance();
      expect(p.getString('active_timer_task_id'), isNull);
    });
  });

  group('time ledger grouping', () {
    test('reconstructs a session with a pause in the middle', () {
      final base = DateTime(2026, 9, 9, 10);
      final runs = groupTimerSessions([
        _event('s1', TimerEventKind.start, base),
        _event('s1', TimerEventKind.pause,
            base.add(const Duration(minutes: 18)),
            elapsed: 18 * 60),
        _event('s1', TimerEventKind.resume,
            base.add(const Duration(minutes: 33)),
            elapsed: 18 * 60),
        _event('s1', TimerEventKind.complete,
            base.add(const Duration(minutes: 53)),
            elapsed: 38 * 60),
      ]);

      expect(runs.length, 1);
      final run = runs.single;
      expect(run.isOpen, isFalse);
      expect(run.outcome, TimerEventKind.complete);
      expect(run.activeSeconds, 38 * 60);
      expect(run.spanSeconds, 53 * 60);
      expect(run.pausedSeconds, 15 * 60,
          reason: 'the 15 minutes away are span minus active');
      expect(run.pauseCount, 1);
    });

    test('groups by session and sorts newest first', () {
      final base = DateTime(2026, 9, 8, 9);
      final runs = groupTimerSessions([
        _event('older', TimerEventKind.start, base),
        _event('older', TimerEventKind.stop,
            base.add(const Duration(minutes: 10)),
            elapsed: 600),
        _event('newer', TimerEventKind.start,
            base.add(const Duration(days: 1))),
      ]);

      expect(runs.map((r) => r.sessionId).toList(), ['newer', 'older']);
      expect(runs.first.isOpen, isTrue,
          reason: 'no terminal event yet — still on the clock');
      expect(runs.first.outcome, isNull);
    });

    test('a session still on the clock counts its live time', () {
      final startedAt = DateTime.now().subtract(const Duration(minutes: 40));
      final run = groupTimerSessions([
        _event('s1', TimerEventKind.start, startedAt),
      ]).single;

      expect(run.isOpen, isTrue);
      expect(run.activeSeconds, greaterThanOrEqualTo(39 * 60),
          reason: 'start logs a zero — without the live tail this reads 00:00');
    });

    test('an auto-pause counts as an interruption', () {
      final base = DateTime(2026, 9, 9, 14);
      final run = groupTimerSessions([
        _event('s1', TimerEventKind.start, base),
        _event('s1', TimerEventKind.autoPause,
            base.add(const Duration(minutes: 5)),
            elapsed: 300),
      ]).single;

      expect(run.interruptionCount, 1);
      expect(run.pauseCount, 0, reason: 'it was the app, not the user');
    });
  });
}
