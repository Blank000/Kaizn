import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/database.dart';
import '../../core/services/app_prefs.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/auto_backup.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/notification_service.dart';
import '../ai/ai_client.dart';

/// "Erase all data" in Settings - the user deleting everything Zuzu holds
/// about them (Google Play requires apps with sign-in to offer this).
///
/// Order matters. The copies elsewhere go first, while the user is still
/// signed in: once signed out, Zuzu can no longer reach their Drive backup
/// or prove to the server who they are. If either can't be reached, nothing
/// is erased, so the user can simply try again instead of being left with
/// an orphaned backup they can't remove from the app.
class EraseData {
  EraseData._();

  /// Erases everything, or returns what couldn't be reached (and erases
  /// nothing).
  static Future<String?> eraseEverything(AppDatabase db) async {
    if (!await AiClient.deleteServerData()) {
      return "Couldn't reach Zuzu's AI server.";
    }
    try {
      await BackupService.deleteBackup();
    } catch (_) {
      return "Couldn't reach your Google Drive backup.";
    }

    await NotificationService.cancelAll();
    await AutoBackup.cancel();
    await db.eraseAllRows();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await AppPrefs.hydrate();
    // Disconnect, not just sign out: it also revokes the Drive access the
    // user granted Zuzu.
    try {
      await AuthService.signOut();
    } catch (_) {}
    return null;
  }
}
