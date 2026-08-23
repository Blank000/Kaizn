import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'living_flame.dart';

/// The streak fire, designer edition: plays the user-picked LottieFiles
/// animation (assets/lottie/streak_flame.json — see assets/lottie/README.md)
/// and falls back to the code-drawn LivingFlame when the file isn't bundled
/// or fails to parse. Zero-streak stays on the drawn ember — the Lottie
/// asset is a full roaring fire, wrong for "not lit yet".
class StreakFlame extends StatelessWidget {
  final int streak;
  final double size;

  const StreakFlame({super.key, required this.streak, this.size = 30});

  @override
  Widget build(BuildContext context) {
    if (streak <= 0) return LivingFlame(streak: streak, size: size);
    final still = MediaQuery.of(context).disableAnimations;
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        'assets/lottie/streak_flame.json',
        fit: BoxFit.contain,
        animate: !still,
        repeat: true,
        errorBuilder: (_, __, ___) =>
            LivingFlame(streak: streak, size: size),
      ),
    );
  }
}
