import 'dart:async';

/// Broadcast bus for "an action just happened via notification" events. The
/// notification-action handler posts here; the top-level ScaffoldMessenger
/// listener shows an in-app snackbar in response. Replaces the second
/// "✓ Logged" notification we used to fire — the app is already opening from
/// the button tap, so in-app UI is the right surface.
class NotificationFeedback {
  NotificationFeedback._();

  static final StreamController<NotificationFeedbackEvent> _controller =
      StreamController.broadcast();
  static final List<NotificationFeedbackEvent> _pending = [];

  static Stream<NotificationFeedbackEvent> get stream => _controller.stream;

  /// Post an event. If the UI hasn't subscribed yet (typical on cold-start
  /// where the notification tap runs before MaterialApp.initState), buffer it
  /// and replay on [drain].
  static void post(NotificationFeedbackEvent event) {
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

enum FeedbackKind { done, skip, snooze }

class NotificationFeedbackEvent {
  final FeedbackKind kind;
  final String taskName;
  final int points;
  final String? undoCompletionId;
  final String taskId;

  /// For [FeedbackKind.snooze] only — when the re-fire is scheduled for.
  final DateTime? snoozedUntil;

  const NotificationFeedbackEvent({
    required this.kind,
    required this.taskName,
    required this.points,
    required this.taskId,
    this.undoCompletionId,
    this.snoozedUntil,
  });
}
