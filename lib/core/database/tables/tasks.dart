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

  // Optional scheduled time for timeline view. Minutes from midnight (0..1439).
  // Null = "anytime" — task is not on the timeline grid.
  IntColumn get startMinute => integer().nullable()();

  // Block length on the timeline in minutes. Defaults to 30; only meaningful
  // when startMinute is non-null.
  IntColumn get durationMinutes =>
      integer().withDefault(const Constant(30))();

  // Whether a per-task reminder notification should fire on days this task is
  // due.
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();

  // Minute-from-midnight (0..1439) the reminder fires at. Null while
  // reminderEnabled means "follow the timeline start time"; an explicit value
  // overrides it. Ignored entirely when reminderEnabled is false.
  IntColumn get reminderMinute => integer().nullable()();

  // Optional specific date the reminder should fire on. When set + reminder
  // is enabled, the reminder is treated as a ONE-SHOT nudge: it fires exactly
  // once on this date+time and ignores the task's recurrence. When null, the
  // reminder follows the recurrence (fires on every day the task is due).
  DateTimeColumn get reminderDate => dateTime().nullable()();

  TextColumn get status =>
      textEnum<TaskStatus>().withDefault(Constant(TaskStatus.active.value))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
