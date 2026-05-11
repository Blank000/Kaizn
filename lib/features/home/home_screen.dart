import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database.dart';
import '../../core/services/achievement_service.dart';
import '../../core/services/app_prefs.dart';
import '../../core/services/streak_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';
import '../../shared/models/recurrence_rule.dart';
import '../../shared/providers/database_provider.dart';
import '../../shared/widgets/achievement_snackbar.dart';
import '../../shared/widgets/animated_number.dart';
import '../../shared/widgets/celebration_dialog.dart';
import '../../shared/widgets/task_tile.dart';
import '../milestones/widgets/task_form_sheet.dart';
import '../rewards/claim_flow.dart';
import 'widgets/streak_popup.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _allDoneCelebrationFiredThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStreakPopup());
  }

  Future<void> _maybeAllDoneCelebration(int doneCount, int pointsToday) async {
    if (_allDoneCelebrationFiredThisSession) return;
    _allDoneCelebrationFiredThisSession = true;

    final last = await AppPrefs.getLastAllDoneCelebrationDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (last != null && last.isAtSameMomentAs(today)) return;

    await AppPrefs.setLastAllDoneCelebrationDate(today);
    if (!mounted) return;
    await showCelebrationDialog(
      context,
      emoji: '⭐',
      title: 'ALL DONE TODAY!',
      subtitle: 'Beautiful work.',
      body: pointsToday > 0
          ? '$doneCount tasks · +$pointsToday pts today'
          : '$doneCount tasks complete',
      titleColor: AppColors.rewardsGold,
    );
    final badge = await AchievementService.checkCompletionist();
    if (badge != null && mounted) {
      showAchievementSnackbar(context, [badge]);
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 22) return 'Good evening';
    return 'Up late';
  }

  Future<void> _maybeStreakPopup() async {
    if (!mounted) return;
    final lastOpen = await AppPrefs.getLastAppOpenDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (lastOpen != null && lastOpen.isAtSameMomentAs(today)) return;

    final db = ref.read(databaseProvider);
    final result = await StreakService.checkOnAppOpen(db);
    await AppPrefs.setLastAppOpenDate(today);
    if (!mounted) return;
    // Only show the popup if something interesting happened or the user has
    // an ongoing streak — silent open for fresh installs.
    final shouldShow = result.milestoneHit != null ||
        result.wasReset ||
        result.currentStreak > 0;
    if (shouldShow) {
      await showStreakPopup(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPoints = ref.watch(totalPointsProvider).valueOrNull ?? 0;
    final todayPoints = ref.watch(todayPointsProvider).valueOrNull ?? 0;
    final streak = ref.watch(currentStreakProvider).valueOrNull;
    final tasks = ref.watch(activeTasksProvider).valueOrNull ?? [];
    final completions =
        ref.watch(recentCompletionsAllProvider).valueOrNull ?? [];
    final milestones =
        ref.watch(activeMilestonesProvider).valueOrNull ?? [];
    final claimableRewards = ref.watch(claimableRewardsProvider);

    final milestoneById = {for (final m in milestones) m.id: m};
    final now = DateTime.now();

    final upNext = <_TodayItem>[];
    final doneToday = <_TodayItem>[];
    final skippedToday = <_TodayItem>[];
    final missedToday = <_TodayItem>[];

    for (final t in tasks) {
      final today = _completionsTodayFor(t.id, completions, now);
      if (today.real != null) {
        doneToday.add(_TodayItem(
            t, TaskRowState(checkedCompletion: today.real)));
        continue;
      }
      if (today.nd != null) {
        missedToday.add(_TodayItem(
            t, TaskRowState(ndCompletion: today.nd)));
        continue;
      }
      if (today.skip != null) {
        skippedToday.add(_TodayItem(
            t, TaskRowState(skipCompletion: today.skip)));
        continue;
      }
      // Already handled earlier in the rule period (e.g. weekly task done
      // Monday — don't reshow on Wednesday).
      final periodState = taskRowStateFor(t, completions);
      if (periodState.isChecked ||
          periodState.isMissed ||
          periodState.isSkipped) continue;
      if (_isScheduledToday(t, now)) {
        upNext.add(_TodayItem(t, const TaskRowState()));
      }
    }

    // Skipped tasks are removed from today's load. Missed tasks stay on the
    // count (they were scheduled and not done).
    final totalScheduled =
        upNext.length + doneToday.length + missedToday.length;
    final allDone = totalScheduled > 0 &&
        upNext.isEmpty &&
        missedToday.isEmpty &&
        doneToday.isNotEmpty;
    if (allDone && !_allDoneCelebrationFiredThisSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeAllDoneCelebration(doneToday.length, todayPoints);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_greeting(), style: AppTypography.heading1),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTaskFormSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('ADD TASK'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _StatsHeader(
            totalPoints: totalPoints,
            currentStreak: streak?.currentStreak ?? 0,
          ),
          const SizedBox(height: 20),
          if (totalScheduled > 0)
            _TodayProgressCard(
              done: doneToday.length,
              total: totalScheduled,
              pointsToday: todayPoints,
            ),
          if (claimableRewards.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionHeader('Ready to claim'),
            ...claimableRewards.map((r) => _ClaimableRewardCard(
                  reward: r,
                  onClaim: () =>
                      claimReward(context, ref, r, totalPoints),
                )),
          ],
          const SizedBox(height: 20),
          if (upNext.isEmpty &&
              doneToday.isEmpty &&
              skippedToday.isEmpty &&
              missedToday.isEmpty)
            _NothingTodayState(
              hasMilestones: milestones.isNotEmpty,
              onAddTask: () => showTaskFormSheet(context),
            )
          else ...[
            if (upNext.isNotEmpty) ...[
              _SectionHeader('Up next today'),
              ...upNext.map((it) => TaskTile(
                    task: it.task,
                    rowState: it.rowState,
                    weeklyChips: weeklyChipsFor(it.task, completions),
                    meta: _metaForHome(it.task,
                        milestoneById[it.task.milestoneId], it.rowState),
                  )),
            ],
            if (doneToday.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionHeader('Done today'),
              ...doneToday.map((it) => TaskTile(
                    task: it.task,
                    rowState: it.rowState,
                    weeklyChips: weeklyChipsFor(it.task, completions),
                    meta: _metaForHome(it.task,
                        milestoneById[it.task.milestoneId], it.rowState),
                  )),
            ],
            if (missedToday.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionHeader('Missed today'),
              ...missedToday.map((it) => TaskTile(
                    task: it.task,
                    rowState: it.rowState,
                    weeklyChips: weeklyChipsFor(it.task, completions),
                    meta: _metaForHome(it.task,
                        milestoneById[it.task.milestoneId], it.rowState),
                  )),
            ],
            if (skippedToday.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionHeader('Skipped today'),
              ...skippedToday.map((it) => TaskTile(
                    task: it.task,
                    rowState: it.rowState,
                    weeklyChips: weeklyChipsFor(it.task, completions),
                    meta: _metaForHome(it.task,
                        milestoneById[it.task.milestoneId], it.rowState),
                  )),
            ],
          ],
        ],
      ),
    );
  }
}

