# Feature Plan — Atomic Habits Wave (July 2026)

Implementation plan for five features: **never-miss-twice banner, identity line,
stopwatch-lite, last-call + clutch bonus, habit stacking**. Produced from a
13-agent design/critique pass over the codebase; all file:line anchors verified
against the working tree as of 2026-07-17.

**Release strategy (value-to-friction ranked):**

| Wave | Features | Why |
|---|---|---|
| **0 — Foundation** | Schema batch + TaskCompletionService + snackbar composition rule | Everything below depends on it; must land first at behavior parity |
| **1** | Never-miss-twice → Identity line → Stopwatch-lite | Best ratio: zero/low notification surface, self-contained, Vivo-safe |
| **2** | Last-call + clutch (default OFF) | Doubles per-task notification volume — contained by opt-in |
| **2/3** | Habit stacking (trimmed core first) | Widest blast radius; let the service consolidation settle first |

---

## Wave 0 — Foundation (do these once, before any feature)

### 0a. One schema commit (v6 → v7)

Single `if (from < 7)` block in `lib/core/database/database.dart` (after the
`if (from < 6)` branch, ~line 77). **Do not open three separate blocks.**

```dart
if (from < 7) {
  await m.addColumn(tasks, tasks.stackedAfterTaskId);        // habit stacking
  await m.addColumn(taskCompletions, taskCompletions.durationSeconds); // stopwatch
  await m.addColumn(milestones, milestones.identity);        // identity line
}
```

Columns (all nullable, no defaults, no backfill):
- `tasks.stacked_after_task_id` — TEXT. **Plain column, NO `references()`** —
  self-referential FKs are awkward in Drift; dangling ids handled in code.
- `task_completions.duration_seconds` — INTEGER. Null = untimed completion.
- `milestones.identity` — TEXT ("a runner").

Same commit: add `PointsReason.clutchBonus('clutch_bonus')` to
`lib/core/database/tables/points_history.dart` (textEnum stores the Dart name —
no migration needed, just codegen).

Then **one** `dart run build_runner build --delete-conflicting-outputs`.

BackupService needs zero changes — Drift `toJson`/`fromJson` picks up new
nullable columns automatically; pre-v7 backups restore with nulls.

### 0b. One TaskCompletionService (the critical consolidation)

The post-completion ritual (completeTaskNow → recordDayLogged → achievement
check → reward check → haptics → snackbar) is duplicated across **4 call
sites** today, and stopwatch adds a 5th:

1. `task_tile.dart` `_toggle` (unchecked branch)
2. `task_tile.dart` `_toggleChip` (today branch; retro branch → `completeOn`)
3. `timeline_view.dart` `_toggleTask`
4. `notification_actions.dart` `_handleDone` (`celebrationChecks: false`)
5. `stop_timer_sheet.dart` MARK COMPLETE (new — **must be call site #5, not a
   copy of old TaskTile code**)

New file `lib/core/services/task_completion_service.dart` with the **merged**
result type (three designs each invented their own — this is the reconciled
one):

```dart
// DB layer (database.dart): completeTaskNow gains {int? durationSeconds} and
// returns a record — renamed so it can't collide with the service class:
typedef DbCompletionOutcome = ({String completionId, int basePoints, int clutchBonus});

// Service layer:
class CompletionResult {
  final String completionId;
  final int basePoints;
  final int clutchBonus;            // 0 until Wave 2
  final int? attachedDurationSeconds;
  final List<Task> stackedNext;     // empty until stacking lands
  final List<AchievementBadge> streakBadges;
  final List<AchievementBadge> completionBadges;
  final List<Reward> unlockedRewards;
  final String? identityLine;       // null until identity lands
  bool get hasCelebration => /* badges or rewards non-empty */;
}
```

