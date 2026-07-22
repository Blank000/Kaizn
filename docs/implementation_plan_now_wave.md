# Implementation Plan — Roadmap "NOW" Wave

*2026-07-23. Engineering plan for the 8 NOW items in
`docs/product_roadmap_research.md`, sequenced into three ship-able waves.
Verified against the codebase: `googleapis ^13.2.0`, `googleapis_auth`, `http`,
and `home_widget` are already dependencies; `TaskStatus.archived` already
exists; the Drive backup already bridges google_sign_in → googleapis clients.*

---

## Wave A — pure Dart, no schema change, no new permissions

Ship first; every item is computable from data we already store. One `flutter
run`, no codegen, no reinstall caveats.

### A1. Habit strength score
- **New** `lib/core/services/habit_strength.dart`: Loop-style exponential
  smoothing. Walk scheduled days (via `RecurrenceRule.isDueOn`) from first
  completion (cap 120 days back): `S = S·(1−α) + α·done`, α ≈ 0.052
  (13-day half-life). Skip days are excluded entirely (not counted, no decay)
  — consistent with skip-vs-missed honesty. Returns 0–100.
- **Surfaces:** milestone detail — per-task "· 87% strong" appended to
  `_metaForDetail`; header gains a strength ring (avg of active recurring
  tasks) next to the votes line. Home stays untouched (attention budget).
- **Perf:** compute per task from the already-watched completions list;
  memoize per build. No DB work.

### A2. Frictionless quick capture
- Home app bar: ⚡ icon → minimal sheet: ONE autofocused TextField + ADD.
  Inserts into the Inbox milestone (auto-seed guaranteed by databaseProvider)
  with defaults: recurrence none, no due date, 10 pts, 30 min. Sheet stays
  open after add ("Added ✓ — next?") for burst capture; swipe down to close.
- Undated one-shots already surface in Up Next daily, so captures are visible
  immediately — no new list needed. "Inbox: N to sort" chip deferred to the
  weekly-review feature (NEXT).
- **Files:** `lib/features/home/widgets/quick_capture_sheet.dart` (new),
  app-bar wiring in `home_screen.dart`.

### A3. Projected finish + estimate calibration
- Up Next section header line: `~2h 40m · done by 7:15 PM` — sum of
  `durationMinutes` over upNext + hidden queued members, projected from now.
  Recomputes free on every stream tick.
- `stop_timer_sheet.dart`: when the task has a duration, add one line —
  "Planned 30m · took 48m" (neutral copy, no judgment color).
- Task form duration row helper: "usually takes ~45m" — new DB read
  `getAvgDurationSeconds(taskId)` (AVG over non-null duration_seconds,
  non-skip completions; plain customSelect, no codegen).

### A4. Run stack — the routine player
- **New** `lib/features/focus/stack_runner_screen.dart`, route `/run-stack/:taskId`
  (top-level, outside bottom nav). Extract `chainFor(task, allTasks)` (walk-up
  + BFS, shared with queue_sheet) into `task_stack.dart`.
- Full-screen player: current task name (+ tiny 2-min alternative if defined),
  shrinking countdown from `durationMinutes`, controls: DONE (fires
  `TaskCompletionService.completeToday` — points/confetti/quests fire
  normally), SKIP STEP (db.skipTaskNow), +5 MIN, pause, exit. Countdown hitting
  zero never auto-completes — it prompts ("Done? / +5") because honesty beats
  convenience. Chain-end: existing celebration dialog with total time.
- Entry points: ▶ button in the queue-sheet header; "Run queue" row in both
  release-in-place menus. Links that are already done/skipped today are
  pre-crossed and auto-skipped by the player.
- Keep screen awake during a run: `wakelock_plus` (new dep, tiny). Timer state
  lives in the screen (wall-clock based, like TimerService) so backgrounding
  doesn't drift.

## Wave B — one schema bump (v10) + the recovery features

Batch all schema work into a single migration + codegen run.

### B0. Schema v10 (single migration)
- `task_completions.miss_reason` TEXT nullable — the miss-check-in tag.
- Migration: `addColumn` on the v9→v10 branch (non-destructive, same pattern
  as color_index). Then `dart run build_runner build --delete-conflicting-outputs`.

