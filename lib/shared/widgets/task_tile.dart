import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/services/achievement_service.dart';
import '../../core/services/streak_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';
import '../../features/rewards/reward_unlock_service.dart';
import '../models/recurrence_rule.dart';
import '../providers/database_provider.dart';
import 'achievement_snackbar.dart';
import 'reward_unlock_snackbar.dart';

/// State of a task row at the time it's rendered. The four "active" states
/// are mutually exclusive in practice — priority is `checked > missed >
/// skipped > unchecked` if multiple completions coexist due to history.
class TaskRowState {
  final TaskCompletion? checkedCompletion;
  final TaskCompletion? skipCompletion;
  final TaskCompletion? ndCompletion;

  const TaskRowState({
    this.checkedCompletion,
    this.skipCompletion,
    this.ndCompletion,
  });

  bool get isChecked => checkedCompletion != null;
  bool get isMissed => !isChecked && ndCompletion != null;
  bool get isSkipped =>
      !isChecked && !isMissed && skipCompletion != null;
  bool get isUnchecked => !isChecked && !isMissed && !isSkipped;
}

/// Returns the row state for [task] given the recent [completions] list,
/// scoped to the task's current rule-defined period (or to the latest
/// completion for one-shot tasks).
TaskRowState taskRowStateFor(Task task, List<TaskCompletion> completions) {
  if (task.recurrence == TaskRecurrence.none) {
    if (task.status == TaskStatus.completed) {
      TaskCompletion? best;
      for (final c in completions) {
        if (c.taskId != task.id || c.isSkip || c.isNd) continue;
        if (best == null || c.completedOn.isAfter(best.completedOn)) best = c;
      }
      return TaskRowState(checkedCompletion: best);
    }
    // Active one-shot — surface today's skip / nd if any.
    final today = _dateOnly(DateTime.now());
    TaskCompletion? skip;
    TaskCompletion? nd;
    for (final c in completions) {
      if (c.taskId != task.id) continue;
      if (!_dateOnly(c.completedOn).isAtSameMomentAs(today)) continue;
      if (c.isSkip) skip ??= c;
      else if (c.isNd) nd ??= c;
    }
    return TaskRowState(skipCompletion: skip, ndCompletion: nd);
  }

  // Recurring task: scan the current rule period.
  final rule = RecurrenceRule.fromTask(task);
  final now = DateTime.now();
  final start = rule.currentPeriodStart(now);
  final end = rule.currentPeriodEnd(now);
  TaskCompletion? real;
  TaskCompletion? skip;
  TaskCompletion? nd;
  for (final c in completions) {
    if (c.taskId != task.id) continue;
    if (c.completedOn.isBefore(start) || !c.completedOn.isBefore(end)) {
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
    checkedCompletion: real,
    skipCompletion: skip,
    ndCompletion: nd,
  );
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// One day-chip in a multi-day weekly task's chip row.
class DayChip {
  final int weekday; // 1-7 (Mon-Sun)
  final DateTime date; // the specific date this week corresponding to [weekday]
  final TaskCompletion? real;
  final TaskCompletion? skip;
  final TaskCompletion? nd;
  final bool isFuture;
  final bool isToday;

  const DayChip({
    required this.weekday,
    required this.date,
    this.real,
    this.skip,
    this.nd,
    required this.isFuture,
    required this.isToday,
  });
}

/// Returns chip data for a multi-day weekly task, or null for any other kind
/// (single-day weekly, daily, monthly, one-shot). Caller passes the result
/// to [TaskTile.weeklyChips].
List<DayChip>? weeklyChipsFor(
    Task task, List<TaskCompletion> completions) {
  if (task.recurrence != TaskRecurrence.weekly) return null;
  final rule = RecurrenceRule.fromTask(task);
  if (rule.daysOfWeek.length <= 1) return null;

  final today = _dateOnly(DateTime.now());
  final monday = today.subtract(Duration(days: today.weekday - 1));

  return rule.daysOfWeek.map((wd) {
    final date = monday.add(Duration(days: wd - 1));
    TaskCompletion? real;
    TaskCompletion? skip;
    TaskCompletion? nd;
    for (final c in completions) {
      if (c.taskId != task.id) continue;
      if (!_isSameDay(c.completedOn, date)) continue;
      if (c.isSkip) {
        skip = c;
      } else if (c.isNd) {
        nd = c;
      } else {
        real ??= c;
      }
    }
    return DayChip(
      weekday: wd,
      date: date,
      real: real,
      skip: skip,
      nd: nd,
      isFuture: date.isAfter(today),
      isToday: _isSameDay(date, today),
    );
  }).toList();
}

/// Shared task tile rendering. Tap toggles the active state. Long-press on an
/// unchecked tile opens a "Skip today" action sheet. Caller provides the
/// meta-line string and an optional trailing widget.
class TaskTile extends ConsumerStatefulWidget {
  final Task task;
  final TaskRowState rowState;
  final String meta;
  final Widget? trailing;

  /// For multi-day weekly tasks: per-day chips (Mon/Wed/Fri etc.). When
  /// non-null, replaces the round main check button with a chip row.
  final List<DayChip>? weeklyChips;

  const TaskTile({
    super.key,
    required this.task,
    required this.rowState,
    required this.meta,
    this.trailing,
    this.weeklyChips,
  });

  @override
  ConsumerState<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends ConsumerState<TaskTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floaterCtrl;
  bool _showFloater = false;

  bool get _isChecked => widget.rowState.isChecked;
  bool get _isMissed => widget.rowState.isMissed;
  bool get _isSkipped => widget.rowState.isSkipped;
  bool get _isUnchecked => widget.rowState.isUnchecked;
  bool get _isOneShot => widget.task.recurrence == TaskRecurrence.none;

  @override
  void initState() {
    super.initState();
    _floaterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _floaterCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) setState(() => _showFloater = false);
      }
    });
  }

  @override
  void dispose() {
    _floaterCtrl.dispose();
    super.dispose();
  }

  void _triggerFloater() {
    _floaterCtrl.reset();
    setState(() => _showFloater = true);
    _floaterCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final hasChips = widget.weeklyChips != null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: _toggle,
            onLongPress: _isUnchecked ? _showActions : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: hasChips
                  ? const EdgeInsets.fromLTRB(14, 12, 4, 12)
                  : const EdgeInsets.fromLTRB(8, 8, 4, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!hasChips) ...[
                    _CheckButton(
                        rowState: widget.rowState, onTap: _toggle),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.task.name,
                          style: AppTypography.body.copyWith(
                            decoration: _isChecked && _isOneShot
                                ? TextDecoration.lineThrough
                                : null,
                            color: (_isChecked || _isSkipped)
                                ? context.appTextSecondary
                                : context.appTextPrimary,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            widget.meta,
                            style: AppTypography.caption.copyWith(
                              color: _isChecked
                                  ? AppColors.primary
                                  : _isMissed
                                      ? Colors.red.shade400
                                      : _isSkipped
                                          ? context.appTextTertiary
                                          : context.appTextSecondary,
                              fontWeight:
                                  (_isChecked || _isMissed)
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (hasChips) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: widget.weeklyChips!
                                .map((c) => _DayChipWidget(
                                      chip: c,
                                      onTap: () => _toggleChip(c),
                                      onLongPress: () => _showChipActions(c),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.trailing != null) widget.trailing!,
                ],
              ),
            ),
          ),
        ),
        if (_showFloater)
          Positioned(
            left: 12,
            top: 8,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _floaterCtrl,
                builder: (_, __) {
                  final t = _floaterCtrl.value;
                  final opacity = t < 0.15
                      ? t / 0.15
                      : t > 0.7
                          ? ((1 - t) / 0.3).clamp(0.0, 1.0)
                          : 1.0;
                  return Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(0, -30 * t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '+${widget.task.pointsPerCompletion}',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _toggle() async {
    final db = ref.read(databaseProvider);
    if (_isChecked && widget.rowState.checkedCompletion != null) {
      await db.undoCompletion(
          widget.rowState.checkedCompletion!.id, widget.task.id);
      HapticFeedback.lightImpact();
    } else if (_isMissed && widget.rowState.ndCompletion != null) {
      // Unmark missed — undoCompletion safely removes the ND row.
      await db.undoCompletion(
          widget.rowState.ndCompletion!.id, widget.task.id);
      HapticFeedback.lightImpact();
    } else if (_isSkipped && widget.rowState.skipCompletion != null) {
      // Unskip: just delete the row. undoCompletion is safe (no points to
      // refund, no status change for one-shots since skip doesn't set
      // completed).
      await db.undoCompletion(
          widget.rowState.skipCompletion!.id, widget.task.id);
      HapticFeedback.lightImpact();
    } else if (_isUnchecked) {
      await db.completeTaskNow(widget.task);
      final streakBadges = await StreakService.recordDayLogged(db);
      final completionBadges =
          await AchievementService.checkAfterCompletion(db);
      final unlockedRewards =
          await RewardUnlockService.checkAfterPointsChange(db);
      HapticFeedback.mediumImpact();
      if (widget.task.pointsPerCompletion > 0 && mounted) {
        _triggerFloater();
      }
      if (mounted) {
        showAchievementSnackbar(
          context,
          [...completionBadges, ...streakBadges],
        );
        showRewardUnlockSnackbar(context, unlockedRewards);
      }
    }
  }

  void _showActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SkipActionsSheet(
        taskName: widget.task.name,
        onSkip: () {
          Navigator.of(ctx).pop();
          _skipToday();
        },
        onMissed: () {
          Navigator.of(ctx).pop();
          _markMissed();
        },
      ),
    );
  }

  Future<void> _skipToday() async {
    final db = ref.read(databaseProvider);
    await db.skipTaskNow(widget.task);
    await StreakService.recordSkipDay(db);
    HapticFeedback.lightImpact();
  }

  Future<void> _markMissed() async {
    final db = ref.read(databaseProvider);
    await db.markTaskMissed(widget.task);
    HapticFeedback.lightImpact();
  }

  /// Long-press on a day chip: surface skip/missed options for that
  /// specific date. Only opens when the chip is empty (no completion yet)
  /// and not in the future.
  void _showChipActions(DayChip chip) {
    if (chip.isFuture) return;
    if (!_isChipEmpty(chip)) return;
    final dateLabel = _formatChipDate(chip.date);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SkipActionsSheet(
        taskName: widget.task.name,
        subtitle: dateLabel,
        onSkip: () async {
          Navigator.of(ctx).pop();
          final db = ref.read(databaseProvider);
          await db.skipTaskOn(widget.task, chip.date);
          HapticFeedback.lightImpact();
        },
        onMissed: () async {
          Navigator.of(ctx).pop();
          final db = ref.read(databaseProvider);
          await db.markTaskMissedOn(widget.task, chip.date);
          HapticFeedback.lightImpact();
        },
      ),
    );
  }

  bool _isChipEmpty(DayChip chip) =>
      chip.real == null && chip.skip == null && chip.nd == null;

  String _formatChipDate(DateTime date) {
    const weekdayNames = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdayNames[date.weekday - 1]}, '
        '${monthNames[date.month - 1]} ${date.day}';
  }

  Future<void> _toggleChip(DayChip chip) async {
    if (chip.isFuture) return;
    final db = ref.read(databaseProvider);

    // Undo any existing completion (real / skip / nd) for this chip's date.
    final existing = chip.real ?? chip.nd ?? chip.skip;
    if (existing != null) {
      await db.undoCompletion(existing.id, widget.task.id);
      HapticFeedback.lightImpact();
      return;
    }

    // Empty chip → log a real completion.
    if (chip.isToday) {
      // Today's chip uses the full flow (streak + achievements + reward unlock).
      await db.completeTaskNow(widget.task);
      final streakBadges = await StreakService.recordDayLogged(db);
      final completionBadges =
          await AchievementService.checkAfterCompletion(db);
      final unlockedRewards =
          await RewardUnlockService.checkAfterPointsChange(db);
      HapticFeedback.mediumImpact();
      if (widget.task.pointsPerCompletion > 0 && mounted) {
        _triggerFloater();
      }
      if (mounted) {
        showAchievementSnackbar(
          context,
          [...completionBadges, ...streakBadges],
        );
        showRewardUnlockSnackbar(context, unlockedRewards);
      }
    } else {
      // Past-date retro-log: points + reward check, but no streak update
      // (the streak for that day was already determined).
      await db.completeTaskOn(widget.task, chip.date);
      final completionBadges =
          await AchievementService.checkAfterCompletion(db);
      final unlockedRewards =
          await RewardUnlockService.checkAfterPointsChange(db);
      HapticFeedback.mediumImpact();
      if (mounted) {
        showAchievementSnackbar(context, completionBadges);
        showRewardUnlockSnackbar(context, unlockedRewards);
      }
    }
  }
}

