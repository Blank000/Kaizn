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
import '../../../shared/models/task_stack.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../shared/widgets/achievement_snackbar.dart';
import '../../../shared/widgets/moment_celebrations.dart';
import '../../../shared/widgets/reward_unlock_snackbar.dart';
import '../../milestones/widgets/task_form_sheet.dart';
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
  /// Which day to render. Null = live today (now-indicator, interactive).
  /// A past date renders that day's record read-only.
  final DateTime? date;

  const TimelineView({super.key, this.date});

  @override
  ConsumerState<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends ConsumerState<TimelineView> {
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _gridKey = GlobalKey();
  final GlobalKey _viewportKey = GlobalKey();
  Timer? _nowTicker;
  DateTime _now = DateTime.now();
  bool _autoScrolled = false;

  // Active resize gesture (single task at a time).
  String? _resizeTaskId;
  int? _resizeOriginalMin;
  double _resizeDeltaPx = 0;

  // Live drag preview (Google-Calendar feel): snapped landing slot + time
  // label, rendered as an outline the card will settle into. ValueNotifier
  // so only the preview layer repaints per drag frame — never the 24h grid.
  final ValueNotifier<_DragPreview?> _dragPreview = ValueNotifier(null);

  // Edge auto-scroll while dragging near the viewport's top/bottom.
  Timer? _autoScrollTimer;
  double _autoScrollVelocity = 0;
  static const _edgeZone = 90.0;
  static const _maxScrollSpeed = 14.0; // px per 16ms tick

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
    _autoScrollTimer?.cancel();
    _dragPreview.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Snap a global drag/tap position to a grid minute (same math as the
  /// drop handler, so the preview always matches the landing slot exactly).
  int? _minuteAt(Offset globalOffset, {int snap = _snapMin}) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(globalOffset);
    final rawMin = ((local.dy - _gridTopPadding) / _pxPerMinute).round();
    return ((rawMin / snap).round() * snap).clamp(0, 24 * 60 - snap);
  }

  void _onDragMove(Task task, Offset globalOffset) {
    final snapped = _minuteAt(globalOffset);
    if (snapped == null) return;
    final clamped = snapped.clamp(0, 24 * 60 - task.durationMinutes);
    final prev = _dragPreview.value;
    if (prev == null ||
        prev.minute != clamped ||
        prev.durationMinutes != task.durationMinutes) {
      _dragPreview.value =
          _DragPreview(minute: clamped, durationMinutes: task.durationMinutes);
      // Detent tick each time the snap slot changes — mechanical-planner feel.
      HapticFeedback.selectionClick();
    }
    _maybeAutoScrollDuringDrag(globalOffset);
  }

  void _clearDragPreview() {
    _dragPreview.value = null;
    _stopAutoScroll();
  }

  void _maybeAutoScrollDuringDrag(Offset globalPos) {
    final vp = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (vp == null) return;
    final local = vp.globalToLocal(globalPos);
    double v = 0;
    if (local.dy < _edgeZone) {
      v = -_maxScrollSpeed * (1 - local.dy / _edgeZone).clamp(0.0, 1.0);
    } else if (local.dy > vp.size.height - _edgeZone) {
      v = _maxScrollSpeed *
          (1 - (vp.size.height - local.dy) / _edgeZone).clamp(0.0, 1.0);
    }
    _autoScrollVelocity = v;
    if (v != 0 && _autoScrollTimer == null) {
      _autoScrollTimer =
          Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (_autoScrollVelocity == 0 || !_scrollCtrl.hasClients) {
          _stopAutoScroll();
          return;
        }
        _scrollCtrl.jumpTo((_scrollCtrl.offset + _autoScrollVelocity)
            .clamp(0.0, _scrollCtrl.position.maxScrollExtent));
      });
    } else if (v == 0) {
      _stopAutoScroll();
    }
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _autoScrollVelocity = 0;
  }

  /// Tap-to-create (GCal): tap an empty slot → new-task form with that time
  /// pre-filled. 30-min snap for creation — cleaner default blocks.
  void _createTaskAt(Offset globalOffset) {
    final minute = _minuteAt(globalOffset, snap: 30);
    if (minute == null) return;
    showTaskFormSheet(
      context,
      initialStartTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    );
  }

  @override
  void didUpdateWidget(TimelineView old) {
    super.didUpdateWidget(old);
    // Re-run the initial scroll when the viewed date changes.
    if (old.date != widget.date) _autoScrolled = false;
  }

  void _maybeAutoScroll(int anchorMinute) {
    if (_autoScrolled || !_scrollCtrl.hasClients) return;
    _autoScrolled = true;
    final target = (anchorMinute - 60) * _pxPerMinute;
    _scrollCtrl.jumpTo(
        target.clamp(0.0, _scrollCtrl.position.maxScrollExtent));
  }

  Future<void> _scheduleTask(Task task, Offset globalDropOffset) async {
    _clearDragPreview();
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalDropOffset);
    final rawMin = ((local.dy - _gridTopPadding) / _pxPerMinute).round();
    final snapped = (rawMin / _snapMin).round() * _snapMin;
    final clamped = snapped.clamp(0, 24 * 60 - task.durationMinutes);

    // Unified long-press grammar: lift-and-MOVE reschedules; lift-and-
    // RELEASE-IN-PLACE (same snapped slot) opens the action menu instead —
    // one gesture, two natural outcomes, no per-state gesture conflicts.
    if (clamped == task.startMinute) {
      final completions =
          ref.read(recentCompletionsAllProvider).valueOrNull ??
              const <TaskCompletion>[];
      final state = taskRowStateFor(task, completions);
      if (state.isUnchecked && mounted) {
        _showSkipMissedSheet(
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
        );
      }
      return;
    }

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
    // All non-archived tasks — a one-shot completed today must stay on the
    // timeline crossed-out for the rest of the day (the day's record),
    // exactly like Home's "Done today".
    final tasks = ref.watch(allTasksProvider).valueOrNull ?? [];
    final completions =
        ref.watch(recentCompletionsAllProvider).valueOrNull ?? [];
    final milestones =
        ref.watch(activeMilestonesProvider).valueOrNull ?? [];
    final milestoneById = {for (final m in milestones) m.id: m};

    final taskById = {for (final t in tasks) t.id: t};
    final childrenByAnchor = stackChildrenByAnchor(tasks);

    final today = DateTime(_now.year, _now.month, _now.day);
    final day = widget.date == null
        ? today
        : DateTime(
            widget.date!.year, widget.date!.month, widget.date!.day);
    final isToday = day.isAtSameMomentAs(today);

    bool hasCompletionToday(String taskId) => completions.any((c) =>
        c.taskId == taskId &&
        c.completedOn.year == day.year &&
        c.completedOn.month == day.month &&
        c.completedOn.day == day.day);

    // "Due today" in the loose sense queues care about: scheduled today per
    // recurrence, OR an undated active one-shot (those surface daily).
    bool dueTodayLoose(Task t) =>
        _isDueToday(t, day) ||
        (t.recurrence == TaskRecurrence.none &&
            t.status == TaskStatus.active &&
            t.dueDate == null);

    // Queue member of today's chain: due today and not yet resolved.
    bool inTodaysQueue(Task c) {
      if (hasCompletionToday(c.id)) return false;
      return dueTodayLoose(c);
    }

    // Waiting queue members are represented inside their anchor's merged
    // block — keep them out of the Anytime tray.
    bool waitingOnAnchor(Task t) {
      if (!isQueueMember(t)) return false;
      final anchor = taskById[t.stackedAfterTaskId];
      if (anchor == null) return false;
      if (!dueTodayLoose(anchor)) return false;
      return !hasCompletionToday(anchor.id);
    }

    final scheduled = <_TimelineEntry>[];
    final anytime = <_TimelineEntry>[];

    for (final task in tasks) {
      // Undated active one-shots surface daily (parity with Home; live day
      // only — for past days, only what was actually due or logged shows).
      final undatedActiveOneShot = task.recurrence == TaskRecurrence.none &&
          task.status == TaskStatus.active &&
          task.dueDate == null;
      // Anything with a completion row on the viewed day belongs on that
      // day's record (incl. one-shots finished that day, crossed out).
      final loggedOnDay = hasCompletionToday(task.id);
      if (!_isDueToday(task, day) &&
          !loggedOnDay &&
          !(isToday && undatedActiveOneShot)) {
        continue;
      }
      // Live day uses rule-period semantics; past days show exactly what
      // was logged on that date.
      final rowState = isToday
          ? taskRowStateFor(task, completions)
          : _rowStateOn(task, completions, day);
      final queue = (isToday && task.startMinute != null)
          ? queueBehind(task, childrenByAnchor, inTodaysQueue)
          : const <Task>[];
      final entry = _TimelineEntry(
        task: task,
        rowState: rowState,
        milestone: milestoneById[task.milestoneId],
        queueCount: queue.length,
        queueExtraMinutes:
            queue.fold<int>(0, (sum, t) => sum + t.durationMinutes),
      );
      if (task.startMinute == null) {
        if (!isToday || !waitingOnAnchor(task)) anytime.add(entry);
      } else {
        scheduled.add(entry);
      }
    }

    // Live day scrolls to "now"; a past day scrolls to its first scheduled
    // block (or 8 AM when the day had none).
    final scrollAnchor = isToday
        ? _now.hour * 60 + _now.minute
        : scheduled
                .map((e) => e.task.startMinute ?? 8 * 60)
                .fold<int?>(null, (m, v) => m == null || v < m ? v : m) ??
            8 * 60;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeAutoScroll(scrollAnchor));

    if (scheduled.isEmpty && anytime.isEmpty) {
      return const _EmptyTimeline();
    }

    // Past days are a read-only record — scrolling stays, but no drag,
    // resize, toggle, or long-press (readOnly threads down to cards/chips).
    // Deliberate retro-logging lives in the weekly chips on the list view.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Anytime tray is always rendered so it can accept
        // "drag-to-unschedule" even when there are no untimed tasks.
        _AnytimeTray(
          entries: anytime,
          readOnly: !isToday,
          onAccept: _unscheduleTask,
        ),
        Expanded(
          child: _TimeGrid(
            scheduled: scheduled,
            now: _now,
            showNowIndicator: isToday,
            readOnly: !isToday,
            scrollCtrl: _scrollCtrl,
            gridKey: _gridKey,
            viewportKey: _viewportKey,
            dragPreview: _dragPreview,
            resizeTaskId: _resizeTaskId,
            effectiveDuration: _effectiveDuration,
            onTaskDrop: _scheduleTask,
            onDragMove: _onDragMove,
            onDragLeave: _clearDragPreview,
            onDragEnded: _clearDragPreview,
            onEmptySlotTap: _createTaskAt,
            onResizeStart: _onResizeStart,
            onResizeUpdate: _onResizeUpdate,
            onResizeEnd: _onResizeEnd,
          ),
        ),
      ],
    );
  }
}

