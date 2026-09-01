import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/services/app_prefs.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';

/// Master Ren — the fox sensei, cast member #2 (see memory/character_ren.md).
/// Owner-approved art (v17 of the cast-call artifact) ported 1:1 from the
/// primitive SVG: ellipses + round-capped strokes + a mathematically tapered
/// tail polygon. Same contract as ZenSpark: the master toggle
/// (AppPrefs.renEnabled) makes the whole widget render nothing, so call
/// sites can include Ren unconditionally; he has no sad/disappointed state
/// and never appears in celebration frames (Kai/the fire own those).
/// Ren's poses. [standing]: staff planted, the default. [meditating]: staff
/// set down, seated, hands in his lap, tail curled low — the focus-timer
/// companion. While meditating, [RenFigure.peek] opens one eye (he checks on
/// you when the timer pauses).
enum RenPose { standing, meditating }

class RenFigure extends StatefulWidget {
  /// Rendered height. The figure keeps the 210:250 art aspect (width ≈ .84h).
  final double size;

  /// Optional proverb, shown in a bubble above (use [RenLines] pools).
  final String? line;

  final RenPose pose;

  /// Meditating only: one eye open (timer paused → he notices).
  final bool peek;

  const RenFigure({
    super.key,
    this.size = 96,
    this.line,
    this.pose = RenPose.standing,
    this.peek = false,
  });

  @override
  State<RenFigure> createState() => _RenFigureState();
}

class _RenFigureState extends State<RenFigure>
    with SingleTickerProviderStateMixin {
  // One looping controller drives both idle motions at different
  // frequencies: head bob (3.8s) and tail swish (3.04s) per 7.6s loop.
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
    final enabled = AppPrefs.renEnabledSync;
    final still = MediaQuery.of(context).disableAnimations;
    _syncIdle(enabled && !still);
    if (!enabled) return const SizedBox.shrink();

    final figure = RepaintBoundary(
      child: CustomPaint(
        size: Size(widget.size * 210 / 250, widget.size),
        painter: _RenPainter(
          repaint: _idle,
          pose: widget.pose,
          peek: widget.peek,
        ),
      ),
    );

    if (widget.line == null) return figure;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: context.appCardSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.appBorder),
          ),
          child: Text(
            widget.line!,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              color: context.appTextPrimary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        figure,
      ],
    );
  }
}

/// Ren's proverb pools — one per moment he hosts. Day-seeded so the line is
/// stable within a day and rotates across days (his promise: nothing repeats
/// often enough to become wallpaper).
class RenLines {
  static const _rest = [
    'Even fire rests. That is how it stays fire.',
    'Stillness is also training.',
    'A bow kept strung loses its spring.',
  ];
  static const _comeback = [
    'You returned. That is the whole lesson.',
    'The path waited. It always does.',
    'Tea first. Then one small step.',
  ];
  static const _empty = [
    'A blank scroll is not empty. It is ready.',
    'One task. Choose it well.',
    'A fox does not chase two rabbits.',
  ];

  static String rest() => _pick(_rest);
  static String comeback() => _pick(_comeback);
  static String empty() => _pick(_empty);

  static String _pick(List<String> pool) {
    final d = DateTime.now();
    return pool[(d.year * 372 + d.month * 31 + d.day) % pool.length];
  }

