import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/services/app_prefs.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';
import 'living_flame.dart';

/// Zen, the Victory Spark — the mascot from docs/character_brief_yatta_spark.md,
/// hand-built in code: the LivingFlame is the body, this adds the face, a
/// blink loop, moods, and the hype-friend speech bubble (2–5 word shouts).
///
/// Kill-list contract, enforced here: Zen has NO sad/sick/disappointed
/// state — [ZenMood] simply doesn't contain one. `sleepy` is serene
/// meditation (rest mode is the user's choice), never moping. The master
/// toggle (AppPrefs.zenEnabled) makes the whole widget render nothing, so
/// call sites can include Zen unconditionally.
enum ZenMood { idle, cheer, sleepy }

class ZenSpark extends StatefulWidget {
  final ZenMood mood;

  /// Streak drives the body's Zenkai stage (flame size/sparks).
  final int streak;
  final double size;

  /// Optional shout, shown in a bubble above ("YATTA!", "LET'S GO!").
  final String? line;

  const ZenSpark({
    super.key,
    this.mood = ZenMood.idle,
    this.streak = 1,
    this.size = 72,
    this.line,
  });

  @override
  State<ZenSpark> createState() => _ZenSparkState();
}

class _ZenSparkState extends State<ZenSpark>
    with SingleTickerProviderStateMixin {
  // Blink: quick lid-close driven by a timer at organic intervals.
  double _blink = 0; // 0 open .. 1 closed
  Timer? _blinkTimer;
  final _rng = math.Random();

  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void initState() {
    super.initState();
    _scheduleBlink();
    // Bounce start/stop lives in build(): it needs BOTH the Zen toggle
    // (a plain static — no dependency hooks fire when Settings flips it)
    // and MediaQuery, so build is the only spot that always sees fresh
    // values. Never animate an invisible mascot.
  }

  void _syncBounce(bool shouldBounce) {
    if (shouldBounce && !_bounce.isAnimating) {
      _bounce.repeat(reverse: true);
    } else if (!shouldBounce && _bounce.isAnimating) {
      _bounce.stop();
      _bounce.value = 0;
    }
  }

  void _scheduleBlink() {
    _blinkTimer = Timer(
      Duration(milliseconds: 2400 + _rng.nextInt(2600)),
      () async {
        if (!mounted) return;
        if (widget.mood == ZenMood.idle &&
            AppPrefs.zenEnabledSync &&
            !MediaQuery.of(context).disableAnimations) {
          setState(() => _blink = 1);
          await Future<void>.delayed(const Duration(milliseconds: 110));
          if (mounted) setState(() => _blink = 0);
        }
        if (!mounted) return; // the 110ms await can outlive this State
        _scheduleBlink();
      },
    );
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = AppPrefs.zenEnabledSync;
    final still = MediaQuery.of(context).disableAnimations;
    _syncBounce(enabled && !still && widget.mood == ZenMood.cheer);
    if (!enabled) return const SizedBox.shrink();

    final spark = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        children: [
          LivingFlame(streak: widget.streak, size: widget.size),
          Positioned.fill(
            child: CustomPaint(
              painter: _FacePainter(
                mood: widget.mood,
                blink: widget.mood == ZenMood.sleepy ? 1 : _blink,
              ),
            ),
          ),
        ],
      ),
    );

    final body = (widget.mood == ZenMood.cheer && !still)
        ? AnimatedBuilder(
            animation: _bounce,
            builder: (_, child) => Transform.translate(
              offset: Offset(
                  0,
                  -6 *
                      Curves.easeOut.transform(_bounce.value) *
                      widget.size /
                      72),
              child: child,
            ),
            child: spark,
          )
        : spark;

    if (widget.line == null) return body;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: context.appCardSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.appBorder),
          ),
          child: Text(
            widget.line!,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w800,
              color: context.appTextPrimary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        body,
      ],
    );
  }
}

class _FacePainter extends CustomPainter {
  final ZenMood mood;
  final double blink; // 0 open .. 1 closed

  _FacePainter({required this.mood, required this.blink});

  // Warm dark chocolate — reads on the gold core, both themes.
  static const _ink = Color(0xFF5D3A00);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final eyeY = size.height * 0.66;
    final gap = size.width * 0.115;
    final r = size.width * 0.052;
    final paint = Paint()..color = _ink;
    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round;

    // Eyes.
    if (mood == ZenMood.sleepy || blink >= 1) {
      // Serene closed lids: gentle down-curves (meditating, never moping).
      for (final dx in [-gap, gap]) {
        final p = Path()
          ..moveTo(cx + dx - r, eyeY)
          ..quadraticBezierTo(cx + dx, eyeY + r * 0.9, cx + dx + r, eyeY);
        canvas.drawPath(p, stroke);
      }
    } else if (mood == ZenMood.cheer) {
      // Happy squint: up-curves (the ^ ^ of a delighted anime face).
      for (final dx in [-gap, gap]) {
        final p = Path()
          ..moveTo(cx + dx - r, eyeY + r * 0.4)
          ..quadraticBezierTo(
              cx + dx, eyeY - r * 1.1, cx + dx + r, eyeY + r * 0.4);
        canvas.drawPath(p, stroke);
      }
    } else {
      // Open eyes, squashed vertically mid-blink.
      final h = r * (1 - 0.85 * blink);
      for (final dx in [-gap, gap]) {
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx + dx, eyeY),
              width: r * 2,
              height: h * 2),
          paint,
        );
        // Catchlight.
        canvas.drawCircle(
          Offset(cx + dx + r * 0.3, eyeY - h * 0.35),
          r * 0.28 * (1 - blink),
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
      }
    }

    // Mouth.
    final mouthY = size.height * 0.76;
    switch (mood) {
      case ZenMood.cheer:
        // Big open grin.
        final rect = Rect.fromCenter(
            center: Offset(cx, mouthY),
            width: size.width * 0.20,
            height: size.width * 0.16);
        canvas.drawArc(rect, 0, math.pi, true, paint);
      case ZenMood.sleepy:
        // Tiny content smile.
        final p = Path()
          ..moveTo(cx - size.width * 0.05, mouthY)
          ..quadraticBezierTo(cx, mouthY + size.width * 0.045,
              cx + size.width * 0.05, mouthY);
        canvas.drawPath(p, stroke);
      case ZenMood.idle:
        final p = Path()
          ..moveTo(cx - size.width * 0.07, mouthY - size.width * 0.01)
          ..quadraticBezierTo(cx, mouthY + size.width * 0.06,
              cx + size.width * 0.07, mouthY - size.width * 0.01);
        canvas.drawPath(p, stroke);
    }
  }

  @override
  bool shouldRepaint(_FacePainter old) =>
      old.mood != mood || old.blink != blink;
}
