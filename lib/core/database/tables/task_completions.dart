import 'package:drift/drift.dart';
import 'tasks.dart';

/// Task completions table - one row per time a task is checked off.
/// Drives streaks, points history, and "today's summary".
@DataClassName('TaskCompletion')
class TaskCompletions extends Table {
  TextColumn get id => text()();

  TextColumn get taskId => text().references(Tasks, #id)();
  TextColumn get userId => text().withDefault(const Constant('local'))();

  // The calendar day this completion counts toward (use date-only semantics).
  DateTimeColumn get completedOn => dateTime()();

  IntColumn get pointsEarned => integer().withDefault(const Constant(0))();

  // Carried over from the old `entries` model.
  BoolColumn get isSkip => boolean().withDefault(const Constant(false))();
  BoolColumn get isNd => boolean().withDefault(const Constant(false))();

  TextColumn get note => text().nullable()();

  // Exact timestamp of the log event.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'task_completions';
}
