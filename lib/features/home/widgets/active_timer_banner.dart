import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/services/timer_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_colors.dart';
import '../../../shared/providers/active_timer_provider.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../shared/widgets/stop_timer_sheet.dart';

/// Pinned live-timer strip on Home. Shows ONLY the ticking session — paused
/// work lives in its own task row, so this slot always answers exactly one
/// question: what am I doing right now?
///
/// The 1s ticker is UI-only — every tick recomputes elapsed from wall clock,
/// so backgrounding/process death needs no lifecycle bookkeeping: the first
/// frame after a cold start is already correct.
class ActiveTimerBanner extends ConsumerStatefulWidget {
  const ActiveTimerBanner({super.key});

  @override
  ConsumerState<ActiveTimerBanner> createState() => _ActiveTimerBannerState();
}

class _ActiveTimerBannerState extends ConsumerState<ActiveTimerBanner> {
  Timer? _ticker;

  /// Task ids we've already run the "is this really gone?" check for —
  /// build can fire many times inside the window before the clear lands, and
  /// each pass would otherwise write its own ledger row and snackbar.
  final Set<String> _vanishChecked = {};

  /// Confirms against the database before destroying a session. Archived
  /// tasks are missing from allTasksProvider but very much still exist.
  Future<void> _checkVanished(String taskId) async {
    if (!_vanishChecked.add(taskId)) return;
    final db = ref.read(databaseProvider);
    final row = await db.getTaskById(taskId);
    if (row != null) return; // archived, not deleted — leave the clock alone
    if (TimerService.forTask(taskId) == null) return;
    await TimerService.clear(taskId, kind: TimerEventKind.vanished);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That task vanished — timer cleared.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && TimerService.running != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(runningTimerProvider);
    if (timer == null) return const SizedBox.shrink();

    final tasks = ref.watch(allTasksProvider).valueOrNull;
    // Tasks not loaded yet — render nothing this frame rather than flashing
    // a "vanished" state.
    if (tasks == null) return const SizedBox.shrink();

    final task = tasks.where((t) => t.id == timer.taskId).firstOrNull;
    if (task == null) {
      // Not in the active list. That is NOT proof the task is gone —
      // allTasksProvider filters out archived tasks, and archiving one must
      // never silently destroy the time on its clock. Ask the database, and
      // only clear if the row is really missing (milestone cascade delete).
      _checkVanished(timer.taskId);
      return const SizedBox.shrink();
    }

    final capped = TimerService.cappedElapsedSeconds(timer);
    const accent = AppColors.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_rounded, size: 20, color: accent),
            const SizedBox(width: 10),
            // The name + clock area opens the stop sheet; the two buttons
            // own their own taps, so PAUSE can never be a mis-hit STOP.
            Expanded(
              child: InkWell(
                onTap: () => showStopTimerSheet(context, ref),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.appTextPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        TimerService.formatElapsed(capped),
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // PAUSE and STOP are deliberately the same size and weight.
            // Pausing is the commoner, safer action — it must never read as
            // the lesser button next to a big filled STOP.
            _BannerAction(
              label: 'PAUSE',
              icon: Icons.pause_rounded,
              filled: false,
              color: accent,
              onPressed: () async {
                await TimerService.pause(task.id, taskName: task.name);
                HapticFeedback.lightImpact();
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(width: 6),
            _BannerAction(
              label: 'STOP',
              icon: Icons.stop_rounded,
              filled: true,
              color: accent,
              onPressed: () => showStopTimerSheet(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

/// Matched-mass banner button: same height, same padding, same type — only
/// the fill differs, so neither action swallows the other.
class _BannerAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final Color color;
  final VoidCallback onPressed;

  const _BannerAction({
    required this.label,
    required this.icon,
    required this.filled,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : color;
    return Material(
      color: filled ? color : color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40, minWidth: 76),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: filled
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.55)),
                ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