`completeToday(db, task, {celebrationChecks = true})` runs, in order:
timer auto-attach (TimerService) → `db.completeTaskNow(durationSeconds:)` →
`StreakService.recordDayLogged` → optional achievement/reward checks →
stack trigger (Wave 2/3) → identity vote line → self-nudge cancel.
`completeOn(db, task, date)` = retro path: no streak, no timer, no stack
trigger; celebration checks kept. **The service returns data only — haptics,
floaters, and snackbar choice stay at call sites** so each surface keeps its
presentation.

Land this refactor **at behavior parity, as its own commit**, before any
feature logic. Consolidation bugs and feature bugs must not mix.

### 0c. One snackbar composition rule

Four features want to mutate the same `FeedbackKind.done` snackbar in
`app.dart _renderFeedback`. Without a rule, whichever merges last silently
wins. The rule (document it next to the celebration-beats-UNDO comment):

- **Title** — exactly one, by precedence:
  `identityLine` > clutch title ("⚡ Beat the clock!") > default `Logged "X"`.
- **Trailing** — ordered join of present segments, single line, ellipsized:
  `+10 pts` · `+5 bonus ⚡` · `⏱ 23:41` · `Next: "Journal" 🔗`.
- **Icon** — `how_to_vote` if identity, else `bolt` if clutch, else
  `check_circle`.
- All fields ride ONE `NotificationFeedbackEvent` (add `clutchBonus`,
  `durationSeconds`, `nextStackedTaskName`, `identityLine` in a single edit).
- Implement as a small pure function `(event) → (icon, title, trailing)` so
  the collision cases are unit-testable.

### 0d. Voice sheet (copy freeze rule)

The five copy sets drifted (gentle coach vs sports-bar vs jokey). House rule:
**short, warm, second person, max one emoji per string, urgency through
brevity not alarm glyphs.** Reference register = the never-miss-twice and
identity copy. Concretely: no 🚨/😤; "clutch pts" → "+5 bonus ⚡"; label
features by behavior, not book jargon ("Do it after another task", not
"Habit stacking").

---

## Wave 1, Feature 1 — Never-Miss-Twice banner  (Effort: S)

**What:** dismissible Home banner when yesterday had no real completion (and
no intentional skip) and today has no win yet: "One small win today puts you
right back on track."

**Schema:** none. **Codegen:** none.

**Where & how:**

| File | Change |
|---|---|
| `lib/features/home/widgets/never_miss_twice_banner.dart` (new) | Pure predicate `shouldShowNeverMissTwice({completions, now, hasUpNext, dismissedDate})` + `NeverMissTwiceBanner` widget (streak-orange tint, 🔥, close button). Predicate is Riverpod-free → unit-testable. |
| `lib/core/services/app_prefs.dart` | `nmt_dismissed_date` key with sync cache (copy the onboarding/theme block style, ~lines 91–131). |
| `lib/features/home/home_screen.dart` | **Mount between `_ViewToggle` and the `Expanded` body** (NOT inside the list-mode ListView) so it shows in both List and Timeline modes — same slot the timer banner uses. |

Predicate (all date-only, from `recentCompletionsAllProvider` — already
streamed to Home): (a) no real completion today (auto-hides reactively the
moment one lands); (b) yesterday has no real completion AND no skip (skip =
intentional rest — never nag after it); (c) ≥1 real completion in the 3 days
before yesterday (filters fresh installs and long-lapsed users); (d) something
is due today; (e) not dismissed.

**Critic fixes applied:**
- **Episode-scoped dismissal** — dismissing suppresses until a *new* miss
  occurs (not just until midnight), so one bad Tuesday ≠ three guilt banners.
- **Reset-morning copy** — when the streak-reset popup fired this session, the
  banner uses forward-only copy ("One win today starts a new streak 🔥") so it
  reads as continuation, not repetition.
- **One-attention-banner policy** — priority: ActiveTimerBanner >
  never-miss-twice > reward-unlock; when a banner holds the slot, collapse
  Ready-to-claim cards to a one-line gold pill ("🎁 2 rewards ready — CLAIM").

Copy: `Never miss twice! 🔥` / `Yesterday slipped by. One small win today puts
you right back on track.` — streak>0 variant: `Save your streak! 🔥` / `One win
today keeps your 12-day streak alive.`

