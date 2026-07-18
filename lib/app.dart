import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/notification_feedback.dart';
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
  StreamSubscription<NotificationFeedbackEvent>? _feedbackSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _feedbackSub = NotificationFeedback.stream.listen(_showFeedback);
    // Drain any events that fired before this listener subscribed (typical on
    // cold-start where the notification tap arrives before initState runs).
    NotificationFeedback.drain();
  }

  @override
  void dispose() {
    _feedbackSub?.cancel();
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

  /// Renders a gamified snackbar in response to Done/Skip taps from a
  /// notification. Also wires the UNDO button to reverse the completion.
  void _showFeedback(NotificationFeedbackEvent event) {
    // Defer to the next frame so a cold-start feedback event — posted BEFORE
    // MaterialApp has mounted its ScaffoldMessenger — still surfaces.
    WidgetsBinding.instance.addPostFrameCallback((_) => _renderFeedback(event));
  }

  void _renderFeedback(NotificationFeedbackEvent event) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();

    late final Color bg;
    late final IconData icon;
    late final String title;
    late final String trailing;

    switch (event.kind) {
      case FeedbackKind.done:
        bg = AppColors.primary;
        icon = Icons.check_circle_rounded;
        title = 'Logged "${event.taskName}"';
        trailing = event.points > 0 ? '+${event.points} pts 🔥' : 'Nice work';
      case FeedbackKind.skip:
        bg = Colors.grey.shade700;
        icon = Icons.remove_circle_rounded;
        title = 'Skipped "${event.taskName}"';
        trailing = 'Streak preserved';
      case FeedbackKind.snooze:
        bg = Colors.blueGrey.shade700;
        icon = Icons.snooze_rounded;
        title = 'Snoozed "${event.taskName}"';
        final when = event.snoozedUntil;
        trailing = when == null
            ? "We'll remind you soon"
            : "Reminds again at ${_fmtClock(when)}";
    }

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

  String _fmtClock(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final hh = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final ampm = h < 12 ? 'AM' : 'PM';
    return '$hh:$m $ampm';
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
