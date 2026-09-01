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

  static const _activeTimerTaskIdKey = 'active_timer_task_id';
  static const _activeTimerStartedAtKey = 'active_timer_started_at_millis';
  static const _activeTimerAccumKey = 'active_timer_accum_seconds';
  static const _activeTimerPausedKey = 'active_timer_paused';
  static String? _activeTimerTaskIdCache;
  static int? _activeTimerStartedAtCache;
  static int _activeTimerAccumCache = 0;
  static bool _activeTimerPausedCache = false;

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
    _activeTimerTaskIdCache = p.getString(_activeTimerTaskIdKey);
    _activeTimerStartedAtCache = p.getInt(_activeTimerStartedAtKey);
    _activeTimerAccumCache = p.getInt(_activeTimerAccumKey) ?? 0;
    _activeTimerPausedCache = p.getBool(_activeTimerPausedKey) ?? false;
    final coachIso = p.getString(_coachDismissedKey);
    _coachDismissedCache = coachIso == null ? null : DateTime.tryParse(coachIso);
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

  // Master Ren, the fox sensei (ON by default). Gates every RenFigure.
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
  // Set in Ren's Sunday review; shown on the Home progress card during its
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

  // ── Active stopwatch timer (stopwatch-lite) ──────────────────────────────
  // Four values ARE the whole persistence story: elapsed = accumulated
  // (banked by pauses) + wall-clock time since the last resume. Everything
  // is recomputed on read, so the timer survives app kill and OEM process
  // death with zero background services. Sync caches so the Home banner can
  // render on the first frame after a cold start. Pause is ALWAYS manual —
  // the app never auto-pauses on backgrounding (timing off-screen work is
  // legitimate; owner decision, do not "fix").

  static String? get activeTimerTaskIdSync => _activeTimerTaskIdCache;
  static int? get activeTimerStartedAtMillisSync => _activeTimerStartedAtCache;
  static int get activeTimerAccumSecondsSync => _activeTimerAccumCache;
  static bool get activeTimerPausedSync => _activeTimerPausedCache;

  static Future<void> setActiveTimer(String taskId, int startedAtMillis) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_activeTimerTaskIdKey, taskId);
    await p.setInt(_activeTimerStartedAtKey, startedAtMillis);
    await p.setInt(_activeTimerAccumKey, 0);
    await p.setBool(_activeTimerPausedKey, false);
    _activeTimerTaskIdCache = taskId;
    _activeTimerStartedAtCache = startedAtMillis;
    _activeTimerAccumCache = 0;
    _activeTimerPausedCache = false;
  }

  /// Pause/resume bookkeeping: [accumSeconds] is the banked total of all
  /// finished run segments; [startedAtMillis] restarts the wall clock on
  /// resume (ignored while paused).
  static Future<void> setActiveTimerRunState({
    required int startedAtMillis,
    required int accumSeconds,
    required bool paused,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_activeTimerStartedAtKey, startedAtMillis);
    await p.setInt(_activeTimerAccumKey, accumSeconds);
    await p.setBool(_activeTimerPausedKey, paused);
    _activeTimerStartedAtCache = startedAtMillis;
    _activeTimerAccumCache = accumSeconds;
    _activeTimerPausedCache = paused;
  }

  static Future<void> clearActiveTimer() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_activeTimerTaskIdKey);
    await p.remove(_activeTimerStartedAtKey);
    await p.remove(_activeTimerAccumKey);
    await p.remove(_activeTimerPausedKey);
    _activeTimerTaskIdCache = null;
    _activeTimerStartedAtCache = null;
    _activeTimerAccumCache = 0;
    _activeTimerPausedCache = false;
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
