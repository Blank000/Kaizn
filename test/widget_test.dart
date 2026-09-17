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

    // The login screen wordmark. Guards the rename: if this ever reads
    // 'Habit Reward Tracker' again, a display-name revert slipped through.
    expect(find.text('Yatta!'), findsOneWidget);
  });
}
