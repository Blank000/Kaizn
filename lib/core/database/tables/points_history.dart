import 'package:drift/drift.dart';
import 'task_completions.dart';
import 'tasks.dart';

/// Reason a point event was recorded. Drives audit log + reporting.
enum PointsReason {
  taskCompletion('task_completion'),
  milestoneBonus('milestone_bonus'),
  // Completion landed in the last stretch of the task's scheduled window
  // ("beat the buzzer"). Wave 2 of the Atomic Habits plan; enum added early
  // so the v7 codegen batch is done once. textEnum stores the Dart name, so
  // adding a value needs no migration.
  clutchBonus('clutch_bonus'),
  // Daily quest completed (fixed small bonus; see gamification_plan.md —
  // total system bonuses stay ≤ ~20% of weekly base to protect the
  // user-priced reward economy).
  questBonus('quest_bonus'),
  // Weekly 5-of-7 quest-chain chest opened (FIXED +50 — anticipation lives
  // in the animation, never in randomized amounts).
  chestBonus('chest_bonus');

  const PointsReason(this.value);
  final String value;
}

/// Points History table - audit log of all point events.
@DataClassName('PointsHistory')
class PointsHistoryTable extends Table {
  TextColumn get id => text()();

  // FK to the completion that triggered the points event.
  // Nullable because milestone bonuses are not tied to a single completion.
  TextColumn get taskCompletionId =>
      text().nullable().references(TaskCompletions, #id)();

  // FK to the task whose completion earned points.
  // Nullable for milestone-bonus events (which are milestone-level).
  TextColumn get taskId => text().nullable().references(Tasks, #id)();

  // FK to the milestone for milestone-bonus events; null for task completions.
  TextColumn get milestoneId => text().nullable()();

  IntColumn get points => integer()();
  TextColumn get reason => textEnum<PointsReason>()();

  DateTimeColumn get earnedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'points_history';
}
