import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../database/database.dart';
import 'app_prefs.dart';
import 'auth_service.dart';
import 'backup_service.dart';

/// Automatic Google Drive backup. Two layers, deliberately:
///
/// 1. **Nightly, around 2 AM** - an Android WorkManager job that wakes the
///    app in the background, waits for a network connection, and uploads.
///    This is best-effort. Vivo / iQOO's Funtouch OS (the owner's phone) is
///    notorious for killing background work, and a phone that is off or in
///    airplane mode at 2 AM simply won't run it.
///
/// 2. **Catch-up whenever the app opens or returns to the foreground** - if
///    the last successful backup is more than 24 hours old, back up right
///    then. This is the guarantee: a habit app gets opened every day, so
///    the backup can never be more than one app-open stale for long.
///
/// If the catch-up fails while the backup is already over a day old, the
/// user gets one non-blocking snackbar that day saying so, and Settings
/// shows exactly why. Silent failure was the original bug.
///
/// iOS: WorkManager-style exact scheduling does not exist there; iOS decides
/// when background tasks run. The nightly job is Android-only and iOS relies
/// on layer 2.
class AutoBackup {
  AutoBackup._();

  /// Versioned so a future change to the schedule can retire the old job
  /// instead of silently keeping it (the policy below is `keep`).
  static const uniqueName = 'zuzu.nightlyBackup.v1';
  static const taskName = 'zuzu.nightlyBackup';

  /// The hour the nightly job aims for.
  static const targetHour = 2;

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  /// Call once from `main()`. Registers the background entry point and makes
  /// sure the nightly job exists. Safe to call on every launch.
  static Future<void> init() async {
    if (!_supported) return;
    try {
      await Workmanager().initialize(autoBackupDispatcher);
      await Workmanager().registerPeriodicTask(
        uniqueName,
        taskName,
        frequency: const Duration(hours: 24),
        // Anchor the first run at the next 2 AM. With the `keep` policy the
        // anchor survives every later app launch instead of drifting to
        // "24 hours after whenever the app was last opened".
        initialDelay: delayUntilNext(DateTime.now(), hour: targetHour),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(
          // Wait for any connection rather than failing on a dark 2 AM
          // network; WorkManager runs the job as soon as one appears.
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 15),
      );
    } catch (e) {
      // Never let backup scheduling stop the app from launching.
      debugPrint('AutoBackup.init failed: $e');
    }
  }

  /// Stops the nightly job. Used by "Erase all data".
  static Future<void> cancel() async {
    if (!_supported) return;
    try {
      await Workmanager().cancelByUniqueName(uniqueName);
    } catch (_) {}
  }

  /// Time from [now] until the next occurrence of [hour]:00. Pure, so the
  /// anchoring maths is testable.
  static Duration delayUntilNext(DateTime now, {required int hour}) {
    var next = DateTime(now.year, now.month, now.day, hour);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next.difference(now);
  }

  /// Should the user be told the backup is stale? Only when it actually is
  /// (over a day old, or never succeeded), only once per day.
  static bool shouldWarnStale({
    required DateTime? lastSuccess,
    required DateTime? warnedOn,
    required DateTime now,
  }) {
    final stale = BackupService.isBackupDue(lastSuccess: lastSuccess, now: now);
    if (!stale) return false;
    if (warnedOn == null) return true;
    final today = DateTime(now.year, now.month, now.day);
    return warnedOn.isBefore(today);
  }
}

/// Background entry point. Runs in a fresh isolate with no app state: every
/// plugin, every pref and the database have to be brought up here.
@pragma('vm:entry-point')
void autoBackupDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != AutoBackup.taskName) return true;

    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    await AppPrefs.hydrate();
    await AuthService.trySilentSignIn();

    final db = AppDatabase();
    try {
      final outcome = await BackupService.backupIfDue(db, force: true);
      // Returning false asks WorkManager to retry with backoff - right for a
      // network blip, which is the commonest 2 AM failure. Not signed in is
      // not worth retrying; the app-open catch-up will surface it.
      if (outcome == AutoBackupOutcome.failed) {
        return AuthService.currentUser == null;
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      await db.close();
    }
  });
}
