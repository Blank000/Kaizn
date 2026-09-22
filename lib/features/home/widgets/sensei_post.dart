import 'package:flutter/material.dart';

import '../../../core/services/app_prefs.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_colors.dart';
import '../../../shared/widgets/zuzu_figure.dart';

/// The daily post — **Zuzu's** permanent station at the top of Home, and the
/// heart of the accountability job: he KNOWS today's plan and says so, by
/// name and by number, morning to night. Tap for the full day's ledger.
///
/// Contract: specific, watchful, never guilting. He states facts and hands
/// the day back to you.
///
/// Cast note: this was Ren's card until the "A Day With Zuzu" storyboard.
/// The split is now Zuzu owns the *daily* surface — invitation, first win,
/// day close — and Ren keeps *reflection*: focus sessions, misses,
/// comebacks and the Sunday review. The copy engine
/// (`ZuzuLines.accountability`) is unchanged; only the face and the voice
/// moved, because the lines are composed from real data and were never
/// character-specific.
class SenseiPost extends StatelessWidget {
  final String line;
  final VoidCallback onTap;

  /// Nothing recorded yet today — Zuzu plays the looping invitation rather
  /// than standing still. Any other state gets frame 0, which is the same
  /// neutral stance.
  final bool inviting;

  const SenseiPost({
    super.key,
    required this.line,
    required this.onTap,
    this.inviting = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!AppPrefs.renEnabledSync) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: context.appCardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(
            children: [
              ZuzuFigure(
                moment: ZuzuMoment.invitation,
                size: inviting ? 60 : 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  line,
                  style: AppTypography.body.copyWith(
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: context.appTextTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// The day's ledger — Zuzu's accounting, opened from the daily post. What
/// stands done, what remains (by name and size), what fell, this week's
/// claw. One button out: back to the day.
Future<void> showSenseiLedgerSheet(
  BuildContext context, {
  required int done,
  required List<({String name, int minutes})> remaining,
  required int missedToday,
  required int currentStreak,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: ctx.appCardSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ctx.appBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                  child: ZuzuFigure(
                      moment: ZuzuMoment.invitation, size: 88)),
              const SizedBox(height: 12),
              Center(
                child: Text("THE DAY'S LEDGER",
                    style: AppTypography.caption.copyWith(
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                      color: ctx.appTextSecondary,
                    )),
              ),
              const SizedBox(height: 14),
              _LedgerRow(
                icon: '✅',
                text: done == 0
                    ? 'Nothing logged yet'
                    : '$done ${done == 1 ? 'task' : 'tasks'} done',
              ),
              if (remaining.isEmpty)
                const _LedgerRow(icon: '🏁', text: 'Nothing remains')
              else ...[
                for (final r in remaining)
                  _LedgerRow(
                    icon: '⏳',
                    text:
                        '${r.name}${r.minutes > 0 ? ' · ~${r.minutes}m' : ''}',
                  ),
              ],
              if (missedToday > 0)
                _LedgerRow(
                    icon: '🌧',
                    text:
                        '$missedToday missed — data, not a verdict'),
              if (AppPrefs.weeklyClawSync != null)
                _LedgerRow(
                    icon: '🐤',
                    text: 'One claw: ${AppPrefs.weeklyClawSync}'),
              if (currentStreak > 0)
                _LedgerRow(
                    icon: '🔥', text: '$currentStreak-day streak alive'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('BACK TO IT'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LedgerRow extends StatelessWidget {
  final String icon;
  final String text;

  const _LedgerRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: AppTypography.body
                    .copyWith(color: context.appTextPrimary)),
          ),
        ],
      ),
    );
  }
}
