import '../database/database.dart';

/// Identity-based habits (Atomic Habits): "every action is a vote for the
/// person you want to become." Milestones carry an optional identity
/// ("a runner"); every [cadence]-th real completion of a task under that
/// milestone swaps the done-snackbar title for a vote line.
///
/// Single owner of the cadence logic so TaskCompletionService stays a
/// one-liner call site.
class IdentityVoice {
  IdentityVoice._();

  static const int cadence = 3;

  /// Rotating template pool. Selection is deterministic per vote count —
  /// mirrors the notification scheduler's hash-rotation pattern, never random.
  static const _templates = [
    'Another vote for becoming %i',
    "That's a vote for becoming %i",
    'Vote cast. Becoming %i',
  ];

  /// One-shot carry: when a vote moment is masked by a celebration snackbar
  /// (badges/rewards win the slot), the vote fires on the NEXT completion
  /// instead of being dropped. Session-scoped in-memory flag — losing it on
  /// a process restart is acceptable.
  static bool _carriedVote = false;

  /// The vote line for this completion, or null when this isn't a vote
  /// moment. Call AFTER the completion insert (the just-logged row counts)
  /// and after celebration checks, passing [masked] = hasCelebration so a
  /// masked vote carries instead of rendering under a celebration.
  static Future<String?> voteLineFor(
    AppDatabase db,
    Task task, {
    required bool masked,
  }) async {
    final milestoneId = task.milestoneId;
    if (milestoneId == null) return null;
    final milestone = await db.getMilestoneById(milestoneId);
    final identity = milestone?.identity;
    if (identity == null || identity.isEmpty) return null;

    final count = await db.getRealCompletionCountForTask(task.id);
    final isVoteMoment = count > 0 && count % cadence == 0;
    if (!isVoteMoment && !_carriedVote) return null;

    if (masked) {
      // Celebration wins the snackbar slot — carry the vote forward so the
      // user's early vote moments (often masked by first badges) still land.
      _carriedVote = true;
      return null;
    }

    _carriedVote = false;
    final template = _templates[(count ~/ cadence) % _templates.length];
    return template.replaceAll('%i', identity);
  }
}
