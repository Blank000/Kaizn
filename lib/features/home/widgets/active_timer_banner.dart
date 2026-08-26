import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/timer_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_colors.dart';
import '../../../shared/providers/active_timer_provider.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../shared/widgets/stop_timer_sheet.dart';

/// Pinned live-timer strip on Home (both view modes). Renders nothing when
/// no timer runs. The 1s ticker is UI-only — every tick recomputes elapsed
/// from wall clock, so backgrounding/process death needs no lifecycle
/// bookkeeping: the first frame after a cold start is already correct.
class ActiveTimerBanner extends ConsumerStatefulWidget {
  const ActiveTimerBanner({super.key});

  @override
  ConsumerState<ActiveTimerBanner> createState() => _ActiveTimerBannerState();
}

class _ActiveTimerBannerState extends ConsumerState<ActiveTimerBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && TimerService.current != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(activeTimerProvider).valueOrNull;
    if (timer == null) return const SizedBox.shrink();

    final tasks = ref.watch(allTasksProvider).valueOrNull;
    // Tasks not loaded yet — render nothing this frame rather than flashing
    // a "vanished" state.
    if (tasks == null) return const SizedBox.shrink();

    final task = tasks.where((t) => t.id == timer.taskId).firstOrNull;
    if (task == null) {
      // Timer's task was deleted (e.g. milestone cascade). Clear once,
      // post-frame, and tell the user.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (TimerService.current?.taskId == timer.taskId) {
          await TimerService.clear();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('That task vanished — timer cleared.')),
            );
          }
        }
      });
      return const SizedBox.shrink();
    }

    final capped = TimerService.cappedElapsedSeconds(timer);
    final paused = timer.isPaused;
    // Paused must be GLANCEABLE: the whole strip goes quiet-gray, the clock
    // freezes, and the label says so.
    final accent = paused ? context.appTextTertiary : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: InkWell(
        onTap: () => showStopTimerSheet(context, ref),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accent.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Icon(paused ? Icons.pause_circle_rounded : Icons.timer_rounded,
                  size: 20, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.appTextPrimary,
                      ),
                    ),
                    if (paused)
                      Text(
                        'Paused — tap ▶ to keep going',
                        style: AppTypography.caption
                            .copyWith(color: context.appTextSecondary),
                      ),
                  ],
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
              // Pause/resume — always manual, never automatic.
              IconButton(
                icon: Icon(
                  paused
                      ? Icons.play_circle_fill_rounded
                      : Icons.pause_circle_filled_rounded,
                  size: 26,
                  color: paused ? AppColors.primary : accent,
                ),
                tooltip: paused ? 'Resume timer' : 'Pause timer',
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  if (paused) {
                    await TimerService.resume();
                  } else {
                    await TimerService.pause();
                  }
                  if (mounted) setState(() {});
                },
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      paused ? context.appTextTertiary : AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => showStopTimerSheet(context, ref),
                child: const Text('STOP'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
