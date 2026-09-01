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
  ]
}
```

Good luck with the training!
''';
    final plan = parseAiPlan(reply);
    expect(plan, hasLength(1));
    final m = plan.first;
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
  });

  test('accepts a bare single-milestone object without fences', () {
    const reply =
        '{"name": "Read more", "tasks": [{"name": "Read 10 pages", "recurrence": "daily"}]}';
    final plan = parseAiPlan(reply);
    expect(plan.single.name, 'Read more');
    expect(plan.single.tasks.single.recurrence, TaskRecurrence.daily);
    expect(plan.single.tasks.single.points, 10); // default
  });

  test('clamps hostile values and rejects garbage kindly', () {
    final plan = parseAiPlan(
        '{"milestones": [{"name": "X", "tasks": [{"name": "Y", "recurrence": "daily", "points": 9999, "duration_minutes": -5}]}]}');
    expect(plan.single.tasks.single.points, 100);
    expect(plan.single.tasks.single.durationMinutes, 1);

    expect(() => parseAiPlan('no json here at all'),
        throwsFormatException);
    expect(() => parseAiPlan('{"milestones": []}'), throwsFormatException);
    expect(
        () => parseAiPlan(
            '{"milestones": [{"tasks": []}]}'), // missing name
        throwsFormatException);
  });
}
