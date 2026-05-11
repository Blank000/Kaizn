import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_reward_tracker/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: HabitRewardTrackerApp(),
      ),
    );

    // Verify that app title is shown
    expect(find.text('Habit Reward Tracker'), findsOneWidget);
  });
}
