import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/services/achievement_service.dart';
import '../../../core/services/streak_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_colors.dart';
import '../../../shared/models/recurrence_rule.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../shared/widgets/achievement_snackbar.dart';
import '../../../shared/widgets/reward_unlock_snackbar.dart';
import '../../../shared/widgets/task_tile.dart'
    show TaskRowState, taskRowStateFor;
import '../../rewards/reward_unlock_service.dart';

const double _pxPerMinute = 1.0; // 60 px per hour
const double _hourLabelWidth = 56;
const double _gridTopPadding = 8;
const double _gridBottomPadding = 24;
const double _totalGridHeight = 24 * 60 * _pxPerMinute;

class TimelineView extends ConsumerStatefulWidget {
  const TimelineView({super.key});

  @override
  ConsumerState<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends ConsumerState<TimelineView> {
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _nowTicker;
  DateTime _now = DateTime.now();
  bool _autoScrolled = false;

  @override
  void initState() {
    super.initState();
    _nowTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _nowTicker?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _maybeAutoScroll() {
    if (_autoScrolled) return;
    if (!_scrollCtrl.hasClients) return;
    _autoScrolled = true;
    final nowMin = _now.hour * 60 + _now.minute;
    final target = (nowMin - 60) * _pxPerMinute;
    final max = _scrollCtrl.position.maxScrollExtent;
    _scrollCtrl.jumpTo(target.clamp(0.0, max));
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(activeTasksProvider).valueOrNull ?? [];
    final completions =
        ref.watch(recentCompletionsAllProvider).valueOrNull ?? [];
    final milestones =
        ref.watch(activeMilestonesProvider).valueOrNull ?? [];
    final milestoneById = {for (final m in milestones) m.id: m};

    final scheduled = <_TimelineEntry>[];
    final anytime = <_TimelineEntry>[];

    for (final task in tasks) {
      if (!_isDueToday(task, _now)) continue;
      final rowState = taskRowStateFor(task, completions);
      final entry = _TimelineEntry(
        task: task,
        rowState: rowState,
        milestone: milestoneById[task.milestoneId],
      );
      if (task.startMinute == null) {
        anytime.add(entry);
      } else {
        scheduled.add(entry);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoScroll());

    if (scheduled.isEmpty && anytime.isEmpty) {
      return const _EmptyTimeline();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (anytime.isNotEmpty) _AnytimeTray(entries: anytime),
        Expanded(
          child: _TimeGrid(
            scheduled: scheduled,
            now: _now,
            scrollCtrl: _scrollCtrl,
          ),
        ),
      ],
    );
  }
}

bool _isDueToday(Task task, DateTime today) {
  if (task.recurrence == TaskRecurrence.none) {
    if (task.status != TaskStatus.active) return false;
    if (task.dueDate == null) return false;
    final due =
        DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
    final t = DateTime(today.year, today.month, today.day);
    return !due.isAfter(t);
  }
  return RecurrenceRule.fromTask(task).isDueOn(today);
}

class _TimelineEntry {
  final Task task;
  final TaskRowState rowState;
  final Milestone? milestone;
  _TimelineEntry({
    required this.task,
    required this.rowState,
    this.milestone,
  });
}

// ── Empty state ─────────────────────────────────────────────────────────────

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🗓️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('Nothing scheduled today', style: AppTypography.heading2),
            const SizedBox(height: 4),
            Text(
              'Add a start time to any task to see it on the timeline.',
              style: AppTypography.body
                  .copyWith(color: context.appTextSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Anytime tray ────────────────────────────────────────────────────────────

class _AnytimeTray extends StatelessWidget {
  final List<_TimelineEntry> entries;
  const _AnytimeTray({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appPageBackground,
        border: Border(bottom: BorderSide(color: context.appBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inbox_rounded,
                  size: 14, color: context.appTextSecondary),
              const SizedBox(width: 4),
              Text('ANYTIME · ${entries.length}',
                  style: AppTypography.caption.copyWith(
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    color: context.appTextSecondary,
                  )),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _AnytimeChip(entry: entries[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnytimeChip extends ConsumerWidget {
  final _TimelineEntry entry;
  const _AnytimeChip({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = entry.rowState;
    final isChecked = state.isChecked;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _toggleTask(context, ref, entry),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isChecked
              ? AppColors.primary
              : context.appCardSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isChecked ? AppColors.primary : context.appBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isChecked
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              size: 16,
              color: isChecked ? Colors.white : context.appTextSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              entry.task.name,
              style: AppTypography.caption.copyWith(
                color: isChecked ? Colors.white : context.appTextPrimary,
                fontWeight: FontWeight.w600,
                decoration:
                    isChecked ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Time grid ──────────────────────────────────────────────────────────────

class _TimeGrid extends StatelessWidget {
  final List<_TimelineEntry> scheduled;
  final DateTime now;
  final ScrollController scrollCtrl;
  const _TimeGrid({
    required this.scheduled,
    required this.now,
    required this.scrollCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final nowMin = now.hour * 60 + now.minute;
    return SingleChildScrollView(
      controller: scrollCtrl,
      child: SizedBox(
        height: _totalGridHeight + _gridTopPadding + _gridBottomPadding,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _HourLinesPainter(
                  textStyle: AppTypography.caption.copyWith(
                    color: context.appTextSecondary,
                    fontSize: 11,
                  ),
                  lineColor: context.appBorder.withValues(alpha: 0.6),
                ),
              ),
            ),
            for (final e in scheduled)
              Positioned(
                left: _hourLabelWidth,
                right: 12,
                top: _gridTopPadding +
                    (e.task.startMinute ?? 0) * _pxPerMinute,
                height: (e.task.durationMinutes * _pxPerMinute)
                    .clamp(28.0, double.infinity),
                child: _TimelineTaskCard(entry: e),
              ),
            Positioned(
              left: 0,
              right: 12,
              top: _gridTopPadding + nowMin * _pxPerMinute - 1,
              child: const _NowIndicator(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HourLinesPainter extends CustomPainter {
  final TextStyle textStyle;
  final Color lineColor;
  _HourLinesPainter({required this.textStyle, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final hourPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    final halfPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.35)
      ..strokeWidth = 0.5;
    for (var h = 0; h < 24; h++) {
      final y = _gridTopPadding + h * 60 * _pxPerMinute;
      canvas.drawLine(
        Offset(_hourLabelWidth, y),
        Offset(size.width, y),
        hourPaint,
      );
      final tp = TextPainter(
        text: TextSpan(text: _formatHour(h), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(_hourLabelWidth - tp.width - 8, y - tp.height / 2),
      );
      final hy = y + 30 * _pxPerMinute;
      if (hy < size.height) {
        canvas.drawLine(
          Offset(_hourLabelWidth, hy),
          Offset(size.width, hy),
          halfPaint,
        );
      }
    }
  }

  String _formatHour(int h) {
    if (h == 0) return '12 AM';
    if (h < 12) return '$h AM';
    if (h == 12) return '12 PM';
    return '${h - 12} PM';
  }

  @override
  bool shouldRepaint(_HourLinesPainter old) =>
      lineColor != old.lineColor || textStyle != old.textStyle;
}

class _NowIndicator extends StatelessWidget {
  const _NowIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: _hourLabelWidth,
          child: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Expanded(child: Container(height: 2, color: Colors.red)),
      ],
    );
  }
}

// ── Card ───────────────────────────────────────────────────────────────────

class _TimelineTaskCard extends ConsumerStatefulWidget {
  final _TimelineEntry entry;
  const _TimelineTaskCard({required this.entry});

  @override
  ConsumerState<_TimelineTaskCard> createState() => _TimelineTaskCardState();
}

class _TimelineTaskCardState extends ConsumerState<_TimelineTaskCard> {
  Task get task => widget.entry.task;
  TaskRowState get rowState => widget.entry.rowState;

  Future<void> _toggle() async {
    await _toggleTask(context, ref, widget.entry);
  }

  void _showActions() {
    if (!rowState.isUnchecked) return;
    _showSkipMissedSheet(
      context,
      taskName: task.name,
      onSkip: () async {
        final db = ref.read(databaseProvider);
        await db.skipTaskNow(task);
        await StreakService.recordSkipDay(db);
        HapticFeedback.lightImpact();
      },
      onMissed: () async {
        final db = ref.read(databaseProvider);
        await db.markTaskMissed(task);
        HapticFeedback.lightImpact();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = _bgColor(context);
    final accent = _accentColor(context);
    final timeRange = _formatTimeRange(task.startMinute!, task.durationMinutes);
    return GestureDetector(
      onTap: _toggle,
      onLongPress: _showActions,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                task.name,
                style: AppTypography.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: rowState.isChecked
                      ? context.appTextSecondary
                      : context.appTextPrimary,
                  decoration: rowState.isChecked
                      ? TextDecoration.lineThrough
                      : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                timeRange,
                style: AppTypography.caption.copyWith(
                  color: context.appTextSecondary,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _accentColor(BuildContext context) {
    if (rowState.isChecked) return AppColors.primary;
    if (rowState.isMissed) return Colors.red.shade400;
    if (rowState.isSkipped) return context.appTextTertiary;
    final mi = widget.entry.milestone;
    if (mi != null) return AppColors.milestoneColor(mi.colorIndex);
    return AppColors.primary;
  }

  Color _bgColor(BuildContext context) {
    if (rowState.isChecked) {
      return AppColors.primary.withValues(alpha: 0.12);
    }
    if (rowState.isMissed) {
      return Colors.red.shade400.withValues(alpha: 0.08);
    }
    if (rowState.isSkipped) {
      return context.appTextTertiary.withValues(alpha: 0.08);
    }
    return context.appCardSurface;
  }

  String _formatTimeRange(int startMin, int duration) {
    final endMin = startMin + duration;
    return '${_fmt(startMin)} – ${_fmt(endMin)}';
  }

  String _fmt(int min) {
    final h = (min ~/ 60) % 24;
    final m = min % 60;
    final hh = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final ampm = h < 12 ? 'AM' : 'PM';
    final mm = m.toString().padLeft(2, '0');
    return '$hh:$mm $ampm';
  }
}

// ── Shared toggle (used by chips + cards) ──────────────────────────────────

Future<void> _toggleTask(
    BuildContext context, WidgetRef ref, _TimelineEntry entry) async {
  final task = entry.task;
  final state = entry.rowState;
  final db = ref.read(databaseProvider);
  if (state.isChecked && state.checkedCompletion != null) {
    await db.undoCompletion(state.checkedCompletion!.id, task.id);
    HapticFeedback.lightImpact();
  } else if (state.isMissed && state.ndCompletion != null) {
    await db.undoCompletion(state.ndCompletion!.id, task.id);
    HapticFeedback.lightImpact();
  } else if (state.isSkipped && state.skipCompletion != null) {
    await db.undoCompletion(state.skipCompletion!.id, task.id);
    HapticFeedback.lightImpact();
  } else {
    await db.completeTaskNow(task);
    final streakBadges = await StreakService.recordDayLogged(db);
    final completionBadges =
        await AchievementService.checkAfterCompletion(db);
    final unlocked = await RewardUnlockService.checkAfterPointsChange(db);
    HapticFeedback.mediumImpact();
    if (context.mounted) {
      showAchievementSnackbar(
          context, [...completionBadges, ...streakBadges]);
      showRewardUnlockSnackbar(context, unlocked);
    }
  }
}

// ── Skip/missed sheet (small duplicate of task_tile's; OK for now) ─────────

void _showSkipMissedSheet(
  BuildContext context, {
  required String taskName,
  required Future<void> Function() onSkip,
  required Future<void> Function() onMissed,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        decoration: BoxDecoration(
          color: ctx.appCardSurface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ctx.appBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(taskName,
                  style: AppTypography.heading2,
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              _SheetOption(
                icon: Icons.do_not_disturb_alt_rounded,
                iconColor: ctx.appTextTertiary,
                title: 'Skip today',
                subtitle:
                    'Intentional rest. Streak preserved, no points.',
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await onSkip();
                },
              ),
              const SizedBox(height: 12),
              _SheetOption(
                icon: Icons.close_rounded,
                iconColor: Colors.red.shade400,
                title: 'Mark as missed',
                subtitle:
                    "Honest miss. Doesn't credit your streak.",
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await onMissed();
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('CANCEL'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: context.appBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTypography.caption.copyWith(
                          color: context.appTextSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
