import 'package:drift/drift.dart';

/// Lifecycle status for a milestone.
enum MilestoneStatus {
  active('active'),
  completed('completed'),
  archived('archived');

  const MilestoneStatus(this.value);
  final String value;
}

/// Milestones table - top-level container for sub-tasks.
/// Tasks can also exist without a milestone (adhoc).
@DataClassName('Milestone')
class Milestones extends Table {
  TextColumn get id => text()();

  // user_id is forward-looking for future leaderboards / multi-user sync.
  TextColumn get userId => text().withDefault(const Constant('local'))();

  TextColumn get name => text()();
  TextColumn get description => text().nullable()();

  TextColumn get status =>
      textEnum<MilestoneStatus>().withDefault(Constant(MilestoneStatus.active.value))();

  // Index into AppColors.milestonePalette. Default 0 = primary green.
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();

  // Optional deadline (e.g. "by Dec 2026").
  DateTimeColumn get targetDate => dateTime().nullable()();

  // Bonus points awarded once when this milestone is fully completed.
  IntColumn get completionPoints => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