  /// The Sensei Post: Ren's accountability line, computed from the actual
  /// state of the day. Specific over generic — he names counts and tasks,
  /// notices yesterday's falls, and marks the hour. Watchful, never guilting.
  static String accountability({
    required int hour,
    required int done,
    required int remaining,
    required int missedToday,
    required int missedYesterday,
    required List<String> nextNames,
  }) {
    String names() {
      if (nextNames.isEmpty) return '';
      final shown = nextNames.take(2).join(', ');
      final more = nextNames.length - 2;
      return more > 0 ? '$shown +$more more' : shown;
    }

    if (remaining == 0 && missedToday == 0 && done > 0) {
      return '“Everything done. Today I have nothing to teach.”';
    }
    if (remaining == 0 && missedToday > 0) {
      return '“The day closes with $missedToday missed. Tomorrow we stand ${missedToday == 1 ? 'it' : 'them'} back up.”';
    }
    if (missedYesterday > 0 && done == 0 && hour < 12) {
      return '“Yesterday took ${missedYesterday == 1 ? 'a fall' : '$missedYesterday falls'}. Today stands ${missedYesterday == 1 ? 'it' : 'them'} up — start with ${nextNames.isNotEmpty ? nextNames.first : 'one task'}.”';
    }
    if (done == 0 && hour >= 17) {
      return '“The scroll is still blank and the sun is low. One line: ${names()}.”';
    }
    if (done == 0 && hour < 12) {
      return '“$remaining ${remaining == 1 ? 'task stands' : 'tasks stand'} before you: ${names()}. Begin with the smallest.”';
    }
    if (done == 0) {
      return '“Nothing logged yet. The day is still yours — barely. ${names()} waits.”';
    }
    if (hour >= 17) {
      return '“$done down. ${names()} ${remaining == 1 ? 'remains' : 'remain'}. Finish the day standing.”';
    }
    return '“$done down, $remaining to go. I am watching — keep walking.”';
  }
}

/// The figure, painted in the art's 210×250 coordinate space and scaled to
/// the widget box. Draw order matches the approved SVG: shadow, tail, staff,
/// robe, chest, arms, feet, head (the head carries the bob).
class _RenPainter extends CustomPainter {
  final Animation<double> repaint;
  final RenPose pose;
  final bool peek;

  _RenPainter({required this.repaint, required this.pose, required this.peek})
      : super(repaint: repaint);

  // Palette (identical hexes to the approved art).
  static const _fox = Color(0xFFE8823C);
  static const _cream = Color(0xFFF7EFDC);
  static const _browCream = Color(0xFFF4F6F8);
  static const _ink = Color(0xFF4A2E1C);
  static const _innerEar = Color(0xFF5C3A22);
  static const _robe = Color(0xFF6B7C90);
  static const _robeDark = Color(0xFF56677A);
  static const _staffWood = Color(0xFFB99568);
  static const _staffDark = Color(0xFF9C7B4E);
  static const _blush = Color(0xFFF49B62);
  static const _toe = Color(0xFFC96F2E);
  static const _knuckle = Color(0xFFD06F2E);

  // ── tapered tail, same math that generated the approved artwork ─────────
  // Standing: the big upward sickle. Meditating: a low curl hugging the
  // ground around his seat.
  static const _standTail = [
    Offset(130, 214), Offset(180, 218), Offset(202, 176), Offset(188, 132),
  ];
  static const _sitTail = [
    Offset(126, 230), Offset(178, 238), Offset(196, 216), Offset(180, 196),
  ];
  static final Path _tailOrangeStand = _tailSegment(_standTail, 0.0, 0.80, 17);
  static final Path _tailTipStand = _tailSegment(_standTail, 0.76, 1.0, 17);
  static final Path _tailOrangeSit = _tailSegment(_sitTail, 0.0, 0.80, 14);
  static final Path _tailTipSit = _tailSegment(_sitTail, 0.76, 1.0, 14);

  static Offset _tailCenter(List<Offset> cp, double t) {
    final mt = 1 - t;
    return cp[0] * (mt * mt * mt) +
        cp[1] * (3 * mt * mt * t) +
        cp[2] * (3 * mt * t * t) +
        cp[3] * (t * t * t);
  }

