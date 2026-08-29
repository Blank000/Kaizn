import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/app_prefs.dart';
import '../../core/services/cosmetics_service.dart';
import '../../core/services/level_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'animated_number.dart';
import 'spring_progress_bar.dart';
import 'streak_flame.dart';
import 'zen_spark.dart';

/// Everything the Day Complete show needs, computed once by the caller.
class DayCompletePayload {
  final int doneCount;
  final int tinyCount;
  final int pointsToday;
  final bool clutchToday;
  final int streakDay;
  final bool questDoneToday;
  final int questWeekDots; // 0..5 chain dots filled this week
  final bool chestReady;
  final LevelInfo level;

  const DayCompletePayload({
    required this.doneCount,
    required this.tinyCount,
    required this.pointsToday,
    required this.clutchToday,
    required this.streakDay,
    required this.questDoneToday,
    required this.questWeekDots,
    required this.chestReady,
    required this.level,
  });
}

/// The Duolingo-style end-of-day choreography: each earned thing gets its
/// own ~1s beat instead of one flat popup. TAP ANYWHERE SKIPS to the next
/// beat — the show is never a gate. Fires at most once per day (the caller
/// keeps that guard). Reduced-motion users get a static summary card.
Future<void> showDayCompleteSequence(
    BuildContext context, DayCompletePayload payload) async {
  final style = await CosmeticsService.selectedConfettiStyle();
  if (!context.mounted) return;
  // Read reduced-motion HERE (live context): the static summary must skip
  // the whole show — no confetti, no beat timers, no sounds, no haptics.
  final reduced = MediaQuery.of(context).disableAnimations;
  if (!reduced) HapticFeedback.heavyImpact();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'day complete',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (ctx, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
    // Material ancestor is MANDATORY: raw widgets from showGeneralDialog
    // render every Text with the yellow debug underline. The gradient box
    // is the show's own dark stage — the cinematic look must not depend on
    // the app theme (a scrim over a LIGHT theme is a muddy gray wash).
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
        child: _DaySequence(
            payload: payload, style: style, reducedMotion: reduced),
      ),
    ),
  );
}

enum _Beat { curtain, points, recap, streak, quest, outro }

class _DaySequence extends StatefulWidget {
  final DayCompletePayload payload;
  final ConfettiStyle style;
  final bool reducedMotion;
  const _DaySequence(
      {required this.payload,
      required this.style,
      required this.reducedMotion});

  @override
  State<_DaySequence> createState() => _DaySequenceState();
}

class _DaySequenceState extends State<_DaySequence> {
  late final List<_Beat> _beats;
  int _index = 0;
  Timer? _timer;
  late final ConfettiController _confetti;

  DayCompletePayload get p => widget.payload;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _beats = [
      _Beat.curtain,
      _Beat.points,
      _Beat.recap,
      _Beat.streak,
      if (p.questDoneToday || p.chestReady) _Beat.quest,
      _Beat.outro,
    ];
    if (!widget.reducedMotion) {
      _confetti.play();
      SoundService.play(AppSound.celebrate);
      _armTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confetti.dispose();
    super.dispose();
  }

  Duration _durationFor(_Beat beat) => switch (beat) {
        _Beat.curtain => const Duration(milliseconds: 1000),
        _Beat.points => const Duration(milliseconds: 1500),
        _Beat.recap => const Duration(milliseconds: 1100),
        _Beat.streak => const Duration(milliseconds: 1500),
        _Beat.quest => const Duration(milliseconds: 1300),
        _Beat.outro => Duration.zero, // holds until CONTINUE
      };

  void _armTimer() {
    _timer?.cancel();
    final beat = _beats[_index];
    if (beat == _Beat.outro) return;
    _timer = Timer(_durationFor(beat), _advance);
  }

  void _advance() {
    if (!mounted) return;
    if (_index >= _beats.length - 1) return;
    setState(() => _index++);
    HapticFeedback.mediumImpact();
    SoundService.play(
        _beats[_index] == _Beat.quest ? AppSound.chest : AppSound.tick);
    _armTimer();
  }

