import 'package:drift/drift.dart';
import 'milestones.dart';

/// Recurrence pattern for a task. `none` = one-shot.
/// All recurring kinds read interval/days/dayOfMonth from `recurrenceConfig`.
enum TaskRecurrence {
  none('none'),
  daily('daily'),
  weekly('weekly'),
  monthly('monthly');

  const TaskRecurrence(this.value);
  final String value;
}

/// Lifecycle status for a task.
enum TaskStatus {
  active('active'),
  completed('completed'),
  archived('archived');

  const TaskStatus(this.value);
  final String value;
}

/// Tasks table - sub-tasks of a milestone, or adhoc tasks (null milestone).
@DataClassName('Task')
class Tasks extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().withDefault(const Constant('local'))();

  // Null = adhoc task (no parent milestone).
  TextColumn get milestoneId =>
      text().nullable().references(Milestones, #id)();

  TextColumn get name => text()();
  TextColumn get description => text().nullable()();

  IntColumn get pointsPerCompletion =>
      integer().withDefault(const Constant(10))();

  TextColumn get recurrence =>
      textEnum<TaskRecurrence>().withDefault(Constant(TaskRecurrence.none.value))();

  // JSON-encoded extra config (e.g. {"days":["mon","wed","fri"]}).
  // Parsed in Dart; null when not needed.
  TextColumn get recurrenceConfig => text().nullable()();

  // For one-shot tasks; null for habits.
  DateTimeColumn get dueDate => dateTime().nullable()();

  TextColumn get status =>
      textEnum<TaskStatus>().withDefault(Constant(TaskStatus.active.value))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