// ── helpers ──────────────────────────────────────────────────────────────────

class _TodayItem {
  final Task task;
  final TaskRowState rowState;
  _TodayItem(this.task, this.rowState);
}

class _TodayCompletions {
  final TaskCompletion? real;
  final TaskCompletion? skip;
  final TaskCompletion? nd;
  const _TodayCompletions({this.real, this.skip, this.nd});
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

_TodayCompletions _completionsTodayFor(
    String taskId, List<TaskCompletion> completions, DateTime today) {
  TaskCompletion? real;
  TaskCompletion? skip;
  TaskCompletion? nd;
  for (final c in completions) {
    if (c.taskId != taskId) continue;
    if (!_isSameDay(c.completedOn, today)) continue;
    if (c.isSkip) {
      skip = c;
    } else if (c.isNd) {
      nd = c;
    } else {
      real ??= c;
    }
  }
  return _TodayCompletions(real: real, skip: skip, nd: nd);
}

bool _isScheduledToday(Task task, DateTime today) {
  if (task.recurrence == TaskRecurrence.none) {
    if (task.status != TaskStatus.active) return false;
    if (task.dueDate == null) return false;
    final due = DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
    final t = DateTime(today.year, today.month, today.day);
    return !due.isAfter(t);
  }
  return RecurrenceRule.fromTask(task).isDueOn(today);
}

String _metaForHome(Task task, Milestone? milestone, TaskRowState rowState) {
  final parts = <String>[];
  if (milestone != null) parts.add(milestone.name);
  parts.add('${task.pointsPerCompletion} pts');
  if (rowState.isMissed) {
    parts.add('Missed today');
  } else if (rowState.isSkipped) {
    parts.add('Skipped today');
  }
  return parts.join(' · ');
}

// ── sub-widgets ──────────────────────────────────────────────────────────────

class _StatsHeader extends StatelessWidget {
  final int totalPoints;
  final int currentStreak;

  const _StatsHeader({
    required this.totalPoints,
    required this.currentStreak,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedNumber(
                value: totalPoints,
                style: AppTypography.display
                    .copyWith(color: AppColors.primary),
              ),
              Text('points',
                  style: AppTypography.caption
                      .copyWith(color: context.appTextSecondary)),
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.streakOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedNumber(
                    value: currentStreak,
                    style: AppTypography.heading1.copyWith(
                      color: AppColors.streakOrange,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    currentStreak == 1 ? 'DAY' : 'DAYS',
                    style: AppTypography.caption.copyWith(
                      fontSize: 9,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TodayProgressCard extends StatelessWidget {
  final int done;
  final int total;
  final int pointsToday;

  const _TodayProgressCard({
    required this.done,
    required this.total,
    required this.pointsToday,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : done / total;
    final allDone = total > 0 && done == total;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appPageBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                allDone ? 'All done today!' : "Today's progress",
                style: AppTypography.body
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              AnimatedNumber(
                value: pointsToday,
                prefix: '+',
                suffix: ' pts',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: context.appBorder.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation(
                allDone ? AppColors.streakOrange : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$done / $total tasks',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.caption.copyWith(
          letterSpacing: 1.5,
          fontWeight: FontWeight.w800,
          color: context.appTextSecondary,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _ClaimableRewardCard extends StatelessWidget {
  final Reward reward;
  final VoidCallback onClaim;

  const _ClaimableRewardCard({required this.reward, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.rewardsGold.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () => context.go('/rewards'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.rewardsGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Text('🎁', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reward.name, style: AppTypography.body),
                    Text(
                      '${reward.pointsThreshold} pts',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: onClaim,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text('CLAIM'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NothingTodayState extends StatelessWidget {
  final bool hasMilestones;
  final VoidCallback onAddTask;

  const _NothingTodayState({
    required this.hasMilestones,
    required this.onAddTask,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: context.appPageBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('🌅', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            hasMilestones ? 'Nothing scheduled today' : 'Get started',
            style: AppTypography.heading2,
          ),
          const SizedBox(height: 4),
          Text(
            hasMilestones
                ? 'Add a task with a daily/weekly cadence and it shows up here.'
                : 'Add your first task to start tracking.',
            style: AppTypography.body
                .copyWith(color: context.appTextSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAddTask,
            icon: const Icon(Icons.add_rounded),
            label: const Text('ADD TASK'),
          ),
        ],
      ),
    );
  }
}
