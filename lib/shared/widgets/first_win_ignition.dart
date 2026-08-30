import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../core/services/sound_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../providers/database_provider.dart';
import 'living_flame.dart';

/// The First-Win Ignition — the approved "Option B" motion
/// (docs/motion/first_win_motion_pitch.html): plays on the FIRST real
/// completion of the day, the moment the streak advances.
///
/// Beats (~2.6s, tap anywhere dismisses):
///   0.00s  scrim + small fire + "Day N-1" + real week strip (today unticked)
///   0.38s  the fire GROWS small → big (elastic) with rising embers
///   1.25s  a spark arcs from the fire down to today's letter
///   1.78s  impact: letter ticks, 8-dot burst, count flips to "Day N 🔥" +1
///   3.05s  auto-dismiss
///
/// The caller gates it: only when no bigger dialog (milestone/PB/level-up)
/// owns the moment, never in rest mode, never under reduced motion.
Future<void> showFirstWinIgnition(
  BuildContext context, {
  required int streakDay,
}) {
  HapticFeedback.lightImpact();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'streak secured',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (ctx, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
    // Material ancestor (kills the yellow debug underline) + the show's
    // own dark stage, so it looks identical over light and dark themes.
    pageBuilder: (_, __, ___) => Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xF50B141D), Color(0xF516222E)],
          ),
        ),
        child: _IgnitionOverlay(streakDay: streakDay),
      ),
    ),
  );
}

class _IgnitionOverlay extends ConsumerStatefulWidget {
  final int streakDay;
  const _IgnitionOverlay({required this.streakDay});

  @override
  ConsumerState<_IgnitionOverlay> createState() => _IgnitionOverlayState();
}

