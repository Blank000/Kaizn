import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/services/achievement_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';
import '../../shared/providers/database_provider.dart';
import '../../shared/widgets/animated_number.dart';

/// Local state provider for the heatmap month/year toggle.
final _heatmapYearModeProvider = StateProvider<bool>((ref) => false);

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  static const _trendDays = 30;
  // Heatmap defaults to current month only; "View year" toggle expands to 12.
  static const _heatmapDays = 380;
  static const _hourlyDays = 90;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lifetimePoints =
        ref.watch(lifetimeEarnedPointsProvider).valueOrNull ?? 0;
    final weekPoints = ref.watch(thisWeekPointsProvider).valueOrNull ?? 0;
    final weekCompletions =
        ref.watch(thisWeekCompletionCountProvider).valueOrNull ?? 0;
    final streak = ref.watch(currentStreakProvider).valueOrNull;
    final dailyPoints =
        ref.watch(dailyPointsLastNDaysProvider(_trendDays)).valueOrNull ??
            const <DateTime, int>{};

    final completions =
        ref.watch(recentCompletionsAllProvider).valueOrNull ?? const [];
    final allTasks = ref.watch(allTasksProvider).valueOrNull ?? const [];
    final milestones =
        ref.watch(activeMilestonesProvider).valueOrNull ?? const [];
    final hourly =
        ref.watch(completionsByHourProvider(_hourlyDays)).valueOrNull ??
            const <int, int>{};

    final taskById = {for (final t in allTasks) t.id: t};
    final milestoneById = {for (final m in milestones) m.id: m};

    final dailyBreakdown =
        _aggregateDailyBreakdown(completions, _heatmapDays);

    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));
    final thisWeekReals = completions
        .where((c) =>
            !c.isSkip &&
            !c.isNd &&
            !c.completedOn.isBefore(monday) &&
            c.completedOn.isBefore(nextMonday))
        .toList();
    final topTasks =
        _computeTopTasks(thisWeekReals, taskById, milestoneById, limit: 5);
    final milestoneStats =
        _computeMilestoneStats(thisWeekReals, taskById, milestones);

    return Scaffold(
      appBar: AppBar(
        title: Text('Stats', style: AppTypography.heading1),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LifetimeCard(
            points: lifetimePoints,
            longestStreak: streak?.longestStreak ?? 0,
          ),
          const SizedBox(height: 20),
          _SectionLabel('This week'),
          const SizedBox(height: 8),
          _ThisWeekCard(
            points: weekPoints,
            completions: weekCompletions,
          ),
          const SizedBox(height: 20),
          const _AchievementsEntry(),
          const SizedBox(height: 20),
          _SectionLabel('Daily points · Last $_trendDays days'),
          const SizedBox(height: 8),
          _DailyPointsCard(data: dailyPoints, days: _trendDays),
          const SizedBox(height: 20),
          _HeatmapHeader(
            yearMode: ref.watch(_heatmapYearModeProvider),
            onToggle: () {
              final n = ref.read(_heatmapYearModeProvider.notifier);
              n.state = !n.state;
            },
          ),
          const SizedBox(height: 8),
          if (ref.watch(_heatmapYearModeProvider))
            _YearOverviewCard(
              breakdown: dailyBreakdown,
              onCellTap: (date) => _showDayDetail(
                  context, date, completions, taskById, milestoneById),
            )
          else
            _MonthlyHeatmapCard(
              breakdown: dailyBreakdown,
              monthCount: 1,
              onCellTap: (date) => _showDayDetail(
                  context, date, completions, taskById, milestoneById),
            ),
          if (topTasks.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionLabel('Top tasks · This week'),
            const SizedBox(height: 8),
            _TopTasksCard(items: topTasks),
          ],
          if (milestoneStats.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionLabel('By milestone · This week'),
            const SizedBox(height: 8),
            _MilestoneBreakdownCard(items: milestoneStats),
          ],
          if (hourly.values.any((v) => v > 0)) ...[
            const SizedBox(height: 20),
            _SectionLabel('Time of day · Last $_hourlyDays days'),
            const SizedBox(height: 8),
            _TimeOfDayCard(data: hourly),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showDayDetail(
    BuildContext context,
    DateTime date,
    List<TaskCompletion> allCompletions,
    Map<String, Task> taskById,
    Map<String, Milestone> milestoneById,
  ) {
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (date.isAfter(today)) return; // future cells are no-op

    final dayCompletions = allCompletions.where((c) {
      final d = DateTime(c.completedOn.year, c.completedOn.month, c.completedOn.day);
      return d.isAtSameMomentAs(date);
    }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DayDetailSheet(
        date: date,
        completions: dayCompletions,
        taskById: taskById,
        milestoneById: milestoneById,
      ),
    );
  }
}

// ── Aggregation helpers ──────────────────────────────────────────────────────

class _DayBreakdown {
  final int real;
  final int skip;
  final int nd;
  const _DayBreakdown({this.real = 0, this.skip = 0, this.nd = 0});

  bool get isEmpty => real == 0 && skip == 0 && nd == 0;
}

Map<DateTime, _DayBreakdown> _aggregateDailyBreakdown(
    List<TaskCompletion> completions, int days) {
  final cutoff = DateTime.now().subtract(Duration(days: days));
  final map = <DateTime, ({int real, int skip, int nd})>{};
  for (final c in completions) {
    if (c.completedOn.isBefore(cutoff)) continue;
    final day = DateTime(c.completedOn.year, c.completedOn.month, c.completedOn.day);
    final cur = map[day] ?? (real: 0, skip: 0, nd: 0);
    if (c.isSkip) {
      map[day] = (real: cur.real, skip: cur.skip + 1, nd: cur.nd);
    } else if (c.isNd) {
      map[day] = (real: cur.real, skip: cur.skip, nd: cur.nd + 1);
    } else {
      map[day] = (real: cur.real + 1, skip: cur.skip, nd: cur.nd);
    }
  }
  return {
    for (final e in map.entries)
      e.key: _DayBreakdown(real: e.value.real, skip: e.value.skip, nd: e.value.nd),
  };
}

class _TopTaskItem {
  final Task task;
  final Milestone? milestone;
  final int count;
  _TopTaskItem(this.task, this.milestone, this.count);
}

List<_TopTaskItem> _computeTopTasks(
  List<TaskCompletion> reals,
  Map<String, Task> taskById,
  Map<String, Milestone> milestoneById, {
  required int limit,
}) {
  final byTask = <String, int>{};
  for (final c in reals) {
    byTask[c.taskId] = (byTask[c.taskId] ?? 0) + 1;
  }
  final entries = byTask.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final out = <_TopTaskItem>[];
  for (final e in entries.take(limit)) {
    final task = taskById[e.key];
    if (task == null) continue;
    final milestone = task.milestoneId != null
        ? milestoneById[task.milestoneId!]
        : null;
    out.add(_TopTaskItem(task, milestone, e.value));
  }
  return out;
}

class _MilestoneStatItem {
  final Milestone milestone;
  final int completions;
  final int points;
  _MilestoneStatItem(this.milestone, this.completions, this.points);
}

List<_MilestoneStatItem> _computeMilestoneStats(
  List<TaskCompletion> reals,
  Map<String, Task> taskById,
  List<Milestone> milestones,
) {
  final byMilestone = <String, ({int count, int points})>{};
  for (final c in reals) {
    final task = taskById[c.taskId];
    final mid = task?.milestoneId;
    if (mid == null) continue;
    final cur = byMilestone[mid] ?? (count: 0, points: 0);
    byMilestone[mid] = (
      count: cur.count + 1,
      points: cur.points + c.pointsEarned,
    );
  }
  final out = <_MilestoneStatItem>[];
  for (final m in milestones) {
    final stat = byMilestone[m.id];
    if (stat == null) continue;
    out.add(_MilestoneStatItem(m, stat.count, stat.points));
  }
  out.sort((a, b) => b.completions.compareTo(a.completions));
  return out;
}

// ── Existing widgets ────────────────────────────────────────────────────────

class _AchievementsEntry extends StatefulWidget {
  const _AchievementsEntry();

  @override
  State<_AchievementsEntry> createState() => _AchievementsEntryState();
}

class _AchievementsEntryState extends State<_AchievementsEntry> {
  late Future<List<AchievementBadge>> _future;

  @override
  void initState() {
    super.initState();
    _future = AchievementService.getAllBadges();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AchievementBadge>>(
      future: _future,
      builder: (context, snapshot) {
        final badges = snapshot.data ?? const <AchievementBadge>[];
        final unlocked = badges.where((b) => b.isUnlocked).length;
        final total = badges.length;
        return InkWell(
          onTap: () => context.go('/stats/achievements'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appCardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.appBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.rewardsGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🏅', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Achievements',
                        style: AppTypography.body
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        total == 0
                            ? 'View all badges'
                            : '$unlocked / $total unlocked',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: context.appTextSecondary),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 0),
      child: Text(
        text.toUpperCase(),
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

class _HeatmapHeader extends StatelessWidget {
  final bool yearMode;
  final VoidCallback onToggle;

  const _HeatmapHeader({required this.yearMode, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _SectionLabel(
            yearMode ? 'Activity · Last 12 months' : 'Activity · This month',
          ),
        ),
        TextButton.icon(
          onPressed: onToggle,
          icon: Icon(
            yearMode
                ? Icons.calendar_view_month_rounded
                : Icons.calendar_today_rounded,
            size: 16,
          ),
          label: Text(yearMode ? 'View month' : 'View year'),
          style: TextButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            minimumSize: const Size(0, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}

class _LifetimeCard extends StatelessWidget {
  final int points;
  final int longestStreak;

  const _LifetimeCard({required this.points, required this.longestStreak});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: context.appPageBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LIFETIME',
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800,
                      color: context.appTextSecondary,
                    )),
                const SizedBox(height: 4),
                AnimatedNumber(
                  value: points,
                  formatter: NumberFormat.decimalPattern(),
                  style: AppTypography.display
                      .copyWith(color: AppColors.primary),
                ),
                Text('points earned',
                    style: AppTypography.caption
                        .copyWith(color: context.appTextSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('BEST STREAK',
                  style: AppTypography.caption.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                    color: context.appTextSecondary,
                  )),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 4),
                  AnimatedNumber(
                    value: longestStreak,
                    style: AppTypography.heading1
                        .copyWith(color: AppColors.streakOrange),
                  ),
                ],
              ),
              Text(
                longestStreak == 1 ? 'day' : 'days',
                style: AppTypography.caption
                    .copyWith(color: context.appTextSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThisWeekCard extends StatelessWidget {
  final int points;
  final int completions;

  const _ThisWeekCard({required this.points, required this.completions});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MetricColumn(
              value: '$points',
              label: 'POINTS',
              color: AppColors.primary,
            ),
          ),
          Container(width: 1, height: 40, color: context.appBorder),
          Expanded(
            child: _MetricColumn(
              value: '$completions',
              label: completions == 1 ? 'COMPLETION' : 'COMPLETIONS',
              color: AppColors.rewardsGold,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _MetricColumn({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final intValue = int.tryParse(value);
    return Column(
      children: [
        intValue != null
            ? AnimatedNumber(
                value: intValue,
                style: AppTypography.heading1
                    .copyWith(color: color, fontSize: 28),
              )
            : Text(value,
                style: AppTypography.heading1
                    .copyWith(color: color, fontSize: 28)),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
            color: context.appTextSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Daily points bar chart ──────────────────────────────────────────────────

class _DailyPointsCard extends StatelessWidget {
  final Map<DateTime, int> data;
  final int days;

  const _DailyPointsCard({required this.data, required this.days});

  @override
  Widget build(BuildContext context) {
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final series = <_DayValue>[];
    for (int i = days - 1; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      series.add(_DayValue(day, data[day] ?? 0));
    }

    final maxPoints =
        series.map((s) => s.value).fold<int>(0, (a, b) => a > b ? a : b);

    if (maxPoints == 0) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: context.appCardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appBorder),
        ),
        alignment: Alignment.center,
        child: Text(
          'No points logged in the last $days days yet.',
          style: AppTypography.caption,
        ),
      );
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: context.appCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxPoints * 1.15).ceilToDouble(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: math.max(1, (maxPoints / 4).ceilToDouble()),
            getDrawingHorizontalLine: (_) => FlLine(
              color: context.appBorder.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: math.max(1, (maxPoints / 2).ceilToDouble()),
                getTitlesWidget: (value, _) => Text(
                  '${value.toInt()}',
                  style: AppTypography.caption.copyWith(fontSize: 10),
                ),
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: 1,
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i == 0 || i == series.length - 1 || i % 7 == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        DateFormat('M/d').format(series[i].day),
                        style: AppTypography.caption.copyWith(fontSize: 9),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          barGroups: [
            for (int i = 0; i < series.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: series[i].value.toDouble(),
                    color: AppColors.primary,
                    width: math.max(4, 280 / series.length),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DayValue {
  final DateTime day;
  final int value;
  _DayValue(this.day, this.value);
}

// ── Year overview (12 compact mini-months in a 3-col grid) ──────────────────

class _YearOverviewCard extends StatelessWidget {
  final Map<DateTime, _DayBreakdown> breakdown;
  final void Function(DateTime date) onCellTap;

  const _YearOverviewCard({
    required this.breakdown,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // 12 months chronological: 11 back through current, oldest first.
    final months = List.generate(
      12,
      (i) => DateTime(now.year, now.month - 11 + i, 1),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: months
                .map((m) => _MiniMonth(
                      month: m,
                      breakdown: breakdown,
                      onCellTap: onCellTap,
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          _HeatmapLegend(),
        ],
      ),
    );
  }
}

class _MiniMonth extends StatelessWidget {
  final DateTime month;
  final Map<DateTime, _DayBreakdown> breakdown;
  final void Function(DateTime date) onCellTap;

  const _MiniMonth({
    required this.month,
    required this.breakdown,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingEmpty = firstOfMonth.weekday - 1;
    final filled = leadingEmpty + daysInMonth;
    final rows = (filled / 7).ceil();
    final isCurrentMonth =
        month.year == today.year && month.month == today.month;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat.MMM().format(firstOfMonth).toUpperCase(),
          style: AppTypography.caption.copyWith(
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
            color: isCurrentMonth
                ? AppColors.primary
                : context.appTextSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Column(
            children: [
              for (int r = 0; r < rows; r++) ...[
                if (r > 0) const SizedBox(height: 2),
                Row(
                  children: [
                    for (int c = 0; c < 7; c++) ...[
                      if (c > 0) const SizedBox(width: 2),
                      Expanded(
                        child: _MiniCell(
                          cellIndex: r * 7 + c,
                          leadingEmpty: leadingEmpty,
                          daysInMonth: daysInMonth,
                          month: month,
                          today: today,
                          breakdown: breakdown,
                          onCellTap: onCellTap,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniCell extends StatelessWidget {
  final int cellIndex;
  final int leadingEmpty;
  final int daysInMonth;
  final DateTime month;
  final DateTime today;
  final Map<DateTime, _DayBreakdown> breakdown;
  final void Function(DateTime date) onCellTap;

  const _MiniCell({
    required this.cellIndex,
    required this.leadingEmpty,
    required this.daysInMonth,
    required this.month,
    required this.today,
    required this.breakdown,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    final dayOfMonth = cellIndex - leadingEmpty + 1;
    if (dayOfMonth < 1 || dayOfMonth > daysInMonth) {
      return const AspectRatio(aspectRatio: 1, child: SizedBox.shrink());
    }
    final date = DateTime(month.year, month.month, dayOfMonth);
    final isFuture = date.isAfter(today);
    final isToday = date.isAtSameMomentAs(today);
    final dayBreakdown = breakdown[date] ?? const _DayBreakdown();
    final bg = _miniCellColor(context, isFuture, dayBreakdown);

    return AspectRatio(
      aspectRatio: 1,
      child: GestureDetector(
        onTap: isFuture ? null : () => onCellTap(date),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(2),
            border: isToday
                ? Border.all(color: AppColors.primary, width: 1)
                : null,
          ),
        ),
      ),
    );
  }

  Color _miniCellColor(
      BuildContext context, bool isFuture, _DayBreakdown b) {
    if (isFuture) return context.appPageBackground;
    if (b.real > 0) {
      if (b.real == 1) return AppColors.primary.withValues(alpha: 0.25);
      if (b.real <= 3) return AppColors.primary.withValues(alpha: 0.55);
      if (b.real <= 5) return AppColors.primary.withValues(alpha: 0.8);
      return AppColors.primary;
    }
    if (b.nd > 0) return Colors.red.shade400.withValues(alpha: 0.6);
    if (b.skip > 0) return context.appTextTertiary.withValues(alpha: 0.45);
    return context.appBorder.withValues(alpha: 0.35);
  }
}

// ── Activity heatmap (calendar-style monthly grids) ─────────────────────────

class _MonthlyHeatmapCard extends StatelessWidget {
  final Map<DateTime, _DayBreakdown> breakdown;
  final int monthCount;
  final void Function(DateTime date) onCellTap;

  const _MonthlyHeatmapCard({
    required this.breakdown,
    required this.monthCount,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Most recent month first: [thisMonth, lastMonth, twoMonthsAgo, ...]
    final months = List.generate(
      monthCount,
      (i) => DateTime(now.year, now.month - i, 1),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < months.length; i++) ...[
            if (i > 0) const SizedBox(height: 20),
            _MonthGrid(
              month: months[i],
              breakdown: breakdown,
              onCellTap: onCellTap,
            ),
          ],
          const SizedBox(height: 14),
          _HeatmapLegend(),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final Map<DateTime, _DayBreakdown> breakdown;
  final void Function(DateTime date) onCellTap;

  const _MonthGrid({
    required this.month,
    required this.breakdown,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // weekday: 1=Mon ... 7=Sun. Number of empty leading cells before day 1.
    final leadingEmpty = firstOfMonth.weekday - 1;
    final filled = leadingEmpty + daysInMonth;
    final rows = (filled / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month header
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 0, 8),
          child: Text(
            DateFormat.yMMMM().format(firstOfMonth).toUpperCase(),
            style: AppTypography.caption.copyWith(
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
              color: context.appTextSecondary,
              fontSize: 11,
            ),
          ),
        ),
        // Weekday header row (Mon..Sun)
        Row(
          children: [
            for (final letter in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      letter,
                      style: AppTypography.caption.copyWith(
                        fontSize: 9,
                        color: context.appTextTertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Day grid
        for (int row = 0; row < rows; row++) ...[
          if (row > 0) const SizedBox(height: 3),
          Row(
            children: [
              for (int col = 0; col < 7; col++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: _buildCell(
                      context,
                      cellIndex: row * 7 + col,
                      leadingEmpty: leadingEmpty,
                      daysInMonth: daysInMonth,
                      today: today,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCell(
    BuildContext context, {
    required int cellIndex,
    required int leadingEmpty,
    required int daysInMonth,
    required DateTime today,
  }) {
    final dayOfMonth = cellIndex - leadingEmpty + 1;
    if (dayOfMonth < 1 || dayOfMonth > daysInMonth) {
      return const AspectRatio(aspectRatio: 1, child: SizedBox.shrink());
    }
    final date = DateTime(month.year, month.month, dayOfMonth);
    final isFuture = date.isAfter(today);
    final isToday = date.isAtSameMomentAs(today);
    final dayBreakdown = breakdown[date] ?? const _DayBreakdown();
    final bg = _cellColor(context, isFuture: isFuture, b: dayBreakdown);
    final fg = _textColor(context, isFuture: isFuture, b: dayBreakdown);

    return AspectRatio(
      aspectRatio: 1,
      child: InkWell(
        onTap: isFuture ? null : () => onCellTap(date),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: isToday
                ? Border.all(color: AppColors.primary, width: 1.5)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '$dayOfMonth',
            style: AppTypography.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }

  Color _cellColor(BuildContext context,
      {required bool isFuture, required _DayBreakdown b}) {
    if (isFuture) return context.appPageBackground;
    if (b.real > 0) {
      if (b.real == 1) return AppColors.primary.withValues(alpha: 0.25);
      if (b.real <= 3) return AppColors.primary.withValues(alpha: 0.55);
      if (b.real <= 5) return AppColors.primary.withValues(alpha: 0.8);
      return AppColors.primary;
    }
    if (b.nd > 0) return Colors.red.shade400.withValues(alpha: 0.6);
    if (b.skip > 0) return context.appTextTertiary.withValues(alpha: 0.45);
    return context.appBorder.withValues(alpha: 0.35);
  }

  Color _textColor(BuildContext context,
      {required bool isFuture, required _DayBreakdown b}) {
    if (isFuture) return context.appTextTertiary;
    // White text on saturated cells (real >= 4, missed-only, skipped-only).
    if (b.real >= 4) return Colors.white;
    if (b.real == 0 && b.nd > 0) return Colors.white;
    if (b.real == 0 && b.skip > 0) return Colors.white;
    return context.appTextSecondary;
  }
}

class _HeatmapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        _LegendChip(
          color: AppColors.primary,
          label: 'Completed',
        ),
        _LegendChip(
          color: Colors.red.shade400.withValues(alpha: 0.55),
          label: 'Missed',
        ),
        _LegendChip(
          color: context.appTextTertiary.withValues(alpha: 0.4),
          label: 'Skipped',
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: AppTypography.caption.copyWith(fontSize: 10)),
      ],
    );
  }
}

// ── Top tasks card ──────────────────────────────────────────────────────────

class _TopTasksCard extends StatelessWidget {
  final List<_TopTaskItem> items;
  const _TopTasksCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: context.appCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: context.appBorder.withValues(alpha: 0.5),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(items[i].task.name,
                            style: AppTypography.body),
                        if (items[i].milestone != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              items[i].milestone!.name,
                              style: AppTypography.caption,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${items[i].count}×',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Milestone breakdown card ────────────────────────────────────────────────

class _MilestoneBreakdownCard extends StatelessWidget {
  final List<_MilestoneStatItem> items;
  const _MilestoneBreakdownCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: context.appCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: context.appBorder.withValues(alpha: 0.5),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.milestoneColor(
                          items[i].milestone.colorIndex),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(items[i].milestone.name,
                        style: AppTypography.body),
                  ),
                  Text(
                    '${items[i].completions} done',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '+${items[i].points} pts',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Time of day distribution ────────────────────────────────────────────────

class _TimeOfDayCard extends StatelessWidget {
  final Map<int, int> data;
  const _TimeOfDayCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxCount =
        data.values.fold<int>(0, (a, b) => a > b ? a : b);

    int? peakHour;
    int peakValue = 0;
    for (var h = 0; h < 24; h++) {
      final v = data[h] ?? 0;
      if (v > peakValue) {
        peakValue = v;
        peakHour = h;
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
      decoration: BoxDecoration(
        color: context.appCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (peakHour != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 0, 8),
              child: Text(
                'Most active around ${_formatHour(peakHour!)}',
                style: AppTypography.body
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (maxCount * 1.15).ceilToDouble(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: math.max(
                      1, (maxCount / 4).ceilToDouble()),
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: context.appBorder.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: math.max(
                          1, (maxCount / 2).ceilToDouble()),
                      getTitlesWidget: (value, _) => Text(
                        '${value.toInt()}',
                        style: AppTypography.caption
                            .copyWith(fontSize: 10),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, _) {
                        final h = value.toInt();
                        // Only label at 0, 6, 12, 18 to keep the axis clean.
                        if (h == 0 || h == 6 || h == 12 || h == 18) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _formatHourShort(h),
                              style: AppTypography.caption
                                  .copyWith(fontSize: 9),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (int h = 0; h < 24; h++)
                    BarChartGroupData(
                      x: h,
                      barRods: [
                        BarChartRodData(
                          toY: (data[h] ?? 0).toDouble(),
                          color: h == peakHour
                              ? AppColors.primary
                              : AppColors.primary
                                  .withValues(alpha: 0.5),
                          width: 8,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatHour(int h) {
  if (h == 0) return '12 AM';
  if (h == 12) return '12 PM';
  if (h < 12) return '$h AM';
  return '${h - 12} PM';
}

String _formatHourShort(int h) {
  if (h == 0) return '12a';
  if (h == 12) return '12p';
  if (h < 12) return '${h}a';
  return '${h - 12}p';
}

// ── Day detail bottom sheet ─────────────────────────────────────────────────

class _DayDetailSheet extends StatelessWidget {
  final DateTime date;
  final List<TaskCompletion> completions;
  final Map<String, Task> taskById;
  final Map<String, Milestone> milestoneById;

  const _DayDetailSheet({
    required this.date,
    required this.completions,
    required this.taskById,
    required this.milestoneById,
  });

  @override
  Widget build(BuildContext context) {
    final reals =
        completions.where((c) => !c.isSkip && !c.isNd).toList();
    final skips = completions.where((c) => c.isSkip).toList();
    final misses = completions.where((c) => c.isNd).toList();
    final pointsToday = reals.fold<int>(0, (sum, c) => sum + c.pointsEarned);

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
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('EEEE, MMM d').format(date),
                    style: AppTypography.heading2,
                  ),
                  if (pointsToday > 0)
                    Text(
                      '+$pointsToday pts',
                      style: AppTypography.body.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (reals.isEmpty && skips.isEmpty && misses.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Nothing logged this day.',
                      style: AppTypography.body
                          .copyWith(color: context.appTextSecondary),
                    ),
                  ),
                ),
              if (reals.isNotEmpty) ...[
                _DaySectionLabel('Completed', count: reals.length),
                ...reals.map((c) => _DayRow(
                      icon: Icons.check_rounded,
                      iconColor: AppColors.primary,
                      completion: c,
                      taskById: taskById,
                      milestoneById: milestoneById,
                      showPoints: true,
                    )),
                const SizedBox(height: 8),
              ],
              if (misses.isNotEmpty) ...[
                _DaySectionLabel('Missed', count: misses.length),
                ...misses.map((c) => _DayRow(
                      icon: Icons.close_rounded,
                      iconColor: Colors.red.shade400,
                      completion: c,
                      taskById: taskById,
                      milestoneById: milestoneById,
                      showPoints: false,
                    )),
                const SizedBox(height: 8),
              ],
              if (skips.isNotEmpty) ...[
                _DaySectionLabel('Skipped', count: skips.length),
                ...skips.map((c) => _DayRow(
                      icon: Icons.remove_rounded,
                      iconColor: context.appTextTertiary,
                      completion: c,
                      taskById: taskById,
                      milestoneById: milestoneById,
                      showPoints: false,
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DaySectionLabel extends StatelessWidget {
  final String label;
  final int count;
  const _DaySectionLabel(this.label, {required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
      child: Text(
        '${label.toUpperCase()} · $count',
        style: AppTypography.caption.copyWith(
          fontSize: 10,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w800,
          color: context.appTextSecondary,
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final TaskCompletion completion;
  final Map<String, Task> taskById;
  final Map<String, Milestone> milestoneById;
  final bool showPoints;

  const _DayRow({
    required this.icon,
    required this.iconColor,
    required this.completion,
    required this.taskById,
    required this.milestoneById,
    required this.showPoints,
  });

  @override
  Widget build(BuildContext context) {
    final task = taskById[completion.taskId];
    final milestone = task?.milestoneId != null
        ? milestoneById[task!.milestoneId!]
        : null;
    final taskName = task?.name ?? '(deleted task)';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(taskName, style: AppTypography.body),
                if (milestone != null)
                  Text(milestone.name,
                      style: AppTypography.caption),
              ],
            ),
          ),
          if (showPoints && completion.pointsEarned > 0)
            Text(
              '+${completion.pointsEarned}',
              style: AppTypography.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}
