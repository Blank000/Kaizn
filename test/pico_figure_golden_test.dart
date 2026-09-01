import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_reward_tracker/shared/widgets/pico_figure.dart';

// Visual check for the Pico port: `flutter test --update-goldens`
// writes test/goldens/pico_figure.png — eyeball it against the cast-call
// artifact before shipping painter changes.
void main() {
  testWidgets('PicoFigure renders the approved art', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF16222E),
          body: Center(child: PicoFigure(size: 220)),
        ),
      ),
    );
    await expectLater(
      find.byType(PicoFigure),
      matchesGoldenFile('goldens/pico_figure.png'),
    );
  });
}
