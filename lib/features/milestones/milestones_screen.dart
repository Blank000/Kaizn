import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';
import '../../shared/providers/database_provider.dart';
import 'widgets/milestone_form_sheet.dart';

class MilestonesScreen extends ConsumerWidget {
  const MilestonesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final milestones = ref.watch(activeMilestonesProvider).valueOrNull ?? [];
    final tasks = ref.watch(activeTasksProvider).valueOrNull ?? [];

    final taskCounts = <String, int>{};
    for (final t in tasks) {
      if (t.milestoneId != null) {
        taskCounts[t.milestoneId!] = (taskCounts[t.milestoneId!] ?? 0) + 1;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Milestones', style: AppTypography.heading1),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showMilestoneFormSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('NEW MILESTONE'),
      ),
      body: milestones.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: milestones.length,
              itemBuilder: (_, i) {
                final m = milestones[i];
                return _MilestoneCard(
                  milestone: m,
                  taskCount: taskCounts[m.id] ?? 0,
                  onTap: () =>
                      context.go('/milestones/${m.id}'),
                );
              },
            ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  final Milestone milestone;
  final int taskCount;
  final VoidCallback onTap;

  const _MilestoneCard({
    required this.milestone,
    required this.taskCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateLine = milestone.targetDate != null
        ? 'By ${DateFormat.yMMMd().format(milestone.targetDate!)}'
        : null;

    final accentColor = AppColors.milestoneColor(milestone.colorIndex);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(milestone.name,
                        style: AppTypography.heading2),
                  ),
                ],
              ),
              if (milestone.description != null &&
                  milestone.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 22),
                  child: Text(
                    milestone.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body
                        .copyWith(color: context.appTextSecondary),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 22),
                child: Row(
                  children: [
                    _InfoChip(
                      icon: Icons.checklist_rounded,
                      label: taskCount == 1 ? '1 task' : '$taskCount tasks',
                    ),
                    if (dateLine != null) ...[
                      const SizedBox(width: 8),
                      _InfoChip(
                        icon: Icons.calendar_today_rounded,
                        label: dateLine,
                      ),
                    ],
                    if (milestone.completionPoints > 0) ...[
                      const SizedBox(width: 8),
                      _InfoChip(
                        icon: Icons.star_rounded,
                        label: '+${milestone.completionPoints} pts',
                        color: AppColors.rewardsGold,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.appTextSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: c,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('Set your first milestone',
                style: AppTypography.heading2),
            const SizedBox(height: 8),
            Text(
              'Habits to build, goals to hit, projects to ship — anything you want to track lives here.',
              style: AppTypography.body
                  .copyWith(color: context.appTextSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => showMilestoneFormSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('CREATE MILESTONE'),
            ),
          ],
        ),
      ),
    );
  }
}
