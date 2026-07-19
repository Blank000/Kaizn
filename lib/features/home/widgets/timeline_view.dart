import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/services/app_event_bus.dart';
import '../../../core/services/streak_service.dart';
import '../../../core/services/task_completion_service.dart';
import '../../../core/services/timer_service.dart';
import '../../../shared/widgets/stop_timer_sheet.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_colors.dart';
import '../../../shared/models/recurrence_rule.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../shared/widgets/achievement_snackbar.dart';
import '../../../shared/widgets/reward_unlock_snackbar.dart';
import '../../../shared/widgets/task_tile.dart'
    show TaskRowState, taskRowStateFor;

const double _pxPerMinute = 1.0;
const double _hourLabelWidth = 56;
const double _gridTopPadding = 8;
const double _gridBottomPadding = 24;
const double _totalGridHeight = 24 * 60 * _pxPerMinute;
const int _snapMin = 15;
const int _minDurationMin = 15;
const int _maxDurationMin = 480;
const double _resizeHandleHeight = 14;
const double _minResizableCardHeight = 40;

class TimelineView extends ConsumerStatefulWidget {
  const TimelineView({super.key});

  @override
  ConsumerState<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends ConsumerState<TimelineView> {
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _gridKey = GlobalKey();
  Timer? _nowTicker;
  DateTime _now = DateTime.now();
  bool _autoScrolled = false;

  // Active resize gesture (single task at a time).
  String? _resizeTaskId;
  int? _resizeOriginalMin;
  double _resizeDeltaPx = 0;

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
    if (_autoScrolled || !_scrollCtrl.hasClients) return;
    _autoScrolled = true;
    final nowMin = _now.hour * 60 + _now.minute;
    final target = (nowMin - 60) * _pxPerMinute;
    _scrollCtrl.jumpTo(
        target.clamp(0.0, _scrollCtrl.position.maxScrollExtent));
  }

