import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';
import '../../features/milestones/widgets/task_form_sheet.dart';
import '../models/recurrence_rule.dart';
import '../models/task_stack.dart';
import '../providers/database_provider.dart';
import 'task_tile.dart' show TaskRowState, taskRowStateFor;

/// Bottom sheet showing a habit-stack chain end-to-end: every link in order,
/// its state today, the total time commitment, and a way to grow the chain.
///
/// Self-contained: hand it ANY task in a chain (head or member) — it walks up
/// to the root, watches the live streams, and stays current while the edit
/// form or the add-to-queue form is open on top of it.
Future<void> showQueueSheet(BuildContext context, Task task) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _QueueSheet(taskId: task.id),
  );
}

class _QueueSheet extends ConsumerWidget {
  final String taskId;
  const _QueueSheet({required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(allTasksProvider).valueOrNull ?? const <Task>[];
    final completions =
        ref.watch(recentCompletionsAllProvider).valueOrNull ??
            const <TaskCompletion>[];
    final byId = {for (final t in tasks) t.id: t};

    final self = byId[taskId];
    if (self == null) return const SizedBox.shrink(); // deleted mid-view

    // Walk UP to the chain's root (cycle-safe). The root may be a normal
    // scheduled/recurring task — only members are start-time-less.
    var root = self;
    final visited = <String>{root.id};
    while (root.stackedAfterTaskId != null) {
      final parent = byId[root.stackedAfterTaskId];
      if (parent == null || !visited.add(parent.id)) break;
      root = parent;
    }

    // Full structural chain (every link, whether or not it runs today).
    final childrenByAnchor = stackChildrenByAnchor(tasks);
    final chain = <Task>[
      root,
      ...queueBehind(root, childrenByAnchor, (_) => true),
    ];

    final today = DateTime.now();
    bool runsToday(Task t) {
      if (t.recurrence != TaskRecurrence.none) {
        return RecurrenceRule.fromTask(t).isDueOn(today);
      }
      if (t.status != TaskStatus.active) return false;
      if (t.dueDate == null) return true; // undated one-shots ride the chain
      final due =
          DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return !due.isAfter(DateTime(today.year, today.month, today.day));
    }

    final states = [for (final t in chain) taskRowStateFor(t, completions)];
    // "Next up" = the first link that's unresolved and actually runs today.
    var nextIdx = -1;
    for (var i = 0; i < chain.length; i++) {
      if (states[i].isUnchecked && runsToday(chain[i])) {
        nextIdx = i;
        break;
      }
    }

    final totalMinutes =
        chain.fold<int>(0, (sum, t) => sum + t.durationMinutes);
    final totalPoints =
        chain.fold<int>(0, (sum, t) => sum + t.pointsPerCompletion);

    // Derived clock times: when the root is scheduled, every link inherits
    // root start + the durations before it (same math as the timeline).
    final times = <int?>[];
    var cursor = root.startMinute;
    for (final t in chain) {
      times.add(cursor);
      if (cursor != null) cursor = cursor + t.durationMinutes;
    }

    return Container(
      decoration: BoxDecoration(
        color: context.appCardSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SafeArea(
        top: false,
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
            Text(
              '🔗 ${root.name}',
              style: AppTypography.heading2,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${chain.length} tasks · ~${formatQueueMinutes(totalMinutes)}'
              ' · $totalPoints pts · tap a task to edit',
              style: AppTypography.caption
                  .copyWith(color: context.appTextSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: chain.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _QueueRow(
                  index: i,
                  task: chain[i],
                  state: states[i],
                  isNext: i == nextIdx,
                  runsToday: runsToday(chain[i]),
                  startMinute: times[i],
                  onTap: () => showTaskFormSheet(context,
                      milestoneId: chain[i].milestoneId, task: chain[i]),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => showTaskFormSheet(
                context,
                milestoneId: chain.last.milestoneId,
                initialStackedAfterTaskId: chain.last.id,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('ADD TO THIS QUEUE'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  final int index;
  final Task task;
  final TaskRowState state;
  final bool isNext;
  final bool runsToday;

  /// Derived clock slot (root start + earlier durations); null when the
  /// chain's root has no start time.
  final int? startMinute;
  final VoidCallback onTap;

  const _QueueRow({
    required this.index,
    required this.task,
    required this.state,
    required this.isNext,
    required this.runsToday,
    this.startMinute,
    required this.onTap,
  });

  static String _fmtClock(int m) {
    final h = (m ~/ 60) % 24;
    final min = m % 60;
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return min == 0
        ? '$h12 $ampm'
        : '$h12:${min.toString().padLeft(2, '0')} $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final Color leadColor;
    final Widget leadChild;
    if (state.isChecked) {
      leadColor = AppColors.primary;
      leadChild = const Icon(Icons.check_rounded, size: 16, color: Colors.white);
    } else if (state.isMissed) {
      leadColor = Colors.red.shade400;
      leadChild = const Icon(Icons.close_rounded, size: 16, color: Colors.white);
    } else if (state.isSkipped) {
      leadColor = context.appTextTertiary;
      leadChild =
          const Icon(Icons.remove_rounded, size: 16, color: Colors.white);
    } else {
      leadColor = Colors.transparent;
      leadChild = Text(
        '${index + 1}',
        style: AppTypography.caption.copyWith(
          fontWeight: FontWeight.w800,
          color: isNext ? AppColors.primary : context.appTextTertiary,
        ),
      );
    }

    final meta = <String>[
      if (startMinute != null) _fmtClock(startMinute!),
      '~${formatQueueMinutes(task.durationMinutes)}',
      '${task.pointsPerCompletion} pts',
      if (task.recurrence != TaskRecurrence.none)
        RecurrenceRule.fromTask(task).summary(),
      if (!runsToday && state.isUnchecked) 'not today',
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isNext ? AppColors.primary : context.appBorder,
            width: isNext ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: leadColor,
                shape: BoxShape.circle,
                border: leadColor == Colors.transparent
                    ? Border.all(
                        color: isNext
                            ? AppColors.primary
                            : context.appBorder,
                        width: 2,
                      )
                    : null,
              ),
              child: leadChild,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      color: (state.isChecked || state.isSkipped)
                          ? context.appTextSecondary
                          : context.appTextPrimary,
                      decoration: state.isChecked
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption
                        .copyWith(color: context.appTextSecondary),
                  ),
                ],
              ),
            ),
            if (isNext) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'NEXT',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
