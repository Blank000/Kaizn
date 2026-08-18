import 'package:flutter/material.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_colors.dart';

/// "Your week" at a glance: seven dots, Mon–Sun. Green check = a real
/// completion that day, soft dash = intentional rest (skips only), empty
/// ring = nothing logged (deliberately NOT red — quiet, never accusatory),
/// today pulses gently. The Duolingo weekly calendar, kill-list edition.
class WeekBoard extends StatefulWidget {
  final List<TaskCompletion> completions;
  const WeekBoard({super.key, required this.completions});

  @override
  State<WeekBoard> createState() => _WeekBoardState();
}

enum _DayState { done, rest, quiet, future }

class _WeekBoardState extends State<WeekBoard>
    with SingleTickerProviderStateMixin {
  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final still = MediaQuery.of(context).disableAnimations;

    var doneCount = 0;
    final days = List.generate(7, (i) {
      final date = monday.add(Duration(days: i));
      if (date.isAfter(today)) return _DayState.future;
      var real = false;
      var skip = false;
      for (final c in widget.completions) {
        if (c.completedOn.year != date.year ||
            c.completedOn.month != date.month ||
            c.completedOn.day != date.day) {
          continue;
        }
        if (c.isSkip) {
          skip = true;
        } else if (!c.isNd) {
          real = true;
          break;
        }
      }
      if (real) {
        doneCount++;
        return _DayState.done;
      }
      return skip ? _DayState.rest : _DayState.quiet;
    });

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: context.appCardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'YOUR WEEK',
                style: AppTypography.caption.copyWith(
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  color: context.appTextSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '$doneCount of 7 days',
                style: AppTypography.caption
                    .copyWith(color: context.appTextTertiary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final isToday =
                  monday.add(Duration(days: i)).isAtSameMomentAs(today);
              return _DayDot(
                letter: _letters[i],
                state: days[i],
                isToday: isToday,
                pulse: isToday && !still ? _pulse : null,
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  final String letter;
  final _DayState state;
  final bool isToday;
  final Animation<double>? pulse;

  const _DayDot({
    required this.letter,
    required this.state,
    required this.isToday,
    this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Widget? glyph;
    switch (state) {
      case _DayState.done:
        fill = AppColors.primary;
        glyph =
            const Icon(Icons.check_rounded, size: 15, color: Colors.white);
      case _DayState.rest:
        fill = context.appTextTertiary.withValues(alpha: 0.35);
        glyph = const Icon(Icons.remove_rounded,
            size: 14, color: Colors.white);
      case _DayState.quiet:
      case _DayState.future:
        fill = Colors.transparent;
        glyph = null;
    }

    final dot = Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: fill == Colors.transparent
            ? Border.all(
                color: state == _DayState.future
                    ? context.appBorder.withValues(alpha: 0.5)
                    : context.appBorder,
                width: 1.5,
              )
            : null,
      ),
      child: glyph,
    );

    // Today: a breathing outline ring around the dot.
    final Widget marked;
    if (isToday && pulse != null) {
      marked = AnimatedBuilder(
        animation: pulse!,
        builder: (_, child) => Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary
                  .withValues(alpha: 0.35 + 0.45 * pulse!.value),
              width: 2,
            ),
          ),
          child: child,
        ),
        child: dot,
      );
    } else if (isToday) {
      marked = Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 2),
        ),
        child: dot,
      );
    } else {
      marked = Padding(padding: const EdgeInsets.all(4), child: dot);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        marked,
        const SizedBox(height: 4),
        Text(
          letter,
          style: AppTypography.caption.copyWith(
            fontSize: 10,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            color: isToday
                ? AppColors.primary
                : context.appTextTertiary,
          ),
        ),
      ],
    );
  }
}