  @override
  Widget build(BuildContext context) {
    // Accessibility: no show, just the facts (and initState never armed
    // the timers/sounds, so nothing invisible plays behind this card).
    if (widget.reducedMotion) {
      return _StaticSummary(payload: p);
    }

    final beat = _beats[_index];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // The whole point: tapping never gets punished — it fast-forwards.
      onTap: beat == _Beat.outro ? null : _advance,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          _confettiFor(widget.style, _confetti),
          SafeArea(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale:
                        Tween(begin: 0.86, end: 1.0).animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_index),
                  child: _beatWidget(beat),
                ),
              ),
            ),
          ),
          if (beat != _Beat.outro)
            Positioned(
              bottom: 28,
              child: Text(
                'tap to skip',
                style: AppTypography.caption
                    .copyWith(color: Colors.white38),
              ),
            ),
        ],
      ),
    );
  }

  Widget _beatWidget(_Beat beat) => switch (beat) {
        _Beat.curtain => const _CurtainBeat(),
        _Beat.points =>
          _PointsBeat(points: p.pointsToday, clutch: p.clutchToday),
        _Beat.recap =>
          _RecapBeat(doneCount: p.doneCount, tinyCount: p.tinyCount),
        _Beat.streak => _StreakBeat(day: p.streakDay),
        _Beat.quest => _QuestBeat(
            questDone: p.questDoneToday,
            dots: p.questWeekDots,
            chestReady: p.chestReady),
        _Beat.outro => _OutroBeat(
            level: p.level,
            streakDay: p.streakDay,
            onContinue: () => Navigator.of(context).pop()),
      };
}

// ── Beats ────────────────────────────────────────────────────────────────────

class _CurtainBeat extends StatelessWidget {
  const _CurtainBeat();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The Victory Burst — brand motif at the brand moment.
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.2, end: 1.0),
          duration: const Duration(milliseconds: 550),
          curve: Curves.elasticOut,
          builder: (_, v, child) =>
              Transform.scale(scale: v, child: child),
          child: const Text('💥', style: TextStyle(fontSize: 88)),
        ),
        const SizedBox(height: 12),
        Text('DAY COMPLETE',
            style: AppTypography.display.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            )),
      ],
    );
  }
}

class _PointsBeat extends StatelessWidget {
  final int points;
  final bool clutch;
  const _PointsBeat({required this.points, required this.clutch});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedNumber(
          value: points,
          prefix: '+',
          suffix: ' pts',
          style: AppTypography.display.copyWith(
            fontSize: 56,
            fontWeight: FontWeight.w900,
            color: clutch ? AppColors.rewardsGold : AppColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          clutch ? 'earned today · ⚡ clutch finish!' : 'earned today',
          style:
              AppTypography.body.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}

class _RecapBeat extends StatefulWidget {
  final int doneCount;
  final int tinyCount;
  const _RecapBeat({required this.doneCount, required this.tinyCount});

  @override
  State<_RecapBeat> createState() => _RecapBeatState();
}

class _RecapBeatState extends State<_RecapBeat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  static const _maxChips = 8;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: Duration(
            milliseconds:
                300 + 70 * widget.doneCount.clamp(0, _maxChips)))
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.doneCount.clamp(0, _maxChips);
    final extra = widget.doneCount - shown;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: List.generate(shown, (i) {
            // Dominos: each chip pops on its own slice of the timeline.
            final start = (i * 70) /
                (_ctrl.duration!.inMilliseconds.toDouble());
            final anim = CurvedAnimation(
              parent: _ctrl,
              curve: Interval(start.clamp(0.0, 0.9), 1.0,
                  curve: Curves.elasticOut),
            );
            final tiny = i >= shown - widget.tinyCount;
            return ScaleTransition(
              scale: anim,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tiny
                      ? AppColors.streakOrange
                      : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: tiny
                    ? const Text('⚡', style: TextStyle(fontSize: 20))
                    : const Icon(Icons.check_rounded,
                        color: Colors.white, size: 26),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
        Text(
          widget.doneCount == 1
              ? 'Your task for today — done ✅'
              : '${widget.doneCount} tasks'
                  '${extra > 0 ? ' (+$extra more)' : ''} — all of them ✅',
          style:
              AppTypography.body.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}

class _StreakBeat extends StatelessWidget {
  final int day;
  const _StreakBeat({required this.day});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.3, end: 1.0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,
          builder: (_, v, child) =>
              Transform.scale(scale: v, child: child),
          // The user-picked Lottie fire (falls back to the drawn flame);
          // a spark for day zero.
          child: day > 0
              ? StreakFlame(streak: day, size: 96)
              : const Text('✨', style: TextStyle(fontSize: 72)),
        ),
        const SizedBox(height: 8),
        if (day > 0)
          AnimatedNumber(
            value: day,
            prefix: 'Day ',
            style: AppTypography.display.copyWith(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: AppColors.streakOrange,
            ),
          )
        else
          Text('Day 1 starts now',
              style: AppTypography.display.copyWith(
                fontSize: 32,
                color: AppColors.streakOrange,
              )),
      ],
    );
  }
}

