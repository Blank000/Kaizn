import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A streak flame that is actually on fire: three layered teardrops whose
/// tips sway and flicker on independent sine rhythms, sized by streak tier
/// (ember → steady → strong → blaze with rising sparks). Vector-drawn, so
/// it's crisp at any size and doubles as the body of Zen, the mascot
/// (docs/character_brief_yatta_spark.md).
///
/// Honors reduced-motion (renders a still frame) and costs one cheap
/// repaint per frame inside its own RepaintBoundary.
class LivingFlame extends StatefulWidget {
  final int streak;

  /// Height of the flame's bounding box.
  final double size;

  const LivingFlame({super.key, required this.streak, this.size = 30});

  @override
  State<LivingFlame> createState() => _LivingFlameState();
}

class _LivingFlameState extends State<LivingFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Streak tiers: how big and lively the fire is.
  double get _tierScale {
    final s = widget.streak;
    if (s <= 0) return 0.72; // unlit ember — small and quiet
    if (s < 3) return 0.82;
    if (s < 7) return 0.95;
    if (s < 30) return 1.08;
    return 1.22; // blaze
  }

  bool get _blaze => widget.streak >= 30;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    final box = widget.size;
    return RepaintBoundary(
      child: SizedBox(
        width: box,
        height: box,
        child: still
            ? CustomPaint(
                painter: _FlamePainter(
                    t: 0.3,
                    scale: _tierScale,
                    lit: widget.streak > 0,
                    sparks: false),
              )
            : AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => CustomPaint(
                  painter: _FlamePainter(
                    t: _ctrl.value,
                    scale: _tierScale,
                    lit: widget.streak > 0,
                    sparks: _blaze,
                  ),
                ),
              ),
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  /// 0..1 loop position.
  final double t;
  final double scale;
  final bool lit;
  final bool sparks;

  _FlamePainter({
    required this.t,
    required this.scale,
    required this.lit,
    required this.sparks,
  });

  double _sway(double freq, double phase) =>
      math.sin(t * 2 * math.pi * freq + phase);

  /// A teardrop flame: round bulb at the bottom, tip pulled up and swaying.
  Path _flame(Size size, double w, double h, double tipSway) {
    final cx = size.width / 2;
    final base = size.height * 0.94;
    final tip = Offset(cx + tipSway, base - h);
    final path = Path()
      ..moveTo(cx, base)
      // left side: bulge out, then curve into the tip
      ..cubicTo(cx - w, base, cx - w * 0.92, base - h * 0.45,
          tip.dx - w * 0.12, tip.dy + h * 0.18)
      ..quadraticBezierTo(tip.dx, tip.dy - h * 0.06, tip.dx + w * 0.12,
          tip.dy + h * 0.18)
      // right side back down to the bulb
      ..cubicTo(cx + w * 0.92, base - h * 0.45, cx + w, base, cx, base)
      ..close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.height * scale;
    // Flicker: height breathes on two frequencies; tip sways on a third.
    final flicker =
        1 + 0.05 * _sway(1, 0) + 0.03 * _sway(2.4, 1.3);
    final tipSway = size.width * 0.055 * _sway(1.7, 0.6) +
        size.width * 0.03 * _sway(3.1, 2.2);

    final dim = lit ? 1.0 : 0.45;

    // Outer flame — deep orange.
    final outerH = unit * 0.78 * flicker;
    final outerW = unit * 0.30;
    canvas.drawPath(
      _flame(size, outerW, outerH, tipSway),
      Paint()
        ..color = const Color(0xFFFF6D00).withValues(alpha: dim)
        ..style = PaintingStyle.fill,
    );

    // Mid flame — brand streak orange, slightly out of phase.
    final midH = unit * 0.56 * (1 + 0.06 * _sway(2.0, 2.6));
    canvas.drawPath(
      _flame(size, outerW * 0.68, midH, tipSway * 0.7),
      Paint()..color = AppColors.streakOrange.withValues(alpha: dim),
    );

    // Core — gold, calmest layer.
    final coreH = unit * 0.34 * (1 + 0.05 * _sway(2.8, 4.0));
    canvas.drawPath(
      _flame(size, outerW * 0.4, coreH, tipSway * 0.45),
      Paint()
        ..color = const Color(0xFFFFE082)
            .withValues(alpha: lit ? 0.95 : 0.4),
    );

    // Blaze tier: two sparks rising and fading on looped offsets.
    if (sparks && lit) {
      for (final (phase, dx) in const [(0.0, -0.22), (0.55, 0.26)]) {
        final p = (t + phase) % 1.0;
        final sy = size.height * (0.55 - 0.5 * p);
        final sx = size.width / 2 +
            size.width * dx +
            size.width * 0.05 * _sway(2.2, phase * 6);
        canvas.drawCircle(
          Offset(sx, sy),
          size.width * 0.045 * (1 - p),
          Paint()
            ..color =
                AppColors.rewardsGold.withValues(alpha: (1 - p) * 0.9),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FlamePainter old) =>
      old.t != t ||
      old.scale != scale ||
      old.lit != lit ||
      old.sparks != sparks;
}
