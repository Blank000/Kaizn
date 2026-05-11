# P4-02 — Data Model

Defines how all app data is structured and stored locally using SQLite (via Drift). Every table, field, and relationship is specified here.

---

## Overview

All data is stored **on-device only** using SQLite. No backend, no cloud sync in v1.

```
┌──────────┐     ┌───────────┐     ┌────────────┐
│ Projects │────▶│  Metrics  │────▶│   Entries  │
└──────────┘     └───────────┘     └────────────┘
                                         │
                                         ▼
                                   ┌───────────┐
                                   │  Points   │
                                   │  History  │
                                   └───────────┘

┌──────────┐     ┌────────────────┐
│ Rewards  │────▶│ Claimed History│
└──────────┘     └────────────────┘

┌────────┐
│ Streak │
└────────┘
```

---

## Table 1 — Projects

Stores each project Alok creates.

| Field | Type | Description |
|---|---|---|
| `id` | UUID (text) | Unique identifier |
| `name` | text | e.g., "Alok Daily Habits" |
| `template_type` | enum | `habit_routine`, `task_board`, `weekly_review`, `job_hunt` |
| `base_points_per_log` | integer | Points earned per log entry |
| `bonus_points_threshold` | integer | Extra points if threshold is met |
| `multiplier` | real | Project-level points multiplier (default 1.0) |
| `created_at` | datetime | When the project was created |
| `is_active` | boolean | Soft delete flag |

---

## Table 2 — Metrics

Stores the configurable metrics within each project.

| Field | Type | Description |
|---|---|---|
| `id` | UUID (text) | Unique identifier |
| `project_id` | UUID (FK → Projects) | Parent project |
| `name` | text | e.g., "Wake-up Time", "Meditation" |
| `unit` | text | e.g., "mins", "count", "HH:MM", "text" |
| `threshold_value` | real (nullable) | Target value (null if no threshold set) |
| `threshold_direction` | enum | `higher_is_better`, `lower_is_better` |
| `display_order` | integer | Order shown in UI |
| `is_active` | boolean | Soft delete flag |

---

## Table 3 — Entries

Stores every individual log entry Alok makes.

| Field | Type | Description |
|---|---|---|
| `id` | UUID (text) | Unique identifier |
| `project_id` | UUID (FK → Projects) | Parent project |
| `metric_id` | UUID (FK → Metrics) | Which metric was logged |
| `logged_value` | text | Stored as text, parsed by metric unit type |
| `log_date` | date | The date this entry belongs to (not timestamp) |
| `is_skip` | boolean | True if marked as intentional skip day |
| `is_nd` | boolean | True if marked Not Done (beyond skip allowance) |
| `points_earned` | integer | Points awarded at time of logging |
| `created_at` | datetime | Exact timestamp of log action |

> `logged_value` is stored as text to handle all unit types (numbers, times, free text) in one table.

---

## Table 4 — Points History

Audit log of all point events. Derived from Entries but kept separately for performance.

| Field | Type | Description |
|---|---|---|
| `id` | UUID (text) | Unique identifier |
| `entry_id` | UUID (FK → Entries) | Source entry |
| `project_id` | UUID (FK → Projects) | Source project |
| `points` | integer | Points awarded (always positive) |
| `reason` | enum | `base_log`, `threshold_bonus` |
| `earned_at` | datetime | When points were earned |

---

## Table 5 — Rewards

Stores all rewards Alok has defined.

| Field | Type | Description |
|---|---|---|
| `id` | UUID (text) | Unique identifier |
| `name` | text | e.g., "Cheat Meal", "Movie Night" |
| `description` | text (nullable) | Optional note |
| `points_threshold` | integer | Points required to claim |
| `is_claimed` | boolean | Whether it has been claimed |
| `claimed_at` | datetime (nullable) | When it was claimed (null if not yet) |
| `created_at` | datetime | When reward was defined |

---

## Table 6 — Streak

Single-row table tracking Alok's streak state.

| Field | Type | Description |
|---|---|---|
| `id` | integer | Always 1 (single row) |
| `current_streak` | integer | Current consecutive day count |
| `longest_streak` | integer | All-time personal best |
| `last_logged_date` | date | Last date a real entry was made |
| `last_milestone_celebrated` | integer | Last milestone shown (e.g., 30) — avoids repeat popups |

---

## Computed Values (not stored, calculated at runtime)

| Value | How it's computed |
|---|---|
| Total points balance | `SUM(points_history.points)` minus `SUM(rewards.points_threshold WHERE is_claimed = true)` |
| % habit recorded | `COUNT(entries WHERE log_date in range AND is_skip=false AND is_nd=false)` ÷ total possible |
| % threshold coverage | `COUNT(entries WHERE threshold met)` ÷ `COUNT(entries logged)` |
| Weekly summary | Aggregated from entries + points_history for Mon–Sun of current week |
| Reward claimable | `total_balance >= reward.points_threshold AND is_claimed = false` |

---

## Relationships Diagram

```
Projects (1) ──────── (many) Metrics
Projects (1) ──────── (many) Entries
Metrics  (1) ──────── (many) Entries
Entries  (1) ──────── (1)    Points History

Rewards  (independent — references total balance only)
Streak   (independent — singleton row)
```
