import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/shield_service.dart';
import '../../../core/services/streak_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_colors.dart';

/// Shows a milestone celebration dialog or a normal streak bottom sheet.
/// [onShieldUsed] is called when the user confirms using a Streak Shield.
Future<void> showStreakPopup(
  BuildContext context,
  StreakCheckResult result, {
  VoidCallback? onShieldUsed,
}) async {
  if (result.milestoneHit != null) {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MilestoneCelebrationDialog(result: result),
    );
  } else {
    await showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NormalStreakSheet(
        result: result,
        onShieldUsed: onShieldUsed,
      ),
    );
  }
}

class _NormalStreakSheet extends StatefulWidget {
  final StreakCheckResult result;
  final VoidCallback? onShieldUsed;
  const _NormalStreakSheet({required this.result, this.onShieldUsed});

  @override
  State<_NormalStreakSheet> createState() => _NormalStreakSheetState();
}

class _NormalStreakSheetState extends State<_NormalStreakSheet> {
  bool _shieldUsed = false;

  Future<void> _useShield() async {
    await ShieldService.useShield();
    widget.onShieldUsed?.call();
    HapticFeedback.mediumImpact();
    setState(() => _shieldUsed = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final canUseShield = result.wasReset &&
        result.streakBeforeReset > 0 &&
        widget.onShieldUsed != null;

    return Container(
      decoration: BoxDecoration(
        color: context.appCardSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.appBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _shieldUsed ? '🛡️' : '🔥',
            style: const TextStyle(fontSize: 64),
          ),
          const SizedBox(height: 8),
          Text(
            _shieldUsed
                ? '${result.streakBeforeReset}'
                : '${result.currentStreak}',
            style: AppTypography.display.copyWith(
              fontSize: 64,
              color: _shieldUsed
                  ? AppColors.infoBlue
                  : AppColors.streakOrange,
            ),
          ),
          Text(
            'DAY STREAK',
            style: AppTypography.caption.copyWith(
              fontSize: 13,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w800,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Personal Best: ${result.longestStreak} days',
            style: AppTypography.body.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _shieldUsed
                  ? AppColors.infoBlue.withValues(alpha: 0.08)
                  : context.appPageBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _shieldUsed
                  ? '🛡️ Shield activated! Your streak is safe.'
                  : result.wasReset
                      ? 'Streak reset. Start fresh today! 💪'
                      : result.currentStreak == 0
                          ? 'Log today to start your streak!'
                          : 'Keep it going, Alok!',
              style: AppTypography.body,
              textAlign: TextAlign.center,
            ),
          ),

          // ── Shield offer ──────────────────────────────────────────────────
          if (canUseShield && !_shieldUsed) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.infoBlue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.infoBlue.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    '🛡️ Use Streak Shield?',
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Restore your ${result.streakBeforeReset}-day streak\nfor ${ShieldService.shieldCost} pts',
                    style: AppTypography.caption
                        .copyWith(color: context.appTextSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.infoBlue,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _useShield,
                      child: Text(
                          'USE SHIELD (${ShieldService.shieldCost} pts)'),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          Text(
            'Tap anywhere to close',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

class _MilestoneCelebrationDialog extends StatefulWidget {
  final StreakCheckResult result;
  const _MilestoneCelebrationDialog({required this.result});

  @override
  State<_MilestoneCelebrationDialog> createState() =>
      _MilestoneCelebrationDialogState();
}

class _MilestoneCelebrationDialogState
    extends State<_MilestoneCelebrationDialog> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _confetti.play();
    HapticFeedback.heavyImpact();
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
                const Text('🔥', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(
                  'YOU HIT\n${widget.result.milestoneHit} DAYS!',
                  style: AppTypography.heading1.copyWith(
                    color: AppColors.streakOrange,
                    fontSize: 28,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "That's a new milestone.\nYou're unstoppable, Alok.",
                  style: AppTypography.body
                      .copyWith(color: context.appTextSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('AWESOME!'),
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
