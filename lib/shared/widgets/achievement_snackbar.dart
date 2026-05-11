import 'package:flutter/material.dart';

import '../../core/services/achievement_service.dart';
import '../../core/theme/app_colors.dart';

/// Show a snackbar listing newly unlocked achievement badges. No-op for empty.
void showAchievementSnackbar(
    BuildContext context, List<AchievementBadge> badges) {
  if (badges.isEmpty) return;
  final text = badges.length == 1
      ? '${badges.first.emoji} Badge unlocked: ${badges.first.name}!'
      : '🎉 Unlocked ${badges.length} badges · '
          '${badges.map((b) => '${b.emoji} ${b.name}').join(' · ')}';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(text),
    duration: const Duration(seconds: 3),
    backgroundColor: AppColors.primary,
  ));
}
