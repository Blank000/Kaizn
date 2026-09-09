import 'package:drift/drift.dart';

/// The time ledger: one immutable row per stopwatch event.
///
/// Every start / pause / resume / stop writes a row here, so a session is
/// reconstructable long after the live timer state is gone ("I started at
/// 10:02, paused 18 minutes in, came back at 10:35"). Rows are append-only —
/// nothing in the app edits or deletes them, which is what makes the ledger
/// trustworthy for pattern analysis later.
///
/// [taskName] is denormalised on purpose: the ledger has to survive the task
/// (or its whole milestone) being deleted.
@DataClassName('TimerEvent')
class TimerEvents extends Table {
  TextColumn get id => text()();

  /// Groups events into one stopwatch session (start → … → stop).
  TextColumn get sessionId => text()();

  TextColumn get taskId => text()();

  /// Snapshot of the task name at event time — survives task deletion.
  TextColumn get taskName => text()();

  /// One of [TimerEventKind]'s wire values.
  TextColumn get kind => text()();

  /// Banked seconds on the clock at the moment of the event.
  IntColumn get elapsedSeconds => integer().withDefault(const Constant(0))();

  /// When it happened (wall clock).
  DateTimeColumn get at => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Wire values stored in [TimerEvents.kind]. Kept as plain strings (not a
/// Drift textEnum) so an unknown future value read from an old row can never
/// crash the ledger screen.
class TimerEventKind {
  TimerEventKind._();

  static const start = 'start';
  static const pause = 'pause';

  /// Paused by the app because the user started timing a different task.
  static const autoPause = 'auto_pause';
  static const resume = 'resume';

  /// Session ended and the time was credited to a completion.
  static const complete = 'complete';

  /// Session ended without crediting (Add time / plain stop).
  static const stop = 'stop';

  /// Session thrown away by the user.
  static const discard = 'discard';

  /// The task disappeared under a running timer.
  static const vanished = 'vanished';

  /// True for the kinds that close a session.
  static bool isTerminal(String kind) =>
      kind == complete || kind == stop || kind == discard || kind == vanished;

  static String label(String kind) {
    switch (kind) {
      case start:
        return 'Started';
      case pause:
        return 'Paused';
      case autoPause:
        return 'Auto-paused';
      case resume:
        return 'Resumed';
      case complete:
        return 'Completed';
      case stop:
        return 'Stopped';
      case discard:
        return 'Discarded';
      case vanished:
        return 'Task deleted';
      default:
        return kind;
    }
  }
}
