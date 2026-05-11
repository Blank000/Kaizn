import 'package:drift/drift.dart';

/// Rewards table - stores all rewards the user has defined.
@DataClassName('Reward')
class Rewards extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().withDefault(const Constant('local'))();

  TextColumn get name => text()();
  TextColumn get description => text().nullable()();

  IntColumn get pointsThreshold => integer()();

  BoolColumn get isClaimed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get claimedAt => dateTime().nullable()();

  // Future "publish for accountability" feature — surfaced now to keep the
  // schema stable across that rollout.
  BoolColumn get isPublic => boolean().withDefault(const Constant(false))();
  DateTimeColumn get publishedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
