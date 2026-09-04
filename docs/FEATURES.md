# Yatta! — Feature Inventory (as of `timetable` @ 2026-09-04)

The canonical list of everything the app does. Written as the checklist for
the iOS bring-up: almost all of this is shared Dart and ports for free —
the **iOS-specific work** section at the bottom is what actually needs
hands.

## Core model
- **Milestones** — goals/projects/habit groups. Name, description, identity
  line, target date, completion-bonus points, 8-color palette. Marking one
  complete awards the bonus; delete cascades tasks. Auto-seeded "Inbox"
  milestone catches quick-adds.
- **Tasks** — belong to a milestone (or adhoc). Recurrence: once / daily /
  weekly (multi-weekday) / monthly (day-of-month or Nth-weekday), intervals
  (every N), optional end date ("until"), first-occurrence anchor. Optional:
  start time + duration (timeline placement), per-task reminder (recurring
  or one-shot date), 2-minute tiny version (half points, full streak
  credit), points per completion, habit stacking ("after X, do Y").
- **Schema**: Drift/SQLite v12. Tables: milestones, tasks, task_completions
  (with duration, tiny, skip, nd, miss_reason), points_history, rewards,
  streak, change_log, league_weeks, ai_chat_messages (+plan_applied).

## Logging & honesty rules
- Tap tile → done now (+points, haptic, float-up). Tap again → undo (today).
- Long-press → **Skip today** (intentional rest; streak-safe, no points) or
  **Mark as missed** (opens the miss check-in: 4 "what got in the way?"
  reasons stored on the row; reasons power the Sunday review; "too hard" +
  tiny version offers the 2-minute rescue).
- Multi-day weekly tasks render M-T-W-T-F-S-S chips; **current-week past
  chips retro-log** (tap complete / long-press skip-miss for that date);
  future chips disabled. Retro-logs never resurrect streaks.
- **Future days are read-only everywhere** (list preview, timeline).
  **Past days are read-only reviews** (the weekly-chip window is the sole
  exception). No back-dating, no history edits — by design.
- Dateless one-shots live in Home's **Anytime** section — visible, but not
  counted as "today".

## Streaks, points, gamification
- Daily streak: any real completion counts the day; 1 missed day forgiven,
  two breaks it; **Streak Shield** (points cost) restores a just-broken
  streak; per-day advance guard; skip preserves.
- **The fire** = streak identity: Lottie flame (user-picked reference)
  everywhere a streak burns — header, streak popup, milestone-days dialog,
  Day Complete, First-Win **Ignition** (first completion of the day: flame
  grows, week letters tick, day counter increments).
- **Day Complete** sequence (last scheduled task): choreographed beats,
  fire hero, YATTA! type, level progress.
- Points → **Rewards**: user-defined, threshold-priced, claim flow with
  confetti; unlock snackbars; Home "Ready to claim" strip.
- Daily quest row, 9 achievement badges + gallery, levels, weekly league
  close-outs (foundation), share-progress card, sounds (off by default),
  celebration dialogs, AnimatedNumber counters, StaggerIn entrances.

## Home (Today)
- Greeting by name + time of day; stats header (points/streak); week board
  (7 dots); today's progress card; **one claw** line (weekly intention).
