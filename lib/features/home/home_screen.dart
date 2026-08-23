import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/services/achievement_service.dart';
import '../../core/services/app_prefs.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/cosmetics_service.dart';
import '../../core/services/goldilocks_service.dart';
import '../../core/services/league_service.dart';
import '../../core/services/level_service.dart';
import '../../core/services/notification_scheduler.dart';
import '../../core/services/quest_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/streak_service.dart';
import '../../core/services/timer_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';
import '../../shared/models/recurrence_rule.dart';
import '../../shared/providers/database_provider.dart';
import '../../shared/widgets/achievement_snackbar.dart';
import '../../shared/widgets/animated_number.dart';
import '../../shared/widgets/celebration_dialog.dart';
import '../../shared/widgets/day_complete_sequence.dart';
import '../../shared/widgets/stagger_in.dart';
import '../../shared/widgets/streak_flame.dart';
import '../../shared/widgets/zen_spark.dart';
import '../../shared/widgets/spring_progress_bar.dart';
import '../../shared/widgets/task_tile.dart';
import '../../shared/models/task_stack.dart';
import '../../shared/providers/active_timer_provider.dart';
import '../milestones/widgets/task_form_sheet.dart';
import '../rewards/claim_flow.dart';
import 'widgets/active_timer_banner.dart';
import 'widgets/never_miss_twice_banner.dart';
import 'widgets/quick_capture_sheet.dart';
import 'widgets/streak_popup.dart';
import 'widgets/timeline_view.dart';
import 'widgets/week_board.dart';

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

  // The day being viewed (date-only). Today = the normal live Home; a past
  // date renders that day's record read-only.
  late DateTime _viewDate;

  @override
  void initState() {
    super.initState();
    _viewMode = AppPrefs.homeViewModeSync == 'timeline'
        ? HomeViewMode.timeline
        : HomeViewMode.list;
    final n = DateTime.now();
    _viewDate = DateTime(n.year, n.month, n.day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeStreakPopup();
      // Lazy weekly close-out (league_weeks) — at most once per week.
      LeagueService.maybeCloseOutLastWeek(ref.read(databaseProvider));
    });
  }

  DateTime get _todayDate {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _viewingToday => _viewDate.isAtSameMomentAs(_todayDate);
  bool get _viewingFuture => _viewDate.isAfter(_todayDate);

  Future<void> _pickViewDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _viewDate,
      firstDate: _todayDate.subtract(const Duration(days: 365)),
      lastDate: _todayDate.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() =>
          _viewDate = DateTime(picked.year, picked.month, picked.day));
    }
  }

  void _switchView(HomeViewMode mode) {
    setState(() => _viewMode = mode);
    AppPrefs.setHomeViewMode(mode == HomeViewMode.timeline ? 'timeline' : 'list');
  }

  /// Read-only record of a past day: what was done / missed / skipped, plus
  /// recurring tasks that were scheduled but never logged. Static rows —
  /// retro-logging stays a deliberate act (weekly chips / milestone detail).
  Widget _buildPastDayList(
    List<Task> tasks,
    List<TaskCompletion> completions,
    Map<String, Milestone> milestoneById,
    Map<String, Task> taskById,
  ) {
    final done = <(Task, TaskCompletion)>[];
    final missed = <Task>[];
    final skipped = <Task>[];
    final notLogged = <Task>[];

    for (final t in tasks) {
      final c = _completionsTodayFor(t.id, completions, _viewDate);
      if (c.real != null) {
        done.add((t, c.real!));
      } else if (c.nd != null) {
        missed.add(t);
      } else if (c.skip != null) {
        skipped.add(t);
      } else if (t.recurrence != TaskRecurrence.none &&
          RecurrenceRule.fromTask(t).isDueOn(_viewDate)) {
        notLogged.add(t);
      }
    }

    String metaFor(Task t) {
      final parts = <String>[];
      final m = milestoneById[t.milestoneId];
      if (m != null) parts.add(m.name);
      parts.add(_cadenceLabel(t));
      return parts.join(' · ');
    }

    if (done.isEmpty &&
        missed.isEmpty &&
        skipped.isEmpty &&
        notLogged.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'Nothing was scheduled or logged this day 🗓',
            style: AppTypography.body
                .copyWith(color: context.appTextSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        if (done.isNotEmpty) ...[
          _SectionHeader('Done'),
          ...done.map((e) => _ReviewRow(
                icon: Icons.check_rounded,
                color: AppColors.primary,
                title: e.$1.name,
                meta: [
                  metaFor(e.$1),
                  if (e.$2.pointsEarned > 0) '+${e.$2.pointsEarned} pts',
                  if (e.$2.isTiny) '⚡ 2-min version',
                  if (e.$2.durationSeconds != null)
                    '⏱ ${TimerService.formatElapsed(e.$2.durationSeconds!)}',
                ].join(' · '),
              )),
          const SizedBox(height: 16),
        ],
        if (missed.isNotEmpty) ...[
          _SectionHeader('Missed'),
          ...missed.map((t) => _ReviewRow(
                icon: Icons.close_rounded,
                color: Colors.red.shade400,
                title: t.name,
                meta: metaFor(t),
              )),
          const SizedBox(height: 16),
        ],
        if (skipped.isNotEmpty) ...[
          _SectionHeader('Skipped'),
          ...skipped.map((t) => _ReviewRow(
                icon: Icons.remove_rounded,
                color: context.appTextTertiary,
                title: t.name,
                meta: '${metaFor(t)} · Intentional rest',
              )),
          const SizedBox(height: 16),
        ],
        if (notLogged.isNotEmpty) ...[
          _SectionHeader('Scheduled · not logged'),
          ...notLogged.map((t) => _ReviewRow(
                icon: Icons.radio_button_unchecked,
                color: context.appTextTertiary,
                title: t.name,
                meta: metaFor(t),
              )),
        ],
      ],
    );
  }

  /// Preview of a future day's plan: what will surface on Home that day.
  /// Static rows — tasks are acted on when the day arrives.
  Widget _buildFutureDayList(
    List<Task> tasks,
    Map<String, Milestone> milestoneById,
    Map<String, Task> taskById,
  ) {
    // Same surfacing rules as the live Home list, evaluated for _viewDate:
    // recurrence hit or open dated one-shot; undated one-shots surface every
    // day until done, stacked ones ride their anchor's schedule.
    bool plannedOn(Task t) {
      if (_isScheduledToday(t, _viewDate)) return true;
      if (t.recurrence == TaskRecurrence.none &&
          t.status == TaskStatus.active &&
          t.dueDate == null) {
        final anchorId = t.stackedAfterTaskId;
        if (anchorId == null) return true;
        final anchor = taskById[anchorId];
        return anchor == null || _isScheduledToday(anchor, _viewDate);
      }
      return false;
    }

    final planned = tasks.where(plannedOn).toList()
      ..sort((a, b) {
        final am = a.startMinute ?? 24 * 60;
        final bm = b.startMinute ?? 24 * 60;
        if (am != bm) return am.compareTo(bm);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    if (planned.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'Nothing planned for this day yet 🗓',
            style: AppTypography.body
                .copyWith(color: context.appTextSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    String metaFor(Task t) {
      final parts = <String>[];
      if (t.startMinute != null) {
        parts.add(TimeOfDay(
                hour: t.startMinute! ~/ 60, minute: t.startMinute! % 60)
            .format(context));
      }
      final m = milestoneById[t.milestoneId];
      if (m != null) parts.add(m.name);
      parts.add(_cadenceLabel(t));
      if (t.recurrence == TaskRecurrence.none && t.dueDate != null) {
        parts.add('due ${DateFormat.MMMd().format(t.dueDate!)}');
      } else if (t.recurrence != TaskRecurrence.none) {
        final ends = RecurrenceRule.fromTask(t).untilLabel;
        if (ends != null) parts.add('ends $ends');
      }
      parts.add('~${formatQueueMinutes(t.durationMinutes)}');
      final anchorName = taskById[t.stackedAfterTaskId]?.name;
      if (anchorName != null) parts.add('🔗 After $anchorName');
      return parts.join(' · ');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _SectionHeader('Planned · ${planned.length}'),
        ...planned.map((t) => _ReviewRow(
              icon: Icons.schedule_rounded,
              color: AppColors.infoBlue,
              title: t.name,
              meta: metaFor(t),
            )),
      ],
    );
  }

  /// The Day Complete choreography (docs/design_day_complete_choreography.md)
  /// — a short sequenced show instead of one flat popup. Once per day.
  Future<void> _maybeAllDoneCelebration(
    int doneCount,
    int tinyCount,
    int pointsToday,
    int streakDay,
    List<Task> tasks,
    List<TaskCompletion> completions,
  ) async {
    if (_allDoneCelebrationFiredThisSession) return;
    _allDoneCelebrationFiredThisSession = true;

    final last = await AppPrefs.getLastAllDoneCelebrationDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (last != null && last.isAtSameMomentAs(today)) return;

    await AppPrefs.setLastAllDoneCelebrationDate(today);

    // Gather the show's facts (all cheap reads).
    final db = ref.read(databaseProvider);
    final clutch = await db.hasClutchBonusToday();
    final lifetime = await db.getLifetimeEarnedPoints();
    final quest = await QuestService.today(db, tasks, completions);

    if (!mounted) return;
    await showDayCompleteSequence(
      context,
      DayCompletePayload(
        doneCount: doneCount,
        tinyCount: tinyCount,
        pointsToday: pointsToday,
        clutchToday: clutch,
        streakDay: streakDay,
        questDoneToday: quest?.done ?? false,
        questWeekDots: (quest?.weekCount ?? 0).clamp(0, 5),
        chestReady: quest?.chestReady ?? false,
        level: LevelService.getLevel(lifetime),
      ),
    );
    final badge = await AchievementService.checkCompletionist();
    if (badge != null && mounted) {
      showAchievementSnackbar(context, [badge]);
    }
  }

  /// Personal, playful, and stable for the whole day (variant rotates by
  /// date, so it never flickers between rebuilds). Falls back to the plain
  /// time-of-day line when there's no signed-in name.
  String _greeting() {
    final now = DateTime.now();
    final hour = now.hour;
    final display = AuthService.currentUser?.displayName?.trim();
    final name = (display == null || display.isEmpty)
        ? null
        : display.split(' ').first;

    if (name == null) {
      if (hour >= 5 && hour < 12) return 'Good morning';
      if (hour >= 12 && hour < 17) return 'Good afternoon';
      if (hour >= 17 && hour < 22) return 'Good evening';
      return 'Up late';
    }

    final List<String> pool;
    if (hour >= 5 && hour < 12) {
      pool = ['Morning, $name! ☀️', 'Rise & shine, $name', 'New day, $name 🌱'];
    } else if (hour >= 12 && hour < 17) {
      pool = ['Back at it, $name 💪', 'Good afternoon, $name', 'Onward, $name 🚀'];
    } else if (hour >= 17 && hour < 22) {
      pool = ['Evening, $name 🌙', 'Home stretch, $name 💪', 'Yey, $name! Keep going'];
    } else {
      pool = ['Up late, $name? 🦉', 'Night owl mode, $name 🦉'];
    }
    return pool[(now.day + now.month) % pool.length];
  }

  Future<void> _maybeStreakPopup() async {
    if (!mounted) return;
    final lastOpen = await AppPrefs.getLastAppOpenDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (lastOpen != null && lastOpen.isAtSameMomentAs(today)) return;

    final db = ref.read(databaseProvider);

    // Long-gap comeback: 7+ days away gets a warm restart screen — never a
    // broken-streak popup over a graveyard of overdue tasks. The streak
    // state still settles quietly underneath.
    if (lastOpen != null && today.difference(lastOpen).inDays >= 7) {
      await StreakService.checkOnAppOpen(db);
      await AppPrefs.setLastAppOpenDate(today);
      if (!mounted) return;
      // Fresh-start framing everywhere else this session.
      setState(() => _resetPopupShownThisSession = true);
      context.push('/comeback');
      return;
    }

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
    if (_viewingToday &&
        allDone &&
        !AppPrefs.isRestingSync &&
        !_allDoneCelebrationFiredThisSession) {
      final tinyDone = doneToday
          .where((it) => it.rowState.checkedCompletion?.isTiny == true)
          .length;
      final streakDay = streak?.currentStreak ?? 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeAllDoneCelebration(doneToday.length, tinyDone, todayPoints,
            streakDay, tasks, completions);
      });
    }

    // Empty-state renders its own ADD TASK button, so hide the FAB there to
    // avoid two identical CTAs stacked on the same screen.
    final showEmptyState = _viewMode == HomeViewMode.list &&
        upNext.isEmpty &&
        doneToday.isEmpty &&
        skippedToday.isEmpty &&
        missedToday.isEmpty;

    // Rest mode: streak safe, no pings, no quests, no judgment. Owns the
    // attention slot outright while active.
    final resting = AppPrefs.isRestingSync;

    // Never-miss-twice banner (Atomic Habits). Auto-hides reactively the
    // moment a real completion lands today (the completions stream re-emits).
    // One-attention-slot policy: the live timer banner outranks it.
    final timerRunning =
        ref.watch(activeTimerProvider).valueOrNull != null;
    final showNmtBanner = !resting &&
        !timerRunning &&
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
    final coachEligible = !resting &&
        !timerRunning &&
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
            icon: const Icon(Icons.bolt_rounded),
            tooltip: 'Quick capture',
            onPressed: () => showQuickCaptureSheet(context),
          ),
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
          _ViewToggle(
            value: _viewMode,
            onChanged: _switchView,
            viewingToday: _viewingToday,
            onPickDate: _pickViewDate,
            gcalShown: _viewMode == HomeViewMode.timeline &&
                    AppPrefs.gcalEnabledSync
                ? AppPrefs.gcalShowOnTimelineSync
                : null,
            onToggleGcal: () async {
              await AppPrefs.setGcalShowOnTimeline(
                  !AppPrefs.gcalShowOnTimelineSync);
              if (mounted) setState(() {});
            },
          ),
          if (!_viewingToday)
            _DateNavStrip(
              date: _viewDate,
              onPrev: () => setState(() =>
                  _viewDate = _viewDate.subtract(const Duration(days: 1))),
              onNext: () => setState(() =>
                  _viewDate = _viewDate.add(const Duration(days: 1))),
              onToday: () => setState(() => _viewDate = _todayDate),
            ),
          // The single attention-banner slot, shared by both view modes,
          // with enter/exit choreography (AnimatedSize + Switcher) so
          // banners glide in and yield instead of teleporting the list.
          // Priority: live timer > never-miss-twice > coach. Banners are
          // present-tense — hidden while reviewing a past day.
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(
                          begin: const Offset(0, -0.15), end: Offset.zero)
                      .animate(anim),
                  child: child,
                ),
              ),
              child: resting
                  ? _RestBanner(
                      key: const ValueKey('slot-rest'),
                      until: AppPrefs.restModeUntilSync!,
                      onEnd: () async {
                        await AppPrefs.setRestModeUntil(null);
                        await NotificationScheduler.reschedule();
                        if (mounted) setState(() {});
                      },
                    )
                  : timerRunning
                  ? const ActiveTimerBanner(key: ValueKey('slot-timer'))
                  : (_viewingToday && showNmtBanner)
                      ? NeverMissTwiceBanner(
                          key: const ValueKey('slot-nmt'),
                          currentStreak: streak?.currentStreak ?? 0,
                          freshStartCopy: _resetPopupShownThisSession,
                          onDismiss: () async {
                            await AppPrefs
                                .setNmtDismissedDate(DateTime.now());
                            if (mounted) setState(() {});
                          },
                        )
                      : (_viewingToday && coachSuggestion != null)
                          ? _CoachBanner(
                              key: const ValueKey('slot-coach'),
                              suggestion: coachSuggestion,
                              onTap: () => showTaskFormSheet(context,
                                  milestoneId:
                                      coachSuggestion.task.milestoneId,
                                  task: coachSuggestion.task),
                              onDismiss: () async {
                                await AppPrefs
                                    .setCoachDismissedDate(DateTime.now());
                                if (mounted) setState(() {});
                              },
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('slot-none')),
            ),
          ),
          Expanded(
            child: _viewMode == HomeViewMode.timeline
                ? TimelineView(date: _viewingToday ? null : _viewDate)
                : _viewingFuture
                    ? _buildFutureDayList(tasks, milestoneById, taskById)
                    : !_viewingToday
                    ? _buildPastDayList(
                        tasks, completions, milestoneById, taskById)
                    : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
          // Staggered entrances: the page ARRIVES top-to-bottom instead of
          // appearing. StaggerIn plays once per element, so live stream
          // rebuilds never re-run the choreography.
          StaggerIn(
            index: 0,
            child: _StatsHeader(
              totalPoints: totalPoints,
              currentStreak: streak?.currentStreak ?? 0,
            ),
          ),
          // "Your week" at a glance — 7 quiet dots. One-attention-cue
          // rule: today's ring pulses ONLY when the Up-next breathe
          // invite isn't live (the invite outranks the calendar).
          StaggerIn(
            index: 1,
            child: WeekBoard(
              completions: completions,
              suppressTodayPulse: !resting &&
                  upNext.isNotEmpty &&
                  weeklyChipsFor(upNext.first.task, completions) == null,
            ),
          ),
          const SizedBox(height: 20),
          if (totalScheduled > 0 && !resting)
            StaggerIn(
              index: 2,
              child: _TodayProgressCard(
                done: doneToday.length,
                total: totalScheduled,
                pointsToday: todayPoints,
              ),
            ),
          // Daily quest — a quiet list row, deliberately NOT a banner (the
          // attention slot stays sacred). No missed state ever: an
          // incomplete quest simply becomes a different quest tomorrow.
          // Rest mode stands the quest down entirely.
          if (!resting)
            StaggerIn(
              index: 3,
              child: _QuestRow(tasks: tasks, completions: completions),
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
              // Projected finish (time-blindness aid): total remaining load
              // incl. hidden queue members, projected from right now.
              Builder(builder: (context) {
                var total = 0;
                for (final it in upNext) {
                  final queue = queueBehind(
                      it.task, childrenByAnchor, inTodaysQueue);
                  total += it.task.durationMinutes +
                      queue.fold<int>(
                          0, (s, t) => s + t.durationMinutes);
                }
                final finish =
                    DateTime.now().add(Duration(minutes: total));
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '~${formatQueueMinutes(total)} of work · done by '
                    '${TimeOfDay.fromDateTime(finish).format(context)} '
                    'if you start now',
                    style: AppTypography.caption
                        .copyWith(color: context.appTextTertiary),
                  ),
                );
              }),
              // Queue members waiting on an anchor are hidden — each tile
              // here is actionable NOW. Heads of queues show what's behind
              // them instead ("+2 in queue · ~45m").
              ...upNext.indexed.map((entry) {
                final (i, it) = entry;
                final queue =
                    queueBehind(it.task, childrenByAnchor, inTodaysQueue);
                return StaggerIn(
                  key: ValueKey(it.task.id),
                  index: 3 + i,
                  child: TaskTile(
                    task: it.task,
                    rowState: it.rowState,
                    weeklyChips: weeklyChipsFor(it.task, completions),
                    showTimerButton: true,
                    // THE next task breathes — one invite, never a
                    // chorus, and never while resting (rest mode must
                    // not nudge action).
                    breathe: i == 0 && !resting,
                    // Queue info lives on the tappable 🔗 chip (opens the
                    // queue sheet), not in the meta string.
                    queueCount: queue.length,
                    queueMinutes: queue.isEmpty
                        ? null
                        : queueTotalMinutes(it.task, queue),
                    meta: _metaForHome(
                      it.task,
                      milestoneById[it.task.milestoneId],
                      it.rowState,
                      anchorName:
                          taskById[it.task.stackedAfterTaskId]?.name,
                    ),
                  ),
                );
              }),
            ],
            if (doneToday.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionHeader('Done today'),
              ...doneToday.indexed.map((entry) => StaggerIn(
                    key: ValueKey(entry.$2.task.id),
                    index: 4 + entry.$1,
                    child: TaskTile(
                      task: entry.$2.task,
                      rowState: entry.$2.rowState,
                      weeklyChips:
                          weeklyChipsFor(entry.$2.task, completions),
                      meta: _metaForHome(
                        entry.$2.task,
                        milestoneById[entry.$2.task.milestoneId],
                        entry.$2.rowState,
                        anchorName: taskById[
                                entry.$2.task.stackedAfterTaskId]
                            ?.name,
                      ),
                    ),
                  )),
            ],
            if (missedToday.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionHeader('Missed today'),
              ...missedToday.map((it) => TaskTile(
                    key: ValueKey(it.task.id),
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
                    key: ValueKey(it.task.id),
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
    {String? anchorName}) {
  final parts = <String>[];
  if (milestone != null) parts.add(milestone.name);
  parts.add(_cadenceLabel(task));
  // Deadline pressure, quietly: a recurring task with an end date shows it.
  if (task.recurrence != TaskRecurrence.none) {
    final ends = RecurrenceRule.fromTask(task).untilLabel;
    if (ends != null) parts.add('ends $ends');
  }
  parts.add('${task.pointsPerCompletion} pts');
  if (anchorName != null) {
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
              // Designer Lottie flame when the asset is bundled; falls
              // back to the code-drawn LivingFlame otherwise.
              StreakFlame(streak: currentStreak, size: 30),
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
          SpringProgressBar(
            value: progress,
            color: allDone ? AppColors.streakOrange : AppColors.primary,
            backgroundColor: context.appBorder.withValues(alpha: 0.3),
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

/// Daily quest + weekly chest row (gamification_plan.md §4, Session 3).
/// A quiet list row — never a banner. De-fanged: satisfiable by the day's
/// existing plan, no missed state, never references the streak.
class _QuestRow extends ConsumerStatefulWidget {
  final List<Task> tasks;
  final List<TaskCompletion> completions;
  const _QuestRow({required this.tasks, required this.completions});

  @override
  ConsumerState<_QuestRow> createState() => _QuestRowState();
}

class _QuestRowState extends ConsumerState<_QuestRow> {
  QuestStatus? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_QuestRow old) {
    super.didUpdateWidget(old);
    _load(); // cheap SharedPrefs read; refreshes as the streams re-emit
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final s =
        await QuestService.today(db, widget.tasks, widget.completions);
    if (mounted) setState(() => _status = s);
  }

  Future<void> _openChest() async {
    final db = ref.read(databaseProvider);
    final reward = await QuestService.claimChest(db);
    if (reward == null || !mounted) return;
    SoundService.play(AppSound.chest);
    await showCelebrationDialog(
      context,
      emoji: '🎁',
      title: 'CHEST OPENED!',
      subtitle: '+${reward.points} pts',
      body: reward.cosmetic == null
          ? 'Five quests this week. Rhythm looks good on you.'
          : 'Unlocked: ${reward.cosmetic!.emoji} ${reward.cosmetic!.name}',
      titleColor: AppColors.rewardsGold,
      style: ConfettiStyle.goldStars,
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    if (s == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          // Chest ready = the card glows gold; the week has a finish line.
          color: s.chestReady
              ? AppColors.rewardsGold.withValues(alpha: 0.10)
              : context.appPageBackground,
          borderRadius: BorderRadius.circular(16),
          border: s.chestReady
              ? Border.all(
                  color: AppColors.rewardsGold.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          children: [
            Text(s.done ? '🎯' : s.quest.emoji,
                style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.done
                        ? 'Quest done · +${s.quest.bonus} pts'
                        : s.quest.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: s.done
                          ? AppColors.primary
                          : context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (!s.done && s.quest.target > 1) ...[
                        SizedBox(
                          width: 90,
                          child: SpringProgressBar(
                            value: s.progress / s.quest.target,
                            height: 6,
                            color: AppColors.primary,
                            backgroundColor:
                                context.appBorder.withValues(alpha: 0.4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${s.progress}/${s.quest.target}',
                            style: AppTypography.caption.copyWith(
                                color: context.appTextSecondary)),
                        const SizedBox(width: 10),
                      ] else if (!s.done) ...[
                        Text('+${s.quest.bonus} pts',
                            style: AppTypography.caption.copyWith(
                                color: context.appTextSecondary)),
                        const SizedBox(width: 10),
                      ],
                      // Weekly chain: 5 dots toward the chest. No red, ever.
                      for (var i = 0;
                          i < QuestService.chestChainTarget;
                          i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < s.weekCount
                                  ? AppColors.rewardsGold
                                  : context.appBorder
                                      .withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (s.chestReady)
              TextButton(
                onPressed: _openChest,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The chest won't sit still — it's ready.
                    TweenAnimationBuilder<double>(
                      key: const ValueKey('chest-wiggle'),
                      tween: Tween(begin: -0.09, end: 0.09),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      builder: (_, v, child) =>
                          Transform.rotate(angle: v, child: child),
                      child: const Text('🎁',
                          style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 4),
                    const Text('OPEN'),
                  ],
                ),
              )
            else if (s.done)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 20),
          ],
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
    super.key,
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
          // Zen greets the blank page (falls back to the sunrise when the
          // mascot is toggled off).
          if (AppPrefs.zenEnabledSync)
            ZenSpark(
              mood: ZenMood.idle,
              streak: 1,
              size: 72,
              line: hasMilestones ? "What's today's win?" : "Let's go!",
            )
          else
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
  final bool viewingToday;
  final VoidCallback onPickDate;

  /// Google Calendar overlay eye-toggle — only rendered on the timeline
  /// view when a calendar is connected. Null = hidden.
  final bool? gcalShown;
  final VoidCallback? onToggleGcal;

  const _ViewToggle({
    required this.value,
    required this.onChanged,
    required this.viewingToday,
    required this.onPickDate,
    this.gcalShown,
    this.onToggleGcal,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<HomeViewMode>(
              // expandedInsets makes each segment fill an equal share of the
              // available width — otherwise SegmentedButton sizes segments to
              // their content and "Timeline" wraps to two lines.
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
          ),
          if (gcalShown != null)
            IconButton(
              icon: Icon(
                gcalShown!
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: gcalShown!
                    ? AppColors.infoBlue
                    : context.appTextTertiary,
              ),
              tooltip: gcalShown!
                  ? 'Hide Google Calendar'
                  : 'Show Google Calendar',
              onPressed: onToggleGcal,
            ),
          IconButton(
            icon: Icon(
              Icons.calendar_month_rounded,
              color: viewingToday
                  ? context.appTextSecondary
                  : AppColors.primary,
            ),
            tooltip: 'View another day',
            onPressed: onPickDate,
          ),
        ],
      ),
    );
  }
}

/// Rest-mode banner — owns the attention slot while active. Calm copy,
/// zero pressure, one exit.
class _RestBanner extends StatelessWidget {
  final DateTime until;
  final Future<void> Function() onEnd;

  const _RestBanner({super.key, required this.until, required this.onEnd});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.infoBlue.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          // Zen meditates through rest mode — serene, never moping.
          if (AppPrefs.zenEnabledSync)
            const ZenSpark(mood: ZenMood.sleepy, streak: 1, size: 40)
          else
            const Text('😴', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rest mode · until ${DateFormat.MMMd().format(until)}',
                  style: AppTypography.body
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Streak safe · no pings · no quests. Recovery is training.',
                  style: AppTypography.caption
                      .copyWith(color: context.appTextSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onEnd,
            child: const Text('END NOW'),
          ),
        ],
      ),
    );
  }
}

/// Thin day-stepper shown while reviewing a past date.
class _DateNavStrip extends StatelessWidget {
  final DateTime date;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _DateNavStrip({
    required this.date,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            visualDensity: VisualDensity.compact,
            onPressed: onPrev,
          ),
          Expanded(
            child: Text(
              DateFormat('EEE, MMM d').format(date),
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w800,
                color: context.appTextPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            visualDensity: VisualDensity.compact,
            onPressed: onNext,
          ),
          TextButton(
            onPressed: onToday,
            child: const Text('TODAY'),
          ),
        ],
      ),
    );
  }
}

/// Static row on the past-day record — deliberately non-interactive.
class _ReviewRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String meta;

  const _ReviewRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.meta,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body),
                  Text(meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption
                          .copyWith(color: context.appTextSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
