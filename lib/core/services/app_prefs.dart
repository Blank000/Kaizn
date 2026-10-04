import 'dart:convert';

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

  static const _homeViewModeKey = 'home_view_mode';
  static String _homeViewModeCache = 'list'; // 'list' | 'timeline'

  static const _nmtDismissedKey = 'nmt_dismissed_date';
  static DateTime? _nmtDismissedCache;

  // Legacy single-timer keys (schema before multi-session). Read once at
  // hydrate to fold any in-flight timer into the new list, then removed.
  static const _activeTimerTaskIdKey = 'active_timer_task_id';
  static const _activeTimerStartedAtKey = 'active_timer_started_at_millis';
  static const _activeTimerAccumKey = 'active_timer_accum_seconds';
  static const _activeTimerPausedKey = 'active_timer_paused';

  /// JSON array of stopwatch sessions — see TimerService.
  static const _timerSessionsKey = 'timer_sessions_json';
  static String _timerSessionsCache = '[]';

  static const _coachDismissedKey = 'coach_dismissed_date';
  static DateTime? _coachDismissedCache;

  /// Loads sync-cached prefs at app startup. Call from `main()` before
  /// `runApp` — and from the notification background isolate before anything
  /// reads a sync getter there (the isolate shares no memory with the app).
  static Future<void> hydrate() async {
    final p = await SharedPreferences.getInstance();
    _onboardingCompleteCache = p.getBool(_onboardingCompleteKey) ?? false;
    _themeModeCache = p.getString(_themeModeKey) ?? 'system';
    _homeViewModeCache = p.getString(_homeViewModeKey) ?? 'list';
    final nmtIso = p.getString(_nmtDismissedKey);
    _nmtDismissedCache = nmtIso == null ? null : DateTime.tryParse(nmtIso);
    _timerSessionsCache = p.getString(_timerSessionsKey) ?? '[]';
    await _migrateLegacyTimer(p);
    final coachIso = p.getString(_coachDismissedKey);
    _coachDismissedCache = coachIso == null ? null : DateTime.tryParse(coachIso);
    _readBackupState(p);
    _readHomeSections(p);
    final restIso = p.getString(_restModeUntilKey);
    _restModeUntilCache = restIso == null ? null : DateTime.tryParse(restIso);
    _soundEnabledCache = p.getBool(_soundEnabledKey) ?? false;
    _zenEnabledCache = p.getBool(_zenEnabledKey) ?? true;
    _renEnabledCache = p.getBool(_renEnabledKey) ?? true;
    _weeklyClawCache = p.getString(_weeklyClawKey);
    _weeklyClawWeekCache = p.getString(_weeklyClawWeekKey);
    _aiApiKeyCache = p.getString(_aiApiKeyKey);
    _aiModelCache = p.getString(_aiModelKey) ?? 'gpt-4o-mini';
    _gcalEnabledCache = p.getBool(_gcalEnabledKey) ?? false;
    _gcalShowOnTimelineCache = p.getBool(_gcalShowOnTimelineKey) ?? true;
    _gcalCalendarIdsCache = p.getStringList(_gcalCalendarIdsKey) ?? const [];
  }

  // ── Google Calendar overlay ───────────────────────────────────────────────

  static const _gcalEnabledKey = 'gcal_enabled';
  static const _gcalShowOnTimelineKey = 'gcal_show_on_timeline';
  static const _gcalCalendarIdsKey = 'gcal_calendar_ids';
  static bool _gcalEnabledCache = false;
  static bool _gcalShowOnTimelineCache = true;
  static List<String> _gcalCalendarIdsCache = const [];

  /// Calendar access granted + connection switched on in Settings.
  static bool get gcalEnabledSync => _gcalEnabledCache;

  /// The timeline eye-toggle: overlay busy blocks on/off (default on).
  static bool get gcalShowOnTimelineSync => _gcalShowOnTimelineCache;

  /// Which calendars feed the overlay (calendar ids).
  static List<String> get gcalCalendarIdsSync => _gcalCalendarIdsCache;

  static Future<void> setGcalEnabled(bool enabled) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_gcalEnabledKey, enabled);
    _gcalEnabledCache = enabled;
  }

  static Future<void> setGcalShowOnTimeline(bool show) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_gcalShowOnTimelineKey, show);
    _gcalShowOnTimelineCache = show;
  }

  static Future<void> setGcalCalendarIds(List<String> ids) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_gcalCalendarIdsKey, ids);
    _gcalCalendarIdsCache = List.unmodifiable(ids);
  }

  // ── Sounds (OFF by default) + Zen the mascot (ON by default) ─────────────

  static const _soundEnabledKey = 'sound_enabled';
  static const _zenEnabledKey = 'zen_enabled';
  static bool _soundEnabledCache = false;
  static bool _zenEnabledCache = true;

  static bool get soundEnabledSync => _soundEnabledCache;
  static bool get zenEnabledSync => _zenEnabledCache;

  static Future<void> setSoundEnabled(bool on) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_soundEnabledKey, on);
    _soundEnabledCache = on;
  }

  static Future<void> setZenEnabled(bool on) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_zenEnabledKey, on);
    _zenEnabledCache = on;
  }

  // Zuzu the companion (ON by default). Gates every ZuzuFigure. Key name
  // keeps the old 'ren' spelling so nobody's saved preference resets.
  static const _renEnabledKey = 'ren_enabled';
  static bool _renEnabledCache = true;

  static bool get renEnabledSync => _renEnabledCache;

  static Future<void> setRenEnabled(bool on) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_renEnabledKey, on);
    _renEnabledCache = on;
  }

  // ── Ask Ren: OpenAI-compatible API access ────────────────────────────────
  // Key + model for the in-app assistant. SharedPreferences is acceptable
  // for a personal device; revisit with flutter_secure_storage before any
  // public release.
  static const _aiApiKeyKey = 'ai_api_key';
  static const _aiModelKey = 'ai_model';
  static String? _aiApiKeyCache;
  static String _aiModelCache = 'gpt-4o-mini';

  static String? get aiApiKeySync => _aiApiKeyCache;
  static String get aiModelSync => _aiModelCache;

  static Future<void> setAiApiKey(String? key) async {
    final p = await SharedPreferences.getInstance();
    if (key == null || key.isEmpty) {
      await p.remove(_aiApiKeyKey);
      _aiApiKeyCache = null;
    } else {
      await p.setString(_aiApiKeyKey, key);
      _aiApiKeyCache = key;
    }
  }

  static Future<void> setAiModel(String model) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_aiModelKey, model);
    _aiModelCache = model;
  }

  // ── Weekly review: "one claw" intention ──────────────────────────────────
  // Set in Zuzu's Sunday review; shown on the Home progress card during its
  // week. weekKey anchors weeks to the most recent Sunday.
  static const _weeklyClawKey = 'weekly_claw';
  static const _weeklyClawWeekKey = 'weekly_claw_week';
  static String? _weeklyClawCache;
  static String? _weeklyClawWeekCache;

  /// Sunday-anchored key for the week containing [d] (yyyy-mm-dd of Sunday).
  static String weekKeyFor(DateTime d) {
    final sunday = DateTime(d.year, d.month, d.day)
        .subtract(Duration(days: d.weekday % 7));
    return '${sunday.year}-${sunday.month.toString().padLeft(2, '0')}-${sunday.day.toString().padLeft(2, '0')}';
  }

  /// The intention, if one was stamped for the CURRENT week; else null.
  static String? get weeklyClawSync =>
      _weeklyClawWeekCache == weekKeyFor(DateTime.now())
          ? _weeklyClawCache
          : null;

  /// True if this week's review was already completed.
  static bool get weeklyReviewDoneSync =>
      _weeklyClawWeekCache == weekKeyFor(DateTime.now());

  static Future<void> setWeeklyClaw(String claw) async {
    final p = await SharedPreferences.getInstance();
    final week = weekKeyFor(DateTime.now());
    await p.setString(_weeklyClawKey, claw);
    await p.setString(_weeklyClawWeekKey, week);
    _weeklyClawCache = claw;
    _weeklyClawWeekCache = week;
  }

  // ── Rest mode (guilt-free multi-day pause) ────────────────────────────────
  // While today <= restModeUntil: streak treats the window as intentional
  // rest, notifications/quests/celebrations stand down. Expires by itself.

  static const _restModeUntilKey = 'rest_mode_until';
  static DateTime? _restModeUntilCache;

  /// Last day (inclusive, date-only) of the rest window; null = not resting.
  static DateTime? get restModeUntilSync => _restModeUntilCache;

  /// True while the rest window covers today.
  static bool get isRestingSync {
    final until = _restModeUntilCache;
    if (until == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !today.isAfter(DateTime(until.year, until.month, until.day));
  }

  static Future<void> setRestModeUntil(DateTime? date) async {
    final p = await SharedPreferences.getInstance();
    if (date == null) {
      await p.remove(_restModeUntilKey);
      _restModeUntilCache = null;
    } else {
      final dateOnly = DateTime(date.year, date.month, date.day);
      await p.setString(_restModeUntilKey, dateOnly.toIso8601String());
      _restModeUntilCache = dateOnly;
    }
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

  static String get homeViewModeSync => _homeViewModeCache;

  static Future<void> setHomeViewMode(String mode) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_homeViewModeKey, mode);
    _homeViewModeCache = mode;
  }

  /// Date the never-miss-twice banner was last dismissed (date-only). The
  /// dismissal is EPISODE-scoped, not day-scoped: the banner's predicate
  /// keeps it hidden until the next real completion "spends" the dismissal
  /// (see shouldShowNeverMissTwice) — one bad Tuesday never nags three
  /// mornings in a row.
  static DateTime? get nmtDismissedDateSync => _nmtDismissedCache;

  static Future<void> setNmtDismissedDate(DateTime date) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final p = await SharedPreferences.getInstance();
    await p.setString(_nmtDismissedKey, dateOnly.toIso8601String());
    _nmtDismissedCache = dateOnly;
  }

  // ── Stopwatch sessions ───────────────────────────────────────────────────
  // One JSON array IS the whole live-state persistence story: each entry is
  // {sessionId, taskId, startedAt, accum, paused}, and elapsed is always
  // recomputed on read as banked seconds + wall clock since the last resume.
  // No background service, nothing for an aggressive OEM to kill; a cold
  // start renders correctly on the first frame via the sync cache.
  //
  // Multiple sessions may exist (one per task) but at most one is unpaused —
  // TimerService owns that invariant. Pause is ALWAYS deliberate: the app
  // never auto-pauses on backgrounding (timing off-screen work is
  // legitimate; owner decision, do not "fix"). Starting a second task is the
  // one exception, and it is logged to the ledger as `auto_pause`.

  static String get timerSessionsJsonSync => _timerSessionsCache;

  static Future<void> setTimerSessionsJson(String json) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_timerSessionsKey, json);
    _timerSessionsCache = json;
  }

  /// Re-reads the sessions from disk before a mutation.
  ///
  /// The sync cache is per-isolate, and the notification background isolate
  /// writes to the same key (a "Done" tap ends a running session). Without
  /// this, the foreground's next write would resurrect a session the
  /// background isolate just finished. Not a lock — SharedPreferences has
  /// none — but it closes the window to the width of one write.
  static Future<String> reloadTimerSessionsJson() async {
    final p = await SharedPreferences.getInstance();
    try {
      await p.reload();
    } catch (_) {
      // Reload is best-effort; the cached value is still usable.
    }
    _timerSessionsCache = p.getString(_timerSessionsKey) ?? '[]';
    return _timerSessionsCache;
  }

  /// Folds a pre-multi-session timer into the new list, once. Preserves the
  /// running clock across the upgrade instead of dropping the user's session.
  static Future<void> _migrateLegacyTimer(SharedPreferences p) async {
    final legacyTaskId = p.getString(_activeTimerTaskIdKey);
    if (legacyTaskId == null) return;
    final startedAt = p.getInt(_activeTimerStartedAtKey);
    if (startedAt != null && _timerSessionsCache == '[]') {
      final entry = {
        'sessionId': 'legacy-$startedAt',
        'taskId': legacyTaskId,
        'startedAt': startedAt,
        'accum': p.getInt(_activeTimerAccumKey) ?? 0,
        'paused': p.getBool(_activeTimerPausedKey) ?? false,
      };
      final json = jsonEncode([entry]);
      await p.setString(_timerSessionsKey, json);
      _timerSessionsCache = json;
    }
    await p.remove(_activeTimerTaskIdKey);
    await p.remove(_activeTimerStartedAtKey);
    await p.remove(_activeTimerAccumKey);
    await p.remove(_activeTimerPausedKey);
  }

  /// Date the Goldilocks coach banner was dismissed — max one suggestion
  /// surfaced per day.
  static DateTime? get coachDismissedDateSync => _coachDismissedCache;

  static Future<void> setCoachDismissedDate(DateTime date) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final p = await SharedPreferences.getInstance();
    await p.setString(_coachDismissedKey, dateOnly.toIso8601String());
    _coachDismissedCache = dateOnly;
  }

  // ── Home section open/closed state ───────────────────────────────────────
  // Up next is the one section that must never stay hidden by accident: you
  // could close it at night and open the app next morning blind to the day.
  // So closing it only lasts until midnight - it stores the DATE it was
  // closed, and counts as open on any other day. Anytime (the someday pile)
  // and Done today simply remember what you last chose.

  static const _upNextClosedOnKey = 'home_up_next_closed_on';
  static const _anytimeOpenKey = 'home_anytime_open';
  static const _doneOpenKey = 'home_done_open';

  static DateTime? _upNextClosedOnCache;
  static bool _anytimeOpenCache = false; // someday pile starts closed
  static bool _doneOpenCache = true;

  static void _readHomeSections(SharedPreferences p) {
    final iso = p.getString(_upNextClosedOnKey);
    _upNextClosedOnCache = iso == null ? null : DateTime.tryParse(iso);
    _anytimeOpenCache = p.getBool(_anytimeOpenKey) ?? false;
    _doneOpenCache = p.getBool(_doneOpenKey) ?? true;
  }

  /// Open unless it was closed earlier *today*.
  static bool get homeUpNextOpenSync {
    final closed = _upNextClosedOnCache;
    if (closed == null) return true;
    final n = DateTime.now();
    return !(closed.year == n.year &&
        closed.month == n.month &&
        closed.day == n.day);
  }

  static bool get homeAnytimeOpenSync => _anytimeOpenCache;
  static bool get homeDoneOpenSync => _doneOpenCache;

  static Future<void> setHomeUpNextOpen(bool open) async {
    final p = await SharedPreferences.getInstance();
    if (open) {
      await p.remove(_upNextClosedOnKey);
      _upNextClosedOnCache = null;
    } else {
      final n = DateTime.now();
      final today = DateTime(n.year, n.month, n.day);
      await p.setString(_upNextClosedOnKey, today.toIso8601String());
      _upNextClosedOnCache = today;
    }
  }

  static Future<void> setHomeAnytimeOpen(bool open) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_anytimeOpenKey, open);
    _anytimeOpenCache = open;
  }

  static Future<void> setHomeDoneOpen(bool open) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_doneOpenKey, open);
    _doneOpenCache = open;
  }

  // ── Automatic Drive backup ───────────────────────────────────────────────
  // Recorded LOCALLY so "is a backup due?" is instant and works offline —
  // asking Drive for the file's modifiedTime costs a network round trip on
  // every app open. Written by both the foreground app and the nightly
  // background isolate, so readers that care call [reloadBackupState] first;
  // each isolate has its own cache.

  static const _backupOkKey = 'backup_last_success_millis';
  static const _backupErrKey = 'backup_last_error';
  static const _backupErrAtKey = 'backup_last_error_millis';
  static const _backupWarnedKey = 'backup_stale_warned_date';

  static DateTime? _backupOkCache;
  static String? _backupErrCache;
  static DateTime? _backupErrAtCache;
  static DateTime? _backupWarnedCache;

  static DateTime? _millis(int? v) =>
      v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);

  static void _readBackupState(SharedPreferences p) {
    _backupOkCache = _millis(p.getInt(_backupOkKey));
    _backupErrCache = p.getString(_backupErrKey);
    _backupErrAtCache = _millis(p.getInt(_backupErrAtKey));
    final w = p.getString(_backupWarnedKey);
    _backupWarnedCache = w == null ? null : DateTime.tryParse(w);
  }

  /// Last time a backup actually reached Drive, or null if never recorded.
  static DateTime? get backupLastSuccessSync => _backupOkCache;

  /// Why the most recent attempt failed. Cleared by the next success.
  static String? get backupLastErrorSync => _backupErrCache;
  static DateTime? get backupLastErrorAtSync => _backupErrAtCache;

  /// The day the "your backup is stale" snackbar last showed — once a day,
  /// never a nag.
  static DateTime? get backupStaleWarnedDateSync => _backupWarnedCache;

  /// Pull values the other isolate may have written since we hydrated.
  static Future<void> reloadBackupState() async {
    final p = await SharedPreferences.getInstance();
    try {
      await p.reload();
    } catch (_) {
      // Best-effort; the cached values are still usable.
    }
    _readBackupState(p);
  }

  static Future<void> recordBackupSuccess(DateTime at) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_backupOkKey, at.millisecondsSinceEpoch);
    await p.remove(_backupErrKey);
    await p.remove(_backupErrAtKey);
    _backupOkCache = at;
    _backupErrCache = null;
    _backupErrAtCache = null;
  }

  static Future<void> recordBackupFailure(String error, DateTime at) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_backupErrKey, error);
    await p.setInt(_backupErrAtKey, at.millisecondsSinceEpoch);
    _backupErrCache = error;
    _backupErrAtCache = at;
  }

  static Future<void> setBackupStaleWarnedDate(DateTime date) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final p = await SharedPreferences.getInstance();
    await p.setString(_backupWarnedKey, dateOnly.toIso8601String());
    _backupWarnedCache = dateOnly;
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
