# Habit Reward Tracker — Complete App Guide

> A standalone reference for what this app does, page by page, feature by feature. Aimed at anyone evaluating, testing, or onboarding to the project.

---

## What This App Is

A **gamified personal productivity tracker** for Android (and iOS-ready), built in Flutter. Users define their own habits, log them daily, earn points for consistency, and unlock self-defined rewards.

**Think Duolingo for your own goals.**

The end-to-end loop:

> **Track anything → Earn points → Unlock rewards you set yourself**

It replaces the spreadsheet-based system the original user (Alok) maintained — adding streaks, levels, achievements, and dopamine-driven feedback to keep engagement high.

---

## Core Concepts (Glossary)

| Concept | Meaning |
|---|---|
| **Project** | A category of things you track (e.g. "Morning Routine", "Job Hunt") |
| **Metric** | A specific thing logged within a project (e.g. "Minutes meditated") |
| **Entry** | A single log of a metric on a specific date |
| **Points** | Earned per log; threshold-based metrics give bonus pts |
| **Reward** | Self-defined goal (e.g. "Buy that book") with a points cost |
| **Streak** | Consecutive days with at least one log |
| **Badge** | Achievement unlocked for hitting milestones |
| **Level** | Progression tier based on total points earned |
| **Daily Challenge** | A bonus task that rotates per day of the week |

---

# Pages & Screens

## 1. Onboarding (first launch only)

A 3-page swipe-through:

1. **Track** — log anything that matters to you
2. **Earn Points** — every entry adds up
3. **Unlock Rewards** — you choose what's worth working for

After the last page, the user lands on Home and the **Create Project** sheet auto-opens. A **SKIP** button bypasses to home directly.

The app detects first-run automatically: if `projects.isEmpty && totalEntries == 0`, it routes to onboarding. No explicit flag needed.

---

## 2. Home Screen

The daily landing page. Designed to answer **"what should I do today, and how am I doing?"**

### Top bar
- Greeting (Good morning / afternoon / evening, Alok)
- 🔥 Streak counter (only if streak > 0)
- Level badge (`Lv.2 Consistent` in colored pill — color shifts grey → blue → green → orange → gold)
- 🔔 Notification settings icon

### Body sections (top to bottom)
- **🎁 Reward ready banner** — gold strip if any reward is claimable (tap → Rewards)
- **TODAY'S SUMMARY card** — circular progress ring (X of Y projects logged today), ⭐ pts earned today, "Next reward" progress bar
- **DAILY CHALLENGE card** — today's bonus task with bonus pts on completion (blue when active, green when done)
- **QUICK LOG button** — primary call-to-action, opens log sheet
- **NOT LOGGED TODAY chips** — quick taps to log specific projects

### On-open behavior
- First-ever user → routes to `/onboarding`
- Returning user → optional streak popup (only shows once per session, only if streak > 0 / milestone hit / streak just broke)

---

## 3. Projects Screen

A list of all active projects with their template type icon (🌿 / ✅ / 📅 / 💼).

- Tap any project → opens **Project Detail**
- Tap **+** in app bar → opens "Create Project" sheet

**Create Project flow:** pick a template → set a name → 4 pre-configured metrics are added for you (editable later).

### The 4 Templates

| Template | Icon | Use case | Default behavior |
|---|---|---|---|
| **Habit Routine** | 🌿 | Daily habits | Skip days (max 2/week), threshold tracking |
| **Task Board** | ✅ | Project work | Priority + completion %, ranking |
| **Weekly Review** | 📅 | Reflection | Auto-aggregates the week (avg/total/count) |
| **Job Hunt** | 💼 | Applications | Status dropdown (Applied / In Progress / Offer / Rejected) |

---

## 4. Project Detail Screen (3 tabs)

Opens full-screen with back nav. Three tabs at the top.

### Overview tab
Template-specific analytics:

