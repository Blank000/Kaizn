import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_reward_tracker/shared/widgets/ren_figure.dart';

// Visual check for the Master Ren port: `flutter test --update-goldens`
// writes test/goldens/ren_figure.png — eyeball it against the approved
// cast-call art before shipping painter changes.
void main() {
  testWidgets('RenFigure renders the approved art', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF16222E),
          body: Center(child: RenFigure(size: 220)),
        ),
      ),
    );
    await expectLater(
      find.byType(RenFigure),
      matchesGoldenFile('goldens/ren_figure.png'),
    );
  });
}
