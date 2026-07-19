import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/app_event_bus.dart';
import 'core/services/notification_scheduler.dart';
import 'core/services/widget_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/database_provider.dart';
import 'shared/providers/router_provider.dart';
import 'shared/providers/theme_mode_provider.dart';

/// Root ScaffoldMessenger key so background systems (notification action
/// handlers, in particular) can show snackbars without needing a BuildContext
/// from the current route.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Main app widget with Riverpod, go_router, and theme setup
class HabitRewardTrackerApp extends ConsumerStatefulWidget {
  const HabitRewardTrackerApp({super.key});

  @override
  ConsumerState<HabitRewardTrackerApp> createState() =>
      _HabitRewardTrackerAppState();
}

class _HabitRewardTrackerAppState extends ConsumerState<HabitRewardTrackerApp>
    with WidgetsBindingObserver {
  StreamSubscription<AppEvent>? _eventSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _eventSub = AppEventBus.stream.listen(_onAppEvent);
    // Drain any events that fired before this listener subscribed (typical on
    // cold-start where the notification tap arrives before initState runs).
    AppEventBus.drain();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh the launcher widget when the user returns to the app — most
      // common moment for stale data.
      WidgetService.refresh();
      // Re-evaluate notifications against the latest data (e.g. drop today's
      // evening nudge if something was logged, pick up new/edited tasks).
      NotificationScheduler.reschedule();
    }
  }

  void _onAppEvent(AppEvent event) {
    // Only task-action events render UI today; future event families
    // (StreakAdvanced, SyncCompleted…) get their own handlers here.
    if (event is TaskActionEvent) {
      // Defer to the next frame so a cold-start event — posted BEFORE
      // MaterialApp has mounted its ScaffoldMessenger — still surfaces.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _renderTaskAction(event));
    }
  }

  /// Renders the gamified feedback snackbar for a task action, wiring the
  /// UNDO button to reverse the completion.
  void _renderTaskAction(TaskActionEvent event) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();

    final (icon, title, trailing, bg) = _composeSnackContent(event);

    messenger.showSnackBar(SnackBar(
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  trailing,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      action: event.undoCompletionId == null
          ? null
          : SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () async {
                final db = ref.read(databaseProvider);
                await db.undoCompletion(
                    event.undoCompletionId!, event.taskId);
              },
            ),
    ));
  }

  /// THE snackbar composition rule (architecture_vision.md §5, "one attention
  /// slot"). Multiple features decorate the same done-snackbar; this is the
  /// single place that arbitrates so they can never clobber each other:
  ///   - Title: exactly one, by precedence
  ///       identity vote > clutch > default "Logged X".
  ///   - Trailing: ordered join of present segments
  ///       points(+bonus) · ⏱ duration · Next: stacked 🔗 — ellipsized.
  ///   - Icon: vote > bolt (clutch) > check.
  /// Pure function — unit-testable with fabricated events.
  (IconData, String, String, Color) _composeSnackContent(
      TaskActionEvent event) {
    switch (event.kind) {
      case TaskActionKind.skip:
        return (
          Icons.remove_circle_rounded,
          'Skipped "${event.taskName}"',
          'Streak preserved',
          Colors.grey.shade700,
        );
      case TaskActionKind.snooze:
        final when = event.snoozedUntil;
        return (
          Icons.snooze_rounded,
          'Snoozed "${event.taskName}"',
          when == null
              ? "We'll remind you soon"
              : 'Reminds again at ${_fmtClock(when)}',
          Colors.blueGrey.shade700,
        );
      case TaskActionKind.done:
        final isClutch = event.clutchBonus > 0;
        final title = event.identityLine ??
            (isClutch ? '⚡ Beat the clock!' : 'Logged "${event.taskName}"');
        final icon = event.identityLine != null
            ? Icons.how_to_vote_rounded
            : (isClutch ? Icons.bolt_rounded : Icons.check_circle_rounded);

        final segments = <String>[
          if (event.points > 0)
            '+${event.points} pts${isClutch ? ' +${event.clutchBonus} bonus ⚡' : ''}'
          else if (isClutch)
            '+${event.clutchBonus} bonus ⚡'
          else
            'Nice work',
          if (event.streakDay != null) '🔥 Day ${event.streakDay}',
          if (event.questBonus > 0) '🎯 Quest +${event.questBonus}',
          if (event.durationSeconds != null)
            '⏱ ${_fmtDuration(event.durationSeconds!)}',
          if (event.nextStackedTaskName != null)
            'Next: "${event.nextStackedTaskName}" 🔗',
        ];
        return (icon, title, segments.join(' · '), AppColors.primary);
    }
  }

  String _fmtClock(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final hh = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final ampm = h < 12 ? 'AM' : 'PM';
    return '$hh:$m $ampm';
  }

  String _fmtDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Habit Reward Tracker',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