/// Row state for a specific past date: exactly what was logged on that day.
TaskRowState _rowStateOn(
    Task task, List<TaskCompletion> completions, DateTime day) {
  TaskCompletion? real;
  TaskCompletion? skip;
  TaskCompletion? nd;
  for (final c in completions) {
    if (c.taskId != task.id) continue;
    if (c.completedOn.year != day.year ||
        c.completedOn.month != day.month ||
        c.completedOn.day != day.day) {
      continue;
    }
    if (c.isSkip) {
      skip ??= c;
    } else if (c.isNd) {
      nd ??= c;
    } else {
      real ??= c;
    }
  }
  return TaskRowState(
      checkedCompletion: real, skipCompletion: skip, ndCompletion: nd);
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

  /// Habit-stack queue behind this task (today's unresolved members only).
  /// A scheduled anchor's block spans its own duration + the queue's.
  final int queueCount;
  final int queueExtraMinutes;

  _TimelineEntry({
    required this.task,
    required this.rowState,
    this.milestone,
    this.queueCount = 0,
    this.queueExtraMinutes = 0,
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
  final bool readOnly;
  final Future<void> Function(Task task) onAccept;
  const _AnytimeTray({
    required this.entries,
    required this.onAccept,
    this.readOnly = false,
  });

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
                        itemBuilder: (_, i) => _AnytimeChip(
                            entry: entries[i], readOnly: readOnly),
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
  final bool readOnly;
  const _AnytimeChip({required this.entry, this.readOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = entry.rowState;
    final isChecked = state.isChecked;
    final body = _AnytimeChipBody(entry: entry, isChecked: isChecked);

    // Past-day record: plain visual, no tap/drag.
    if (readOnly) return body;

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
  final bool showNowIndicator;
  final bool readOnly;
  final ScrollController scrollCtrl;
  final GlobalKey gridKey;
  final GlobalKey viewportKey;
  final ValueNotifier<_DragPreview?> dragPreview;
  final String? resizeTaskId;
  final int Function(Task task) effectiveDuration;
  final Future<void> Function(Task task, Offset globalDrop) onTaskDrop;
  final void Function(Task task, Offset globalPos) onDragMove;
  final VoidCallback onDragLeave;
  final VoidCallback onDragEnded;
  final void Function(Offset globalPos) onEmptySlotTap;
  final void Function(Task task) onResizeStart;
  final void Function(double dy) onResizeUpdate;
  final Future<void> Function() onResizeEnd;

  const _TimeGrid({
    required this.scheduled,
    required this.now,
    required this.showNowIndicator,
    required this.readOnly,
    required this.scrollCtrl,
    required this.gridKey,
    required this.viewportKey,
    required this.dragPreview,
    required this.resizeTaskId,
    required this.effectiveDuration,
    required this.onTaskDrop,
    required this.onDragMove,
    required this.onDragLeave,
    required this.onDragEnded,
    required this.onEmptySlotTap,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final nowMin = now.hour * 60 + now.minute;
    return SingleChildScrollView(
      key: viewportKey,
      controller: scrollCtrl,
      child: SizedBox(
        height: _totalGridHeight + _gridTopPadding + _gridBottomPadding,
        child: DragTarget<Task>(
          onWillAcceptWithDetails: (_) => true,
          onMove: (d) => onDragMove(d.data, d.offset),
          onLeave: (_) => onDragLeave(),
          onAcceptWithDetails: (d) => onTaskDrop(d.data, d.offset),
          builder: (context, candidate, rejected) {
            return GestureDetector(
              // Empty-slot taps only — cards sit on top and claim their own.
              behavior: HitTestBehavior.translucent,
              onTapUp: readOnly
                  ? null
                  : (details) => onEmptySlotTap(details.globalPosition),
              child: Stack(
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
                    // short for both lines. Queue anchors span their whole
                    // chain's total time.
                    height: ((effectiveDuration(e.task) +
                                e.queueExtraMinutes) *
                            _pxPerMinute)
                        .clamp(32.0, double.infinity),
                    child: _TimelineTaskCard(
                      entry: e,
                      readOnly: readOnly,
                      isResizing: resizeTaskId == e.task.id,
                      effectiveDurationMinutes: effectiveDuration(e.task),
                      onDragEnded: onDragEnded,
                      onResizeStart: () => onResizeStart(e.task),
                      onResizeUpdate: onResizeUpdate,
                      onResizeEnd: onResizeEnd,
                    ),
                  ),
                if (showNowIndicator)
                  Positioned(
                    left: 0,
                    right: 12,
                    top: _gridTopPadding + nowMin * _pxPerMinute - 1,
                    child: const _NowIndicator(),
                  ),
                // Snap-preview outline + live time chip — topmost layer, so
                // it stays visible over existing cards. Repaints alone per
                // drag frame via the ValueNotifier; the grid never rebuilds.
                ValueListenableBuilder<_DragPreview?>(
                  valueListenable: dragPreview,
                  builder: (context, p, __) {
                    if (p == null) return const SizedBox.shrink();
                    return Positioned(
                      left: _hourLabelWidth,
                      right: 12,
                      top: _gridTopPadding + p.minute * _pxPerMinute,
                      height: (p.durationMinutes * _pxPerMinute)
                          .clamp(28.0, double.infinity),
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                AppColors.primary.withValues(alpha: 0.10),
                            border: Border.all(
                                color: AppColors.primary, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(6),
                                  bottomRight: Radius.circular(8),
                                ),
                              ),
                              child: Text(
                                '${_fmtMinutes(p.minute)} – ${_fmtMinutes(p.minute + p.durationMinutes)}',
                                style: AppTypography.caption.copyWith(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            );
          },
        ),
      ),
    );
  }
}

/// Live drag-preview payload: where the dragged block would land.
class _DragPreview {
  final int minute;
  final int durationMinutes;
  const _DragPreview({required this.minute, required this.durationMinutes});
}

/// Shared clock formatting for cards and the drag chip.
String _fmtMinutes(int min) {
  final wrapped = min % (24 * 60);
  final h = wrapped ~/ 60;
  final m = wrapped % 60;
  final hh = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  final ampm = h < 12 ? 'AM' : 'PM';
  return '$hh:${m.toString().padLeft(2, '0')} $ampm';
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
  final bool readOnly;
  final bool isResizing;
  final int effectiveDurationMinutes;
  final VoidCallback onDragEnded;
  final VoidCallback onResizeStart;
  final void Function(double dy) onResizeUpdate;
  final Future<void> Function() onResizeEnd;

  const _TimelineTaskCard({
    required this.entry,
    required this.readOnly,
    required this.isResizing,
    required this.effectiveDurationMinutes,
    required this.onDragEnded,
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
        final canShowHandle =
            !readOnly && cardHeight >= _minResizableCardHeight;

        final surface = _CardSurface(
          entry: entry,
          isResizing: isResizing,
          effectiveDurationMinutes: effectiveDurationMinutes,
        );

        // Past-day record: static card, no toggle/drag/resize.
        if (readOnly) return surface;

        return LongPressDraggable<Task>(
          data: task,
          hapticFeedbackOnStart: true,
          // Clears the snap preview when the drag ends anywhere (accepted,
          // cancelled, or dropped outside a target).
          onDragEnd: (_) => onDragEnded(),
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
          // No onLongPress here: long-press belongs EXCLUSIVELY to the
          // LongPressDraggable (calendar grammar — lift and drag). The
          // action menu opens via lift-and-release-in-place, handled in
          // _scheduleTask when the drop lands on the unchanged slot.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleTask(context, ref, entry),
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
    // Queue anchors display the whole chain: name badge + total time span.
    final totalMinutes = effectiveDurationMinutes + entry.queueExtraMinutes;
    final displayName = entry.queueCount > 0
        ? '🔗 ${task.name} +${entry.queueCount}'
        : task.name;
    final timeRange =
        '${_fmtMinutes(start)} – ${_fmtMinutes(start + totalMinutes)}';
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
                  displayName,
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

  if (context.mounted) await surfaceDialogMoments(context, result);

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
      streakDay: result.streakDay,
      questBonus: result.questCompleted?.bonus ?? 0,
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
