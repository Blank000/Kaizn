import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database.dart';
import '../../core/services/achievement_service.dart';
import '../../core/services/app_prefs.dart';
import '../../core/services/goldilocks_service.dart';
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
import '../../shared/models/task_stack.dart';
import '../../shared/providers/active_timer_provider.dart';
import '../milestones/widgets/task_form_sheet.dart';
import '../rewards/claim_flow.dart';
import 'widgets/active_timer_banner.dart';
import 'widgets/never_miss_twice_banner.dart';
import 'widgets/streak_popup.dart';
import 'widgets/timeline_view.dart';

enum HomeViewMode { list, timeline }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _allDoneCelebrationFiredThisSession = false;
  // True after the streak-reset popup fired this session — the
  // never-miss-twice banner then switches to forward-only copy so the user
  // isn't told "yesterday slipped" twice in three seconds.
  bool _resetPopupShownThisSession = false;
  late HomeViewMode _viewMode;

  @override
  void initState() {
    super.initState();
    _viewMode = AppPrefs.homeViewModeSync == 'timeline'
        ? HomeViewMode.timeline
        : HomeViewMode.list;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStreakPopup());
  }

  void _switchView(HomeViewMode mode) {
    setState(() => _viewMode = mode);
    AppPrefs.setHomeViewMode(mode == HomeViewMode.timeline ? 'timeline' : 'list');
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
      if (result.wasReset) {
        setState(() => _resetPopupShownThisSession = true);
      }
      await showStreakPopup(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPoints = ref.watch(totalPointsProvider).valueOrNull ?? 0;
    final todayPoints = ref.watch(todayPointsProvider).valueOrNull ?? 0;
    final streak = ref.watch(currentStreakProvider).valueOrNull;
    // All non-archived tasks — NOT just active ones. A one-shot completed
    // today flips to status=completed and would vanish from an active-only
    // list; it must stay visible in "Done today" (and count toward the
    // progress card) for the rest of the day.
    final tasks = ref.watch(allTasksProvider).valueOrNull ?? [];
    final completions =
        ref.watch(recentCompletionsAllProvider).valueOrNull ?? [];
    final milestones =
        ref.watch(activeMilestonesProvider).valueOrNull ?? [];
    final claimableRewards = ref.watch(claimableRewardsProvider);

    final milestoneById = {for (final m in milestones) m.id: m};
    final taskById = {for (final t in tasks) t.id: t};
    final now = DateTime.now();

    // "Due today" in the loose sense queues care about: scheduled today per
    // recurrence, OR an undated active one-shot (those surface daily).
    bool dueTodayLoose(Task t) =>
        _isScheduledToday(t, now) ||
        (t.recurrence == TaskRecurrence.none &&
            t.status == TaskStatus.active &&
            t.dueDate == null);

    // Habit stacking: a queue member is "waiting" while its anchor is due
    // today and unresolved (no completion of any kind yet). Waiting tasks
    // are HIDDEN from Up next — only the head of each queue is actionable;
    // the next link pops in the moment the head resolves.
    bool waitingOnAnchor(Task t) {
      if (!isQueueMember(t)) return false;
      final anchor = taskById[t.stackedAfterTaskId];
      if (anchor == null) return false; // dangling ref (restored backup)
      if (!dueTodayLoose(anchor)) return false;
      final anchorToday = _completionsTodayFor(anchor.id, completions, now);
      return anchorToday.real == null &&
          anchorToday.skip == null &&
          anchorToday.nd == null;
    }

    // Queue lookups for head tiles ("+2 in queue · ~45m") and the honest
    // progress denominator.
    final childrenByAnchor = stackChildrenByAnchor(tasks);
    bool inTodaysQueue(Task c) {
      final cToday = _completionsTodayFor(c.id, completions, now);
      if (cToday.real != null || cToday.skip != null || cToday.nd != null) {
        return false;
      }
      return dueTodayLoose(c);
    }

    // Whether [t] belongs on today's list. Beyond the recurrence rule,
    // one-shot tasks with no due date surface every day until they're done —
    // a captured task must never be invisible. Stacked undated one-shots
    // ride their anchor's schedule instead (they belong to the anchor's
    // days); a dangling anchor falls back to always-surface.
    bool surfacesToday(Task t) {
      if (_isScheduledToday(t, now)) return true;
      if (t.recurrence == TaskRecurrence.none &&
          t.status == TaskStatus.active &&
          t.dueDate == null) {
        final anchorId = t.stackedAfterTaskId;
        if (anchorId == null) return true;
        final anchor = taskById[anchorId];
        return anchor == null || _isScheduledToday(anchor, now);
      }
      return false;
    }

    final upNext = <_TodayItem>[];
    final doneToday = <_TodayItem>[];
    final skippedToday = <_TodayItem>[];
    final missedToday = <_TodayItem>[];
    // Queue members hidden behind an unresolved anchor — invisible in Up
    // next, but still today's work for the progress denominator.
    var hiddenQueuedCount = 0;

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
      // Monday — don't reshow on Wednesday). Also filters one-shots
      // completed on a PREVIOUS day (their best completion marks them
      // checked), so old finished tasks don't clutter today.
      final periodState = taskRowStateFor(t, completions);
      if (periodState.isChecked ||
          periodState.isMissed ||
          periodState.isSkipped) continue;
      if (surfacesToday(t)) {
        if (waitingOnAnchor(t)) {
          hiddenQueuedCount++;
        } else {
          upNext.add(_TodayItem(t, const TaskRowState()));
        }
      }
    }

    // Skipped tasks are removed from today's load. Missed tasks stay on the
    // count (they were scheduled and not done), and so do queued tasks
    // hidden behind their anchor.
    final totalScheduled = upNext.length +
        doneToday.length +
        missedToday.length +
        hiddenQueuedCount;
    final allDone = totalScheduled > 0 &&
        upNext.isEmpty &&
        missedToday.isEmpty &&
        doneToday.isNotEmpty;
    if (allDone && !_allDoneCelebrationFiredThisSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeAllDoneCelebration(doneToday.length, todayPoints);
      });
    }

    // Empty-state renders its own ADD TASK button, so hide the FAB there to
    // avoid two identical CTAs stacked on the same screen.
    final showEmptyState = _viewMode == HomeViewMode.list &&
        upNext.isEmpty &&
        doneToday.isEmpty &&
        skippedToday.isEmpty &&
        missedToday.isEmpty;

    // Never-miss-twice banner (Atomic Habits). Auto-hides reactively the
    // moment a real completion lands today (the completions stream re-emits).
    // One-attention-slot policy: the live timer banner outranks it.
    final timerRunning =
        ref.watch(activeTimerProvider).valueOrNull != null;
    final showNmtBanner = !timerRunning &&
        shouldShowNeverMissTwice(
          completions: completions,
          now: now,
          hasUpNext: upNext.isNotEmpty,
          dismissedDate: AppPrefs.nmtDismissedDateSync,
        );

    // Goldilocks coach (lowest banner priority: timer > NMT > coach). One
    // suggestion per day max; dormant until the user's own history triggers
    // it (3 straight misses → shrink; 14-for-14 → level up).
    final coachDismissed = AppPrefs.coachDismissedDateSync;
    final coachEligible = !timerRunning &&
        !showNmtBanner &&
        (coachDismissed == null ||
            !coachDismissed
                .isAtSameMomentAs(DateTime(now.year, now.month, now.day)));
    final coachSuggestion = coachEligible
        ? GoldilocksService.evaluate(tasks, completions, now)
        : null;

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
      floatingActionButton: showEmptyState
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showTaskFormSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('ADD TASK'),
            ),
      body: Column(
        children: [
          _ViewToggle(value: _viewMode, onChanged: _switchView),
          // The single attention-banner slot, shared by both view modes.
          // Priority: live timer > never-miss-twice (showNmtBanner already
          // yields when a timer runs). ActiveTimerBanner renders nothing
          // when no timer is active.
          const ActiveTimerBanner(),
          if (showNmtBanner)
            NeverMissTwiceBanner(
              currentStreak: streak?.currentStreak ?? 0,
              freshStartCopy: _resetPopupShownThisSession,
              onDismiss: () async {
                await AppPrefs.setNmtDismissedDate(DateTime.now());
                if (mounted) setState(() {});
              },
            ),
          if (coachSuggestion != null)
            _CoachBanner(
              suggestion: coachSuggestion,
              onTap: () => showTaskFormSheet(context,
                  milestoneId: coachSuggestion.task.milestoneId,
                  task: coachSuggestion.task),
              onDismiss: () async {
                await AppPrefs.setCoachDismissedDate(DateTime.now());
                if (mounted) setState(() {});
              },
            ),
          Expanded(
            child: _viewMode == HomeViewMode.timeline
                ? const TimelineView()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
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
            // One-attention-slot policy: while the never-miss-twice banner
            // holds the slot, rewards collapse to a single-line pill so the
            // first actionable task stays above the fold.
            if (showNmtBanner)
              _RewardsReadyPill(count: claimableRewards.length)
            else ...[
              _SectionHeader('Ready to claim'),
              ...claimableRewards.map((r) => _ClaimableRewardCard(
                    reward: r,
                    onClaim: () =>
                        claimReward(context, ref, r, totalPoints),
                  )),
            ],
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
              // Queue members waiting on an anchor are hidden — each tile
              // here is actionable NOW. Heads of queues show what's behind
              // them instead ("+2 in queue · ~45m").
              ...upNext.map((it) {
                final queue =
                    queueBehind(it.task, childrenByAnchor, inTodaysQueue);
                return TaskTile(
                  task: it.task,
                  rowState: it.rowState,
                  weeklyChips: weeklyChipsFor(it.task, completions),
                  showTimerButton: true,
                  meta: _metaForHome(
                    it.task,
                    milestoneById[it.task.milestoneId],
                    it.rowState,
                    anchorName: taskById[it.task.stackedAfterTaskId]?.name,
                    queueCount: queue.length,
                    queueMinutes: queue.isEmpty
                        ? null
                        : queueTotalMinutes(it.task, queue),
                  ),
                );
              }),
            ],
            if (doneToday.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionHeader('Done today'),
              ...doneToday.map((it) => TaskTile(
                    task: it.task,
                    rowState: it.rowState,
                    weeklyChips: weeklyChipsFor(it.task, completions),
                    meta: _metaForHome(
                      it.task,
                      milestoneById[it.task.milestoneId],
                      it.rowState,
                      anchorName:
                          taskById[it.task.stackedAfterTaskId]?.name,
                    ),
                  )),
            ],
            if (missedToday.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionHeader('Missed today'),
              ...missedToday.map((it) => TaskTile(
                    task: it.task,
                    rowState: it.rowState,
                    weeklyChips: weeklyChipsFor(it.task, completions),
                    meta: _metaForHome(
                      it.task,
                      milestoneById[it.task.milestoneId],
                      it.rowState,
                      anchorName:
                          taskById[it.task.stackedAfterTaskId]?.name,
                    ),
                  )),
            ],
            if (skippedToday.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionHeader('Skipped today'),
              ...skippedToday.map((it) => TaskTile(
                    task: it.task,
                    rowState: it.rowState,
                    weeklyChips: weeklyChipsFor(it.task, completions),
                    meta: _metaForHome(
                      it.task,
                      milestoneById[it.task.milestoneId],
                      it.rowState,
                      anchorName:
                          taskById[it.task.stackedAfterTaskId]?.name,
                    ),
                  )),
            ],
          ],
                    ],
                  ),
          ),
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