- **Habit Routine** — for each metric: average value this week, threshold coverage %, week skip count
- **Task Board** — priority score per item using `((11-rank)/10 + (100-completion%)/10 + hours_remaining/hours_planned*10) * 10/3`, plus completion progress
- **Job Hunt** — current status of each application, count by status
- **Weekly Review** — auto-computed weekly aggregates per tracked metric

### Log History tab
Reverse-chronological list of all entries for this project. Shows logged value, date, and points earned per entry.

### Settings tab
- Rename the project
- For each metric:
  - Edit name / unit / threshold / direction
  - Delete metric
  - 🔔 **Reminder bell** — set a per-metric daily reminder time. Filled bell + green = active. Subtitle shows time inline ("mins · 🔔 8:00 AM").
- Delete project (soft delete via `isActive = false`)

---

## 5. Rewards Screen

Three sections (all conditionally rendered):

- **POINTS BALANCE card** — large green hero showing current pts (after claims and shield deductions)
- **READY TO CLAIM** — rewards where balance ≥ threshold; tap **CLAIM** → confirmation dialog → confetti celebration → reward marked claimed and pts deducted
- **KEEP EARNING** — locked rewards with progress bars and pts remaining
- **CLAIMED** — history of past claims with dates

**+ button** in the AppBar → "Create Reward" sheet (name, description, point threshold).

Claiming the first reward automatically unlocks the **🎁 Treat Yourself** badge.

---

## 6. Stats Screen

A read-only dashboard. Four sections stacked vertically:

- **Summary cards (2×2 grid):** ⭐ Total Points · 📝 Total Logs · 🔥 Current Streak · 🏆 Best Streak
- **POINTS — LAST 14 DAYS** — line chart with gradient fill (`fl_chart`)
- **POINTS BY PROJECT** — ranked list with relative bars showing each project's contribution
- **BADGES** — 3-column grid of all 9 achievement badges. Unlocked = full color + date earned. Locked = greyed out.

---

# Cross-Cutting Gamification Systems

## Points System

```
Per-log points = (basePointsPerLog × project.multiplier × streakMultiplier)
Bonus points   = (bonusPointsThreshold × project.multiplier × streakMultiplier)  [if threshold met]
Total          = base + bonus + (daily challenge bonus, if condition met)
```

- Default base: 10 pts/log, bonus: 5 pts for hitting threshold
- Project multiplier set per-project (e.g. 1.0, 1.5)
- Streak multiplier kicks in at 7 days

## Streak System

Tracks consecutive days where at least one log happened.

| Lifecycle event | Behavior |
|---|---|
| **Increment** | First real log of a new day |
| **Hold** | Already logged today — no change |
| **Break** | 2+ days without a log → resets to 0 |
| **Milestone** | 7 / 14 / 30 / 60 / 100 / 365 days → confetti celebration |

The **streak popup** appears on app open if streak > 0 / milestone hit / streak just broke.

## Streak Shield 🛡️

When the streak just broke, the popup offers:
> **"Use Streak Shield? Restore your X-day streak for 50 pts."**

Tap → 50 pts deducted from balance, streak restored to its pre-break value, `lastLoggedDate` set to yesterday so it doesn't break again immediately. Tracked in SharedPreferences (no DB schema change required).

## Streak Multiplier

| Streak length | Multiplier |
|---|---|
| 0–6 days | 1.0x |
| 7–13 days | 1.2x |
| 14–29 days | 1.5x |
| 30+ days | 2.0x |

A 🔥 chip appears in Quick Log form when active.

## Level System

Total points earned (lifetime, before reward deductions) = XP. Five tiers:

| Lv | Title | Threshold | Color |
|---|---|---|---|
| 1 | Novice | 0 pts | Grey |
| 2 | Consistent | 500 pts | Blue |
| 3 | Dedicated | 1,500 pts | Green |
| 4 | Focused | 3,000 pts | Orange |
| 5 | Master | 6,000 pts | Gold |

