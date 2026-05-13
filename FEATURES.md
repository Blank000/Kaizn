# Kaizn (Habit Reward Tracker) — Feature Inventory

A one-stop reference for everything the app currently supports. Use this as a context handoff when planning a new feature so you can place it correctly relative to existing capabilities.

The app is a Flutter (iOS + Android) milestone-centric, gamified habit tracker. One-liner: **track milestones (habits, goals, projects) and their tasks → earn points → unlock self-defined rewards**. Duolingo-style.

---

## 1. Identity & Auth

### Google Sign-In
- Mandatory sign-in gate on first launch (`/login` route, outside the bottom-nav shell).
- Scopes: `email` + `drive.appdata`.
- Silent re-sign-in at app startup so returning users skip the login screen and land directly in their data.
- **Benefit:** zero-friction return-user experience; ties data to a real identity for backup/restore.

### Sign Out
- Account section in Settings shows avatar + email + Sign Out.
- **Benefit:** lets users disconnect their Google account from the device without uninstalling.

---

## 2. Cloud Backup & Restore (Google Drive)

- Backups stored in **Drive AppData folder** — a hidden, app-scoped folder that only this app can read.
- Single JSON file `habit_reward_tracker.json` written via Drift's `toJson` / `fromJson`.
- "Back up now" pushes a fresh dump; updates the file if it exists.
- "Restore from backup" wipes local rows in reverse FK order and re-inserts in FK order, all in one transaction. No app restart needed.
- Last-backup-time pill surfaces freshness.
- **Benefit:** user owns their data, no third-party storage cost, survives uninstall/reinstall and device migration. Privacy-friendly — Anthropic/we never see the data.

---

## 3. Milestones (the core organizing unit)

A "milestone" is a habit, goal, or project — the parent container for tasks.

- **CRUD**: create / edit / cascade-delete from `lib/features/milestones/`.
- **Fields**: name, description, target date (optional), completion bonus points, color.
- **Per-milestone color**: 8-color palette (green/blue/orange/gold/red/purple/pink/slate). Picker UI in the form sheet. Surfaces as:
  - Vertical accent strip on milestone list cards
  - Tinted header on milestone detail screen
  - 10px color dot in Stats "By milestone" rows
- **Mark complete**: awards the milestone's bonus points and locks the milestone.
- **Inbox milestone**: auto-seeded on first launch so the user can quick-add tasks without first creating a milestone.
- **Benefit:** users can group related work (e.g., "Run a half marathon" with daily run + weekly long-run + nutrition tasks) and earn a big payoff when the whole milestone is done — not just per-task drips.

---

## 4. Tasks & Recurrence

A "task" lives under a milestone and is the thing the user actually checks off.

### Task CRUD
- Create / edit / delete from milestone detail or from Home (quick-add).
- Fields: name, milestone, points value, recurrence, optional one-time due date.

### Recurrence Builder (Google-Calendar-style)
- **Frequencies**: Once, Daily, Weekly, Monthly.
- **Interval stepper**: every N days/weeks/months (e.g., every 2 weeks).
- **Weekly day picker**: pick any combination of M/T/W/T/F/S/S chips.
- **Monthly**: by day-of-month (e.g., 15th) **or** by weekday-position (e.g., "1st Monday").
- **First occurrence anchor**: when interval > 1, an explicit start date so biweekly/monthly cycles line up the way the user expects.
- **Live schedule preview**: human-readable summary below the form ("Mon · Wed · Fri", "Every 2 weeks · Mon", "1st Monday of every month").
- **Benefit:** matches the mental model of any modern calendar app — no learning curve. Users can express almost any habit cadence they care about.

### Quick-Add from Home
- FAB → task form sheet, milestone picker pre-selects last-used.
- **Benefit:** capture-friendly. Most users only have 1–2 active milestones — the picker shouldn't be friction.

---

## 5. Today View (Home)

The default landing screen — designed to answer "what should I do today?"

