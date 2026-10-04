import 'dart:convert';
import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../database/database.dart';
import 'app_prefs.dart';
import 'auth_service.dart';

/// What an automatic backup attempt did.
enum AutoBackupOutcome {
  succeeded,
  failed,

  /// The last good backup is recent enough; nothing to do.
  skippedFresh,

  /// A recent attempt failed; waiting before hitting Drive again.
  skippedThrottled,

  /// Another attempt is already running in this isolate.
  skippedBusy,
}

/// Backup the user's app data to a JSON file in their Google Drive AppData
/// folder. AppData is a hidden, app-scoped folder — only this app can read
/// it, but the user owns the file (visible in Drive's "Manage apps" panel).
///
/// We export each table to JSON via Drift's auto-generated `toJson` /
/// `fromJson` on data classes, then upload one combined JSON document.
/// On restore, we wipe local rows and re-insert — atomic via a transaction.
class BackupService {
  BackupService._();

  static const _backupFileName = 'habit_reward_tracker.json';

  // ── JSON ↔ database ────────────────────────────────────────────────────────

  static Future<String> exportToJson(AppDatabase db) async {
    final milestones = await db.select(db.milestones).get();
    final tasks = await db.select(db.tasks).get();
    final completions = await db.select(db.taskCompletions).get();
    final points = await db.select(db.pointsHistoryTable).get();
    final rewards = await db.select(db.rewards).get();
    final streak = await db.select(db.streakTable).getSingleOrNull();

    final data = <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'milestones': milestones.map((m) => m.toJson()).toList(),
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'taskCompletions': completions.map((c) => c.toJson()).toList(),
      'pointsHistory': points.map((p) => p.toJson()).toList(),
      'rewards': rewards.map((r) => r.toJson()).toList(),
      if (streak != null) 'streak': streak.toJson(),
    };
    return jsonEncode(data);
  }

  static Future<void> importFromJson(AppDatabase db, String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    await db.transaction(() async {
      // Delete in reverse FK order.
      await db.delete(db.pointsHistoryTable).go();
      await db.delete(db.taskCompletions).go();
      await db.delete(db.tasks).go();
      await db.delete(db.rewards).go();
      await db.delete(db.milestones).go();

      // Insert in FK order.
      for (final m in (data['milestones'] as List? ?? [])) {
        await db.into(db.milestones).insert(
              Milestone.fromJson(m as Map<String, dynamic>).toCompanion(true),
            );
      }
      for (final t in (data['tasks'] as List? ?? [])) {
        await db.into(db.tasks).insert(
              Task.fromJson(t as Map<String, dynamic>).toCompanion(true),
            );
      }
      for (final c in (data['taskCompletions'] as List? ?? [])) {
        await db.into(db.taskCompletions).insert(
              TaskCompletion.fromJson(c as Map<String, dynamic>)
                  .toCompanion(true),
            );
      }
      for (final p in (data['pointsHistory'] as List? ?? [])) {
        await db.into(db.pointsHistoryTable).insert(
              PointsHistory.fromJson(p as Map<String, dynamic>)
                  .toCompanion(true),
            );
      }
      for (final r in (data['rewards'] as List? ?? [])) {
        await db.into(db.rewards).insert(
              Reward.fromJson(r as Map<String, dynamic>).toCompanion(true),
            );
      }

      // Streak singleton: replace, don't insert.
      final streakJson = data['streak'];
      if (streakJson != null) {
        final s = Streak.fromJson(streakJson as Map<String, dynamic>);
        await db.update(db.streakTable).replace(s);
      }
    });
  }

  // ── Drive integration ─────────────────────────────────────────────────────

  static Future<drive.DriveApi> _driveApi() async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw const _BackupException('Not signed in');
    }
    final headers = await user.authHeaders;
    return drive.DriveApi(_AuthClient(headers));
  }

  static Future<String?> _findBackupFileId(drive.DriveApi api) async {
    final list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName'",
      $fields: 'files(id)',
    );
    final files = list.files ?? [];
    if (files.isEmpty) return null;
    return files.first.id;
  }

  /// Returns the modifiedTime of the latest backup, or null if none exists.
  static Future<DateTime?> lastBackupAt() async {
    if (AuthService.currentUser == null) return null;
    final api = await _driveApi();
    final list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName'",
      $fields: 'files(id, modifiedTime)',
    );
    final files = list.files ?? [];
    if (files.isEmpty) return null;
    return files.first.modifiedTime;
  }

  /// Push the local DB to Drive. Creates or updates the backup file, and
  /// records the outcome locally so automatic backup knows when it is due.
  static Future<void> backup(AppDatabase db) async {
    try {
      await _upload(db);
      await AppPrefs.recordBackupSuccess(DateTime.now());
    } catch (e) {
      await AppPrefs.recordBackupFailure(describeError(e), DateTime.now());
      rethrow;
    }
  }

  // ── Automatic backup ──────────────────────────────────────────────────────

  static bool _inFlight = false;

  /// Back up only if the last successful backup is older than [maxAge] (or
  /// there has never been one). Never throws: the outcome is returned and
  /// recorded in AppPrefs, because callers are the app opening and a
  /// background task - neither has anyone to show an exception to.
  ///
  /// [force] skips the staleness check; the nightly run uses it, because a
  /// backup at 2 AM is the whole point of that run even if one happened
  /// yesterday evening.
  static Future<AutoBackupOutcome> backupIfDue(
    AppDatabase db, {
    Duration maxAge = const Duration(hours: 24),
    bool force = false,
  }) async {
    if (_inFlight) return AutoBackupOutcome.skippedBusy;
    await AppPrefs.reloadBackupState();
    final now = DateTime.now();

    if (!force &&
        !isBackupDue(
            lastSuccess: AppPrefs.backupLastSuccessSync,
            now: now,
            maxAge: maxAge)) {
      return AutoBackupOutcome.skippedFresh;
    }
    // A failed attempt is not retried on every app resume - that would hit
    // Drive repeatedly while offline. The nightly run ignores this throttle.
    if (!force &&
        recentlyFailed(
            lastErrorAt: AppPrefs.backupLastErrorAtSync, now: now)) {
      return AutoBackupOutcome.skippedThrottled;
    }

    _inFlight = true;
    try {
      if (AuthService.currentUser == null) {
        await AuthService.trySilentSignIn();
      }
      if (AuthService.currentUser == null) {
        await AppPrefs.recordBackupFailure(
            'Not signed in to Google', DateTime.now());
        return AutoBackupOutcome.failed;
      }
      await backup(db);
      return AutoBackupOutcome.succeeded;
    } catch (_) {
      // backup() already recorded the reason.
      return AutoBackupOutcome.failed;
    } finally {
      _inFlight = false;
    }
  }

  /// Is a backup overdue? Pure, so it can be tested without Drive.
  static bool isBackupDue({
    required DateTime? lastSuccess,
    required DateTime now,
    Duration maxAge = const Duration(hours: 24),
  }) {
    if (lastSuccess == null) return true;
    // A clock moved backwards makes the age negative; treat that as due
    // rather than trusting a backup timestamped in the future.
    final age = now.difference(lastSuccess);
    return age.isNegative || age >= maxAge;
  }

  /// Back off for half an hour after a failure before trying again on
  /// app open.
  static bool recentlyFailed({
    required DateTime? lastErrorAt,
    required DateTime now,
    Duration window = const Duration(minutes: 30),
  }) {
    if (lastErrorAt == null) return false;
    final since = now.difference(lastErrorAt);
    return !since.isNegative && since < window;
  }

  /// Turn a Drive / auth / socket exception into one short line a person can
  /// act on. The raw text of these is usually a stack-shaped wall.
  static String describeError(Object e) {
    final s = e.toString();
    final lower = s.toLowerCase();
    if (e is _BackupException) return e.message;
    if (lower.contains('socket') ||
        lower.contains('failed host lookup') ||
        lower.contains('network') ||
        lower.contains('connection')) {
      return 'No internet connection';
    }
    if (lower.contains('401') ||
        lower.contains('invalid_grant') ||
        lower.contains('unauthenticated') ||
        lower.contains('sign_in')) {
      return 'Google sign-in expired - sign in again';
    }
    if (lower.contains('403') || lower.contains('quota')) {
      return 'Google Drive refused the upload (storage or quota)';
    }
    return s.length > 120 ? '${s.substring(0, 117)}...' : s;
  }

  static Future<void> _upload(AppDatabase db) async {
    final api = await _driveApi();
    final json = await exportToJson(db);
    final bytes = utf8.encode(json);
    final media = drive.Media(Stream.value(bytes), bytes.length);

    final existingId = await _findBackupFileId(api);
    if (existingId != null) {
      await api.files.update(drive.File(), existingId, uploadMedia: media);
    } else {
      await api.files.create(
        drive.File()
          ..name = _backupFileName
          ..parents = ['appDataFolder'],
        uploadMedia: media,
      );
    }
  }

  /// Download the backup from Drive and overwrite local data. Throws if no
  /// backup exists.
  static Future<void> restore(AppDatabase db) async {
    final api = await _driveApi();
    final existingId = await _findBackupFileId(api);
    if (existingId == null) {
      throw const _BackupException('No backup found in Drive');
    }
    final media = await api.files.get(
      existingId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final builder = BytesBuilder();
    await for (final chunk in media.stream) {
      builder.add(chunk);
    }
    final json = utf8.decode(builder.toBytes());
    await importFromJson(db, json);
  }
}

class _BackupException implements Exception {
  final String message;
  const _BackupException(this.message);
  @override
  String toString() => message;
}

class _AuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _AuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}