  static Path _tailSegment(
      List<Offset> cp, double t0, double t1, double baseHalf) {
    const n = 26;
    final left = <Offset>[], right = <Offset>[];
    for (var i = 0; i <= n; i++) {
      final t = t0 + (t1 - t0) * i / n;
      final c = _tailCenter(cp, t);
      final d = _tailCenter(cp, math.min(t + 0.01, 1.0)) -
          _tailCenter(cp, math.max(t - 0.01, 0.0));
      final len = d.distance == 0 ? 1.0 : d.distance;
      final nrm = Offset(-d.dy / len, d.dx / len);
      final h = baseHalf * (1 - math.pow(t, 2.2)) + 1.2;
      left.add(c - nrm * h);
      right.add(c + nrm * h);
    }
    final path = Path()..moveTo(right.first.dx, right.first.dy);
    for (final p in right.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final p in left.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final v = repaint.value;
    final sitting = pose == RenPose.meditating;
    // Head bob: 2 cycles per loop (3.8s). Tail: 2.5 cycles (3.04s) —
    // mirrors the approved pitch page; both soften while meditating.
    final bob = math.sin(v * 2 * math.pi * 2) * (sitting ? 1.8 : 3.0);
    final tailDeg = sitting
        ? math.sin(v * 2 * math.pi * 2.5) * 1.5
        : 0.5 + math.sin(v * 2 * math.pi * 2.5) * 4.5;

    canvas.scale(size.height / 250);

    final fill = Paint()..style = PaintingStyle.fill;
    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;

    // Ground shadow.
    canvas.drawOval(
        Rect.fromCenter(
            center: const Offset(100, 244),
            width: sitting ? 130 : 116,
            height: 12),
        fill..color = Colors.black.withValues(alpha: 0.18));

    // Tail (rotates about its root).
    final tailRoot = sitting ? const Offset(128, 230) : const Offset(132, 214);
    canvas.save();
    canvas.translate(tailRoot.dx, tailRoot.dy);
    canvas.rotate(tailDeg * math.pi / 180);
    canvas.translate(-tailRoot.dx, -tailRoot.dy);
    canvas.drawPath(sitting ? _tailOrangeSit : _tailOrangeStand,
        fill..color = _fox);
    canvas.drawPath(sitting ? _tailTipSit : _tailTipStand,
        fill..color = _cream);
    canvas.restore();

    if (!sitting) {
      // Staff — planted to the ground, crook + knob + two pegs. (Set down
      // while meditating: a teacher doesn't lean on anything to sit.)
      canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(160, 30, 7, 216),
              const Radius.circular(3.5)),
          fill..color = _staffWood);
      canvas.drawPath(
          Path()
            ..moveTo(163, 34)
            ..cubicTo(163, 24, 168, 18, 175, 18),
          stroke(_staffWood, 6));
      canvas.drawCircle(const Offset(176, 17), 7.5, fill..color = _staffWood);
      canvas.drawLine(
          const Offset(167, 78), const Offset(177, 76), stroke(_staffDark, 3));
      canvas.drawLine(const Offset(167, 108), const Offset(177, 106),
          stroke(_staffDark, 3));
    }