  Future<void> _scheduleTask(Task task, Offset globalDropOffset) async {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalDropOffset);
    final rawMin = ((local.dy - _gridTopPadding) / _pxPerMinute).round();
    final snapped = (rawMin / _snapMin).round() * _snapMin;
    final clamped = snapped.clamp(0, 24 * 60 - task.durationMinutes);
    final db = ref.read(databaseProvider);
    await db.setTaskStartMinute(task.id, clamped);
    HapticFeedback.lightImpact();
  }

  Future<void> _unscheduleTask(Task task) async {
    if (task.startMinute == null) return;
    final db = ref.read(databaseProvider);
    await db.setTaskStartMinute(task.id, null);
    HapticFeedback.lightImpact();
  }

  void _onResizeStart(Task task) {
    setState(() {
      _resizeTaskId = task.id;
      _resizeOriginalMin = task.durationMinutes;
      _resizeDeltaPx = 0;
    });
    HapticFeedback.selectionClick();
  }

  void _onResizeUpdate(double dy) {
    setState(() => _resizeDeltaPx += dy);
  }

  Future<void> _onResizeEnd() async {
    final taskId = _resizeTaskId;
    final originalMin = _resizeOriginalMin;
    final deltaPx = _resizeDeltaPx;
    setState(() {
      _resizeTaskId = null;
      _resizeOriginalMin = null;
      _resizeDeltaPx = 0;
    });
    if (taskId == null || originalMin == null) return;
    final deltaMin = (deltaPx / _pxPerMinute).round();
    final rawDuration = originalMin + deltaMin;
    final snapped = (rawDuration / _snapMin).round() * _snapMin;
    final clamped = snapped.clamp(_minDurationMin, _maxDurationMin);
    if (clamped == originalMin) return;
    final db = ref.read(databaseProvider);
    await db.setTaskDurationMinutes(taskId, clamped);
    HapticFeedback.lightImpact();
  }

  int _effectiveDuration(Task task) {
    if (_resizeTaskId == task.id && _resizeOriginalMin != null) {
      final deltaMin = (_resizeDeltaPx / _pxPerMinute).round();
      return (_resizeOriginalMin! + deltaMin)
          .clamp(_minDurationMin, _maxDurationMin);
    }
    return task.durationMinutes;
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
        // Anytime tray is always rendered so it can accept "drag-to-unschedule"
        // even when there are currently no untimed tasks.
        _AnytimeTray(
          entries: anytime,
          onAccept: _unscheduleTask,
        ),
        Expanded(
          child: _TimeGrid(
            scheduled: scheduled,
            now: _now,
            scrollCtrl: _scrollCtrl,
            gridKey: _gridKey,
            resizeTaskId: _resizeTaskId,
            effectiveDuration: _effectiveDuration,
            onTaskDrop: _scheduleTask,
            onResizeStart: _onResizeStart,
            onResizeUpdate: _onResizeUpdate,
            onResizeEnd: _onResizeEnd,
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
  final Future<void> Function(Task task) onAccept;
  const _AnytimeTray({required this.entries, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    return DragTarget<Task>(
      onWillAcceptWithDetails: (d) => d.data.startMinute != null,
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (context, candidate, rejected) {
        final highlighted = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: highlighted
                ? AppColors.primary.withValues(alpha: 0.12)
                : context.appPageBackground,
            border: Border(
              bottom: BorderSide(
                color: highlighted
                    ? AppColors.primary
                    : context.appBorder,
                width: highlighted ? 2 : 1,
              ),
            ),
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
                  Text(
                    highlighted
                        ? 'DROP TO UNSCHEDULE'
                        : 'ANYTIME · ${entries.length}',
                    style: AppTypography.caption.copyWith(
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      color: highlighted
                          ? AppColors.primary
                          : context.appTextSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: entries.isEmpty
                    ? _EmptyTrayHint(highlighted: highlighted)
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: entries.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (_, i) =>
                            _AnytimeChip(entry: entries[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyTrayHint extends StatelessWidget {
  final bool highlighted;
  const _EmptyTrayHint({required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        highlighted
            ? 'Release to remove its time'
            : 'No untimed tasks. Drag one here to unschedule.',
        style: AppTypography.caption.copyWith(
          color: context.appTextTertiary,
          fontStyle: FontStyle.italic,
        ),
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
    final body = _AnytimeChipBody(entry: entry, isChecked: isChecked);

    return LongPressDraggable<Task>(
      data: entry.task,
      hapticFeedbackOnStart: true,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.85,
          child: _AnytimeChipBody(entry: entry, isChecked: isChecked),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: body),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _toggleTask(context, ref, entry),
        child: body,
      ),
    );
  }
}

class _AnytimeChipBody extends StatelessWidget {
  final _TimelineEntry entry;
  final bool isChecked;
  const _AnytimeChipBody({required this.entry, required this.isChecked});

  @override
  Widget build(BuildContext context) {
    return Container(
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
        mainAxisSize: MainAxisSize.min,
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
    );
  }
}

// ── Time grid ──────────────────────────────────────────────────────────────

class _TimeGrid extends StatelessWidget {
  final List<_TimelineEntry> scheduled;
  final DateTime now;
  final ScrollController scrollCtrl;
  final GlobalKey gridKey;
  final String? resizeTaskId;
  final int Function(Task task) effectiveDuration;
  final Future<void> Function(Task task, Offset globalDrop) onTaskDrop;
  final void Function(Task task) onResizeStart;
  final void Function(double dy) onResizeUpdate;
  final Future<void> Function() onResizeEnd;

  const _TimeGrid({
    required this.scheduled,
    required this.now,
    required this.scrollCtrl,
    required this.gridKey,
    required this.resizeTaskId,
    required this.effectiveDuration,
    required this.onTaskDrop,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final nowMin = now.hour * 60 + now.minute;
    return SingleChildScrollView(
      controller: scrollCtrl,
      child: SizedBox(
        height: _totalGridHeight + _gridTopPadding + _gridBottomPadding,
        child: DragTarget<Task>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (d) => onTaskDrop(d.data, d.offset),
          builder: (context, candidate, rejected) {
            return Stack(
              key: gridKey,
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HourLinesPainter(
                      textStyle: AppTypography.caption.copyWith(
                        color: context.appTextSecondary,
                        fontSize: 11,
                      ),
                      lineColor:
                          context.appBorder.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                for (final e in scheduled)
                  Positioned(
                    left: _hourLabelWidth,
                    right: 12,
                    top: _gridTopPadding +
                        (e.task.startMinute ?? 0) * _pxPerMinute,
                    // 32 fits one line of the task name comfortably; the card
                    // itself drops the time-range subtitle if it's still too
                    // short for both lines.
                    height: (effectiveDuration(e.task) * _pxPerMinute)
                        .clamp(32.0, double.infinity),
                    child: _TimelineTaskCard(
                      entry: e,
                      isResizing: resizeTaskId == e.task.id,
                      effectiveDurationMinutes: effectiveDuration(e.task),
                      onResizeStart: () => onResizeStart(e.task),
                      onResizeUpdate: onResizeUpdate,
                      onResizeEnd: onResizeEnd,
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 12,
                  top: _gridTopPadding + nowMin * _pxPerMinute - 1,
                  child: const _NowIndicator(),
                ),
              ],
            );
          },
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

class _TimelineTaskCard extends ConsumerWidget {
  final _TimelineEntry entry;
  final bool isResizing;
  final int effectiveDurationMinutes;
  final VoidCallback onResizeStart;
  final void Function(double dy) onResizeUpdate;
  final Future<void> Function() onResizeEnd;

  const _TimelineTaskCard({
    required this.entry,
    required this.isResizing,
    required this.effectiveDurationMinutes,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
  });

  Task get task => entry.task;
  TaskRowState get rowState => entry.rowState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = constraints.maxHeight;
        final canShowHandle = cardHeight >= _minResizableCardHeight;

        final surface = _CardSurface(
          entry: entry,
          isResizing: isResizing,
          effectiveDurationMinutes: effectiveDurationMinutes,
        );

        return LongPressDraggable<Task>(
          data: task,
          hapticFeedbackOnStart: true,
          feedback: Material(
            color: Colors.transparent,
            elevation: 8,
            child: SizedBox(
              width: constraints.maxWidth,
              height: cardHeight,
              child: Opacity(
                opacity: 0.92,
                child: _CardSurface(
                  entry: entry,
                  isResizing: false,
                  effectiveDurationMinutes: effectiveDurationMinutes,
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.25, child: surface),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleTask(context, ref, entry),
            onLongPress: rowState.isUnchecked
                ? () => _showSkipMissedSheet(
                      context,
                      taskName: task.name,
                      onTimer: () => _handleTimerAction(context, ref, task),
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
                    )
                : null,
            child: Stack(
              children: [
                surface,
                if (canShowHandle)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _resizeHandleHeight,
                    child: _ResizeHandle(
                      onStart: () => onResizeStart(),
                      onUpdate: onResizeUpdate,
                      onEnd: onResizeEnd,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CardSurface extends StatelessWidget {
  final _TimelineEntry entry;
  final bool isResizing;
  final int effectiveDurationMinutes;
  const _CardSurface({
    required this.entry,
    required this.isResizing,
    required this.effectiveDurationMinutes,
  });

  Task get task => entry.task;
  TaskRowState get rowState => entry.rowState;

  Color _accent(BuildContext context) {
    if (rowState.isChecked) return AppColors.primary;
    if (rowState.isMissed) return Colors.red.shade400;
    if (rowState.isSkipped) return context.appTextTertiary;
    final mi = entry.milestone;
    if (mi != null) return AppColors.milestoneColor(mi.colorIndex);
    return AppColors.primary;
  }

  Color _bg(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    final bg = _bg(context);
    final start = task.startMinute ?? 0;
    final timeRange =
        '${_fmt(start)} – ${_fmt(start + effectiveDurationMinutes)}';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: accent, width: 4)),
        boxShadow: isResizing
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.25),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Body line ≈ 19.5px + caption ≈ 15.4px + padding 8 = ~43px minimum
          // to render both lines without an overflow warning. Below that,
          // render just the name.
          final showTimeRange = constraints.maxHeight >= 44;
          return ClipRect(
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
                if (showTimeRange)
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
          );
        },
      ),
    );
  }

  String _fmt(int min) {
    final wrapped = min % (24 * 60);
    final h = wrapped ~/ 60;
    final m = wrapped % 60;
    final hh = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final ampm = h < 12 ? 'AM' : 'PM';
    final mm = m.toString().padLeft(2, '0');
    return '$hh:$mm $ampm';
  }
}

class _ResizeHandle extends StatelessWidget {
  final VoidCallback onStart;
  final void Function(double dy) onUpdate;
  final Future<void> Function() onEnd;
  const _ResizeHandle({
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) => onStart(),
        onVerticalDragUpdate: (d) => onUpdate(d.delta.dy),
        onVerticalDragEnd: (_) => onEnd(),
        onVerticalDragCancel: () => onEnd(),
        child: Align(
          alignment: Alignment.center,
          child: Container(
            width: 28,
            height: 4,
            decoration: BoxDecoration(
              color: context.appTextTertiary.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared toggle (used by chips + cards) ──────────────────────────────────

Future<void> _toggleTask(
    BuildContext context, WidgetRef ref, _TimelineEntry entry) async {
  final task = entry.task;
  final state = entry.rowState;
  final db = ref.read(databaseProvider);

  // Locked-completion policy on Home / Timeline: tapping an already-completed
  // tile is a no-op. Recovery is via the 6s UNDO snackbar or Milestone Detail.
  if (state.isChecked || state.isMissed || state.isSkipped) {
    HapticFeedback.selectionClick();
    return;
  }

  final result = await TaskCompletionService.completeToday(db, task);
  HapticFeedback.mediumImpact();

  if (context.mounted && result.hasCelebration) {
    showAchievementSnackbar(
        context, [...result.completionBadges, ...result.streakBadges]);
    showRewardUnlockSnackbar(context, result.unlockedRewards);
  } else {
    // Global bus — safe even if this card was disposed by the completion
    // (one-shots leave the active list immediately).
    AppEventBus.post(TaskActionEvent(
      kind: TaskActionKind.done,
      taskId: task.id,
      taskName: task.name,
      points: result.basePoints,
      clutchBonus: result.clutchBonus,
      durationSeconds: result.attachedDurationSeconds,
      nextStackedTaskName: result.stackedNext.firstOrNull?.name,
      identityLine: result.identityLine,
      undoCompletionId: result.completionId,
    ));
  }
}

// ── Timer action (start / stop / conflict) ─────────────────────────────────

Future<void> _handleTimerAction(
    BuildContext context, WidgetRef ref, Task task) async {
  final current = TimerService.current;
  if (current?.taskId == task.id) {
    if (context.mounted) await showStopTimerSheet(context, ref);
  } else if (current != null) {
    if (context.mounted) {
      await showTimerConflictDialog(context, ref, newTask: task);
    }
  } else {
    await TimerService.start(task.id);
    HapticFeedback.lightImpact();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("⏱ Timer on! Go get '${task.name}'."),
      ));
    }
  }
}

// ── Skip/missed sheet (small duplicate of task_tile's; OK for now) ─────────

void _showSkipMissedSheet(
  BuildContext context, {
  required String taskName,
  required Future<void> Function() onTimer,
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
                icon: Icons.timer_rounded,
                iconColor: AppColors.primary,
                title: 'Start timer',
                subtitle: 'Time this session. Stop anytime from Home.',
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await onTimer();
                },
              ),
              const SizedBox(height: 12),
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
