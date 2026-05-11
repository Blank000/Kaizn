import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database.dart';
import '../../core/theme/app_colors.dart';

/// Show a celebratory snackbar listing rewards that just became claimable.
/// Includes a "CLAIM" action button that navigates to /rewards.
void showRewardUnlockSnackbar(
    BuildContext context, List<Reward> rewards) {
  if (rewards.isEmpty) return;
  final text = rewards.length == 1
      ? '🎁 "${rewards.first.name}" is now claimable!'
      : '🎁 ${rewards.length} rewards now claimable: '
          '${rewards.map((r) => r.name).join(", ")}';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(text),
    duration: const Duration(seconds: 4),
    backgroundColor: AppColors.rewardsGold,
    action: SnackBarAction(
      label: 'CLAIM',
      textColor: Colors.white,
      onPressed: () => context.go('/rewards'),
    ),
  ));
}