    if (sitting) {
      // Seated dome robe + hem.
      canvas.drawPath(
          Path()
            ..moveTo(46, 240)
            ..cubicTo(46, 200, 66, 162, 100, 162)
            ..cubicTo(134, 162, 154, 200, 154, 240)
            ..close(),
          fill..color = _robe);
      canvas.drawPath(
          Path()
            ..moveTo(46, 234)
            ..lineTo(154, 234)
            ..lineTo(154, 240)
            ..lineTo(46, 240)
            ..close(),
          fill..color = _robeDark);
      // Chest V + straps, seated.
      canvas.drawPath(
          Path()
            ..moveTo(89, 166)
            ..lineTo(111, 166)
            ..lineTo(100, 188)
            ..close(),
          fill..color = _cream);
      canvas.drawLine(
          const Offset(84, 168), const Offset(118, 196), stroke(_robeDark, 6));
      canvas.drawLine(
          const Offset(116, 168), const Offset(82, 196), stroke(_robeDark, 6));
      // Sleeves meeting in the lap, paws resting together.
      canvas.drawPath(
          Path()
            ..moveTo(70, 190)
            ..cubicTo(74, 204, 84, 212, 96, 214),
          stroke(_robe, 18));
      canvas.drawPath(
          Path()
            ..moveTo(130, 190)
            ..cubicTo(126, 204, 116, 212, 104, 214),
          stroke(_robe, 18));
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: const Offset(100, 215), width: 28, height: 13),
              const Radius.circular(6.5)),
          fill..color = _fox);
      canvas.drawLine(
          const Offset(100, 210), const Offset(100, 220), stroke(_toe, 2));
    } else {
      // Robe (floor length) + hem band.
      canvas.drawPath(
          Path()
            ..moveTo(56, 240)
            ..cubicTo(56, 184, 72, 134, 100, 134)
            ..cubicTo(128, 134, 144, 184, 144, 240)
            ..close(),
          fill..color = _robe);
      canvas.drawPath(
          Path()
            ..moveTo(56, 234)
            ..lineTo(144, 234)
            ..lineTo(144, 240)
            ..lineTo(56, 240)
            ..close(),
          fill..color = _robeDark);

      // Kimono chest: cream V under crossed straps.
      canvas.drawPath(
          Path()
            ..moveTo(88, 138)
            ..lineTo(112, 138)
            ..lineTo(100, 162)
            ..close(),
          fill..color = _cream);
      canvas.drawLine(
          const Offset(82, 140), const Offset(120, 172), stroke(_robeDark, 6));
      canvas.drawLine(
          const Offset(118, 140), const Offset(80, 172), stroke(_robeDark, 6));

      // Left arm: hanging sleeve, cuff line, paw peeking.
      canvas.drawPath(
          Path()
            ..moveTo(68, 164)
            ..cubicTo(55, 174, 49, 190, 51, 212),
          stroke(_robe, 20));
      canvas.drawPath(
          Path()
            ..moveTo(43, 208)
            ..quadraticBezierTo(51, 217, 61, 211),
          stroke(_robeDark, 3.5));
      canvas.drawCircle(const Offset(51, 220), 6.5, fill..color = _fox);

      // Right arm: raised sleeve, cuff, round paw on the staff, knuckle line.
      canvas.drawPath(
          Path()
            ..moveTo(128, 158)
            ..cubicTo(140, 152, 150, 142, 156, 128),
          stroke(_robe, 19));
      canvas.drawPath(
          Path()
            ..moveTo(149, 133)
            ..quadraticBezierTo(158, 138, 163, 130),
          stroke(_robeDark, 3.5));
      canvas.drawCircle(const Offset(162, 117), 10, fill..color = _fox);
      canvas.drawPath(
          Path()
            ..moveTo(155, 113)
            ..quadraticBezierTo(162, 106, 169, 112),
          stroke(_knuckle, 2.5));

      // Feet with toe lines.
      canvas.drawOval(
          Rect.fromCenter(center: const Offset(80, 242), width: 24, height: 14),
          fill..color = _fox);
      canvas.drawOval(
          Rect.fromCenter(
              center: const Offset(120, 242), width: 24, height: 14),
          fill..color = _fox);
      for (final x in const [76.0, 84.0, 116.0, 124.0]) {
        canvas.drawLine(Offset(x, 237), Offset(x, 245), stroke(_toe, 2));
      }
    }

    // ── Head group (carries the bob; sits lower in meditation) ──────────
    canvas.save();
    canvas.translate(0, bob + (sitting ? 22 : 0));

    // Ears: curved petals with concentric inner panels.
    canvas.drawPath(
        Path()
          ..moveTo(58, 66)
          ..cubicTo(50, 44, 52, 26, 62, 14)
          ..cubicTo(74, 20, 86, 34, 92, 50)
          ..cubicTo(80, 56, 67, 61, 58, 66)
          ..close(),
        fill..color = _fox);
    canvas.drawPath(
        Path()
          ..moveTo(63, 56)
          ..cubicTo(58, 42, 60, 32, 66, 24)
          ..cubicTo(73, 29, 80, 38, 84, 47)
          ..cubicTo(76, 51, 69, 54, 63, 56)
          ..close(),
        fill..color = _innerEar);
    canvas.drawPath(
        Path()
          ..moveTo(142, 66)
          ..cubicTo(150, 44, 148, 26, 138, 14)
          ..cubicTo(126, 20, 114, 34, 108, 50)
          ..cubicTo(120, 56, 133, 61, 142, 66)
          ..close(),
        fill..color = _fox);
    canvas.drawPath(
        Path()
          ..moveTo(137, 56)
          ..cubicTo(142, 42, 140, 32, 134, 24)
          ..cubicTo(127, 29, 120, 38, 116, 47)
          ..cubicTo(124, 51, 131, 54, 137, 56)
          ..close(),
        fill..color = _innerEar);

    // Skull + cheek fur tufts (welded into the silhouette).
    canvas.drawOval(Rect.fromCenter(center: const Offset(100, 90), width: 94, height: 84),
        fill..color = _fox);
    canvas.drawPath(
        Path()
          ..moveTo(64, 108)
          ..lineTo(42, 112)
          ..lineTo(60, 119)
          ..lineTo(46, 125)
          ..lineTo(64, 129)
          ..close(),
        fill..color = _fox);
    canvas.drawPath(
        Path()
          ..moveTo(136, 108)
          ..lineTo(156, 112)
          ..lineTo(140, 118)
          ..lineTo(151, 124)
          ..lineTo(136, 128)
          ..close(),
        fill..color = _fox);

    // Bushy cream brows + serene closed eyes.
    canvas.drawPath(
        Path()
          ..moveTo(64, 84)
          ..quadraticBezierTo(77, 76, 90, 82),
        stroke(_browCream, 7.5));
    canvas.drawPath(
        Path()
          ..moveTo(110, 82)
          ..quadraticBezierTo(123, 76, 136, 84),
        stroke(_browCream, 7.5));
    if (peek && sitting) {
      // Timer paused: one eye opens to check on you. The other stays shut.
      canvas.drawOval(
          Rect.fromCenter(center: const Offset(80, 98), width: 16, height: 13),
          fill..color = Colors.white);
      canvas.drawCircle(const Offset(80, 99), 4, fill..color = _ink);
      canvas.drawCircle(const Offset(81.5, 97.5), 1.4,
          fill..color = Colors.white);
      canvas.drawPath(
          Path()
            ..moveTo(110, 96)
            ..quadraticBezierTo(120, 104, 130, 96),
          stroke(_ink, 6));
    } else {
      canvas.drawPath(
          Path()
            ..moveTo(70, 96)
            ..quadraticBezierTo(80, 104, 90, 96),
          stroke(_ink, 6));
      canvas.drawPath(
          Path()
            ..moveTo(110, 96)
            ..quadraticBezierTo(120, 104, 130, 96),
          stroke(_ink, 6));
    }

    // Muzzle, nose, philtrum, mouth.
    canvas.drawOval(Rect.fromCenter(center: const Offset(100, 121), width: 58, height: 40),
        fill..color = _cream);
    canvas.drawOval(Rect.fromCenter(center: const Offset(100, 112), width: 15, height: 11),
        fill..color = _ink);
    canvas.drawLine(const Offset(100, 117), const Offset(100, 126), stroke(_ink, 3));
    canvas.drawPath(
        Path()
          ..moveTo(93, 129)
          ..quadraticBezierTo(100, 134, 107, 129),
        stroke(_ink, 3));

    // Blush + whisker dots (the childish touch, per the owner).
    canvas.drawOval(Rect.fromCenter(center: const Offset(66, 114), width: 14, height: 9),
        fill..color = _blush);
    canvas.drawOval(Rect.fromCenter(center: const Offset(134, 114), width: 14, height: 9),
        fill..color = _blush);
    final dots = Paint()..color = const Color(0xFF7A4A28);
    canvas.drawCircle(const Offset(68, 123), 2, dots);
    canvas.drawCircle(const Offset(74, 128), 2, dots);
    canvas.drawCircle(const Offset(132, 123), 2, dots);
    canvas.drawCircle(const Offset(126, 128), 2, dots);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_RenPainter old) =>
      old.pose != pose || old.peek != peek; // idle motion via Listenable
}