---

## Wave 1, Feature 2 — Identity line  (Effort: M)

**What:** milestones get an optional identity ("a runner"); every 3rd real
completion of a task under that milestone swaps the done-snackbar title to
"Another vote for becoming a runner."

**Schema:** `milestones.identity` (in the Wave-0 batch).

**Where & how:**

| File | Change |
|---|---|
| `lib/core/services/identity_voice.dart` (new) | `IdentityVoice.voteLineFor(db, task)` — null unless milestone has identity AND `getRealCompletionCountForTask(task.id) % 3 == 0` (counted AFTER insert). Template rotation by `(count ~/ 3) % 3` — deterministic, mirrors `_catchyTitle` hash rotation. |
| `lib/core/database/database.dart` | `getRealCompletionCountForTask(taskId)` (filter isSkip=false, isNd=false). |
| `lib/core/services/task_completion_service.dart` | Call `voteLineFor` inside the service (populates `result.identityLine`) — **NOT at the five call sites** (that design predated the consolidation). |
| `lib/app.dart` | Title precedence per rule 0c; icon `Icons.how_to_vote_rounded`. |
| `milestone_form_sheet.dart` | One TextField below description: label "I am becoming… (optional)", hint "a runner · a writer · an early riser". Normalize: trim, strip leading "becoming "/"i am becoming ", strip trailing period, empty → null. Wire `identity: Value(...)` into both save paths. |
| `milestones_screen.dart` ~line 100 | Accent-colored italic "Becoming a runner" between name and description. |
| `milestone_detail_screen.dart` ~line 260 | Same line as first child of `_Header`'s Column. |

**Critic fix applied — carry flag:** when a vote moment is masked by a
badge/reward celebration (common early — first_log etc.), don't drop it; fire
the vote line on the NEXT real completion (one-shot carry flag in
IdentityVoice, no queue). Otherwise new users may never see the feature.

---

## Wave 1, Feature 3 — Stopwatch-lite  (Effort: L)

**What:** start a timer on any unchecked task (long-press sheet), live-ticking
banner on Home with STOP, stop-flow routes through the completion ritual and
stamps `duration_seconds`, auto-attach when the task completes by any other
means, "Time invested · This week" Stats card.

**Architecture:** timer state = two AppPrefs values
(`active_timer_task_id`, `active_timer_started_at_millis`) with sync caches.
Elapsed is ALWAYS recomputed from wall clock → survives app kill and Vivo
process death with **zero background services or alarms**. One timer at a
time. 12h sanity cap. Clamp-at-zero for clock rollback.

**Where & how:**

| File | Change |
|---|---|
| `lib/core/services/timer_service.dart` (new) | `ActiveTimer`, start/clear/elapsed/capped/format + broadcast `watch()` stream (mirrors NotificationFeedback bus pattern). |
| `lib/shared/providers/active_timer_provider.dart` (new) | `StreamProvider` over `TimerService.watch()`. |
| `lib/features/home/widgets/active_timer_banner.dart` (new) | Green-tinted pinned card: pulsing ⏱, task name, mm:ss (1s UI ticker, wall-clock derived), STOP → stop sheet. Vanished-task guard: clear + "That task vanished — timer cleared." |
| `lib/shared/widgets/stop_timer_sheet.dart` (new) | Branch A (not done today): "Nice session! ⏱ 23:41" → MARK COMPLETE (+N PTS) via **TaskCompletionService.completeToday** / KEEP TIMING / Discard. Branch B (already done): "Add 23:41 to today's log?" → ADD TIME (`db.addDurationToCompletion`). Plus `showTimerConflictDialog` (FINISH THAT ONE / DISCARD IT / CANCEL). |
| `lib/core/database/database.dart` | `completeTaskNow`/`completeTaskOn` gain `{int? durationSeconds}`; add `addDurationToCompletion`. |
| `task_tile.dart` + `timeline_view.dart` | "Start timer" row added to the existing long-press sheets (flips to "Stop timer · 23:41 on the clock" when this task owns the timer). No form changes, no per-tile button. |
| `home_screen.dart` | Mount banner between `_ViewToggle` and `Expanded` (both view modes). |
| `stats_screen.dart` | `_TimeInvestedCard` after the By-milestone block; hidden until a timed completion exists this week. |
| `app.dart` | `⏱ mm:ss` trailing segment per rule 0c. |