class _QuestBeat extends StatelessWidget {
  final bool questDone;
  final int dots;
  final bool chestReady;
  const _QuestBeat(
      {required this.questDone,
      required this.dots,
      required this.chestReady});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (chestReady) ...[
          TweenAnimationBuilder<double>(
            tween: Tween(begin: -0.06, end: 0.06),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            builder: (_, v, child) =>
                Transform.rotate(angle: v, child: child),
            child: const Text('🎁', style: TextStyle(fontSize: 64)),
          ),
          const SizedBox(height: 8),
          Text('CHEST READY',
              style: AppTypography.heading1
                  .copyWith(color: AppColors.rewardsGold)),
          Text('Open it from Home 🎉',
              style: AppTypography.body
                  .copyWith(color: Colors.white70)),
        ] else ...[
          Text('Quest complete 🎯',
              style: AppTypography.heading1
                  .copyWith(color: Colors.white)),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            final filled = i < dots;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: i == dots - 1 ? 0.0 : 1.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? AppColors.rewardsGold
                        : Colors.white24,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text('$dots of 5 this week',
            style: AppTypography.caption
                .copyWith(color: Colors.white54)),
      ],
    );
  }
}

class _OutroBeat extends StatelessWidget {
  final LevelInfo level;
  final int streakDay;
  final VoidCallback onContinue;
  const _OutroBeat(
      {required this.level,
      required this.streakDay,
      required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zen takes the bow with you (spacer gated with him, so the
          // toggle leaves no dangling gap).
          if (AppPrefs.zenEnabledSync) ...[
            ZenSpark(
                mood: ZenMood.cheer,
                streak: streakDay,
                size: 84,
                line: 'YATTA!'),
            const SizedBox(height: 16),
          ],
          // Non-breaking space: the wave must never wrap onto its own line.
          Text('Beautiful work. See you tomorrow 👋',
              textAlign: TextAlign.center,
              style: AppTypography.heading2
                  .copyWith(color: Colors.white)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🎖️ Lv ${level.level} · ${level.title}',
                  style: AppTypography.body.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 220,
            child: SpringProgressBar(
              value: level.progress,
              height: 10,
              color: AppColors.primary,
              backgroundColor: Colors.white24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${level.nextPoints - level.minPoints - ((level.progress) * (level.nextPoints - level.minPoints)).round()} pts to Lv ${level.level + 1}',
            style: AppTypography.caption
                .copyWith(color: Colors.white54),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: onContinue,
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 48, vertical: 14)),
            child: const Text('CONTINUE'),
          ),
        ],
      ),
    );
  }
}

/// Reduced-motion fallback: the facts, no show.
class _StaticSummary extends StatelessWidget {
  final DayCompletePayload payload;
  const _StaticSummary({required this.payload});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Day complete ⭐',
                style: AppTypography.display
                    .copyWith(color: Colors.white)),
            const SizedBox(height: 12),
            Text(
              '${payload.doneCount} tasks · +${payload.pointsToday} pts'
              '${payload.streakDay > 0 ? ' · Day ${payload.streakDay} 🔥' : ''}',
              style: AppTypography.body
                  .copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CONTINUE'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Confetti (per-style, mirrors celebration_dialog) ────────────────────────

Path _starPath(Size size) {
  const points = 5;
  final outer = size.width / 2;
  final inner = outer / 2.5;
  final center = Offset(size.width / 2, size.height / 2);
  final path = Path();
  const step = math.pi / points;
  for (var i = 0; i < points * 2; i++) {
    final r = i.isEven ? outer : inner;
    final a = i * step - math.pi / 2;
    final pt = center + Offset(r * math.cos(a), r * math.sin(a));
    i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
  }
  path.close();
  return path;
}

Widget _confettiFor(ConfettiStyle style, ConfettiController ctrl) {
  switch (style) {
    case ConfettiStyle.goldStars:
      return ConfettiWidget(
        confettiController: ctrl,
          minimumSize: const Size(4, 8),
          maximumSize: const Size(8, 14),
        blastDirectionality: BlastDirectionality.explosive,
        numberOfParticles: 24,
        gravity: 0.15,
        createParticlePath: _starPath,
        colors: const [
          AppColors.rewardsGold,
          Color(0xFFFFE082),
          Color(0xFFFFB300),
          Colors.white,
        ],
      );
    case ConfettiStyle.emberRain:
      return ConfettiWidget(
        confettiController: ctrl,
          minimumSize: const Size(4, 8),
          maximumSize: const Size(8, 14),
        blastDirection: math.pi / 2,
        blastDirectionality: BlastDirectionality.directional,
        numberOfParticles: 40,
        emissionFrequency: 0.08,
        gravity: 0.08,
        minBlastForce: 3,
        maxBlastForce: 8,
        colors: const [
          AppColors.streakOrange,
          Color(0xFFFF6D00),
          Color(0xFFFFAB40),
          Color(0xFFD84315),
        ],
      );
    case ConfettiStyle.classic:
      return ConfettiWidget(
        confettiController: ctrl,
          minimumSize: const Size(4, 8),
          maximumSize: const Size(8, 14),
        blastDirectionality: BlastDirectionality.explosive,
        numberOfParticles: 30,
        colors: const [
          AppColors.primary,
          AppColors.streakOrange,
          AppColors.rewardsGold,
          AppColors.infoBlue,
        ],
      );
  }
}