- **Time-of-day greeting** in app bar (Good morning / afternoon / evening / Up late).
- **Stats header**: total points + current streak (animated counters).
- **Today's progress card**: X/Y done + points earned today.
- **Ready to claim section** (passive surface): claimable rewards inline with one-tap CLAIM button.
- **Up next today**: due-today recurring tasks + active one-shots due now or earlier.
- **Done today / Missed today / Skipped today**: each in its own section so the day's state is readable at a glance.
- **All done today celebration**: confetti + dialog the first time the user finishes their last scheduled task each day.
- **Benefit:** opening the app should give an actionable answer in <2 seconds. No nav, no scrolling required to know what to do.

---

## 6. Task Tile Interactions

Shared `TaskTile` widget used on Home and Milestone Detail.

### 4-State Round Button
- Unchecked (hollow gray) → Checked (primary green ✓) → Missed (red X) → Skipped (gray −).
- Priority on display: `checked > missed > skipped > unchecked`.

### Tap-to-Complete
- Single tap on round button → completes task, awards points, updates streak.
- Haptic feedback + animated `+N pts` float-up.
- Tap on a completed tile → undo (refunds points).

### Long-Press → Skip / Missed Sheet
- **Skip today**: intentional rest. Preserves streak, no points. Gray icon.
- **Mark as missed**: honest miss. No points, doesn't credit streak. Red icon.
- **Benefit:** users can be honest about a day without losing all their progress — a major source of habit-app abandonment.

### Per-Day Weekly Chips (multi-day weekly tasks)
- For tasks scheduled on >1 weekday/week, the main button is replaced by a horizontal row of round day-chips (M/T/W/T/F/S/S).
- Each chip is tappable independently for its specific date.
- Past chips: tappable for retro-logging. Future chips: dimmed, non-tappable. Today's chip: primary outline.
- Long-press on an empty past/today chip → same skip/missed sheet for that specific date.
- **Benefit:** "Mon/Wed/Fri" tasks behave correctly — completing Monday doesn't mark Wed/Fri as done. Users can also fix yesterday's omission without leaving the screen.

---

## 7. Streaks

- Single `streak` row tracks `currentStreak`, `longestStreak`, `lastLoggedDate`, `milestone` (e.g., 7, 30).
- `StreakService.recordDayLogged` increments at most once per day (guarded by `AppPrefs.lastStreakAdvanceDate`).
- **1-day grace**: missing one day is forgiven; two breaks the streak.
- **Skip-day preservation**: skipping updates `lastLoggedDate` (so tomorrow still counts) but doesn't increment the streak.
- **Streak popup**: fires once per day on first open if the streak is meaningful (≥1, milestone hit, or just reset).
- **Benefit:** loss-aversion drives daily return without being so punitive that one bad week destroys months of work.

---

## 8. Points & Rewards

### Earning
- Points awarded on each non-skip, non-missed task completion.
- Milestone bonus awarded when the milestone is marked complete.
- `points_history` table records each transaction for auditability and Stats aggregation.

### Defining Rewards
- User defines their own rewards (name, description, points threshold).
- **Benefit:** intrinsic motivation. The user chooses what's worth working for — "movie night when I hit 500 pts" beats any system-imposed badge.

### Rewards Screen
- Balance card with "X pts to {next reward}" preview.
- Sections: **Ready to claim** / **Keep earning** / **Claimed**.
- Edit + delete on every card.

### Claim Flow (`claimReward` helper)
- Confirm dialog → DB write → confetti + celebration dialog → achievement-badge check.
- Used by both the Rewards screen and the Home "Ready to claim" inline button.

### Reward Unlock Surfacing
- **Active snackbar** (gold-tinted, `CLAIM` action): fires after task completion / milestone bonus / new reward creation if the user just crossed a threshold. Persists "announced" IDs in prefs so each unlock fires once.
- **Passive Home surface**: same claimable rewards shown inline on Home for users who missed the snackbar.
- **Benefit:** the moment-of-victory dopamine hit is hard to miss but never spammy.

---

## 9. Achievements (Auto-Badges)

9 badges defined in `achievement_service.dart`. Categories:

- **First log**: complete any task once.
- **Century / Grand**: lifetime points milestones.
- **Streak 7 / Streak 30**: streak duration milestones.
- **Early bird / Night owl**: log before 7 AM / after 10 PM.
- **Completionist**: all tasks done on a single day (any day).
- **Reward claimant**: claim your first reward.

