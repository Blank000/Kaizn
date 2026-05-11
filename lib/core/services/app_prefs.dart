import 'package:shared_preferences/shared_preferences.dart';

/// App-level user preferences stored in SharedPreferences.
class AppPrefs {
  static const _lastUsedMilestoneKey = 'last_used_milestone_id';
  static const _lastAppOpenDateKey = 'last_app_open_date';
  static const _inboxSeededKey = 'inbox_seeded';

  // ── Last-used milestone (for quick-add pre-selection) ────────────────────

  static Future<String?> getLastUsedMilestoneId() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_lastUsedMilestoneKey);
  }

  static Future<void> setLastUsedMilestoneId(String id) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_lastUsedMilestoneKey, id);
  }

  // ── Last app-open date (for once-a-day streak popup) ─────────────────────

  /// Returns the date the user last opened the app (date-only, local).
  /// Null on first ever launch.
  static Future<DateTime?> getLastAppOpenDate() async {
    final p = await SharedPreferences.getInstance();
    final iso = p.getString(_lastAppOpenDateKey);
    if (iso == null) return null;
    return DateTime.tryParse(iso);
  }

  static Future<void> setLastAppOpenDate(DateTime date) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final p = await SharedPreferences.getInstance();
    await p.setString(_lastAppOpenDateKey, dateOnly.toIso8601String());
  }

  // ── Inbox-seeded flag (true after the auto-create has run) ───────────────

  static Future<bool> isInboxSeeded() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_inboxSeededKey) ?? false;
  }

  static Future<void> markInboxSeeded() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_inboxSeededKey, true);
  }

  // ── Last-celebrated-all-done date (one celebration per day max) ──────────

  static const _lastAllDoneKey = 'last_all_done_celebration_date';

  static Future<DateTime?> getLastAllDoneCelebrationDate() async {
    final p = await SharedPreferences.getInstance();
    final iso = p.getString(_lastAllDoneKey);
    if (iso == null) return null;
    return DateTime.tryParse(iso);
  }

  static Future<void> setLastAllDoneCelebrationDate(DateTime date) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final p = await SharedPreferences.getInstance();
    await p.setString(_lastAllDoneKey, dateOnly.toIso8601String());
  }

  // ── Last day the streak counter was advanced ────────────────────────────
  // Tracked separately from `streak.lastLoggedDate` so that "skip first, real
  // completion later same day" still advances the streak on the real one.

  static const _lastStreakAdvanceKey = 'last_streak_advance_date';

  static Future<DateTime?> getLastStreakAdvanceDate() async {
    final p = await SharedPreferences.getInstance();
    final iso = p.getString(_lastStreakAdvanceKey);
    if (iso == null) return null;
    return DateTime.tryParse(iso);
  }

  static Future<void> setLastStreakAdvanceDate(DateTime date) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final p = await SharedPreferences.getInstance();
    await p.setString(_lastStreakAdvanceKey, dateOnly.toIso8601String());
  }

  // ── Onboarding-complete flag + theme mode ────────────────────────────────
  // Cached synchronously so the GoRouter redirect / MaterialApp.themeMode
  // can decide on first frame without awaiting SharedPreferences. Hydrate
  // via [hydrate] from main().

  static const _onboardingCompleteKey = 'onboarding_complete';
  static bool _onboardingCompleteCache = false;

  static const _themeModeKey = 'theme_mode';
  static String _themeModeCache = 'system'; // 'system' | 'light' | 'dark'

  /// Loads sync-cached prefs at app startup. Call from `main()` before
  /// `runApp`.
  static Future<void> hydrate() async {
    final p = await SharedPreferences.getInstance();
    _onboardingCompleteCache = p.getBool(_onboardingCompleteKey) ?? false;
    _themeModeCache = p.getString(_themeModeKey) ?? 'system';
  }

  static bool get isOnboardingCompleteSync => _onboardingCompleteCache;

  static Future<void> markOnboardingComplete() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_onboardingCompleteKey, true);
    _onboardingCompleteCache = true;
  }

  static String get themeModeSync => _themeModeCache;

  static Future<void> setThemeMode(String mode) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_themeModeKey, mode);
    _themeModeCache = mode;
  }

  // ── Announced reward IDs (so each reward unlock fires its snackbar once) ─

  static const _announcedRewardIdsKey = 'announced_reward_ids';

  static Future<Set<String>> getAnnouncedRewardIds() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_announcedRewardIdsKey) ?? const []).toSet();
  }

  static Future<void> markRewardAnnounced(String id) async {
    final p = await SharedPreferences.getInstance();
    final current = p.getStringList(_announcedRewardIdsKey)?.toList() ?? [];
    if (!current.contains(id)) {
      current.add(id);
      await p.setStringList(_announcedRewardIdsKey, current);
    }
  }
}
