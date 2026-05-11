import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../database/database.dart';
import 'auth_service.dart';

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

  /// Push the local DB to Drive. Creates or updates the backup file.
  static Future<void> backup(AppDatabase db) async {
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