### B1. Miss check-in (self-compassion + B=MAP triage)
- After any "Mark as missed" action (task_tile `_markMissed`, timeline sheet,
  chip actions): show a dismissible bottom sheet — kind line ("One miss is
  data, not a verdict.") + four chips: Didn't see it / Too hard / No time /
  Didn't feel like it. Fully skippable; dismiss = no tag.
- Routing on tap: *Didn't see it* → opens the task's reminder editor;
  *Too hard* → if a 2-min version exists, offer "do it now instead" (undoes
  the miss, completes tiny — the never-miss-twice save), else deep-link to the
  form's 2-min field; *No time* → offer duration shrink (Goldilocks-style);
  *Didn't feel like it* → identity line card, nothing else.
- Tag written to `miss_reason` on the ND completion row. GoldilocksService
  gains a "3× same reason" trigger later (already designed to accept it).

### B2. Comeback flow (gentle re-entry)
- Detection in `main.dart`/router: `AppPrefs.lastAppOpenDate` ≥ 7 days ago →
  redirect once to `/comeback` (new AppPrefs flag `comebackPendingDate` so it
  survives process death, cleared on completion).
- Screen: warm header (no miss counts, no red), list of active recurring
  tasks with keep/shelve toggles (shelve = `TaskStatus.archived` — the enum
  already exists and all providers already filter it), "restart with 1–3"
  emphasis, single CTA. Suppress the streak-reset popup that session
  (`_resetPopupShownThisSession` pattern already exists).
- Streak: `checkOnAppOpen` runs after, streak resets quietly; copy on the
  comeback screen frames Monday/today as the new line ("fresh start effect").

### B3. Rest mode
- `AppPrefs.restModeUntil` (nullable date). Settings row + Home banner
  ("Rest mode · until Jul 30 · END NOW", uses the attention slot at top
  priority while active — timers/NMT/coach suppressed anyway).
- Gates while active (read-time logic, NO daily skip-row writing):
  - `StreakService.checkOnAppOpen`: days inside the rest window count as
    skip-days (advance `lastLoggedDate`, never reset).
  - `NotificationScheduler.reschedule`: desired set = empty (cancels all).
  - `QuestService`: no quest today. Home list/timeline: sections render but
    the progress card shows "Resting 😴" instead of X/Y.
- On expiry (date passes) everything resumes with zero cleanup — that's the
  payoff of gating reads instead of writing skip rows.

## Wave C — Google Calendar read-only overlay

### C0. Prerequisite (USER ACTION — Cloud Console)
Add the `https://www.googleapis.com/auth/calendar.readonly` scope to the OAuth
consent screen for the existing client. Until then, connect attempts fail the
same way the original DEVELOPER_ERROR did.

### C1. Auth
- `auth_service.dart`: add `CalendarApi.calendarReadonlyScope` to the scope
  list. Existing sessions won't have it — Settings' "Connect Google Calendar"
  toggle calls `requestScopes` (incremental consent) and stores
  `AppPrefs.gcalEnabled` + chosen `gcalCalendarIds`.

### C2. Calendar service + provider
- **New** `lib/core/services/calendar_service.dart`: reuse the same
  google_sign_in → googleapis client bridge BackupService uses for Drive.
  `eventsForDay(day)`: `events.list(calendarId, timeMin/timeMax, singleEvents:
  true, orderBy: startTime)` per selected calendar; all-day events excluded
  from the grid (shown as a slim strip under the Anytime tray). In-memory
  cache keyed by (day, calendarId) with 15-min TTL; refresh on app resume.
- `calendarEventsProvider = FutureProvider.family<List<BusyBlock>, DateTime>`.

### C3. Timeline layer
- New paint layer in `_TimeGrid` UNDER task cards: gray rounded blocks
  (`IgnorePointer` — no drag, no tap, no resize), title at low opacity, hatch
  or 12% fill so user tasks visually sit "on top of" busy time. Works on any
  viewed date (past/future) since fetch is by day.
- Settings section: connect toggle, calendar checklist, "events stay on your
  device" privacy note.
- Explicitly NOT in this wave: writing to Google Calendar, auto-avoiding busy
  time when deriving queue slots (candidate for the drag-suggestion phase).

## Sequencing & checkpoints

| Order | Items | Schema | New deps | User action |
|---|---|---|---|---|
| Wave A | strength, capture, projection, stack runner | none | wakelock_plus | rebuild + test |
| Wave B | miss check-in, comeback, rest mode | v10 (+codegen) | none | rebuild (codegen first!) + test |
| Wave C | GCal overlay | none | none (googleapis present) | Cloud Console scope, then rebuild |

Each wave ends with: `flutter analyze` → commit per feature → push → on-device
test via `.\dev.ps1`. Wave B's rebuild MUST be preceded by build_runner
(schema v10), per RUN_ANDROID.md.

## Risks / open questions
- **Rest mode × streak math** is the only delicate logic (touching
  checkOnAppOpen); everything else is additive. Mitigation: treat rest window
  exactly like recorded skip days, which the streak service already survives.
- **Comeback shelving** uses `TaskStatus.archived` — verify every watcher
  filters archived (allTasksProvider does; double-check stats queries).
- **GCal quota/latency**: per-day fetches are tiny; TTL cache handles
  timeline scrubbing. Incremental syncTokens deliberately deferred to the
  write-back phase.
- **Stack runner + timer service**: the runner does NOT start TimerService
  stopwatches per step (double-timer confusion); it attaches the step's
  elapsed as durationSeconds on completion instead.