/// Short cadence hint so a glance tells recurring habits and one-time tasks
/// apart on the Home list.
String _cadenceLabel(Task task) => switch (task.recurrence) {
      TaskRecurrence.none => 'Once',
      TaskRecurrence.daily => 'Daily',
      TaskRecurrence.weekly => 'Weekly',
      TaskRecurrence.monthly => 'Monthly',
    };

String _metaForHome(Task task, Milestone? milestone, TaskRowState rowState,
    {String? anchorName, int queueCount = 0, int? queueMinutes}) {
  final parts = <String>[];
  if (milestone != null) parts.add(milestone.name);
  parts.add(_cadenceLabel(task));
  parts.add('${task.pointsPerCompletion} pts');
  if (queueCount > 0) {
    parts.add('🔗 +$queueCount in queue'
        '${queueMinutes == null ? '' : ' · ~${formatQueueMinutes(queueMinutes)}'}');
  } else if (anchorName != null) {
    parts.add('🔗 After $anchorName');
  }
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

/// Goldilocks coach suggestion — the quietest banner in the attention slot.
/// Tap opens the task's edit form; X mutes the coach for the day.
class _CoachBanner extends StatelessWidget {
  final GoldilocksSuggestion suggestion;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _CoachBanner({
    required this.suggestion,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          decoration: BoxDecoration(
            color: AppColors.infoBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.infoBlue.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Text(suggestion.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  suggestion.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: context.appTextTertiary,
                tooltip: 'Not today',
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact stand-in for the Ready-to-claim cards while another banner holds
/// the attention slot. Tapping goes to the Rewards tab.
class _RewardsReadyPill extends StatelessWidget {
  final int count;
  const _RewardsReadyPill({required this.count});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/rewards'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.rewardsGold.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.rewardsGold.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const Text('🎁', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                count == 1
                    ? '1 reward ready to claim'
                    : '$count rewards ready to claim',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimary,
                ),
              ),
            ),
            Text(
              'CLAIM',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: AppColors.rewardsGold,
              ),
            ),
          ],
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

class _ViewToggle extends StatelessWidget {
  final HomeViewMode value;
  final ValueChanged<HomeViewMode> onChanged;
  const _ViewToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SegmentedButton<HomeViewMode>(
        // expandedInsets makes each segment fill an equal share of the
        // available width — otherwise SegmentedButton sizes segments to their
        // content and "Timeline" wraps to two lines. softWrap:false on the
        // labels belt-and-suspenders that in case the layout still gets
        // squeezed on some rotation / font-scale combo.
        segments: const [
          ButtonSegment(
            value: HomeViewMode.list,
            label: Text('List', softWrap: false, maxLines: 1),
          ),
          ButtonSegment(
            value: HomeViewMode.timeline,
            label: Text('Timeline', softWrap: false, maxLines: 1),
          ),
        ],
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
        showSelectedIcon: false,
        expandedInsets: EdgeInsets.zero,
        style: const ButtonStyle(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