### Gallery
- `/stats/achievements` route. 2-col grid. Unlocked badges: full-color, unlock date. Locked: dimmed, "LOCKED" label. Header shows X / 9 unlocked + progress bar.

### Unlock Surfacing
- `showAchievementSnackbar(context, badges)` fires from task completion, all-done celebration, reward claim, and streak advances.
- **Benefit:** intermittent reinforcement on top of the explicit reward system — users discover badges without needing to hunt for them.

---

## 10. Stats Screen

Pure data-vis tab — no actions, just feedback.

- **Lifetime card**: all-time points earned + longest streak ever.
- **This week card**: points + completions in the last 7 days.
- **Achievements entry**: tap to gallery.
- **Daily points bar chart**: last 30 days, `fl_chart` `BarChart`.
- **Activity heatmap**:
  - **Month view (default)**: full-size grid, day numbers, tap to see what was done that day.
  - **Year view (toggle)**: 3×4 mini-month grid for an at-a-glance year. Tap-on-cell still drills into day detail.
- **Top tasks · This week**: top 5 tasks by completion count with milestone subtitle and "N×" badge.
- **By milestone · This week**: active milestones with at least one completion this week (color dot + "N done · +M pts").
- **Time of day · Last 90 days**: 24-bar hourly distribution with a headline insight ("Most active around 8 PM"). Peak hour bar in full primary, others at 50% opacity. Hidden when there's no data.
- **Benefit:** turns the user's own history into encouragement. Pattern-recognition ("I'm consistent at night") helps users schedule new habits where they're likely to succeed.

---

## 11. Theme

- **Light + dark themes**, both fully built out via a shared `_build` helper in `lib/core/theme/app_theme.dart`.
- **Defaults to system** preference.
- **Settings override**: System / Light / Dark radio. Switches live without rebuild. Persists via `AppPrefs.themeMode`.
- **Brand accent colors** (primary green, streak orange, gold, etc.) consistent across both modes.
- **Neutral colors** via `BuildContext` extension `AppColorsContext` (`context.appCardSurface`, `context.appTextPrimary`, etc.) — every widget adapts automatically.
- **Benefit:** comfort in any lighting + battery savings on OLED + respects user choice.

---

## 12. Onboarding

- 4-page carousel for fresh installs:
  - 🎯 Track milestones
  - 🔥 Build streaks (mentions skip-day grace)
  - 🎁 Define rewards + auto-earn badges
  - 🚀 Ready
- Final page swaps NEXT for `[+ ADD FIRST TASK]` (opens task form sheet) + a `Just take me in` text button.
- **Inbox milestone** is auto-seeded so the first add doesn't require creating a parent milestone.
- Router redirect enforces onboarding before /home for fresh installs.
- **Benefit:** zero-friction first task creation — the moment most habit apps lose users.

---

## 13. Settings Hub

Route `/settings` (top-level, outside the shell, back arrow). Sections:

- **Account**: avatar, email, Sign Out.
- **Backup**: Back up now / Restore from backup with last-backup-time pill.
- **Theme**: System / Light / Dark.
- **Notifications**: tile that opens the notification preferences sheet.
- **More**: Achievements (→ `/stats/achievements`), About (Material `showAboutDialog` with version + green check icon).
- **Benefit:** every infrequent control in one predictable place; doesn't clutter the daily-use screens.

---

## 14. Notifications

Scaffolded via `flutter_local_notifications` + `flutter_timezone`.

- **Daily reminder**: configurable hour/minute, fires every day.
- **Streak alert**: fires at 9 PM if user hasn't logged yet.
- **Weekly recap**: every Sunday 8 PM.
- **Per-metric reminders**: arbitrary tasks can have their own daily reminder (hashed-ID slot).
- Cancel methods for all of the above.
- **Benefit:** keeps the streak loop alive even when the app isn't open. Per-task reminders let users tie a habit to a specific cue (e.g., "8 AM journal").

