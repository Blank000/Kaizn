import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/services/achievement_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';
import '../../shared/providers/database_provider.dart';
import '../../shared/widgets/achievement_snackbar.dart';
import '../../shared/widgets/celebration_dialog.dart';

/// Shared claim flow used by both the Rewards screen and the Home "Ready to
/// claim" section. Handles: confirm dialog → DB write → confetti celebration
/// → achievement-badge check + snackbar.
Future<void> claimReward(
  BuildContext context,
  WidgetRef ref,
  Reward reward,
  int currentPoints,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) =>
        _ConfirmClaimDialog(reward: reward, currentPoints: currentPoints),
  );
  if (confirmed != true || !context.mounted) return;

  HapticFeedback.heavyImpact();
  final db = ref.read(databaseProvider);
  await db.updateReward(reward.copyWith(
    isClaimed: true,
    claimedAt: Value(DateTime.now()),
  ));

  if (!context.mounted) return;
  await showCelebrationDialog(
    context,
    emoji: '🎉',
    title: 'REWARD CLAIMED!',
    subtitle: reward.name,
    body: 'Go enjoy it!',
  );

  final badge = await AchievementService.checkAfterRewardClaim();
  if (badge != null && context.mounted) {
    showAchievementSnackbar(context, [badge]);
  }
}

class _ConfirmClaimDialog extends StatelessWidget {
  final Reward reward;
  final int currentPoints;
  const _ConfirmClaimDialog({
    required this.reward,
    required this.currentPoints,
  });

  @override
  Widget build(BuildContext context) {
    final newBalance = currentPoints - reward.pointsThreshold;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Claim "${reward.name}"?', style: AppTypography.heading2),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reward.description != null && reward.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                reward.description!,
                style: AppTypography.body
                    .copyWith(color: context.appTextSecondary),
              ),
            ),
          Row(
            children: [
              const Icon(Icons.toll_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              Text('Cost: ${reward.pointsThreshold} pts',
                  style: AppTypography.body),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  color: context.appTextSecondary, size: 18),
              const SizedBox(width: 6),
              Text(
                'New balance: $newBalance pts',
                style: AppTypography.body
                    .copyWith(color: context.appTextSecondary),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('CLAIM IT'),
        ),
      ],
    );
  }
}
