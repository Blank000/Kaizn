# P2-02 — Business Rules

Defines the logic, formulas, and constraints that govern how the app behaves. These rules are derived from the original Excel tracker and Phase 1-2 decisions.

---

## 1. Points System

### Configuration
- Points are configured **per project**, not globally.
- When setting up or editing a project, Alok defines:
  - **Points per log entry** — base points awarded each time a metric is logged
  - **Bonus points for hitting threshold** — extra points if the logged value meets or exceeds the metric's target
  - **Multiplier (optional)** — a project-level multiplier to weight high-effort projects higher

### Earning Points
- Points are awarded **at the time of logging** an entry.
- If a threshold is set for a metric and the logged value meets it → bonus points are added automatically.
- If a habit is marked as "skipped" (within allowed skip days) → no points earned, but no penalty either.
- If a habit entry is marked "ND" (Not Done, outside skip allowance) → no points earned.

### Points are never deducted
- Points only go up. There is no penalty/deduction mechanic in v1.

---

## 2. Skip Days (Habit Routine)

- Each habit allows a maximum of **2 skip days per week**.
- A "skip" is an intentional, guilt-free absence — it does not count as a missed day.
- Days beyond the 2-skip allowance are marked as **ND (Not Done)** and are flagged visually (orange-red, matching the original Excel).
- The week resets on **Monday** (standard calendar week).

---

## 3. Thresholds (Habit Routine)

- Each metric in a Habit Routine project can have an optional **threshold value** (the target to hit).
- Thresholds have a **direction**: some metrics are "lower is better" (e.g., wake-up time — earlier is better), others are "higher is better" (e.g., meditation minutes).
- The app calculates **% threshold coverage** = number of logged days where threshold was met ÷ total logged days.
- Average performance per habit is shown alongside threshold coverage so Alok can see both volume and quality.

---

## 4. Weekly Review — Auto-Aggregation

- The Weekly Review template automatically pulls from all daily project logs within the current calendar week (Monday–Sunday).
- Aggregated metrics:
  - **Total points earned** across all projects
  - **Average completion %** across all tasks in the Task Board
  - **Total hours logged** vs total hours planned (from Task Board)
  - **Number of habit entries logged** vs total possible entries
- Weekly Review is **read-only** — it is not manually editable. It reflects logged data only.
- A weekly summary is generated every Sunday night (or on first app open after Sunday).

---

## 5. Task Scoring (Task Board)

- Each task has an auto-calculated **Effective Priority Score** based on:
  - Task rank / position (earlier tasks = higher urgency)
  - Current completion % (lower completion = higher urgency)
  - Remaining hours (more remaining = higher urgency)
- Formula (from original Excel):
  ```
  Score = ((11 - rank) / 10 + (100 - completion%) / 10 + (hours_remaining / hours_planned) * 10) * 10 / 3
  ```
- Higher score = higher priority. This score is shown visually to help Alok triage.

---

## 6. Streak Mechanic

- A **streak** = the number of consecutive calendar days where Alok logged at least one entry in any project.
- Streak increments once per day (first log of the day triggers it).
- Streak **breaks** if a full calendar day passes with zero logs.
- Skip days on habits do **not** count as a log — Alok must log at least one real entry to keep the streak alive.
- On every app open, a **streak popup** is shown displaying:
  - Current streak (days)
  - Longest streak ever (personal best)
  - Milestone celebration if a new milestone is hit (7, 14, 30, 60, 100, 365 days)
- The popup is dismissible with a single tap.

---

## 7. Rewards

- Rewards are user-defined — Alok creates each reward with:
  - A name (e.g., "Movie Night")
  - An optional description or note
  - A **point threshold** required to claim it
- A reward becomes **claimable** when Alok's total point balance ≥ the reward's threshold.
- Claiming a reward:
  - Is a **manual action** — Alok taps "Claim"
  - **Deducts the threshold points** from the total balance
  - Moves the reward to the "Claimed History"
- Unclaimed rewards **never expire** — they stay in the rewards list indefinitely.
- Multiple rewards can be claimable at the same time.
- Alok can edit or delete a reward at any time (even after it becomes claimable, before claiming).

---

## 8. Data & Storage

- All data is **stored locally on device** in v1 — no backend, no sync, no account.
- Historical data is retained indefinitely unless manually deleted by the user.
- Excel data migration is **not supported** in v1 — Alok starts fresh.
