import 'package:flutter/material.dart';

import '../../core/services/app_prefs.dart';
import '../../core/services/cosmetics_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/task_completion_service.dart';
import '../../core/theme/app_colors.dart';
import 'celebration_dialog.dart';
import 'first_win_ignition.dart';

/// Dialog-tier moments a completion can produce (same-day streak milestone,
/// new personal best, level-up) — surfaced identically from every completion
/// surface (tile, chip, timeline, stop-timer sheet). Shown sequentially,
/// milestone first: it's the rarer, more meaningful moment.
Future<void> surfaceDialogMoments(
    BuildContext context, CompletionResult result) async {
  // First-Win Ignition (the approved Option B motion): plays when the
  // streak ADVANCES — the day's first real completion — unless a bigger
  // dialog owns the moment, the user is resting, or motion is reduced.
  if (result.streakDay != null &&
      result.streakMilestone == null &&
      !result.isNewBestStreak &&
      result.levelUp == null &&
      !AppPrefs.isRestingSync &&
      !MediaQuery.of(context).disableAnimations) {
    await showFirstWinIgnition(context, streakDay: result.streakDay!);
  }

  if (result.streakMilestone != null) {
    await showCelebrationDialog(
      context,
      emoji: '🔥',
      title: '${result.streakMilestone} DAY STREAK!',
      subtitle: 'Same time tomorrow?',
      body: 'You showed up ${result.streakMilestone} days in a row.',
      titleColor: AppColors.streakOrange,
      style: ConfettiStyle.emberRain,
    );
  } else if (result.isNewBestStreak && result.streakDay != null) {
    await showCelebrationDialog(
      context,
      emoji: '🏆',
      title: 'NEW BEST STREAK!',
      subtitle: '${result.streakDay} days — your longest ever',
      titleColor: AppColors.streakOrange,
      style: ConfettiStyle.emberRain,
    );
  }

  final levelUp = result.levelUp;
  if (levelUp != null && context.mounted) {
    SoundService.play(AppSound.levelUp);
    await showCelebrationDialog(
      context,
      emoji: '🎖️',
      title: 'LEVEL ${levelUp.level}!',
      subtitle: levelUp.title,
      body: result.cosmeticUnlocked != null
          ? 'Unlocked: ${result.cosmeticUnlocked!.emoji} '
              '${result.cosmeticUnlocked!.name}'
          : 'Every point you ever earned counts — levels never reset.',
      titleColor: AppColors.rewardsGold,
      style: ConfettiStyle.goldStars,
    );
  }
}