class _CheckButton extends StatelessWidget {
  final TaskRowState rowState;
  final VoidCallback onTap;
  const _CheckButton({required this.rowState, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color border;
    final IconData? icon;
    if (rowState.isChecked) {
      fill = AppColors.primary;
      border = AppColors.primary;
      icon = Icons.check_rounded;
    } else if (rowState.isMissed) {
      fill = Colors.red.shade400;
      border = Colors.red.shade400;
      icon = Icons.close_rounded;
    } else if (rowState.isSkipped) {
      fill = context.appTextTertiary;
      border = context.appTextTertiary;
      icon = Icons.remove_rounded;
    } else {
      fill = Colors.transparent;
      border = context.appBorder;
      icon = null;
    }
    return SizedBox(
      width: 44,
      height: 44,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: fill,
              border: Border.all(color: border, width: 2),
              shape: BoxShape.circle,
            ),
            child: icon != null
                ? Icon(icon, size: 18, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}

class _DayChipWidget extends StatelessWidget {
  final DayChip chip;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _DayChipWidget({
    required this.chip,
    required this.onTap,
    this.onLongPress,
  });

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color textColor;
    if (chip.isFuture) {
      bg = context.appPageBackground;
      textColor = context.appTextTertiary;
    } else if (chip.real != null) {
      bg = AppColors.primary;
      textColor = Colors.white;
    } else if (chip.nd != null) {
      bg = Colors.red.shade400;
      textColor = Colors.white;
    } else if (chip.skip != null) {
      bg = context.appTextTertiary;
      textColor = Colors.white;
    } else {
      bg = context.appBorder.withValues(alpha: 0.4);
      textColor = context.appTextSecondary;
    }

    final letter = _letters[chip.weekday - 1];

    return InkWell(
      onTap: chip.isFuture ? null : onTap,
      onLongPress: chip.isFuture ? null : onLongPress,
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: chip.isToday
              ? Border.all(color: AppColors.primary, width: 2)
              : null,
        ),
        child: Text(
          letter,
          style: AppTypography.caption.copyWith(
            color: textColor,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _SkipActionsSheet extends StatelessWidget {
  final String taskName;
  final String? subtitle; // e.g., "Mon, May 5" — set by chip long-press
  final VoidCallback onSkip;
  final VoidCallback onMissed;

  const _SkipActionsSheet({
    required this.taskName,
    this.subtitle,
    required this.onSkip,
    required this.onMissed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                color: context.appBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(taskName,
                style: AppTypography.heading2,
                textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: AppTypography.caption.copyWith(
                      color: context.appTextSecondary),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            _OptionRow(
              icon: Icons.do_not_disturb_alt_rounded,
              iconColor: context.appTextTertiary,
              title: 'Skip today',
              subtitle: 'Intentional rest. Streak preserved, no points.',
              onTap: onSkip,
            ),
            const SizedBox(height: 12),
            _OptionRow(
              icon: Icons.close_rounded,
              iconColor: Colors.red.shade400,
              title: 'Mark as missed',
              subtitle: "Honest miss. Doesn't credit your streak.",
              onTap: onMissed,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CANCEL'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionRow({
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
