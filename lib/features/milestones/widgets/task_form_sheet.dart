import 'dart:math';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import '../../../core/services/app_prefs.dart';
import '../../../core/services/notification_scheduler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_colors.dart';
import '../../../shared/models/recurrence_rule.dart';
import '../../../shared/providers/database_provider.dart';
import 'milestone_form_sheet.dart';

Future<void> showTaskFormSheet(
  BuildContext context, {
  String? milestoneId,
  Task? task,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TaskFormSheet(milestoneId: milestoneId, task: task),
  );
}

class _TaskFormSheet extends ConsumerStatefulWidget {
  final String? milestoneId;
  final Task? task;
  const _TaskFormSheet({required this.milestoneId, this.task});

  @override
  ConsumerState<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends ConsumerState<_TaskFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _pointsController;
  late final TextEditingController _tinyController;

  // Milestone selection
  List<Milestone> _milestones = [];
  String? _selectedMilestoneId;
  bool _milestonesLoaded = false;

  // Recurrence state
  TaskRecurrence _frequency = TaskRecurrence.none;
  int _interval = 1;
  late Set<int> _daysOfWeek;
  MonthlyKind _monthlyKind = MonthlyKind.dayOfMonth;
  late int _dayOfMonth;
  int _weekdayOrdinal = 1;
  late int _weekdayMonthly;
  DateTime? _anchor;

  DateTime? _dueDate;

  // Optional timeline scheduling
  TimeOfDay? _startTime;
  int _durationMinutes = 30;

  // Optional reminder. When enabled with no override, the reminder follows the
  // timeline start time; an override sets an independent time. When
  // `_reminderDate` is set, the reminder is a one-shot for that specific date
  // regardless of the task's recurrence.
  bool _reminderEnabled = false;
  TimeOfDay? _reminderOverride;
  DateTime? _reminderDate;

  // Habit stacking: id of the anchor task this one follows ("After
  // [anchor], I will [this]"). Lives behind the More-options expander.
  String? _stackedAfterTaskId;
  bool _moreOptions = false;
  List<Task> _allTasks = [];

  bool _saving = false;

  bool get _isEdit => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _nameController = TextEditingController(text: t?.name ?? '');
    _pointsController =
        TextEditingController(text: (t?.pointsPerCompletion ?? 10).toString());
    _tinyController = TextEditingController(text: t?.tinyName ?? '');

    final today = DateTime.now();
    _daysOfWeek = {today.weekday};
    _dayOfMonth = today.day;
    _weekdayMonthly = today.weekday;

    if (t != null) {
      _frequency = t.recurrence;
      _dueDate = t.dueDate;
      if (t.startMinute != null) {
        _startTime = TimeOfDay(
          hour: t.startMinute! ~/ 60,
          minute: t.startMinute! % 60,
        );
      }
      _durationMinutes = t.durationMinutes;
      _reminderEnabled = t.reminderEnabled;
      if (t.reminderMinute != null) {
        _reminderOverride = TimeOfDay(
          hour: t.reminderMinute! ~/ 60,
          minute: t.reminderMinute! % 60,
        );
      }
      _reminderDate = t.reminderDate;
      _stackedAfterTaskId = t.stackedAfterTaskId;
      // Surface already-configured power options instead of hiding them.
      _moreOptions = t.stackedAfterTaskId != null || t.tinyName != null;
      if (_frequency != TaskRecurrence.none) {
        final rule = RecurrenceRule.fromTask(t);
        _interval = rule.interval;
        // Preserve the existing anchor on edit so the cycle phase doesn't
        // shift. (For interval=1 this has no effect, but keeps later edits
        // safe if interval is bumped up.)
        _anchor = rule.anchor;
        if (rule.frequency == TaskRecurrence.weekly) {
          _daysOfWeek = rule.daysOfWeek.toSet();
        }
        if (rule.frequency == TaskRecurrence.monthly) {
          _monthlyKind = rule.monthlyKind ?? MonthlyKind.dayOfMonth;
          if (rule.dayOfMonth != null) _dayOfMonth = rule.dayOfMonth!;
          if (rule.weekdayOrdinal != null) {
            _weekdayOrdinal = rule.weekdayOrdinal!;
          }
          if (rule.weekday != null) _weekdayMonthly = rule.weekday!;
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMilestones());
  }

  Future<void> _loadMilestones() async {
    final db = ref.read(databaseProvider);
    final list = await db.getActiveMilestones();
    final allTasks = await db.getAllActiveTasks();
    String? initial = _isEdit ? widget.task!.milestoneId : widget.milestoneId;
    if (initial == null) {
      final lastUsed = await AppPrefs.getLastUsedMilestoneId();
      if (lastUsed != null && list.any((m) => m.id == lastUsed)) {
        initial = lastUsed;
      } else if (list.isNotEmpty) {
        initial = list.first.id;
      }
    } else if (!list.any((m) => m.id == initial)) {
      initial = list.isNotEmpty ? list.first.id : null;
    }
    if (!mounted) return;
    setState(() {
      _milestones = list;
      _allTasks = allTasks;
      _selectedMilestoneId = initial;
      _milestonesLoaded = true;
    });
  }

  /// Whether picking [candidate] as this task's anchor would create a loop:
  /// following the candidate's own anchor chain reaches the task being
  /// edited. Visited-set walk, depth-capped — dangling ids just end the walk.
  bool _wouldLoop(Task candidate) {
    final editingId = widget.task?.id;
    if (editingId == null) return false; // new task: no one anchors on it yet
    final byId = {for (final t in _allTasks) t.id: t};
    final visited = <String>{};
    Task? cur = candidate;
    for (var depth = 0; cur != null && depth < 25; depth++) {
      if (cur.id == editingId) return true;
      final next = cur.stackedAfterTaskId;
      if (next == null || !visited.add(next)) break;
      cur = byId[next];
    }
    return false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pointsController.dispose();
    _tinyController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickAnchor() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _anchor = picked);
  }

