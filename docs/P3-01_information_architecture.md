# P3-01 — Information Architecture

Defines all screens in the app, how they are organised, and how Alok navigates between them. Designed around the core principle: quick-log anything in under 30 seconds.

---

## Navigation Structure

The app uses a **Bottom Navigation Bar** with 4 tabs. Always visible, always one tap away.

```
┌─────────────────────────────────────┐
│                                     │
│           SCREEN CONTENT            │
│                                     │
├─────────┬─────────┬────────┬────────┤
│  Home   │Projects │Rewards │ Stats  │
└─────────┴─────────┴────────┴────────┘
```

---

## Tab 1 — Home

The daily command centre. First thing Alok sees when he opens the app.

```
Home
├── Streak Popup (modal, on every app open)
│     ├── Current streak
│     ├── Personal best
│     └── Milestone celebration (if applicable)
│
├── Quick Log (primary action)
│     ├── Smart suggestions (what hasn't been logged today)
│     └── Log entry form (context-aware per project type)
│
└── Today's Summary Card
      ├── Points earned today
      ├── Projects logged today vs total
      └── Nearest reward (progress bar to next claimable reward)
```

---

## Tab 2 — Projects

All of Alok's projects live here.

```
Projects
├── Project List Screen
│     ├── Project cards (one per project, shows name, type, today's status)
│     └── + Create New Project button
│
├── Project Detail Screen (per project)
│     ├── Overview (total entries, avg performance, points earned)
│     ├── Log History (chronological list of all entries)
│     ├── Stats View (charts/graphs per metric)
│     └── Settings (edit metrics, thresholds, points formula)
│
└── Create / Edit Project Screen
      ├── Choose template (Habit Routine / Task Board / Weekly Review / Job Hunt)
      ├── Name the project
      ├── Configure metrics (add/remove/rename fields, set units & thresholds)
      └── Configure points (base points per log, bonus for threshold, multiplier)
```

---

## Tab 3 — Rewards

Alok's motivation engine.

```
Rewards
├── Rewards Dashboard
│     ├── Total points balance (large, prominent)
│     ├── Claimable rewards (highlighted, claim button active)
│     └── Locked rewards (greyed out with progress bar to threshold)
│
├── Create / Edit Reward Screen
│     ├── Reward name
│     ├── Description / note (optional)
│     └── Point threshold to unlock
│
└── Claimed History Screen
      └── List of all previously claimed rewards with date claimed
```

---

## Tab 4 — Stats

Big picture view of Alok's progress over time.

```
Stats
├── Overall Dashboard
│     ├── Total points (all time)
│     ├── Current streak + longest streak
│     ├── Total entries logged (all time)
│     └── Most consistent project
│
├── Per-Project Stats (drilldown)
│     ├── % days logged
│     ├── % threshold coverage (for Habit Routine)
│     └── Performance trend (weekly sparkline)
│
└── Weekly Review
      ├── Auto-generated weekly summary (Monday–Sunday)
      ├── Points earned this week
      ├── Hours planned vs completed
      ├── Habit consistency score
      └── Week-over-week comparison
```

---

## Modal / Overlay Screens

Screens that appear on top of the current tab — not part of the nav bar.

| Screen | Triggered By |
|---|---|
| Streak Popup | Every app open |
| Milestone Celebration | Streak hits 7 / 14 / 30 / 60 / 100 / 365 days |
| Reward Unlocked Alert | Points balance crosses a reward threshold |
| Quick Log Sheet | Tap on Quick Log from Home |
| Confirm Claim Reward | Tap "Claim" on a reward |

---

## Screen Count Summary

| Category | Screens |
|---|---|
| Home | 1 main + 1 modal (streak popup) |
| Projects | 3 (list, detail, create/edit) |
| Rewards | 3 (dashboard, create/edit, history) |
| Stats | 2 (overall, weekly review) |
| Modals/Overlays | 5 |
| **Total** | **~15 screens** |