> Note (May 2026): iOS init settings (`DarwinInitializationSettings`) live only on the `ios-release` branch. Main branch's `NotificationService.init` is Android-only — port the iOS init when merging iOS support to main.

---

## 15. Visual Polish & Animations

- **Animated number counters** (`AnimatedNumber` widget): smooth integer tweens for points, streak, +N pts, balance, weekly stats. First mount tweens 0→value (fanfare); subsequent rebuilds tween from previous animated value.
- **Confetti** on reward claims, milestone completion, all-done-today.
- **Points float-up**: animated `+N` chip after task completion.
- **App icon**: green background + white check, 1024×1024, generated programmatically (`tools/generate_icon.dart`) and rendered to adaptive Android + iOS launcher assets via `flutter_launcher_icons`.
- **Benefit:** completes the gamification loop — every action gives a satisfying micro-reward.

---

## 16. Data Model (Drift, schemaVersion 3)

6 tables:
- `milestones` — name, description, target date, bonus, color index, status
- `tasks` — name, points, recurrence config (JSON), one-time due date, status, parent milestone
- `task_completions` — one row per check-in, with `isSkip` / `isNd` flags
- `points_history` — every points delta, for auditing and Stats
- `rewards` — user-defined rewards with thresholds
- `streak` — singleton row

Migrations:
- v1→v2 (pre-launch): destructive wipe of old `projects`/`metrics`/`entries` model.
- v2→v3 (post-launch): non-destructive `addColumn(milestones.colorIndex)`, default 0 = green.

**Don't add another destructive wipe** — real user data exists now.

---

## 17. Architecture Cheat Sheet

- **State**: Riverpod (`flutter_riverpod`). DB streams via `database_provider.dart`.
- **Routing**: `go_router` with auth + onboarding redirect.
- **Persistence**: Drift (SQLite) for app data; SharedPreferences via `AppPrefs` for small sync-cached flags (theme, onboarding-done, last-used milestone, last-streak-advance-date, announced rewards, etc.).
- **Auth/Backup HTTP**: `googleapis` + `googleapis_auth` + `http` with a tiny `_AuthClient` wrapper that injects Google headers.
- **Recurrence**: `lib/shared/models/recurrence_rule.dart` is the single source of truth for "is this due today?" / "what's the current period?" / "human summary."

---

## 18. Currently Stubbed / Backlog (so a future feature lands in the right place)

- **Auto-backup** (debounced trigger on data changes) — not yet wired; manual only.
- **Notification scheduling UI** — sheet exists but per-task / per-metric reminders aren't fully exposed everywhere.
- **Designer-made app icon** — current icon is programmatic. Drop a real PNG at `assets/icon.png` and re-run `flutter_launcher_icons`.
- **Leaderboards / public rewards / social** — vision-stage only.
- **iOS** — supported via `ios-release` branch; main hasn't merged the iOS notification init or Podfile/setup yet.

---

## 19. Key File Map

| Concern | Path |
|---|---|
| Database tables | `lib/core/database/tables/` |
| Drift DB + queries | `lib/core/database/database.dart` |
| Recurrence model | `lib/shared/models/recurrence_rule.dart` |
| Auth | `lib/core/services/auth_service.dart` |
| Backup | `lib/core/services/backup_service.dart` |
| Prefs | `lib/core/services/app_prefs.dart` |
| Streak logic | `lib/core/services/streak_service.dart` |
| Notifications | `lib/core/services/notification_service.dart` |
| Achievements | `lib/core/services/achievement_service.dart` |
| Theme | `lib/core/theme/` |
| Router | `lib/shared/providers/router_provider.dart` |
| Home (Today) | `lib/features/home/home_screen.dart` |
| Task tile | `lib/shared/widgets/task_tile.dart` |
| Milestones | `lib/features/milestones/` |
| Rewards | `lib/features/rewards/` |
| Stats | `lib/features/stats/stats_screen.dart` |
| Achievements gallery | `lib/features/achievements/achievements_screen.dart` |
| Settings | `lib/features/settings/settings_screen.dart` |
| Onboarding | `lib/features/onboarding/onboarding_screen.dart` |
| Login | `lib/features/auth/login_screen.dart` |