class _IgnitionOverlayState extends ConsumerState<_IgnitionOverlay>
    with TickerProviderStateMixin {
  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  final _rootKey = GlobalKey();
  final _flameKey = GlobalKey();
  final _todayKey = GlobalKey();

  /// Which past weekdays (Mon..Sun, index 0-6) had a real completion.
  List<bool> _doneDays = List.filled(7, false);
  int _todayIdx = DateTime.now().weekday - 1;

  late final AnimationController _grow = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 820));
  late final Animation<double> _flameScale = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: .5, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 65),
    TweenSequenceItem(
        tween: Tween(begin: 1.18, end: 1.02)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35),
  ]).animate(_grow);

  late final AnimationController _spark = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 520));
  Offset? _sparkFrom, _sparkTo;

  late final AnimationController _burst = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 430));
  late final AnimationController _pump = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 460));

  bool _impacted = false; // flips the counter, ticks today
  bool _showPlusOne = false;
  final _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    _loadWeek();
    _at(380, () {
      _grow.forward();
    });
    _at(1250, _launchSpark);
    _at(1780, _impact);
    _at(3050, _dismiss);
  }

  void _at(int ms, VoidCallback fn) =>
      _timers.add(Timer(Duration(milliseconds: ms), () {
        if (mounted) fn();
      }));

  Future<void> _loadWeek() async {
    final db = ref.read(databaseProvider);
    final completions =
        await db.getRecentCompletions(const Duration(days: 8));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final done = List.filled(7, false);
    for (final c in completions) {
      if (c.isSkip || c.isNd) continue;
      final d = DateTime(
          c.completedOn.year, c.completedOn.month, c.completedOn.day);
      final i = d.difference(monday).inDays;
      // Today stays visually unticked — the animation ticks it.
      if (i >= 0 && i < 7 && i != _todayIdx) done[i] = true;
    }
    if (mounted) setState(() => _doneDays = done);
  }

  void _launchSpark() {
    final root =
        _rootKey.currentContext?.findRenderObject() as RenderBox?;
    final flame =
        _flameKey.currentContext?.findRenderObject() as RenderBox?;
    final today =
        _todayKey.currentContext?.findRenderObject() as RenderBox?;
    if (root == null || flame == null || today == null) return;
    Offset centerOf(RenderBox b) =>
        b.localToGlobal(b.size.center(Offset.zero), ancestor: root);
    setState(() {
      _sparkFrom = centerOf(flame);
      _sparkTo = centerOf(today);
    });
    _spark.forward();
  }

  void _impact() {
    HapticFeedback.mediumImpact();
    SoundService.play(AppSound.tick);
    setState(() {
      _impacted = true;
      _showPlusOne = true;
    });
    _burst.forward();
    _pump.forward();
  }

  void _dismiss() {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _grow.dispose();
    _spark.dispose();
    _burst.dispose();
    _pump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.streakDay;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismiss, // never a gate
      child: Stack(
        key: _rootKey,
        children: [
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // YOUR fire (extracted from the reference), growing as
                  // today is secured. Pump rides on top of the grow scale.
                  AnimatedBuilder(
                    animation: Listenable.merge([_grow, _pump]),
                    builder: (_, child) {
                      final pump = 1 +
                          .12 *
                              math.sin(math.pi *
                                  Curves.easeOut.transform(_pump.value));
                      return Transform.scale(
                        scale: _flameScale.value * pump,
                        alignment: Alignment.bottomCenter,
                        child: child,
                      );
                    },
                    child: SizedBox(
                      key: _flameKey,
                      width: 110,
                      height: 138,
                      child: Lottie.asset(
                        'assets/lottie/streak_flame.json',
                        fit: BoxFit.contain,
                        repeat: true,
                        errorBuilder: (_, __, ___) =>
                            LivingFlame(streak: day, size: 110),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // The honest count: N-1 until impact, then N.
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      TweenAnimationBuilder<double>(
                        key: ValueKey(_impacted),
                        tween: Tween(
                            begin: _impacted ? 1.22 : 1.0, end: 1.0),
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.elasticOut,
                        builder: (_, v, child) =>
                            Transform.scale(scale: v, child: child),
                        child: Text(
                          // No 🔥 emoji — the real fire burns right above.
                          _impacted ? 'Day $day' : 'Day ${day - 1}',
                          style: AppTypography.display.copyWith(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: AppColors.streakOrange,
                          ),
                        ),
                      ),
                      if (_showPlusOne)
                        Positioned(
                          right: -30,
                          top: -6,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOut,
                            onEnd: () {
                              if (mounted) {
                                setState(() => _showPlusOne = false);
                              }
                            },
                            builder: (_, t, __) => Opacity(
                              opacity:
                                  t < .35 ? t / .35 : (1 - t) / .65,
                              child: Transform.translate(
                                offset: Offset(0, 6 - 32 * t),
                                child: Text('+1',
                                    style: AppTypography.body.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.rewardsGold,
                                    )),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  // The real week, today ticking at impact.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(7, (i) {
                      final isToday = i == _todayIdx;
                      final done =
                          _doneDays[i] || (isToday && _impacted);
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TweenAnimationBuilder<double>(
                              key: isToday
                                  ? ValueKey('t$_impacted')
                                  : null,
                              tween: Tween(
                                  begin: isToday && _impacted ? .6 : 1.0,
                                  end: 1.0),
                              duration:
                                  const Duration(milliseconds: 420),
                              curve: Curves.elasticOut,
                              builder: (_, v, child) =>
                                  Transform.scale(scale: v, child: child),
                              child: Container(
                                key: isToday ? _todayKey : null,
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: done
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  border: done
                                      ? null
                                      : Border.all(
                                          color: isToday
                                              ? AppColors.primary
                                              : Colors.white24,
                                          width: 2),
                                ),
                                child: done
                                    ? const Icon(Icons.check_rounded,
                                        size: 16, color: Colors.white)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _letters[i],
                              style: AppTypography.caption.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isToday
                                    ? AppColors.primary
                                    : Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'streak secured',
                    style: AppTypography.caption
                        .copyWith(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
          // The spark: fire → today's letter, sine arc.
          if (_sparkFrom != null && _sparkTo != null)
            AnimatedBuilder(
              animation: _spark,
              builder: (_, __) {
                if (_spark.value == 0 || _spark.isCompleted) {
                  return const SizedBox.shrink();
                }
                final k = _spark.value;
                final p = Offset.lerp(_sparkFrom, _sparkTo, k)! -
                    Offset(0, math.sin(k * math.pi) * 46);
                return Positioned(
                  left: p.dx - 5,
                  top: p.dy - 5,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.rewardsGold,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.rewardsGold
                                .withValues(alpha: .55),
                            blurRadius: 12,
                            spreadRadius: 3),
                      ],
                    ),
                  ),
                );
              },
            ),
          // 8-dot radial burst at today's letter on impact.
          if (_sparkTo != null)
            AnimatedBuilder(
              animation: _burst,
              builder: (_, __) => _burst.isAnimating
                  ? CustomPaint(
                      painter: _BurstPainter(
                          progress: _burst.value, center: _sparkTo!),
                      child: const SizedBox.expand(),
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  final double progress;
  final Offset center;
  _BurstPainter({required this.progress, required this.center});

  @override
  void paint(Canvas canvas, Size size) {
    final eased = Curves.easeOutCubic.transform(progress);
    final r = 12.0 + 30.0 * eased;
    final dotR = 3.0 * (1 - progress);
    final green = Paint()
      ..color =
          AppColors.primary.withValues(alpha: (1 - progress).clamp(0, 1));
    final gold = Paint()
      ..color = AppColors.rewardsGold
          .withValues(alpha: (1 - progress).clamp(0, 1));
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final p = center + Offset(r * math.cos(a), r * math.sin(a));
      canvas.drawCircle(p, dotR, i.isEven ? green : gold);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.progress != progress || old.center != center;
}
