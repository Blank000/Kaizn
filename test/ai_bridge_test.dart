import 'package:flutter_test/flutter_test.dart';

import 'package:habit_reward_tracker/core/database/tables/tasks.dart';
import 'package:habit_reward_tracker/features/ai/ai_bridge.dart';

void main() {
  test('parses a typical AI reply: prose + fenced json block', () {
    const reply = '''
Great! Here's a plan for your 10K goal:

```json
{
  "milestones": [
    {
      "name": "Run a 10K",
      "target_date": "2026-12-01",
      "completion_bonus": 300,
      "tasks": [
        {
          "name": "Morning run",
          "recurrence": "weekly",
          "days_of_week": ["mon", "wed", "fri"],
          "start_time": "07:00",
          "duration_minutes": 30,
          "points": 15,
          "reminder": "06:45",
          "tiny_version": "Put on running shoes"
        },
        {
          "name": "Register for the race",
          "recurrence": "once",
          "due_date": "2026-09-15"
        }
      ]
    }
  ],
  "rewards": [
    {"name": "New running shoes", "points_threshold": 800}
  ]
}
```

Good luck with the training!
''';
    final plan = parseAiPlan(reply);
    expect(plan.milestones, hasLength(1));
    final m = plan.milestones.first;
    expect(m.name, 'Run a 10K');
    expect(m.completionBonus, 300);
    expect(m.targetDate, DateTime(2026, 12, 1));
    expect(m.tasks, hasLength(2));

    final run = m.tasks.first;
    expect(run.recurrence, TaskRecurrence.weekly);
    expect(run.daysOfWeek, [1, 3, 5]);
    expect(run.startMinute, 7 * 60);
    expect(run.reminderMinute, 6 * 60 + 45);
    expect(run.points, 15);
    expect(run.tinyVersion, 'Put on running shoes');
    expect(run.summary(), isNotEmpty);

    final race = m.tasks[1];
    expect(race.recurrence, TaskRecurrence.none);
    expect(race.dueDate, DateTime(2026, 9, 15));

    expect(plan.rewards, hasLength(1));
    expect(plan.rewards.single.name, 'New running shoes');
    expect(plan.rewards.single.pointsThreshold, 800);
  });

  test('accepts a bare single-milestone object without fences', () {
    const reply =
        '{"name": "Read more", "tasks": [{"name": "Read 10 pages", "recurrence": "daily"}]}';
    final plan = parseAiPlan(reply);
    expect(plan.milestones.single.name, 'Read more');
    expect(plan.milestones.single.tasks.single.recurrence,
        TaskRecurrence.daily);
    expect(plan.milestones.single.tasks.single.points, 10); // default
    expect(plan.rewards, isEmpty);
  });

  test('accepts a rewards-only plan', () {
    const reply =
        '{"rewards": [{"name": "Spa day", "description": "earned", "points_threshold": 1500}]}';
    final plan = parseAiPlan(reply);
    expect(plan.milestones, isEmpty);
    expect(plan.rewards.single.name, 'Spa day');
    expect(plan.rewards.single.description, 'earned');
    expect(plan.rewards.single.pointsThreshold, 1500);
  });

  test('parses updates and enforces their shape', () {
    const reply = '''
```json
{
  "updates": [
    {"type": "milestone", "id": "abc123", "set": {"name": "Run a half marathon", "target_date": "2027-03-01"}},
    {"type": "task", "id": "t456", "set": {"points": 20, "reminder": null, "bogus_field": 1}},
    {"type": "reward", "id": "r789", "set": {"points_threshold": 900}}
  ]
}
```''';
    final plan = parseAiPlan(reply);
    expect(plan.milestones, isEmpty);
    expect(plan.updates, hasLength(3));
    expect(plan.updates[0].type, 'milestone');
    expect(plan.updates[0].set['name'], 'Run a half marathon');
    // reminder:null must survive (it means "clear the reminder"); unknown
    // fields are dropped.
    expect(plan.updates[1].set.containsKey('reminder'), isTrue);
    expect(plan.updates[1].set['reminder'], isNull);
    expect(plan.updates[1].set.containsKey('bogus_field'), isFalse);
    expect(plan.updates[2].set['points_threshold'], 900);

    expect(
        () => parseAiPlan(
            '{"updates": [{"type": "streak", "id": "x", "set": {"days": 99}}]}'),
        throwsFormatException);
    expect(
        () => parseAiPlan(
            '{"updates": [{"type": "task", "set": {"name": "x"}}]}'),
        throwsFormatException);
    expect(
        () => parseAiPlan(
            '{"updates": [{"type": "task", "id": "t1", "set": {"bogus": 1}}]}'),
        throwsFormatException);
  });

  test('update targeting survives model id-mangling', () {
    // Prefixed, bracketed, and name-as-id forms must all resolve.
    expect(normalizeUpdateId('m:abc123'), 'abc123');
    expect(normalizeUpdateId('[t:xyz]'), 'xyz');
    expect(normalizeUpdateId('  r: q1w2 '), 'q1w2');
    expect(normalizeUpdateId('plainid'), 'plainid');

    final names = {'id1': 'Run a 10K', 'id2': 'Read More', 'id3': 'read more'};
    AiPlanUpdate u(String id) =>
        AiPlanUpdate(type: 'milestone', id: id, set: const {'name': 'x'});
    expect(resolveUpdateId(u('id2'), names), 'id2'); // exact id
    expect(resolveUpdateId(u('m:id1'), names), 'id1'); // prefixed id
    expect(resolveUpdateId(u('Run a 10K'), names), 'id1'); // unique name
    expect(resolveUpdateId(u('Read More'), names),
        isNull); // ambiguous name (case-insensitive dup) → skip
    expect(resolveUpdateId(u('nope'), names), isNull);

    // Parser normalizes ids up front.
    final plan = parseAiPlan(
        '{"updates": [{"type": "milestone", "id": "[m:abc]", "set": {"name": "N"}}]}');
    expect(plan.updates.single.id, 'abc');
  });

  test('clamps hostile values and rejects garbage kindly', () {
    final plan = parseAiPlan(
        '{"milestones": [{"name": "X", "tasks": [{"name": "Y", "recurrence": "daily", "points": 9999, "duration_minutes": -5}]}], "rewards": [{"name": "R", "points_threshold": -3}]}');
    expect(plan.milestones.single.tasks.single.points, 100);
    expect(plan.milestones.single.tasks.single.durationMinutes, 1);
    expect(plan.rewards.single.pointsThreshold, 1);

    expect(() => parseAiPlan('no json here at all'),
        throwsFormatException);
    expect(() => parseAiPlan('{"milestones": []}'), throwsFormatException);
    expect(() => parseAiPlan('{"milestones": [], "rewards": []}'),
        throwsFormatException);
    expect(
        () => parseAiPlan(
            '{"milestones": [{"tasks": []}]}'), // missing name
        throwsFormatException);
    expect(
        () => parseAiPlan(
            '{"rewards": [{"points_threshold": 100}]}'), // missing name
        throwsFormatException);
  });
}