Level badge always visible in the Home AppBar. Crossing a threshold triggers a **🏅 LEVEL UP!** confetti dialog right after the points float-up animation in Quick Log.

## Achievement Badges

9 predefined badges, auto-unlocked:

| Badge | Trigger |
|---|---|
| 📝 First Log | Your first ever log |
| 💯 Century | 100 total points |
| 🏆 Grand | 1,000 total points |
| 🌅 Early Bird | Log before 7am |
| 🦉 Night Owl | Log after 10pm |
| ✅ Completionist | Log all projects in one day |
| 🔥 Week Warrior | 7-day streak |
| 🌟 Monthly Master | 30-day streak |
| 🎁 Treat Yourself | Claim your first reward |

Unlock notification → green SnackBar at the bottom of the screen.
Wall view → Stats screen → BADGES section.

## Daily Challenges

A new bonus task each day, rotates by weekday:

| Day | Challenge | Reward |
|---|---|---|
| Mon | 🌅 Early Riser — log before noon | +20 pts |
| Tue | 📊 Triple Threat — log 3+ metrics | +30 pts |
| Wed | 🎯 On Target — hit a threshold | +25 pts |
| Thu | 🌙 Night Shift — log after 6pm | +15 pts |
| Fri | 🔀 Multitasker — log 2+ projects | +20 pts |
| Sat | 💪 Just Show Up — log anything | +10 pts |
| Sun | 🔥 Streak Builder — keep streak alive | +15 pts |

Card on home screen. Auto-detects condition during a log. Bonus pts added to that log.

## Points Float-Up Animation

After every log: **"+25 pts ✨"** floats up and fades in 1.4 seconds. Combined with `HapticFeedback.mediumImpact()` for tactile response.

---

# Notification System

Four independent notification types, all toggled in Settings → 🔔 icon:

| Type | When it fires | Source |
|---|---|---|
| **Daily reminder** | User-chosen time daily (e.g. 8 AM) | Global toggle |
| **Streak alert** | 9 PM if no log today | Global toggle |
| **Weekly recap** | Every Sunday at 8 PM | Global toggle |
| **Per-metric reminders** | Per-metric chosen time | Project Detail → Settings → bell icon |

Implemented via `flutter_local_notifications` with `timezone` package for IANA timezone handling. Reminders auto-repeat using `matchDateTimeComponents`. Per-metric IDs computed as `1000 + metricId.hashCode.abs() % 8000` to avoid collisions.

---

# Flow Diagrams

## First-time user
```
App launch
  │
  ├─ Check: any projects? any entries?
  │     │ No
  │     ▼
  │   Onboarding (3 pages)
  │     │
  │     ▼
  │   SKIP or finish last page
  │     │
  │     ▼
  │   Home screen
  │     │
  │     ▼
  │   "Create Project" sheet auto-opens
  │     │
  │     ▼
  │   Pick template → set name → 4 metrics seeded
  │     │
  │     ▼
  │   Quick Log first entry → +pts → 📝 First Log badge
```

## Daily logging flow
```
Tap QUICK LOG (or unlogged project chip)
  │
  ▼
Bottom sheet: Suggested + Log Again metrics
  │
  ▼
Pick metric → form opens
  │
  ├─ Habit Routine? → Skip Day buttons available
  │
  ▼
Enter value → tap LOG IT
  │
  ▼
DB: insert entry + points_history (× streak multiplier)
  │
  ▼
Streak service: record day logged
  │
  ▼
Daily challenge: check condition → award bonus pts if met
  │
  ▼
Float-up animation: "+25 pts ✨" + haptic
  │
  ▼
Achievement check → SnackBar if new badge
  │
  ▼
Level-up check → 🏅 confetti dialog if leveled up
  │
  ▼
Sheet closes
```

