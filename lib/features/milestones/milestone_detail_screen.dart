import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/services/habit_strength.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';
import '../../shared/models/recurrence_rule.dart';
import '../../shared/models/task_stack.dart';
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
          _Header(
            milestone: milestone,
            taskCount: tasks.length,
            votes: ref.watch(milestoneVotesProvider(milestoneId)).valueOrNull,
            strength: HabitStrength.milestoneAverage(tasks, completions),
          ),
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
            // Shelved tasks (parked by the comeback flow) — quiet rows with
            // a one-tap way back. History intact, zero daily presence.
            _ShelvedGroup(milestoneId: milestoneId),
          ],
        ],
      ),
    );
  }

  Future<void> _markComplete(
      BuildContext context, WidgetRef ref, Milestone milestone) async {
    // NOTE: dialogs must pop with the DIALOG's context (dctx). This screen
    // lives inside the bottom-nav shell navigator, but showDialog mounts on
    // the root navigator — popping with the screen's context targets the
    // wrong navigator and the await never resolves.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Mark milestone complete?'),
        content: Text(milestone.completionPoints > 0
            ? "You'll earn a ${milestone.completionPoints}-point bonus. This can't be undone."
            : "This can't be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dctx).pop(true),
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
    // Pops MUST use the dialog's context (dctx) — see _markComplete note.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Delete milestone?'),
        content: Text(taskCount == 0
            ? '"${milestone.name}" will be permanently deleted.'
            : '"${milestone.name}" and its $taskCount task${taskCount == 1 ? '' : 's'} (with all completion history) will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(true),
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

String _metaForDetail(Task task, TaskRowState state,
    {String? anchorName, int? strength}) {
  final parts = <String>['${task.pointsPerCompletion} pts'];
  if (anchorName != null) parts.add('🔗 After $anchorName');
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
    // Long-horizon consistency — forgiving where the streak is fragile.
    if (strength != null) parts.add('$strength% strong');
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

/// Shelved (archived) tasks with a RESTORE action. Renders nothing when the
/// milestone has no shelf.
class _ShelvedGroup extends ConsumerWidget {
  final String milestoneId;
  const _ShelvedGroup({required this.milestoneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelved = ref
            .watch(shelvedTasksForMilestoneProvider(milestoneId))
            .valueOrNull ??
        const <Task>[];
    if (shelved.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
            child: Text(
              'SHELVED',
              style: AppTypography.caption.copyWith(
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800,
                color: context.appTextSecondary,
                fontSize: 11,
              ),
            ),
          ),
          ...shelved.map((t) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  title: Text(
                    t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body
                        .copyWith(color: context.appTextTertiary),
                  ),
                  subtitle: Text(
                    'Resting — history kept',
                    style: AppTypography.caption
                        .copyWith(color: context.appTextTertiary),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      await ref.read(databaseProvider).updateTask(
                          t.copyWith(status: TaskStatus.active));
                      HapticFeedback.lightImpact();
                    },
                    child: const Text('RESTORE'),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Milestone milestone;
  final int taskCount;

  /// Lifetime real completions across this milestone's tasks — "votes for
  /// the person you're becoming" (Atomic Habits). Null while loading.
  final int? votes;

  /// Average habit strength (0–100) of the active recurring tasks; null
  /// until at least one has enough history to score.
  final int? strength;

  const _Header(
      {required this.milestone,
      required this.taskCount,
      this.votes,
      this.strength});

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
          if (milestone.identity != null &&
              milestone.identity!.isNotEmpty) ...[
            Text(
              'Becoming ${milestone.identity}',
              style: AppTypography.body.copyWith(
                color: accent,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (votes != null) ...[
              const SizedBox(height: 4),
              Text(
                votes! > 0
                    ? '🗳 $votes ${votes == 1 ? 'vote' : 'votes'} cast for that identity'
                    : '🗳 Every completion casts a vote',
                style: AppTypography.caption
                    .copyWith(color: context.appTextSecondary),
              ),
            ],
            const SizedBox(height: 8),
          ],
          if (milestone.description != null &&
              milestone.description!.isNotEmpty) ...[
            Text(milestone.description!, style: AppTypography.body),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              _StatBox(label: 'TASKS', value: '$taskCount'),
              if (strength != null) ...[
                const SizedBox(width: 12),
                _StatBox(label: 'STRENGTH', value: '$strength%'),
              ],
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
    // Four boxes share the row on a narrow screen — value and label scale
    // DOWN to fit their slot instead of wrapping ("+100/0", "STRENGT/H").
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: context.appCardSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  maxLines: 1,
                  softWrap: false,
                  style: AppTypography.heading1
                      .copyWith(color: c, fontSize: 22)),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: AppTypography.caption.copyWith(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: context.appTextSecondary,
                ),
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
    // Anchor names can live in OTHER milestones — resolve against all tasks.
    final allTasks = ref.watch(allTasksProvider).valueOrNull ?? const <Task>[];
    final anchorNameById = {for (final t in allTasks) t.id: t.name};
    // Structural queue sizes (every link, today-or-not) — detail is the
    // management surface, so it shows the whole chain on the 🔗 chip.
    final childrenByAnchor = stackChildrenByAnchor(allTasks);
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
            final queue = queueBehind(t, childrenByAnchor, (_) => true);
            return TaskTile(
              task: t,
              rowState: state,
              queueCount: queue.length,
              queueMinutes:
                  queue.isEmpty ? null : queueTotalMinutes(t, queue),
              meta: _metaForDetail(t, state,
                  anchorName: anchorNameById[t.stackedAfterTaskId],
                  strength: HabitStrength.scoreFor(t, completions)),
              weeklyChips: chips,
              // Milestone detail is the "management" surface — the escape hatch
              // when a completion has already fallen out of the 6-second UNDO
              // snackbar on Home / Timeline. Tap-to-toggle stays enabled here.
              allowInlineUndo: true,
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    showTaskFormSheet(context,
                        milestoneId: t.milestoneId, task: t);
                  } else if (v == 'delete') {
                    // Pops MUST use the dialog's context (dctx) — this
                    // screen is inside the shell navigator; the dialog is
                    // on the root one.
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (dctx) => AlertDialog(
                        title: const Text('Delete task?'),
                        content: Text(
                            '"${t.name}" and its completion history will be permanently deleted.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dctx).pop(false),
                            child: const Text('CANCEL'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(dctx).pop(true),
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
