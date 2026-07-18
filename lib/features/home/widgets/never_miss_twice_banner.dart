import 'package:flutter/material.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_colors.dart';

/// Whether the never-miss-twice banner should show (Atomic Habits: one miss
/// is an accident, two is the start of a new habit — so the morning after a
/// miss is THE moment to nudge).
///
/// Pure and Riverpod-free so it's unit-testable with fabricated completions.
/// All comparisons are date-only.
///
/// Shows iff ALL of:
///  (a) no real completion today — the Drift stream re-emits the moment one
///      lands, so the banner auto-hides reactively;
///  (b) yesterday was a miss: no real completion AND no intentional skip
///      (skip's own copy promises "streak preserved" — nagging after a skip
///      would contradict the app's promise; an ND row or plain silence both
///      count as a miss);
///  (c) recent practice: ≥1 real completion in the 3 days before yesterday —
///      filters fresh installs (nothing to rescue) and long-lapsed users
///      (a guilt banner is the wrong welcome-back);
///  (d) something is due today — otherwise "one win today" is a dead CTA;
///  (e) no unspent dismissal. Dismissals are EPISODE-scoped: dismissing
///      suppresses the banner until the next real completion "spends" it,
///      so one bad Tuesday never nags three mornings straight.
bool shouldShowNeverMissTwice({
  required List<TaskCompletion> completions,
  required DateTime now,
  required bool hasUpNext,
  required DateTime? dismissedDate,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  bool isReal(TaskCompletion c) => !c.isSkip && !c.isNd;
  DateTime dayOf(TaskCompletion c) =>
      DateTime(c.completedOn.year, c.completedOn.month, c.completedOn.day);

  // (a) today already has a win.
  if (completions
      .any((c) => isReal(c) && dayOf(c).isAtSameMomentAs(today))) {
    return false;
  }

  // (b) yesterday must be an honest miss.
  final yesterdayReal = completions
      .any((c) => isReal(c) && dayOf(c).isAtSameMomentAs(yesterday));
  final yesterdaySkipped = completions
      .any((c) => c.isSkip && dayOf(c).isAtSameMomentAs(yesterday));
  if (yesterdayReal || yesterdaySkipped) return false;

  // (c) recent practice in the 3 days before yesterday.
  final windowStart = today.subtract(const Duration(days: 4));
  final hasRecentPractice = completions.any((c) {
    if (!isReal(c)) return false;
    final d = dayOf(c);
    return !d.isBefore(windowStart) && d.isBefore(yesterday);
  });
  if (!hasRecentPractice) return false;

  // (d) a win must be available today.
  if (!hasUpNext) return false;

  // (e) episode-scoped dismissal: spent only by a real completion on or
  // after the dismissal date.
  if (dismissedDate != null) {
    final spent = completions
        .any((c) => isReal(c) && !dayOf(c).isBefore(dismissedDate));
    if (!spent) return false;
  }

  return true;
}

/// Inline, dismissible "one win today" banner. Mounted above the Home body
/// (both List and Timeline modes), styled in streak orange to tie it to the
/// streak it protects.
class NeverMissTwiceBanner extends StatelessWidget {
  final int currentStreak;

  /// True on mornings the streak-reset popup already fired this session —
  /// the banner then uses forward-only copy instead of restating the miss
  /// (one message, two surfaces, zero repeated guilt).
  final bool freshStartCopy;
  final VoidCallback onDismiss;

  const NeverMissTwiceBanner({
    super.key,
    required this.currentStreak,
    required this.freshStartCopy,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final (title, body) = switch ((currentStreak > 0, freshStartCopy)) {
      (true, _) => (
          'Save your streak! 🔥',
          'One win today keeps your $currentStreak-day streak alive.',
        ),
      (false, true) => (
          'Never miss twice! 🔥',
          'One win today starts a new streak.',
        ),
      (false, false) => (
          'Never miss twice! 🔥',
          'Yesterday slipped by. One small win today puts you right back on track.',
        ),
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.streakOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.streakOrange.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: AppTypography.caption
                      .copyWith(color: context.appTextSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: context.appTextTertiary,
            tooltip: 'Hide until my next win',
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