## Streak break + shield flow
```
App opens → StreakService.checkOnAppOpen()
  │
  ├─ Days since last log ≥ 2?
  │     │ Yes
  │     ▼
  │   oldStreak = currentStreak
  │   currentStreak = 0
  │   Return wasReset = true, streakBeforeReset = oldStreak
  │
  ▼
Streak popup shows
  │
  ├─ User has ≥ 50 pts AND oldStreak > 0?
  │     │ Yes
  │     ▼
  │   "Use Shield" button visible
  │     │ Tap
  │     ▼
  │   ShieldService.useShield()  → shield_total_spent += 50
  │   StreakService.restoreStreakAfterShield(oldStreak)
  │     - currentStreak = oldStreak
  │     - lastLoggedDate = yesterday
  │     ▼
  │   totalPointsProvider rebuilds → balance shows -50
  │     ▼
  │   Popup updates: "🛡️ Shield activated!"
```

## Reward claim flow
```
Points accumulate → claimableRewardsProvider detects balance ≥ threshold
  │
  ▼
Home screen shows gold "🎁 Reward ready" banner
  │
  ▼
User taps banner → Rewards screen
  │
  ▼
Tap CLAIM in "Ready to Claim" section
  │
  ▼
Confirm dialog: "Cost: X pts, New balance: Y pts"
  │ Confirm
  ▼
DB: reward.isClaimed = true, claimedAt = now
  │
  ▼
totalPointsProvider rebuilds (claimed rewards subtracted)
  │
  ▼
🎉 Confetti celebration dialog
  │
  ▼
🎁 Treat Yourself badge unlocks (first claim only)
  │
  ▼
Reward moves to "Claimed" section
```

## Level-up flow
```
User submits log
  │
  ▼
Float-up animation plays (1.4s)
  │
  ▼
db.getTotalPoints() → cumulative
  │
  ▼
LevelService.checkAndSaveLevelUp(cumulative)
  │
  ├─ New level > stored level?
  │     │ Yes
  │     ▼
  │   Show 🏅 LEVEL UP! confetti dialog
  │     │
  │     ▼
  │   User taps "AWESOME!"
  │
  ▼
Quick Log sheet pops
```

---

# Data Model (Drift / SQLite)

| Table | Key columns |
|---|---|
| **projects** | id, name, template_type, base_points_per_log, multiplier, bonus_points_threshold, is_active |
| **metrics** | id, project_id, name, unit, threshold_value, threshold_direction, display_order, is_active |
| **entries** | id, project_id, metric_id, logged_value, log_date, is_skip, is_nd, points_earned |
| **points_history** | id, entry_id, project_id, points, reason, earned_at |
| **rewards** | id, name, description, points_threshold, is_claimed, claimed_at, created_at |
| **streak** | id (singleton=1), current_streak, longest_streak, last_logged_date, last_milestone_celebrated |

### SharedPreferences (non-DB state)
- Achievement unlock state and dates per badge (`achievement_<id>_unlocked`, `achievement_<id>_date`)
- Last known level (`last_known_level`) — for level-up detection
- Daily challenge completion per date (`challenge_completed_YYYY-M-D`)
- Shield total spent (`shield_total_spent`) — subtracted from points balance in provider
- Notification preferences (toggle states + chosen times)

### Points balance computation
```
balance = SUM(points_history.points)
        - SUM(claimed_rewards.points_threshold)
        - shield_total_spent (from SharedPreferences)
```

---

# Tech Stack

- **Flutter 3.8+** (Dart 3 with records, `$1`/`$2` tuples)
- **Drift** — SQLite ORM with code generation (`database.g.dart`)
- **Riverpod** — state management. Stream/future providers polling DB every 1–2s for reactivity
- **go_router** — navigation. `StatefulShellRoute.indexedStack` for tab persistence
- **fl_chart** — line + bar charts on Stats screen
- **confetti** — celebration animations (milestone, level-up, reward claim)
- **flutter_local_notifications** + **timezone** + **flutter_timezone** — scheduled push
- **shared_preferences** — lightweight key-value storage for non-DB state
- **Nunito font** (Google Fonts) — bold, friendly typography

