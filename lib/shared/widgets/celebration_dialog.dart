import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/cosmetics_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';

/// Reusable confetti celebration dialog. Per-moment confetti styles keep
/// celebrations from habituating (identical confetti 200 times stops firing
/// dopamine): classic burst = general wins, gold stars = economy moments
/// (rewards, chests, level-ups), ember rain = streak moments. When [style]
/// is null, the user's selected cosmetic style applies.
Future<void> showCelebrationDialog(
  BuildContext context, {
  required String emoji,
  required String title,
  required String subtitle,
  String? body,
  String buttonLabel = 'AWESOME!',
  Color titleColor = AppColors.primary,
  ConfettiStyle? style,
}) async {
  final resolved = style ?? await CosmeticsService.selectedConfettiStyle();
  if (!context.mounted) return;
  HapticFeedback.heavyImpact();
  // Scale-in entrance (0.85 → 1.0 easeOutBack) instead of the stock fade —
  // loud content deserves a loud arrival.
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'celebration',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(curved), child: child),
      );
    },
    pageBuilder: (_, __, ___) => _CelebrationDialog(
      emoji: emoji,
      title: title,
      subtitle: subtitle,
      body: body,
      buttonLabel: buttonLabel,
      titleColor: titleColor,
      style: resolved,
    ),
  );
}

/// A five-pointed star path for gold-star confetti.
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
    final p = center + Offset(r * math.cos(a), r * math.sin(a));
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  path.close();
  return path;
}

class _CelebrationDialog extends StatefulWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? body;
  final String buttonLabel;
  final Color titleColor;
  final ConfettiStyle style;

  const _CelebrationDialog({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.buttonLabel,
    required this.titleColor,
    required this.style,
  });

  @override
  State<_CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<_CelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final ConfettiController _confetti;
  late final AnimationController _emojiCtrl;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _confetti.play();
    // Delayed elastic pop for the emoji — arrives just after the dialog.
    _emojiCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _emojiCtrl.forward();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    _emojiCtrl.dispose();
    super.dispose();
  }

  ConfettiWidget _confettiFor(ConfettiStyle style) {
    switch (style) {
      case ConfettiStyle.goldStars:
        return ConfettiWidget(
          confettiController: _confetti,
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
          confettiController: _confetti,
          minimumSize: const Size(4, 8),
          maximumSize: const Size(8, 14),
          blastDirection: math.pi / 2, // straight down
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
          confettiController: _confetti,
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

  @override
  Widget build(BuildContext context) {
    final emojiScale = CurvedAnimation(
        parent: _emojiCtrl, curve: Curves.elasticOut);
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        _confettiFor(widget.style),
        Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: Tween(begin: 0.3, end: 1.0).animate(emojiScale),
                  child:
                      Text(widget.emoji, style: const TextStyle(fontSize: 64)),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  style: AppTypography.heading1
                      .copyWith(color: widget.titleColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  style: AppTypography.heading2,
                  textAlign: TextAlign.center,
                ),
                if (widget.body != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.body!,
                    style: AppTypography.body
                        .copyWith(color: context.appTextSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(widget.buttonLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
