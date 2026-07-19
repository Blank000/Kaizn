import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/achievement_service.dart';
import '../../core/theme/app_colors.dart';

/// Show a snackbar listing newly unlocked achievement badges. No-op for
/// empty. A badge deserves more than plain text: haptic thump + a VIEW
/// action into the gallery.
void showAchievementSnackbar(
    BuildContext context, List<AchievementBadge> badges) {
  if (badges.isEmpty) return;
  HapticFeedback.heavyImpact();
  final text = badges.length == 1
      ? '${badges.first.emoji} Badge unlocked: ${badges.first.name}!'
      : '🎉 Unlocked ${badges.length} badges · '
          '${badges.map((b) => '${b.emoji} ${b.name}').join(' · ')}';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(text),
    duration: const Duration(seconds: 4),
    backgroundColor: AppColors.primary,
    behavior: SnackBarBehavior.floating,
    action: SnackBarAction(
      label: 'VIEW',
      textColor: Colors.white,
      onPressed: () => context.go('/stats/achievements'),
    ),
  ));
}
