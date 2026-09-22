# Zuzu — full context briefing for an AI

*Paste this whole file into a fresh AI session to bring it up to speed on the
product, the code and the decisions already made. Written 2026-09-22 against
branch `timetable`.*

---

You are being briefed on **Zuzu**, a Flutter mobile app (Android shipping,
iOS ported but not yet compiled). Read everything below before proposing
anything. Section 10 lists decisions that are already locked — suggesting
them again wastes the owner's time.

## 1. What Zuzu is

A **gamified, milestone-centric habit and goal tracker** for a single user.
It replaced the owner's hand-built Excel habit scorecard, and the Excel
origin still shows in the product's values: it is a **record you can trust**
first and a game second.

The loop is:

> **Milestones** (goals, projects, habit groups) contain **tasks**.
> Completing tasks earns **points**. Points buy **rewards that the user
> defines themselves**. Streaks, levels, quests and badges sit on top.

The reference point for tone is Duolingo — daily, celebratory, streak-driven
— but the owner has repeatedly pushed the brand *away* from childish and
toward **professional, lifestyle, aspirational**. Celebration is loud; guilt
is quiet. The app never nags or shames.

Single-user, offline-first, local SQLite. No server, no accounts beyond
Google Sign-In for backup. Nothing leaves the device except an optional
Google Drive backup and optional AI calls the user pays for with their own
key.

## 2. Brand and identity

- **Name:** Zuzu. (Earlier names, all discarded: Kaizn, Yatta!, Kizora. The
  full naming graveyard with availability findings is in `docs/brand.md`.)
- **Icon:** owner-supplied artwork — an open book with a checklist and a gold
  tick, with Zuzu the bird peeking over the top, on deep teal `#034749`.
  Built into launcher assets by `tools/build_icon_from_art.py`.
- **Interface palette** (`lib/core/theme/app_colors.dart`): primary green
  `#58CC02`, streak orange `#FF9600`, rewards gold `#FFD700`, info blue
  `#1CB0F6`. Full light/dark theming; `context.appCardSurface` and friends
  are the hot-path accessors.
- **Identity strings deliberately NOT renamed**, because changing them
  orphans user data: the Dart package name, the Android package id
  `com.alokraj.habit_reward_tracker`, the Drift database name, the Drive
  backup filename, and the iOS app-group id.

## 3. The cast, and the rules that govern it

Four characters exist. **Their roles do not overlap — this is enforced in
code review, not just convention.**

| Character | Owns | Notes |
|---|---|---|
| **Master Ren**, a fox sensei | Reflection: rest days, comebacks, empty states, miss check-ins, the Sunday review, stats voice | `ren_figure.dart`, CustomPaint, golden-tested. **Never appears in a celebration frame. Never guilts.** User-toggleable in Settings. |
| **Pico**, a gadget robot | The machine: every AI surface | `pico_figure.dart`, golden-tested. Not toggleable — it is a functional surface. |
| **Kai**, a shonen boy | Hype, greetings, celebrations | Designed and approved, **not yet ported into the app**. |
| **The fire** | All streak visuals | A Lottie animation, not a character drawing. |

Hard rule inherited from the start: **no copyrighted characters.** Luffy was
explicitly declined. Everything is original.

## 4. Data model — Drift/SQLite, schema v13

Ten tables in `lib/core/database/tables/`:

`milestones`, `tasks`, `task_completions`, `points_history`, `rewards`,
`streak`, `change_log`, `league_weeks`, `ai_chat_messages`, `timer_events`.

Key shapes:

- **milestones** — name, description, identity line, target date,
  completion-bonus points, 8-colour palette index, status. Deleting one
  cascades its tasks.
- **tasks** — milestone id (nullable, for adhoc), name, **description**,
  points per completion, recurrence (`none`/`daily`/`weekly`/`monthly`) plus
  a JSON `recurrenceConfig`, due date, start minute + duration (for the
  timeline), per-task reminder (recurring or one-shot date),
  `stackedAfterTaskId` (habit stacking), `tinyName` (the 2-minute version),
  status.
- **task_completions** — task id, `completedOn` (date-only semantics),
  points earned, `durationSeconds` (from the stopwatch), `isTiny`, `isSkip`,
  `isNd` (not-done / honest miss), `missReason`, note.
- **timer_events** — append-only stopwatch ledger. One row per
  start / pause / auto_pause / resume / stop / complete / discard, carrying
  the session id, a denormalised task name (so it survives task deletion),
  the clock reading, and wall-clock time. **Nothing in the app ever edits or
  deletes these rows.**
- **ai_chat_messages** — local Pico chat history, threaded, with a
  `planApplied` one-shot guard.

