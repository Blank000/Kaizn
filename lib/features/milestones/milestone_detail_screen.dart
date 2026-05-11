import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';
import '../../shared/models/recurrence_rule.dart';
import '../../shared/providers/database_provider.dart';
import '../../shared/widgets/celebration_dialog.dart';
import '../../shared/widgets/reward_unlock_snackbar.dart';
import '../../shared/widgets/task_tile.dart';
import '../rewards/reward_unlock_service.dart';
import 'widgets/milestone_form_sheet.dart';
import 'widgets/task_form_sheet.dart';

class MilestoneDetailScreen extends ConsumerWidget {
  final String milestoneId;
  const MilestoneDetailScreen({super.key, required this.milestoneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final milestones = ref.watch(activeMilestonesProvider).valueOrNull ?? [];
    final tasks =
        ref.watch(tasksForMilestoneProvider(milestoneId)).valueOrNull ?? [];
    final completions = ref
            .watch(recentCompletionsForMilestoneProvider(milestoneId))
            .valueOrNull ??
        const <TaskCompletion>[];

    final milestone = milestones.where((m) => m.id == milestoneId).firstOrNull;
    if (milestone == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Milestone not found')),
      );
    }

    final daily = tasks.where((t) => t.recurrence == TaskRecurrence.daily).toList();
    final weekly =
        tasks.where((t) => t.recurrence == TaskRecurrence.weekly).toList();
    final monthly =
        tasks.where((t) => t.recurrence == TaskRecurrence.monthly).toList();
    final oneShot =
        tasks.where((t) => t.recurrence == TaskRecurrence.none).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(milestone.name,
            style: AppTypography.heading2, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit milestone',
            onPressed: () =>
                showMilestoneFormSheet(context, milestone: milestone),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'complete') _markComplete(context, ref, milestone);
              if (v == 'delete') {
                _confirmDelete(context, ref, milestone, tasks.length);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'complete',
                child: ListTile(
                  leading: Icon(Icons.check_circle_outline),
                  title: Text('Mark complete'),
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red),
                  title: Text('Delete milestone',
                      style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            showTaskFormSheet(context, milestoneId: milestoneId),
        icon: const Icon(Icons.add_rounded),
        label: const Text('ADD TASK'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _Header(milestone: milestone, taskCount: tasks.length),
          const SizedBox(height: 24),
          if (tasks.isEmpty)
            _NoTasksState(
              onAdd: () =>
                  showTaskFormSheet(context, milestoneId: milestoneId),
            )
          else ...[
            if (daily.isNotEmpty)
              _TaskGroup(
                title: 'Daily',
                tasks: daily,
                completions: completions,
              ),
            if (weekly.isNotEmpty)
              _TaskGroup(
                title: 'Weekly',
                tasks: weekly,
                completions: completions,
              ),
            if (monthly.isNotEmpty)
              _TaskGroup(
                title: 'Monthly',
                tasks: monthly,
                completions: completions,
              ),
            if (oneShot.isNotEmpty)
              _TaskGroup(
                title: 'One-time',
                tasks: oneShot,
                completions: completions,
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _markComplete(
      BuildContext context, WidgetRef ref, Milestone milestone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark milestone complete?'),
        content: Text(milestone.completionPoints > 0
            ? "You'll earn a ${milestone.completionPoints}-point bonus. This can't be undone."
            : "This can't be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('COMPLETE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final db = ref.read(databaseProvider);
    await db.awardMilestoneBonus(
      milestoneId: milestone.id,
      bonusPoints: milestone.completionPoints,
    );
    final unlockedRewards =
        await RewardUnlockService.checkAfterPointsChange(db);
    HapticFeedback.heavyImpact();
    if (!context.mounted) return;
    await showCelebrationDialog(
      context,
      emoji: '🏆',
      title: 'MILESTONE COMPLETE!',
      subtitle: milestone.name,
      body: milestone.completionPoints > 0
          ? '+${milestone.completionPoints} pts bonus'
          : null,
    );
    if (!context.mounted) return;
    showRewardUnlockSnackbar(context, unlockedRewards);
    context.go('/milestones');
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Milestone milestone,
    int taskCount,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete milestone?'),
        content: Text(taskCount == 0
            ? '"${milestone.name}" will be permanently deleted.'
            : '"${milestone.name}" and its $taskCount task${taskCount == 1 ? '' : 's'} (with all completion history) will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(databaseProvider).deleteMilestoneCascade(milestone.id);
    if (context.mounted) context.go('/milestones');
  }
}

// ────────────────────────────────────────────────────────────────────────────

String _metaForDetail(Task task, TaskRowState state) {
  final parts = <String>['${task.pointsPerCompletion} pts'];
  if (task.recurrence == TaskRecurrence.none) {
    if (state.isChecked) {
      parts.add('Completed');
    } else if (state.isMissed) {
      parts.add('Missed');
    } else if (state.isSkipped) {
      parts.add('Skipped');
    } else if (task.dueDate != null) {
      parts.add('Due ${DateFormat.MMMd().format(task.dueDate!)}');
    }
  } else {
    parts.add(RecurrenceRule.fromTask(task).summary());
    if (state.isChecked) {
      parts.add('Done');
    } else if (state.isMissed) {
      parts.add('Missed');
    } else if (state.isSkipped) {
      parts.add('Skipped');
    }
  }
  return parts.join(' · ');
}

class _Header extends StatelessWidget {
  final Milestone milestone;
  final int taskCount;

  const _Header({required this.milestone, required this.taskCount});

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.milestoneColor(milestone.colorIndex);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (milestone.description != null &&
              milestone.description!.isNotEmpty) ...[
            Text(milestone.description!, style: AppTypography.body),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              _StatBox(label: 'TASKS', value: '$taskCount'),
              const SizedBox(width: 12),
              if (milestone.targetDate != null)
                _StatBox(
                  label: 'BY',
                  value: DateFormat.MMMd().format(milestone.targetDate!),
                ),
              if (milestone.completionPoints > 0) ...[
                if (milestone.targetDate != null) const SizedBox(width: 12),
                _StatBox(
                  label: 'BONUS',
                  value: '+${milestone.completionPoints}',
                  color: AppColors.rewardsGold,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatBox({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: context.appCardSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: AppTypography.heading1.copyWith(color: c, fontSize: 22)),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: context.appTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskGroup extends ConsumerWidget {
  final String title;
  final List<Task> tasks;
  final List<TaskCompletion> completions;

  const _TaskGroup({
    required this.title,
    required this.tasks,
    required this.completions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
            child: Text(
              title.toUpperCase(),
              style: AppTypography.caption.copyWith(
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800,
                color: context.appTextSecondary,
                fontSize: 11,
              ),
            ),
          ),
          ...tasks.map((t) {
            final state = taskRowStateFor(t, completions);
            final chips = weeklyChipsFor(t, completions);
            return TaskTile(
              task: t,
              rowState: state,
              meta: _metaForDetail(t, state),
              weeklyChips: chips,
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    showTaskFormSheet(context,
                        milestoneId: t.milestoneId, task: t);
                  } else if (v == 'delete') {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete task?'),
                        content: Text(
                            '"${t.name}" and its completion history will be permanently deleted.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('CANCEL'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.red),
                            child: const Text('DELETE'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref
                          .read(databaseProvider)
                          .deleteTaskCascade(t.id);
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _NoTasksState extends StatelessWidget {
  final VoidCallback onAdd;
  const _NoTasksState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.appPageBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.checklist_rounded,
              size: 40, color: context.appBorder),
          const SizedBox(height: 12),
          Text('No tasks yet',
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Break this milestone into bite-sized tasks',
            style: AppTypography.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('ADD FIRST TASK'),
          ),
        ],
      ),
    );
  }
}
