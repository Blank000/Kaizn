import 'package:drift/drift.dart';

/// Streak table - single-row table tracking streak state
@DataClassName('Streak')
class StreakTable extends Table {
  // Primary key (always 1 - singleton)
  IntColumn get id => integer().withDefault(const Constant(1))();

  // Streak data
  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get longestStreak => integer().withDefault(const Constant(0))();

  // Last activity
  DateTimeColumn get lastLoggedDate =>
      dateTime().nullable()(); // Last date a real entry was made

  // Milestone tracking
  IntColumn get lastMilestoneCelebrated =>
      integer().withDefault(const Constant(0))(); // Avoids repeat popups

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'streak';
}