- **Sensei Post** — Ren's daily accountability card: state-aware line from
  real data (remaining task names, counts, hour, yesterday's falls); tap →
  the Day's Ledger sheet.
- Up next / Done / Missed / Skipped sections + Anytime; single
  attention-banner slot (timer > never-miss-twice > coach); breathe invite
  on the next task; rest-mode banner; projected-finish line.
- **Timeline view** toggle: drag tasks to time slots, chain-derived slots
  for stacked tasks, read-only Google Calendar busy blocks (eye toggle),
  editable own gcal events.
- Date stepper: past-day review, future-day plan preview (both read-only).

## Focus tools
- Per-task **stopwatch** (pause/resume, never auto-pauses; persistent
  banner; conflict dialog; duration lands on the completion row).
- **Stack Runner**: guided queue execution — countdown per step, DONE /
  SKIP / +5 min / 2-min rescue, wakelock, auto-advance; **Ren meditates
  beside the timer, opens one eye on pause**, leaves before the fanfare.

## Stats & the Sunday review
- Lifetime + weekly cards; 30-day points chart; month heatmap (year
  toggle); top tasks; by-milestone; time-of-day chart with peak-hour
  insight (in Ren's voice).
- **Weekly review** (`/review`, Stats card + Sunday Home invite): three
  scrolls — what burned, what slipped (miss reasons + counsel), ONE claw
  stamped for next week (shows on Home all week).

## The cast (all original characters)
- **Ren, the fox sensei** (`ren_figure.dart`, CustomPaint, golden-tested):
  standing + meditating poses, idle bob/tail/ears. Owns reflection —
  Sensei Post, rest banner, comeback screen, empty state, miss check-in,
  review host, stalled-milestone nudge, evening-notification voice, shield
  counsel copy. Settings toggle; never appears in celebrations.
- **Pico, the gadget robot** (`pico_figure.dart`, golden-tested): hover,
  antenna pulse, blinks, heartbeat, wave. Owns the machine — the AI
  assistant's face. Not toggleable (functional surface).
- **Kai** (hype) + the fire: designed, poses approved (cast-call
  artifact); Kai not yet ported in-app.
- Comeback screen (7+ day gap): no-guilt re-entry, shelve/keep tasks.
- Rest mode: multi-day pause, streak-safe, quests stand down.

## Pico — the AI assistant
- **Floating Pico** over every tab: free 2-D drag, session-remembered
  position, tap → chat, needs-key dot, keyboard-safe.
- **Chat** (`/ask-ren`): live context pack (streak, week, claw, all
  milestones/tasks/rewards with ids + schedules) + full **app manual** +
  hard boundaries in the system prompt; Pico persona; markdown rendering;
  1→4-line growing input; **speech-to-text mic** (on-device, never
  auto-sends); suggestion chips; thread **history** (persisted locally,
  resume-last, browse/delete threads, 30-message replay cap).
- **Plan pipeline** (chat button + Settings paste-import): JSON contract —
  create milestones/tasks/rewards, **update** any of them by exact id
  (rename, re-point, re-schedule, reminders incl. clearing) — **no delete
  op exists**; id normalization + unique-name fallback; preview sheet with
  resolved names and red will-be-skipped warnings; APPLY once (button
  retires, persisted); values clamped; parser test-covered.
- **BYOK**: per-user OpenAI key (self-explaining setup gate; Settings
  manage/clear; on-device only; model configurable, default gpt-4o-mini).
- **Export for AI / Import plan** (Settings): the same powers via
  copy-paste with any chat AI (works with a plain ChatGPT subscription).

## Notifications
- Morning summary, evening nudge (Ren-voiced "The scroll waits"), per-task
  reminders with Done/Skip/Snooze actions, last-call replaces evening in
  its band, exact alarms (Android), weekly + feedback kinds.

## Auth, backup, settings
- Google Sign-In (silent restore at startup; login screen gate).
- Drive AppData JSON backup/restore (manual; wipe+reinsert in FK order).
- Settings: theme (system/light/dark), notification times, sounds toggle,
  Ren toggle, Pico key/model, AI export/import, achievements, about.
- Onboarding 4-page carousel; erase-all-data designed, not built.

## iOS-specific work for the port (the real checklist)
The `ios-release` branch is 80+ commits stale — **do not rebuild features
there; merge `timetable` in** and then do only:
1. `Info.plist`: `NSMicrophoneUsageDescription` +
   `NSSpeechRecognitionUsageDescription` (Pico mic), notification
   permission prompt copy.
2. Notifications: iOS init settings exist on `ios-release` (a166f3c) —
   port that one commit's idea forward; no exact-alarm concept on iOS
   (scheduler already guards by platform? verify), action buttons need
   iOS category registration.
3. Google Sign-In iOS: URL scheme + reversed client id in Info.plist,
   iOS OAuth client in the same Cloud project (Drive + Calendar scopes).
4. Launcher icons: `flutter_launcher_icons` already configured — rerun.
5. Verify plugins on iOS: speech_to_text (locale prompt), wakelock_plus,
   share_plus, audioplayers (ambient category is already set in
   SoundService), local notifications timezone init.
6. Status-bar/safe-area pass on notched iPhones (floating Pico clamps,
   timeline, sheets).
7. Build: needs a Mac or CI (Codemagic/GitHub Actions macOS runner) —
   Windows cannot produce the .ipa.
