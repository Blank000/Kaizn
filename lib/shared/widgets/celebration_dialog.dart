import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';

/// Reusable confetti-burst celebration dialog.
/// Used by reward claims, milestone completion, and "all done today."
Future<void> showCelebrationDialog(
  BuildContext context, {
  required String emoji,
  required String title,
  required String subtitle,
  String? body,
  String buttonLabel = 'AWESOME!',
  Color titleColor = AppColors.primary,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CelebrationDialog(
      emoji: emoji,
      title: title,
      subtitle: subtitle,
      body: body,
      buttonLabel: buttonLabel,
      titleColor: titleColor,
    ),
  );
}

class _CelebrationDialog extends StatefulWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? body;
  final String buttonLabel;
  final Color titleColor;

  const _CelebrationDialog({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.buttonLabel,
    required this.titleColor,
  });

  @override
  State<_CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<_CelebrationDialog> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        ConfettiWidget(
          confettiController: _confetti,
          blastDirectionality: BlastDirectionality.explosive,
          numberOfParticles: 30,
          colors: const [
            AppColors.primary,
            AppColors.streakOrange,
            AppColors.rewardsGold,
            AppColors.infoBlue,
          ],
        ),
        Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.emoji, style: const TextStyle(fontSize: 64)),
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
