import 'package:drift/drift.dart';

/// Append-only journal of every data mutation (see docs/architecture_vision.md
/// §2, decision 3). Written inside the same transaction as the mutation it
/// records.
///
/// What it powers, in order of arrival:
///  - now: debounced auto-backup ("something changed → back up soon")
///  - soon: audit/history UI, robust undo
///  - later: multi-device sync (replay the journal) and the outbox for
///    two-way integrations (push completions to Notion etc., retry on failure)
///
/// Rows are cheap (one insert per write) and never read on hot paths.
@DataClassName('ChangeLogEntry')
class ChangeLog extends Table {
  // Monotonic append order. Drift autoIncrement = INTEGER PRIMARY KEY.
  IntColumn get seq => integer().autoIncrement()();

  // What was touched: 'task' | 'milestone' | 'completion' | 'reward' |
  // 'points' | 'streak'. Plain text, not an enum — new entity types must not
  // require a migration.
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();

  // 'create' | 'update' | 'delete'. Plain text for the same reason.
  TextColumn get op => text()();

  // Optional JSON snapshot of the row (or the delta) at mutation time.
  // Nullable — cheap ops may log without a payload.
  TextColumn get payloadJson => text().nullable()();

  DateTimeColumn get at => dateTime().withDefault(currentDateAndTime)();

  // Which device wrote this. 'local' until real multi-device sync exists.
  TextColumn get deviceId => text().withDefault(const Constant('local'))();

  // Sync/outbox bookkeeping: false until a connector has shipped this entry.
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  String get tableName => 'change_log';
}