---

# File Layout (high level)

```
lib/
├── main.dart                            # App entry, notification init
├── core/
│   ├── database/
│   │   ├── database.dart                # AppDatabase + queries
│   │   ├── database.g.dart              # Drift code-gen output
│   │   └── tables/                      # 6 table definitions
│   ├── services/
│   │   ├── streak_service.dart          # Streak logic
│   │   ├── level_service.dart           # XP/levels
│   │   ├── achievement_service.dart     # Badge unlocks
│   │   ├── challenge_service.dart       # Daily challenges
│   │   ├── shield_service.dart          # Streak shield (SharedPrefs)
│   │   ├── notification_service.dart    # Schedule/cancel notifications
│   │   └── notification_prefs.dart      # Notification settings storage
│   └── theme/                           # app_colors, app_typography, app_theme, app_constants
├── features/
│   ├── home/
│   │   ├── home_screen.dart
│   │   └── widgets/
│   │       ├── quick_log_sheet.dart
│   │       ├── today_summary_card.dart
│   │       ├── streak_popup.dart
│   │       └── notification_settings_sheet.dart
│   ├── projects/
│   │   ├── projects_screen.dart
│   │   └── project_detail_screen.dart
│   ├── rewards/
│   │   ├── rewards_screen.dart
│   │   └── widgets/create_reward_sheet.dart
│   ├── stats/
│   │   └── stats_screen.dart
│   └── onboarding/
│       └── onboarding_screen.dart
└── shared/
    └── providers/
        ├── database_provider.dart       # All Riverpod providers
        └── router_provider.dart         # go_router config
```

---

# Running & Building

### Local development
```powershell
flutter pub get
flutter run -d <device>          # see `flutter devices` for IDs
```

Hot reload (`r`) for UI changes. Hot restart (`R`) for new imports / providers. Schema changes require:
```powershell
dart run build_runner build --delete-conflicting-outputs
```

### Release APK (Android)
```powershell
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### iOS / IPA
Cannot be built on Windows — requires macOS + Xcode. Options:
- Build on a Mac: `flutter build ipa`
- Use Codemagic / GitHub Actions macOS runner for CI builds

---

# Permissions Required (Android)

- `POST_NOTIFICATIONS` — show local reminders
- `RECEIVE_BOOT_COMPLETED` — restore scheduled notifications after reboot
- `VIBRATE` — haptic feedback
- `SCHEDULE_EXACT_ALARM` (implicit via flutter_local_notifications)

Build configuration enables Java 8 desugaring (`isCoreLibraryDesugaringEnabled = true`) to support time-based APIs needed by `flutter_local_notifications`.

---

# Roadmap / Not Yet Built

| Idea | Tier | Effort |
|---|---|---|
| Shareable streak card (screenshot-friendly) | Low | Medium |
| Habit insights ("You miss Thursdays most often") | Low | High |
| Mascot/avatar that evolves with level | Low | High |
| iOS build + TestFlight distribution | Mid | Medium (needs Mac) |
| Cloud backup / multi-device sync | High | High |
| Dark mode | Mid | Low (theme already partially set up) |

---

# Glossary of UX patterns used

- **Optimistic UI** — entries appear instantly; DB persistence is async
- **Polling reactivity** — providers re-query DB every 1–2s rather than using triggers (simple, good enough for single-user)
- **SharedPreferences for ephemeral state** — anything that doesn't need to be queryable (level, badges, challenge completion, shield spent) avoids DB schema migrations
- **Confetti for emotional moments** — milestones, level-ups, reward claims all use the same `ConfettiWidget` for consistency
- **Color semantics** — green = success/primary, orange = streak/skip, gold = rewards, blue = info, red = missed

---

*This guide reflects the app state as of 2026-04-28.*
