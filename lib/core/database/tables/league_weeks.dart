import 'package:drift/drift.dart';

/// One closed-out week of activity (Mon–Sun), written lazily on the first
/// app open after a week ends. This is the "real leagues later" prep from
/// docs/gamification_plan.md §1: we persist NORMALIZED metrics from day one
/// (active days, completion ratio, quests) because task point values are
/// user-defined — raw points can never be a fair cross-user ranking metric.
/// Rows flow through change_log like every mutation, so week history syncs
/// for free when the backend arrives.
@DataClassName('LeagueWeek')
class LeagueWeeks extends Table {
  /// Monday of the week, date-only. Primary key.
  DateTimeColumn get weekStart => dateTime()();

  /// Points earned that week (personal metric — display only).
  IntColumn get points => integer().withDefault(const Constant(0))();

  /// Real (non-skip, non-ND) completions that week.
  IntColumn get completions => integer().withDefault(const Constant(0))();

  /// Days with at least one real completion (0–7).
  IntColumn get activeDays => integer().withDefault(const Constant(0))();

  /// completions / scheduled-occurrences, clamped 0–1. The future fair
  /// ranking ingredient.
  RealColumn get completionRatio => real().withDefault(const Constant(0))();

  /// Daily quests completed that week (0–7). Fair-metric ingredient.
  IntColumn get questsCompleted => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {weekStart};

  @override
  String get tableName => 'league_weeks';
}