**Critic fixes applied:**
- **Background-isolate hydration bug (medium):** `notificationTapBackground`
  never calls `AppPrefs.hydrate()`, so the timer auto-attach silently fails
  when Done is tapped with the app killed. Fix: add `await AppPrefs.hydrate();`
  in `handleNotificationAction`'s `ownDb` branch (`notification_actions.dart`
  ~line 60).
- **Discoverability (high):** the long-press sheet is invisible. Ship: (1) a
  one-time coach mark on first Home visit after update ("Long-press any task:
  timer, skip & more"), (2) a small ⏱ ghost icon on timeline cards, (3) one
  line on the onboarding Track page. Fixes skip/missed discoverability too.
- **Midnight rule:** session credits the day the timer STOPS (an
  11:50pm→12:10am session advances the new day's streak — generous, matches
  every other logging surface).

---

## Wave 2 — Last-call + clutch bonus  (Effort: M, default OFF)

**What:** (a) urgent second reminder before a scheduled task's window closes;
(b) +5 bonus points for completions landing in the last 20% of the window.

**Schema:** none beyond `PointsReason.clutchBonus` (Wave-0 batch).

**Where & how:**

| File | Change |
|---|---|
| `lib/core/database/database.dart` | `clutchBonusPoints = 5`; `isClutchTime(task, now)`; `completeTaskNow` inserts the bonus `points_history` row **inside the existing transaction with `taskCompletionId` set** → `undoCompletion`'s existing delete-by-taskCompletionId refunds it for free. Returns `DbCompletionOutcome`. |
| `lib/core/services/task_completion_service.dart` | Surfaces `basePoints`/`clutchBonus` on the result; calls `unawaited(NotificationScheduler.reschedule())` after completion so a pending last-call cancels immediately (not on the 15-min ticker). |
| `notification_service.dart` | `lastCallBase = 2300000` (slot 200 of taskBase space; collision-free vs all existing families; swept by the existing `id >= taskBase` arm of `_isManagedId`). |
| `notification_scheduler.dart` | Last-call block in the day loop: due + `startMinute != null` + **`durationMinutes >= 45`** + not logged today; fire at `start + duration − 20 min`. Joins the desired-map diff → past-time skip and stale-cancel come free. Urgent-but-calm copy pool. |
| `notification_prefs.dart` + `notification_settings_sheet.dart` | `notif_last_call_enabled`, **default false**; toggle visually nested under TASK REMINDERS ("Last-call alerts — one final nudge 20 min before a scheduled task's window closes"). |
| `app.dart` | Clutch title/trailing per rule 0c ("⚡ Beat the clock!", "+10 pts +5 bonus ⚡"). |

**Critic fixes applied:**
- **≥45-min window guard** (was ≤20): stops reminder + last-call double-firing
  minutes apart on short tasks.
- **Clutch restricted to windowed tasks in v1.** The after-9-PM rule for
  anytime tasks inflates points ~50% for evening loggers and makes the special
  moment ambient noise. Revisit in v2 with a "zero completions before 9 PM +
  once per day" guard if wanted.
- **Evening-nudge suppression:** in `reschedule()`, skip that day's 9 PM
  streak alert when a last-call is scheduled between 8:30–10 PM — kills the
  9–10 PM notification rush hour.
- **Copy:** "⏳ 20 min left: %s" / "Final stretch — %s"; no 🚨, no "clutch pts"
  jargon.

---

## Wave 2/3 — Habit stacking  (Effort: L — trimmed core first)

**What:** "After [anchor task], I will [this task]" —
`tasks.stacked_after_task_id` names an anchor; completing the anchor surfaces
the stacked task.

**v1 (trimmed core — ~⅓ the surface for ~80% of the value):**

| File | Change |
|---|---|
| `lib/core/database/database.dart` | `getTasksStackedAfter(anchorId)`; cascade-to-null inside `deleteTaskCascade` and `deleteMilestoneCascade` transactions. |
| `task_form_sheet.dart` | **"More options" collapsed expander at the form's bottom** holding: "Do it after another task" picker + the existing reminder-date row (net-negative visible fields on the default form). Picker: active tasks minus self minus cycle candidates (visited-set walk, depth cap 25); footer "Tasks that would loop back to this one aren't listed." |
| `home_screen.dart` | `🔗 After Meditate` meta segment; stable-partition Up-next (anchor-satisfied tasks first, waiting ones last). **No dimming in v1** (0.55 opacity read as "disabled" — cut per UX critique). |
| `task_completion_service.dart` | `stackedNext` populated: stacked tasks not yet really-done today, due today per their own recurrence (undated one-shots ride the anchor's schedule). Single-level query → data-level cycles can't loop. |
| `app.dart` | `Next: "Journal" 🔗` trailing segment per rule 0c. |

**v2 additions (after the service settles):**
- System nudge (`_stackNudgeBase = 70000 + hash`, outside the managed sweep —
  immediate `show()`, never a scheduled alarm → inherently Vivo-safe) **gated
  on app lifecycle**: fire ONLY when
  `WidgetsBinding.instance.lifecycleState != resumed` (foreground users
  already have the snackbar + list re-sort; a push during active use is the
  naggiest moment of the release). Coalesce multi-stack anchors into one
  notification ("🔗 Next up: Journal +2 more").
- Undo retraction: in both undo paths (app.dart UNDO action,
  `notification_actions._handleUndo`) cancel downstream stack nudges —
  `for (s in getTasksStackedAfter(taskId)) NotificationService.cancel(70000 + hash(s.id))`.
- Waiting-state pill on tiles ("🔗 after Meditate") at ~0.7 opacity — labeled
  state, not implied.
- Opt-in policy must match last-call's (dedicated pref, or document that stack
  nudges ride the task-reminders master — the two designs currently
  contradict).

---

## Build order & verification

1. **Wave 0a** — schema commit (v7 batch + clutch enum) + codegen.
2. **Wave 0b** — TaskCompletionService at behavior parity; rewire 4 sites;
   verify haptics/floater/snackbar priority unchanged per site.
3. **Wave 0c/0d** — snackbar composition function + voice sheet.
4. **NMT banner** → **Identity** → **Stopwatch** (each independently
   shippable; test on the iQOO after each).
5. **Last-call + clutch** (default off).
6. **Stacking trimmed core** → v2 trigger machinery.

**Cross-feature verification matrix (the cases the critics flagged):**
- Timer running on anchor A (B stacked after A) → STOP → MARK COMPLETE →
  B surfaces, snackbar shows `⏱` + `Next: "B" 🔗`, duration lands.
- Clutch completion → 2 points_history rows share `taskCompletionId` → UNDO
  refunds both (balance −15).
- 3rd completion that also unlocks a badge → celebration wins, vote line
  carries to the 4th completion.
- Done tapped on a reminder while that task's timer runs, app killed →
  duration attaches (hydrate fix), timer cleared, no double-credit via ADD TIME.
- Undo anchor within 6s → stacked nudge cancelled (v2).
- Reset morning → streak popup then forward-only NMT copy; banner hides the
  frame a completion lands; UNDO brings it back.
- Backup → restore round-trips all three new columns; no timer resurrection.

## Deferred / cut

- Two-minute-rule fallback + Goldilocks difficulty suggestions — needs usage
  data; revisit after this wave ships.
- After-9-PM anytime clutch — see Wave 2 notes.
- Stack-nudge-while-foregrounded, stacking dimming — cut from v1 by design.
- Place-based implementation intentions — out of scope.
