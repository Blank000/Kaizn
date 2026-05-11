import '../../core/database/database.dart';
import '../../core/services/app_prefs.dart';
import '../../core/services/shield_service.dart';

/// Detects rewards that *just* became claimable due to a points change.
///
/// Tracks "announced" reward IDs in SharedPrefs so each reward only triggers
/// its unlock snackbar once. If the user's balance later dips and re-crosses
/// the same reward's threshold, no re-announcement.
class RewardUnlockService {
  /// Call after any action that increases the user's points balance
  /// (task completion, milestone bonus). Returns rewards that became
  /// claimable AND haven't been announced before; marks them announced
  /// before returning.
  static Future<List<Reward>> checkAfterPointsChange(AppDatabase db) async {
    final dbTotal = await db.getTotalPoints();
    final shieldSpent = await ShieldService.getTotalSpent();
    final balance = dbTotal - shieldSpent;

    final unclaimed = await db.getUnclaimedRewards();
    final claimable =
        unclaimed.where((r) => balance >= r.pointsThreshold).toList();
    if (claimable.isEmpty) return const [];

    final announced = await AppPrefs.getAnnouncedRewardIds();
    final newlyUnlocked =
        claimable.where((r) => !announced.contains(r.id)).toList();
    for (final r in newlyUnlocked) {
      await AppPrefs.markRewardAnnounced(r.id);
    }
    return newlyUnlocked;
  }
}
