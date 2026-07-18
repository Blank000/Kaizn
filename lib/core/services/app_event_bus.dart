import 'dart:async';

/// App-wide domain event bus (architecture_vision.md §2, decision 2).
///
/// Services post events here; subscribers (the snackbar renderer in app.dart
/// today; widgets, connectors, sync tomorrow) react without the poster
/// knowing they exist. Grown from the old NotificationFeedback bus — the
/// buffering contract is unchanged: events posted before the UI subscribes
/// (cold-start from a notification tap) are held and replayed on [drain].
class AppEventBus {
  AppEventBus._();

  static final StreamController<AppEvent> _controller =
      StreamController.broadcast();
  static final List<AppEvent> _pending = [];

  static Stream<AppEvent> get stream => _controller.stream;

  /// Post an event. Buffered if nothing is listening yet.
  static void post(AppEvent event) {
    if (_controller.hasListener) {
      _controller.add(event);
    } else {
      _pending.add(event);
    }
  }

  /// Replay buffered events. Called once by the UI subscriber right after it
  /// starts listening.
  static void drain() {
    for (final e in _pending) {
      _controller.add(e);
    }
    _pending.clear();
  }
}

/// Base type for everything on the bus. New event families (StreakAdvanced,
/// TimerStarted, SyncCompleted…) subclass this — subscribers filter with
/// `stream.where((e) => e is X)`.
sealed class AppEvent {
  const AppEvent();
}

enum TaskActionKind { done, skip, snooze }

/// A task was acted on (completed / skipped / snoozed) from any surface —
/// tile tap, weekly chip, timeline card, or notification button. Carries
/// everything the feedback snackbar needs so the renderer stays synchronous
/// and DB-free.
class TaskActionEvent extends AppEvent {
  final TaskActionKind kind;
  final String taskId;
  final String taskName;

  /// Base points earned (0 for skip/snooze).
  final int points;

  /// Extra points from a clutch completion (last-call feature; 0 until then).
  final int clutchBonus;

  /// Stopwatch seconds attached to this completion, if any.
  final int? durationSeconds;

  /// Name of the first task stacked after this one (habit stacking), if any.
  final String? nextStackedTaskName;

  /// Identity-vote line ("Another vote for becoming a runner"), if this
  /// completion is a vote moment.
  final String? identityLine;

  /// Completion row id, so the snackbar UNDO can reverse exactly this action.
  final String? undoCompletionId;

  /// For [TaskActionKind.snooze] only — when the re-fire is scheduled.
  final DateTime? snoozedUntil;

  const TaskActionEvent({
    required this.kind,
    required this.taskId,
    required this.taskName,
    this.points = 0,
    this.clutchBonus = 0,
    this.durationSeconds,
    this.nextStackedTaskName,
    this.identityLine,
    this.undoCompletionId,
    this.snoozedUntil,
  });
}