  RecurrenceRule? _buildRule() {
    switch (_frequency) {
      case TaskRecurrence.none:
        return null;
      case TaskRecurrence.daily:
        return RecurrenceRule.daily(interval: _interval, anchor: _anchor);
      case TaskRecurrence.weekly:
        return RecurrenceRule.weekly(
          interval: _interval,
          daysOfWeek: _daysOfWeek.toList(),
          anchor: _anchor,
        );
      case TaskRecurrence.monthly:
        if (_monthlyKind == MonthlyKind.weekdayPosition) {
          return RecurrenceRule.monthlyByWeekday(
            interval: _interval,
            weekdayOrdinal: _weekdayOrdinal,
            weekday: _weekdayMonthly,
            anchor: _anchor,
          );
        }
        return RecurrenceRule.monthlyByDay(
          interval: _interval,
          dayOfMonth: _dayOfMonth,
          anchor: _anchor,
        );
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your task a name')),
      );
      return;
    }
    if (_selectedMilestoneId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a milestone for this task')),
      );
      return;
    }
    if (_frequency == TaskRecurrence.weekly && _daysOfWeek.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one day of the week')),
      );
      return;
    }
    // Habit stacking: defense-in-depth cycle check at save (the picker
    // already excludes loop candidates; this catches stale state).
    if (_stackedAfterTaskId != null) {
      final anchor =
          _allTasks.where((t) => t.id == _stackedAfterTaskId).firstOrNull;
      if (anchor == null || anchor.id == widget.task?.id ||
          _wouldLoop(anchor)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text("That anchor would create a loop — pick another task")),
        );
        return;
      }
    }

    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final points = int.tryParse(_pointsController.text.trim()) ?? 10;
    final dueDate = _frequency == TaskRecurrence.none ? _dueDate : null;
    final rule = _buildRule();
    final cfg = rule?.toJsonString();
    // Queued tasks have no time of day — their start IS "when the anchor
    // finishes". They keep a duration; the anchor's timeline block spans
    // the whole queue's total.
    final startMin = (_stackedAfterTaskId != null || _startTime == null)
        ? null
        : _startTime!.hour * 60 + _startTime!.minute;
    final tinyTrimmed = _tinyController.text.trim();
    final tinyName = tinyTrimmed.isEmpty ? null : tinyTrimmed;
    // Persist the override only; a null reminderMinute with reminderEnabled on
    // means "follow the start time".
    final reminderMin = _reminderOverride == null
        ? null
        : _reminderOverride!.hour * 60 + _reminderOverride!.minute;

    // Only persist the one-shot reminder date when the reminder is enabled.
    final reminderDate = _reminderEnabled ? _reminderDate : null;

    if (_isEdit) {
      final t = widget.task!;
      await db.updateTask(t.copyWith(
        name: name,
        milestoneId: Value(_selectedMilestoneId),
        pointsPerCompletion: points,
        recurrence: _frequency,
        recurrenceConfig: Value(cfg),
        dueDate: Value(dueDate),
        startMinute: Value(startMin),
        durationMinutes: _durationMinutes,
        reminderEnabled: _reminderEnabled,
        reminderMinute: Value(reminderMin),
        reminderDate: Value(reminderDate),
        stackedAfterTaskId: Value(_stackedAfterTaskId),
        tinyName: Value(tinyName),
      ));
    } else {
      await db.insertTask(TasksCompanion.insert(
        id: _generateId(),
        milestoneId: Value(_selectedMilestoneId),
        name: name,
        pointsPerCompletion: Value(points),
        recurrence: Value(_frequency),
        recurrenceConfig: Value(cfg),
        dueDate: Value(dueDate),
        startMinute: Value(startMin),
        durationMinutes: Value(_durationMinutes),
        reminderEnabled: Value(_reminderEnabled),
        reminderMinute: Value(reminderMin),
        reminderDate: Value(reminderDate),
        stackedAfterTaskId: Value(_stackedAfterTaskId),
        tinyName: Value(tinyName),
      ));
    }
    await AppPrefs.setLastUsedMilestoneId(_selectedMilestoneId!);
    // Reflect the new/changed reminder in the scheduled notifications.
    await NotificationScheduler.reschedule();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: BoxDecoration(
          color: context.appCardSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
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
              const SizedBox(height: 20),
              Text(_isEdit ? 'Edit task' : 'New task',
                  style: AppTypography.heading2),
              const SizedBox(height: 20),
              if (_milestonesLoaded && _milestones.isEmpty)
                _NoMilestonesPanel()
              else
                _buildMilestoneDropdown(),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                autofocus: !_isEdit,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. 20 pushups',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pointsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Points per completion',
                ),
              ),
              const SizedBox(height: 24),
              Text('Repeats', style: AppTypography.caption),
              const SizedBox(height: 8),
              SegmentedButton<TaskRecurrence>(
                // Hide the leading check icon — the selected segment already
                // reads as selected via its filled background, and the icon
                // squeezes labels enough on narrow screens to wrap "Once".
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: TaskRecurrence.none, label: Text('Once')),
                  ButtonSegment(
                      value: TaskRecurrence.daily, label: Text('Daily')),
                  ButtonSegment(
                      value: TaskRecurrence.weekly, label: Text('Weekly')),
                  ButtonSegment(
                      value: TaskRecurrence.monthly, label: Text('Monthly')),
                ],
                selected: {_frequency},
                onSelectionChanged: (s) =>
                    setState(() => _frequency = s.first),
              ),
              const SizedBox(height: 16),
              if (_frequency != TaskRecurrence.none) _buildIntervalRow(),
              if (_frequency == TaskRecurrence.weekly) ...[
                const SizedBox(height: 16),
                _buildWeekdayChips(),
              ],
              if (_frequency == TaskRecurrence.monthly) ...[
                const SizedBox(height: 16),
                _buildMonthlyOptions(),
              ],
              if (_frequency != TaskRecurrence.none && _interval > 1) ...[
                const SizedBox(height: 16),
                _buildAnchorPicker(),
              ],
              if (_frequency == TaskRecurrence.none) ...[
                const SizedBox(height: 8),
                _buildDueDatePicker(),
              ],
              if (_buildRule() != null) ...[
                const SizedBox(height: 12),
                _SchedulePreview(rule: _buildRule()!),
              ],
              const SizedBox(height: 24),
              _buildScheduleTimeRow(),
              const SizedBox(height: 24),
              _buildReminderRow(),
              const SizedBox(height: 12),
              _buildMoreOptions(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_saving ||
                          (_milestonesLoaded && _milestones.isEmpty))
                      ? null
                      : _save,
                  child: Text(_isEdit ? 'SAVE CHANGES' : 'ADD TASK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── milestone dropdown ────────────────────────────────────────────────────

  Widget _buildMilestoneDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedMilestoneId,
      decoration: const InputDecoration(
        labelText: 'Milestone',
      ),
      items: _milestones
          .map((m) => DropdownMenuItem(
                value: m.id,
                child: Text(m.name, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (v) => setState(() => _selectedMilestoneId = v),
    );
  }

  // ── interval stepper ──────────────────────────────────────────────────────

  Widget _buildIntervalRow() {
    final unit = switch (_frequency) {
      TaskRecurrence.daily => _interval == 1 ? 'day' : 'days',
      TaskRecurrence.weekly => _interval == 1 ? 'week' : 'weeks',
      TaskRecurrence.monthly => _interval == 1 ? 'month' : 'months',
      _ => '',
    };
    return Row(
      children: [
        Text('Every', style: AppTypography.body),
        const SizedBox(width: 12),
        _Stepper(
          value: _interval,
          min: 1,
          max: 99,
          onChanged: (v) => setState(() => _interval = v),
        ),
        const SizedBox(width: 8),
        Text(unit, style: AppTypography.body),
      ],
    );
  }

  // ── weekly day chips ──────────────────────────────────────────────────────

  Widget _buildWeekdayChips() {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('On these days', style: AppTypography.caption),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final dayIndex = i + 1;
            final selected = _daysOfWeek.contains(dayIndex);
            return _DayChip(
              label: labels[i],
              selected: selected,
              onTap: () {
                setState(() {
                  if (selected) {
                    _daysOfWeek.remove(dayIndex);
                  } else {
                    _daysOfWeek.add(dayIndex);
                  }
                });
              },
            );
          }),
        ),
      ],
    );
  }

  // ── monthly options ───────────────────────────────────────────────────────

  Widget _buildMonthlyOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RadioListTile<MonthlyKind>(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: MonthlyKind.dayOfMonth,
          groupValue: _monthlyKind,
          onChanged: (v) => setState(() => _monthlyKind = v!),
          title: Row(
            children: [
              Text('On day', style: AppTypography.body),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _dayOfMonth,
                onChanged: _monthlyKind == MonthlyKind.dayOfMonth
                    ? (v) => setState(() => _dayOfMonth = v!)
                    : null,
                items: List.generate(
                  31,
                  (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text(i + 1 == 31 ? 'Last day' : '${i + 1}'),
                  ),
                ),
              ),
            ],
          ),
        ),
        RadioListTile<MonthlyKind>(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: MonthlyKind.weekdayPosition,
          groupValue: _monthlyKind,
          onChanged: (v) => setState(() => _monthlyKind = v!),
          title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text('On the', style: AppTypography.body),
              DropdownButton<int>(
                value: _weekdayOrdinal,
                onChanged: _monthlyKind == MonthlyKind.weekdayPosition
                    ? (v) => setState(() => _weekdayOrdinal = v!)
                    : null,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1st')),
                  DropdownMenuItem(value: 2, child: Text('2nd')),
                  DropdownMenuItem(value: 3, child: Text('3rd')),
                  DropdownMenuItem(value: 4, child: Text('4th')),
                  DropdownMenuItem(value: -1, child: Text('Last')),
                ],
              ),
              DropdownButton<int>(
                value: _weekdayMonthly,
                onChanged: _monthlyKind == MonthlyKind.weekdayPosition
                    ? (v) => setState(() => _weekdayMonthly = v!)
                    : null,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Monday')),
                  DropdownMenuItem(value: 2, child: Text('Tuesday')),
                  DropdownMenuItem(value: 3, child: Text('Wednesday')),
                  DropdownMenuItem(value: 4, child: Text('Thursday')),
                  DropdownMenuItem(value: 5, child: Text('Friday')),
                  DropdownMenuItem(value: 6, child: Text('Saturday')),
                  DropdownMenuItem(value: 7, child: Text('Sunday')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnchorPicker() {
    final unit = _frequency == TaskRecurrence.daily
        ? 'day'
        : _frequency == TaskRecurrence.weekly
            ? 'week'
            : 'month';
    return InkWell(
      onTap: _pickAnchor,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'First occurrence',
          helperText: 'Sets where the every-$_interval-$unit cycle starts',
          suffixIcon: _anchor == null
              ? const Icon(Icons.calendar_today_outlined)
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _anchor = null),
                ),
        ),
        child: Text(
          _anchor == null
              ? 'Defaults to today'
              : DateFormat.yMMMMd().format(_anchor!),
          style: AppTypography.body.copyWith(
            color: _anchor == null
                ? context.appTextSecondary
                : context.appTextPrimary,
          ),
        ),
      ),
    );
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      // Snap minute to nearest 5 to keep the picker readable.
      final snapped = TimeOfDay(
        hour: picked.hour,
        minute: (picked.minute ~/ 5) * 5,
      );
      setState(() => _startTime = snapped);
    }
  }

  Widget _buildScheduleTimeRow() {
    final anchored = _stackedAfterTaskId != null;
    final has = _startTime != null;
    final timeLabel = has
        ? _startTime!.format(context)
        : 'No time — shows in Anytime tray';
    final durationHint = anchored
        ? 'Runs whenever you finish its anchor — no start time needed'
        : has
            ? 'Sets the size of its timeline block'
            : 'Feeds timeline blocks and task-queue totals';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Duration is a first-class field on EVERY task — it powers timeline
        // block sizes, queue totals ("~1h 15m"), and future planning stats.
        Text('Takes about', style: AppTypography.caption),
        const SizedBox(height: 8),
        Row(
          children: [
            _DurationStepper(
              minutes: _durationMinutes,
              onChanged: (v) => setState(() => _durationMinutes = v),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                durationHint,
                style: AppTypography.caption
                    .copyWith(color: context.appTextSecondary),
              ),
            ),
          ],
        ),
        // Queued tasks have no time of day of their own.
        if (!anchored) ...[
          const SizedBox(height: 24),
          Text('Schedule on timeline', style: AppTypography.caption),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickStartTime,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Start time',
                suffixIcon: has
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _startTime = null),
                      )
                    : const Icon(Icons.schedule_rounded),
              ),
              child: Text(
                timeLabel,
                style: AppTypography.body.copyWith(
                  color:
                      has ? context.appTextPrimary : context.appTextSecondary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _toggleReminder(bool value) {
    setState(() {
      _reminderEnabled = value;
      // Give the reminder a concrete time when there's no start time to follow.
      if (value && _reminderOverride == null && _startTime == null) {
        _reminderOverride = const TimeOfDay(hour: 9, minute: 0);
      }
    });
  }

  Future<void> _pickReminderTime() async {
    final base = _reminderOverride ??
        _startTime ??
        const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: base);
    if (picked != null) setState(() => _reminderOverride = picked);
  }

  Future<void> _pickReminderDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _reminderDate ?? today,
      firstDate: today,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _reminderDate = picked);
  }

  Widget _buildReminderRow() {
    final followsStart = _reminderOverride == null && _startTime != null;
    final effective = _reminderOverride ?? _startTime;
    final timeLabel =
        effective == null ? 'Pick a time' : effective.format(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Remind me', style: AppTypography.body),
                  Text(
                    'Notify on days this task is due',
                    style: AppTypography.caption
                        .copyWith(color: context.appTextSecondary),
                  ),
                ],
              ),
            ),
            Switch(
              value: _reminderEnabled,
              onChanged: _toggleReminder,
              activeColor: AppColors.primary,
            ),
          ],
        ),
        if (_reminderEnabled) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickReminderTime,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Reminder time',
                helperText: followsStart ? 'Follows the start time' : null,
                suffixIcon: (_reminderOverride != null && _startTime != null)
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Follow start time',
                        onPressed: () =>
                            setState(() => _reminderOverride = null),
                      )
                    : const Icon(Icons.notifications_active_outlined),
              ),
              child: Text(
                timeLabel,
                style: AppTypography.body.copyWith(
                  color: effective == null
                      ? context.appTextSecondary
                      : context.appTextPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickReminderDate,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Reminder date (optional)',
                helperText: _reminderDate == null
                    ? 'Fires on every day this task is due'
                    : 'One-time nudge on this date only',
                suffixIcon: _reminderDate == null
                    ? const Icon(Icons.event_outlined)
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear date',
                        onPressed: () =>
                            setState(() => _reminderDate = null),
                      ),
              ),
              child: Text(
                _reminderDate == null
                    ? 'No date — follows recurrence'
                    : DateFormat.yMMMMd().format(_reminderDate!),
                style: AppTypography.body.copyWith(
                  color: _reminderDate == null
                      ? context.appTextSecondary
                      : context.appTextPrimary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── More options (progressive disclosure for niche power features) ───────

  /// Both this task and its anchor are weekly but share no common day —
  /// the stack would never fire the "Next up" moment.
  bool _scheduleMismatch(Task anchor) {
    if (_frequency != TaskRecurrence.weekly) return false;
    if (anchor.recurrence != TaskRecurrence.weekly) return false;
    final anchorDays = RecurrenceRule.fromTask(anchor).daysOfWeek.toSet();
    return anchorDays.isNotEmpty &&
        _daysOfWeek.isNotEmpty &&
        _daysOfWeek.intersection(anchorDays).isEmpty;
  }

  String _scheduleSummaryOf(Task t) => t.recurrence == TaskRecurrence.none
      ? 'One-time'
      : RecurrenceRule.fromTask(t).summary();

  Widget _buildMoreOptions() {
    final anchor = _stackedAfterTaskId == null
        ? null
        : _allTasks.where((t) => t.id == _stackedAfterTaskId).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _moreOptions = !_moreOptions),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  _moreOptions
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: context.appTextSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'More options',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_moreOptions) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _tinyController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: '2-minute version (optional)',
              hintText: 'e.g. Read one page',
              helperText:
                  'A bad-day fallback: half points, full streak credit',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickAnchorTask,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Do it after another task (optional)',
                helperText: anchor == null
                    ? null
                    : _scheduleMismatch(anchor)
                        ? "⚠ This task and its anchor aren't due on the same days"
                        : 'Surfaces after you finish that task · '
                            '${_scheduleSummaryOf(anchor)}',
                helperMaxLines: 2,
                suffixIcon: _stackedAfterTaskId == null
                    ? const Icon(Icons.link_rounded)
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Remove anchor',
                        onPressed: () =>
                            setState(() => _stackedAfterTaskId = null),
                      ),
              ),
              child: Text(
                anchor?.name ?? 'None — starts on its own',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body.copyWith(
                  color: anchor == null
                      ? context.appTextSecondary
                      : context.appTextPrimary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickAnchorTask() async {
    final selfId = widget.task?.id;
    final candidates = _allTasks
        .where((t) => t.id != selfId && !_wouldLoop(t))
        .toList();
    final excludedForLoops =
        _allTasks.where((t) => t.id != selfId).length - candidates.length;

    final milestoneById = {for (final m in _milestones) m.id: m};
    final picked = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: ctx.appCardSurface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
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
            const SizedBox(height: 16),
            Text('After completing…', style: AppTypography.heading2),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const Icon(Icons.link_off_rounded),
                    title: Text('No anchor — starts on its own',
                        style: AppTypography.body),
                    onTap: () => Navigator.of(ctx).pop('__none__'),
                  ),
                  for (final t in candidates)
                    ListTile(
                      leading: const Icon(Icons.link_rounded),
                      title: Text(t.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body),
                      subtitle: Text(
                        [
                          if (milestoneById[t.milestoneId] != null)
                            milestoneById[t.milestoneId]!.name,
                          _scheduleSummaryOf(t),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption,
                      ),
                      onTap: () => Navigator.of(ctx).pop(t.id),
                    ),
                ],
              ),
            ),
            if (excludedForLoops > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "Tasks that would loop back to this one aren't listed.",
                  style: AppTypography.caption
                      .copyWith(color: ctx.appTextTertiary),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return; // dismissed
    setState(() {
      _stackedAfterTaskId = picked == '__none__' ? null : picked;
      // A queued task has no time of day of its own.
      if (_stackedAfterTaskId != null) _startTime = null;
    });
  }

  Widget _buildDueDatePicker() {
    return InkWell(
      onTap: _pickDueDate,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Due date (optional)',
          suffixIcon: _dueDate == null
              ? const Icon(Icons.calendar_today_outlined)
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _dueDate = null),
                ),
        ),
        child: Text(
          _dueDate == null
              ? 'No due date'
              : DateFormat.yMMMMd().format(_dueDate!),
          style: AppTypography.body.copyWith(
            color: _dueDate == null
                ? context.appTextSecondary
                : context.appTextPrimary,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────

class _NoMilestonesPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appPageBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No milestones yet',
              style: AppTypography.body
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Tasks belong to milestones. Create one first, then come back.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              showMilestoneFormSheet(context);
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('CREATE MILESTONE'),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appPageBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: value > min ? () => onChanged(value - 1) : null,
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: AppTypography.body
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: value < max ? () => onChanged(value + 1) : null,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _DurationStepper extends StatelessWidget {
  final int minutes;
  final ValueChanged<int> onChanged;
  static const _step = 15;
  static const _min = 15;
  static const _max = 480;

  const _DurationStepper({required this.minutes, required this.onChanged});

  String _label(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '${h}h' : '${h}h ${rem}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appPageBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed:
                minutes > _min ? () => onChanged(minutes - _step) : null,
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 56,
            child: Text(
              _label(minutes),
              textAlign: TextAlign.center,
              style:
                  AppTypography.body.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed:
                minutes < _max ? () => onChanged(minutes + _step) : null,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.primary : context.appBorder,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : context.appTextSecondary,
          ),
        ),
      ),
    );
  }
}

class _SchedulePreview extends StatelessWidget {
  final RecurrenceRule rule;
  const _SchedulePreview({required this.rule});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_repeat_rounded,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              rule.summary(),
              style: AppTypography.body.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _generateId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final r = Random.secure();
  return 't${List.generate(19, (_) => chars[r.nextInt(chars.length)]).join()}';
}