**Migration rule, non-negotiable:** a destructive wipe path exists for
pre-v2 only. **Never add another wipe — real user data exists.** All
migrations since are additive `addColumn` / `createTable`.

## 5. Feature inventory

### Logging and honesty rules
- Tap a tile to complete; tap again to undo (today only).
- Long-press gives **Skip today** (intentional rest, streak-safe, no points)
  or **Mark as missed** (opens a self-compassion check-in with four "what got
  in the way?" reasons, stored on the row and used by the Sunday review).
- Multi-day weekly tasks render M–S chips. Current-week past chips can be
  retro-logged; future chips are disabled. **Retro-logs never resurrect a
  streak.**
- **Future days are read-only everywhere. Past days are read-only reviews**,
  with the current-week weekly-chip window as the single exception. No
  back-dating, no history editing. This is deliberate.
- Dateless one-shot tasks live in an **Anytime** section on Home — visible,
  but excluded from "today" counts and celebrations.

### Streaks, points, gamification
- Daily streak: any real completion counts the day. One missed day is
  forgiven; two breaks it. A points-priced **Streak Shield** can restore a
  just-broken streak. Skips preserve it.
- **Day Complete** choreographed sequence on the last scheduled task, with
  the fire as hero and a "YATTA!" shout (kept deliberately — it is Japanese
  for "I did it", not a leftover brand reference).
- **First-Win Ignition** on the first completion of a day.
- Points convert to **user-defined rewards** with threshold prices, a claim
  flow with confetti, and unlock snackbars.
- Plus: daily quest row, nine achievement badges and a gallery, levels,
  weekly league close-outs, a shareable progress card, optional sounds.

### Home
Greeting, stats header, seven-dot week board, today's progress card, and the
**one claw** line (the single weekly intention set in the Sunday review).
**Sensei Post** is Ren's daily accountability card, generated from real data
(remaining task names, counts, hour of day, yesterday's misses); tapping it
opens the Day's Ledger.

Sections: Up next / Done / Missed / Skipped / Anytime. A **single attention
banner slot** with strict priority: running timer > never-miss-twice >
Goldilocks coach. A **Timeline view** toggle allows dragging tasks onto time
slots, with read-only Google Calendar busy blocks behind them.

### Focus tools
- **Stopwatch, multi-session.** Every task can hold its own session, but
  **only one ever runs** — starting or resuming a second task banks and
  pauses the first rather than forcing a discard. The invariant is enforced
  by serialising all mutations through one queue, and every load repairs an
  impossible state by banking time rather than dropping it.
- **Where a timer shows:** the pinned Home banner carries only the *running*
  session. Paused work appears as an amber pill inside its own task row, on
  every surface that renders a task tile.
- **It never auto-pauses on backgrounding.** Timing off-screen work
  (reading, a workout) is legitimate. This is an owner decision — do not
  "fix" it.
- **Time ledger** at `/stats/time-log`: session cards, active vs away time,
  typical session length, most common start hour, interruption counts.
- **Stack Runner**: guided queue execution with a per-step countdown,
  DONE / SKIP / +5 min / 2-minute rescue, and wakelock. Ren meditates beside
  the timer and opens one eye when you pause.

### Stats and the Sunday review
Lifetime and weekly cards, a 30-day points chart, a month heatmap, top tasks,
by-milestone breakdown, and a time-of-day chart with a peak-hour insight in
Ren's voice. The **Weekly Review** at `/review` is three scrolls: what
burned, what slipped (using the stored miss reasons), and one claw stamped
for next week.

### Notifications
Morning summary, evening nudge, per-task reminders with Done / Skip / Snooze
action buttons, and a last-call that replaces the evening nudge in its band.
Android uses exact alarms. The background isolate re-hydrates prefs and
attaches its own database, and waits for the stopwatch ledger to flush before
closing it.

### Auth and backup
Google Sign-In with silent restore at startup. Manual Google Drive AppData
JSON backup and restore (wipe and reinsert in foreign-key order).

## 6. Pico, the AI assistant — read this carefully if you are that assistant

- **Floating Pico** sits over every tab: freely draggable in 2-D, remembers
  its position, tap to open the chat.
- **Chat** at `/ask-ren`. The system prompt carries a live **context pack**
  (streak, week, claw, every milestone / task / reward with ids and
  schedules) plus a full **app manual** and hard boundaries. Markdown
  rendering, a growing 1→4 line input, on-device **speech-to-text** that
  never auto-sends, suggestion chips, and locally persisted thread history.
- **Plan pipeline.** The AI replies with JSON that can create milestones,
  tasks and rewards, and **update** any of them by exact id (rename,
  re-point, re-schedule, set or clear reminders).
- **The safety invariant: the AI proposes, the user previews, the app
  executes.** There is **no delete operation** and there never has been.
  History is immutable. Ids are normalised and fall back to a unique-name
  match; ambiguous targets are skipped and shown in red in the preview.
  Applying retires the button permanently so nothing is created twice.
- **Bring your own key.** The user supplies their own OpenAI key, stored on
  device only. Default model `gpt-4o-mini`. A setup gate explains this before
  asking.
- Settings also offers **Export for AI / Import plan**, giving the same
  powers by copy-paste with any chat AI.

## 7. Architecture

- **Flutter / Dart 3.** State via **Riverpod**. Routing via **GoRouter**
  with a `StatefulShellRoute.indexedStack` bottom-nav shell.
- **Drift** over SQLite, code-generated. Providers expose Drift `.watch()`
  streams — **never poll**; an earlier `Stream.periodic(1s)` was the main
  source of UI lag and was removed.
- Characters are **CustomPaint**, built from primitives (ellipses,
  round-capped strokes) rather than hand-plotted polygon paths, which caused
  repeated distortion. Guarded by **golden tests**.
- Layout: `lib/core/` (database, services, theme, constants),
  `lib/features/` (achievements, ai, auth, comeback, focus, home, milestones,
  onboarding, review, rewards, settings, stats), `lib/shared/`
  (widgets, providers, models).
- Notable services: `task_completion_service` (the single completion path
  every surface routes through), `timer_service`, `streak_service`,
  `notification_scheduler`, `achievement_service`, `shield_service`,
  `backup_service`, `app_event_bus`.
- Key dependencies: `flutter_riverpod`, `go_router`, `drift`, `fl_chart`,
  `flutter_local_notifications`, `google_sign_in`, `googleapis`, `lottie`,
  `confetti`, `speech_to_text`, `flutter_markdown_plus`, `share_plus`,
  `wakelock_plus`, `home_widget`, `audioplayers`.

## 8. Platform status

- **Android:** working, release APKs built regularly. A home-screen timeline
  widget exists.
- **iOS:** all code and config that could be prepared from Windows is done —
  Darwin notification init, mic and speech permission strings, Google
  Sign-In client id and URL scheme, deployment target 13.0, launcher icons.
  **It has never been compiled**, because that requires a Mac. Runbook is
  `docs/IOS_BUILD.md`. Known deltas: exact alarms are Android-only,
  notification action buttons need Darwin categories.

## 9. Environment

Windows (not WSL). Flutter at `C:\Program Files\Flutter`. The test device is
an iQOO Z10x connected over **wifi debugging only, never USB** — Funtouch OS
suppresses the logcat line `flutter run` needs, so `.\dev.ps1` bypasses
discovery with a fixed VM-service port and `flutter attach`.

```
flutter run                  # or .\dev.ps1 for the wifi hot-reload loop
dart run build_runner build --delete-conflicting-outputs
flutter analyze --no-fatal-infos
flutter test
flutter build apk --release
python tools/build_icon_from_art.py && dart run flutter_launcher_icons
```

## 10. Locked decisions — do not re-propose these

1. **Never add another destructive migration.** Real data exists.
2. **The timer never auto-pauses on backgrounding.**
3. **No delete operation for the AI assistant**, ever.
4. **Future days and past days stay read-only.** No back-dating.
5. **`MilestoneKind` was deliberately dropped** — `targetDate` plus
   `recurrence` carry those distinctions now.
6. **Multi-day weekly tasks use per-day periods** — Monday being done does
   not satisfy Wednesday.
7. **No copyrighted characters.**
8. **Cast roles do not overlap** (section 3).
9. **Don't habitually run `flutter analyze`** — it takes minutes. Save it for
   commits and large refactors.
10. **For pre-launch model breaks, prefer a clean rebuild over a port.**
11. **Verify visuals with real screenshots before claiming success.** For
    character or icon work, run an adversarial critic pass first — the
    owner has been burned by having to QA distortions himself.
12. **Intuitive, easy-to-learn UX is a primary design constraint**, ranked
    above feature count.

## 11. Open items

- The owner's **final feedback pass** after living with the app for a real
  week. Repeatedly promised, not yet delivered. It outranks new features.
- **iOS compile** on a Mac.
- The icon is **mush at 48px** (a book, three checkbox rows, a tick and a
  bird). Accepted by the owner; the fallback is a single-subject crop of the
  bird's head.
- Parked, not approved: streaming AI replies, AI cost visibility, a Gemini
  free-tier option, Kai's in-app port, Google Calendar write-back,
  erase-all-data, `flutter_secure_storage` for the API key before any public
  release.
