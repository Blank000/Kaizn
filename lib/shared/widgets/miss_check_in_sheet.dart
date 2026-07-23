import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/services/task_completion_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';
import '../../features/milestones/widgets/task_form_sheet.dart';
import '../providers/database_provider.dart';
import 'achievement_snackbar.dart';
import 'moment_celebrations.dart';
import 'reward_unlock_snackbar.dart';

/// Miss check-in (self-compassion + B=MAP triage). Shown right after a task
/// is marked missed TODAY: one kind line, four "what got in the way?" chips.
/// Each answer is recorded on the miss row and routes to an existing tool —
/// the fix for a miss depends on WHY it happened (Fogg: every miss is a
/// prompt, ability, or motivation problem). Fully dismissible; dismissing
/// records nothing.
Future<void> showMissCheckInSheet(
  BuildContext context,
  WidgetRef ref,
  Task task,
  String completionId,
) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _MissCheckInSheet(
      task: task,
      completionId: completionId,
      hostContext: context,
      hostRef: ref,
    ),
  );
}

class _MissCheckInSheet extends StatelessWidget {
  final Task task;
  final String completionId;

  /// Context/ref of the SCREEN under the sheet — follow-up flows (form,
  /// snackbars, tiny-completion celebrations) must outlive this sheet.
  final BuildContext hostContext;
  final WidgetRef hostRef;

  const _MissCheckInSheet({
    required this.task,
    required this.completionId,
    required this.hostContext,
    required this.hostRef,
  });

  Future<void> _pick(BuildContext sheetContext, String reason) async {
    Navigator.of(sheetContext).pop();
    final db = hostRef.read(databaseProvider);
    await db.setMissReason(completionId, reason);
    HapticFeedback.selectionClick();
    if (!hostContext.mounted) return;

    switch (reason) {
      case 'not_seen':
        // Prompt problem → the fix lives in the reminder editor.
        ScaffoldMessenger.of(hostContext).showSnackBar(const SnackBar(
          content:
              Text("Let's make it impossible to miss — set a reminder ⏰"),
        ));
        showTaskFormSheet(hostContext,
            milestoneId: task.milestoneId, task: task);
      case 'too_hard':
        // Ability problem → the 2-minute version IS the fix. If one exists,
        // offer to do it right now (undo the miss, bank the tiny win).
        if (task.tinyName != null) {
          await _offerTinyRescue(hostContext);
        } else {
          ScaffoldMessenger.of(hostContext).showSnackBar(const SnackBar(
            content: Text(
                'Add a 2-minute version — a bad-day size that still counts ⚡'),
          ));
          showTaskFormSheet(hostContext,
              milestoneId: task.milestoneId, task: task);
        }
      case 'no_time':
        ScaffoldMessenger.of(hostContext).showSnackBar(const SnackBar(
          content: Text(
              "Tomorrow's a clean slate. If this keeps happening, shrink it to fit the day 🤏"),
        ));
      case 'no_mood':
        ScaffoldMessenger.of(hostContext).showSnackBar(const SnackBar(
          content: Text(
              'Motivation follows action, not the other way round. One miss is data, not a verdict 💚'),
        ));
    }
  }

  /// "Too hard" + a tiny version exists: one tap turns the miss into the
  /// 2-minute win — the never-miss-twice save, offered at the exact moment.
  Future<void> _offerTinyRescue(BuildContext host) async {
    final doTiny = await showDialog<bool>(
      context: host,
      builder: (dctx) => AlertDialog(
        title: const Text('Do the 2-minute version instead? ⚡'),
        content: Text(
            "'${task.tinyName}' — half points, full streak credit. The miss becomes a win."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('KEEP THE MISS'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text("DO IT · IT COUNTS"),
          ),
        ],
      ),
    );
    if (doTiny != true || !host.mounted) return;

    final db = hostRef.read(databaseProvider);
    await db.undoCompletion(completionId, task.id);
    final result =
        await TaskCompletionService.completeToday(db, task, tiny: true);
    HapticFeedback.mediumImpact();
    if (!host.mounted) return;
    await surfaceDialogMoments(host, result);
    if (!host.mounted) return;
    if (result.hasCelebration) {
      showAchievementSnackbar(
          host, [...result.completionBadges, ...result.streakBadges]);
      showRewardUnlockSnackbar(host, result.unlockedRewards);
    } else {
      ScaffoldMessenger.of(host).showSnackBar(SnackBar(
        content: Text(
            "⚡ '${task.tinyName}' logged — that's a real win${result.basePoints > 0 ? ' · +${result.basePoints} pts' : ''}"),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appCardSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.appBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Logged. One miss is data, not a verdict.',
                  style: AppTypography.heading2,
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                'What got in the way? (helps ${task.name.length > 24 ? 'this task' : "'${task.name}'"} fit your life better)',
                style: AppTypography.caption
                    .copyWith(color: context.appTextSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _ReasonChip(
                    emoji: '🙈',
                    label: "Didn't see it",
                    onTap: () => _pick(context, 'not_seen'),
                  ),
                  _ReasonChip(
                    emoji: '🏋️',
                    label: 'Too hard today',
                    onTap: () => _pick(context, 'too_hard'),
                  ),
                  _ReasonChip(
                    emoji: '⏳',
                    label: 'No time',
                    onTap: () => _pick(context, 'no_time'),
                  ),
                  _ReasonChip(
                    emoji: '🌧',
                    label: "Didn't feel like it",
                    onTap: () => _pick(context, 'no_mood'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('JUST LOG IT'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _ReasonChip(
      {required this.emoji, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: context.appBorder),
          borderRadius: BorderRadius.circular(20),
          color: AppColors.infoBlue.withValues(alpha: 0.06),
        ),
        child: Text('$emoji  $label',
            style:
                AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
