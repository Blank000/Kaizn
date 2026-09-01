import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Pico — the gadget companion from the cast call, now cast as the face of
/// the AI features (Ask-anything chat, plan import). Ported 1:1 from the
/// approved cast-call art with his full idle set: hover, antenna pulse,
/// screen-eye blinks, a beating pixel heart, and the little wave.
///
/// Functional surface only — no delight toggle: the AI UI never loses its
/// face. Motion still respects reduced-motion.
class PicoFigure extends StatefulWidget {
  /// Rendered height (art space 210×250, width ≈ .84h).
  final double size;

  const PicoFigure({super.key, this.size = 96});

  @override
  State<PicoFigure> createState() => _PicoFigureState();
}

class _PicoFigureState extends State<PicoFigure>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7600),
  );

  void _syncIdle(bool animate) {
    if (animate && !_idle.isAnimating) {
      _idle.repeat();
    } else if (!animate && _idle.isAnimating) {
      _idle.stop();
      _idle.value = 0;
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncIdle(!MediaQuery.of(context).disableAnimations);
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(widget.size * 210 / 250, widget.size),
        painter: _PicoPainter(repaint: _idle),
      ),
    );
  }
}

class _PicoPainter extends CustomPainter {
  final Animation<double> repaint;

  _PicoPainter({required this.repaint}) : super(repaint: repaint);

  static const _shell = Color(0xFFE9EEF4);
  static const _shellDark = Color(0xFFD7E0E9);
  static const _bolt = Color(0xFFC6D2DC);
  static const _antenna = Color(0xFFB9C6D2);
  static const _screen = Color(0xFF15202B);
  static const _eye = Color(0xFF1CB0F6);
  static const _light = Color(0xFFFF9600);
  static const _heart = Color(0xFF58CC02);

  @override
  void paint(Canvas canvas, Size size) {
    final v = repaint.value;
    // Idle mix, mirroring the cast-call page: hover 3 cycles/loop (~2.5s),
    // antenna pulse ~6, heart beat ~4.75, wave 3, blink every 3.4s.
    final hover = math.sin(v * 2 * math.pi * 3) * 5.0;
    final lightAlpha = 0.65 + 0.35 * math.sin(v * 2 * math.pi * 6);
    final heartScale =
        1 + 0.10 * math.max(0.0, math.sin(v * 2 * math.pi * 4.75));
    final waveDeg = math.sin(v * 2 * math.pi * 3) * 8.0;
    final blinkT = (v * 7600 % 3400) / 3400;
    final eyeScaleY = (blinkT > 0.93 && blinkT < 0.99) ? 0.15 : 1.0;

    canvas.scale(size.height / 250);

    final fill = Paint()..style = PaintingStyle.fill;

    // Ground shadow stays put while the body hovers.
    canvas.drawOval(
        Rect.fromCenter(
            center: const Offset(100, 242), width: 60, height: 12),
        fill..color = Colors.black.withValues(alpha: 0.2));

    canvas.save();
    canvas.translate(0, hover);

    // Antenna + status light.
    canvas.drawLine(
        const Offset(100, 122),
        const Offset(100, 102),
        Paint()
          ..color = _antenna
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(const Offset(100, 95), 7,
        fill..color = _light.withValues(alpha: lightAlpha));

    // Body capsule + ear bolts.
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(62, 118, 76, 112),
            const Radius.circular(34)),
        fill..color = _shell);
    canvas.drawCircle(const Offset(60, 142), 7, fill..color = _bolt);
    canvas.drawCircle(const Offset(140, 142), 7, fill..color = _bolt);

    // Face screen.
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(70, 130, 60, 36),
            const Radius.circular(13)),
        fill..color = _screen);
    // Eyes blink by squashing about their centers.
    for (final x in const [82.0, 108.0]) {
      canvas.save();
      canvas.translate(x + 5, 146.5);
      canvas.scale(1, eyeScaleY);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(-5, -6.5, 10, 13),
              const Radius.circular(3)),
          fill..color = _eye);
      canvas.restore();
    }
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(95, 158, 10, 3),
            const Radius.circular(1.5)),
        fill..color = _eye.withValues(alpha: 0.65));

    // Belly panel + the beating pixel heart.
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(76, 178, 48, 34),
            const Radius.circular(10)),
        fill..color = _shellDark);
    canvas.save();
    canvas.translate(100, 196);
    canvas.scale(heartScale);
    canvas.translate(-100, -196);
    fill.color = _heart;
    canvas.drawRect(const Rect.fromLTWH(88, 186, 9, 8), fill);
    canvas.drawRect(const Rect.fromLTWH(103, 186, 9, 8), fill);
    canvas.drawRect(const Rect.fromLTWH(86, 192, 28, 7), fill);
    canvas.drawRect(const Rect.fromLTWH(91, 199, 18, 5), fill);
    canvas.drawRect(const Rect.fromLTWH(96, 204, 8, 4), fill);
    canvas.restore();

    // Resting arm (viewer left).
    canvas.save();
    canvas.translate(49, 179);
    canvas.rotate(14 * math.pi / 180);
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-9, -21, 18, 42),
            const Radius.circular(9)),
        fill..color = _shell);
    canvas.restore();
    canvas.drawCircle(const Offset(45, 202), 9, fill..color = _shellDark);

    // Waving arm (viewer right): base pose −146° with the wave on top.
    canvas.save();
    canvas.translate(148, 168);
    canvas.rotate(waveDeg * math.pi / 180);
    canvas.translate(-148, -168);
    canvas.save();
    canvas.translate(149, 151);
    canvas.rotate(-146 * math.pi / 180);
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-9, -23, 18, 46),
            const Radius.circular(9)),
        fill..color = _shell);
    canvas.restore();
    canvas.drawCircle(const Offset(160, 128), 9, fill..color = _shellDark);
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PicoPainter old) => false; // driven by the Listenable
}
