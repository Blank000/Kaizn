# Kaizn Product Roadmap — Research-Backed Feature Candidates

*2026-07-23. Synthesized from an 89-technique research sweep across habit science
(Fogg, Duhigg, Eyal, Lally/Wood), time-management systems (GTD, Deep Work,
Pomodoro, Ivy Lee, 12-Week Year), motivation psychology & behavioral economics
(Gollwitzer, Oettingen, Milkman, SDT, flow), ADHD/neurodivergent practice, 14
competitor apps, and the integrations landscape. Full inventory with sources:
`docs/research_digest_productivity.md`.*

---

## The doctrine: one-stop WITHOUT hard-to-use

Every technique below survives only if it fits these rules. This is how we
serve many productivity styles with one simple app:

1. **Optional layers, never mandatory concepts.** A user who ignores a feature
   must never see it. Tags appear only after the first tag exists; Pomodoro
   hides inside the timer users already have; the day-plan picker defaults to
   "None".
2. **Styles, not features.** When three techniques solve the same problem
   (Frog / Ivy Six / 1-3-5 all shape "what do I do today"), ship ONE concept
   with selectable skins — the app gains one idea, not three screens.
3. **Compose, don't add.** Prefer features that are runtime views or framing
   over existing data (routine runner over stacks; focus garden over timer
   logs; strength score over completions) — zero new mental models.
4. **The kill list is law.** No guilt, no fake pressure, no dying pets, no
   money stakes, no silent auto-rescheduling, no competitor leaderboards.
   Several high-engagement mechanics were rejected on this rule alone (§Rejected).
5. **One new *concept* per release wave.** Surfaces can grow; vocabulary grows
   slowly.

## What we already cover (stronger than expected)

Make it obvious → timeline, reminders + last-call, stacking chains with derived
slots, cadence hints. Make it easy → 2-minute fallbacks, Goldilocks coach,
queues. Make it satisfying → points/rewards, streaks + skip-vs-missed honesty,
never-miss-twice, celebrations, identity votes. Autonomy + competence (SDT) are
strong. **The systematic gaps:** relatedness (fully single-player), lapse
recovery beyond 1 day, quantity/quota habits, quit-habits, capture friction,
reflection, and everything outside the app (widgets, calendar, health).

---

## NOW — next 2–4 weeks (high impact, low risk, builds on what exists)

1. **Google Calendar read-only overlay.** Gray untouchable "busy" blocks from
   the user's calendar behind our timeline (we already hold Google OAuth — add
   `calendar.readonly`). Habits get planned into *real* gaps. This is Phase 1
   of cross-sync; write-back is LATER.
2. **Habit strength score** (Loop-style exponential smoothing, skips excluded).
   A forgiving 0–100 ring beside the fragile streak: one bad day after 60 good
   ones no longer erases visible progress. Pairs with identity votes
   ("92% strong · 148 votes"). Read-only, computed from existing completions.
3. **Frictionless capture.** True zero-decision add: one text field → Inbox
   milestone, no other questions. Home lightning-add first; home-screen widget
   in NEXT. (GTD capture + ADHD brain-dump; our form is currently 6 decisions.)
4. **Miss check-in (self-compassion + B=MAP triage).** Marking a miss offers
   one optional chip row: "Didn't see it / Too hard / Didn't feel like it" +
   one kind line. Each answer routes to an existing tool (reminder editor /
   2-min fallback / identity card) and feeds the Goldilocks coach. Best
   evidence-per-pixel in the whole sweep (Wohl 2010; Gollwitzer d≈0.65 for the
   if-then follow-up).
5. **Comeback flow.** 7+ days away → warm "welcome back" screen instead of a
   graveyard of red: bulk archive-or-keep, pick 1–3 restart habits, gap marked
   as a "break" not a wall of misses. The largest silent churn cohort of every
   habit app, and we currently punish them on arrival.
6. **Rest mode.** One toggle (+ optional end date): auto-skip everything,
   suppress quests/alerts, pause strength decay. Composes existing skip
   semantics; Todoist-vacation-mode equivalent without the monetization.
7. **Run stack (routine runner).** A ▶ Play button on any queue: full-screen
   one-step-at-a-time player with per-step countdown, auto-advance, chain-end
   celebration. Pure composition of stacks + timer + durations — and the
   feature that makes our stacking model *feel* magical (Routinery's whole app
   is this).
8. **Projected finish + estimate calibration.** Up Next header: "~2h 40m ·
   done by 7:15 PM". After timed sessions: "planned 30m, took 48m" and
   "usually ~45m" in the duration picker. Time-blindness aid; pure arithmetic
   over data we already store.

## NEXT — the following waves

- **Day-plan styles picker** (None / Frog / Ivy Six / 1-3-5): one concept,
  three skins, sets Up Next ordering + a hero card. Morning prompt optional.
- **Close the day** (shutdown ritual): sweep leftovers (move/skip/missed),
  preview tomorrow, "Day closed" stamp — the natural host for Ivy Lee picks
  and a one-line reflection journal entry. Sunsama's calm, as dismissible cards.
- **Weekly review, chest-gated the nice way:** completing the (fully optional)
  Sunday review — triage Inbox, stale-task sweep, shelve/revive — is what
  *opens* the already-built weekly chest.
- **Timer suite:** countdown mode with a Time-Timer shrinking disk (default
  when a duration exists), Pomodoro cycling, full-screen Focus mode with DND +
  post-session "too easy / just right / too hard" feeding the Goldilocks coach,
  hyperfocus exit ramp at ~125% of planned duration.
- **Measurable habits + weekly quotas:** numeric targets ("2L water", partial
  progress ring) and "3×/week any days" with an on-pace hint ("1 of 3 · 2 days
  left"). Category-standard in every serious competitor; our biggest model gap.
- **Avoid habits (quit-something):** success-by-default day, "I slipped"
  honesty, zero shame copy. Huge unserved audience; reuses missed semantics.
- **Home-screen widgets** (tap-to-complete Up Next / today checklist) and a
  lock-screen Live Activity for the running timer.
- **Health auto-complete** (steps/workouts first): the wearable becomes the
  logger; completions flow through TaskCompletionService so everything fires
  normally, labeled "via Health".
- **Fresh-start landmarks + life anchors:** date picker highlights Mondays/1sts/
  birthday; chains can be headed by an untracked real-world anchor ("after
  morning coffee") rendered as a Fogg recipe sentence.
- **ADHD pack:** "Just pick one" paralysis-breaker button, task variants
  ("Today: yoga") for novelty, first-step field ("open the file"), dopamine
  menu, low-battery day toggle (light-tasks filter).
- **Starter templates:** ~8 identity-framed milestone templates whose week-1
  tasks are the 2-minute versions (Fabulous journeys minus the coercion).
- **Sharable weekly recap card** (image export, no backend) — the first,
  cheapest leg of relatedness.

## LATER — needs backend, native depth, or more evidence

- **Google Calendar write-back** (two-way): app-owned "Kaizn" calendar,
  task-ID dedup in extendedProperties, webhook + hourly polling, latest-edit-
  wins. Strictly opt-in, degrades to overlay on any failure.
- **Social v2:** witness link (read-only milestone progress for one chosen
  person) → co-op shared-progress challenges (contributions only ever add;
  misses invisible — Habitica minus the friendly fire). First backend feature.
- **MCP server:** Phase 1 read-only over the Drive backup snapshot
  (get_week_summary, get_habit_history); write tools once a sync backend exists.
- **Deeper science widgets:** automaticity meter (Lally curve), context
  stability score, keystone habit detection, chronotype bands, burnout deload
  offers — all read-only insights; ship after Stats gets real usage.
- **More:** spaced-repetition review tasks + exam back-planning template,
  Notion/Obsidian markdown journal export, CSV + webhook, NFC tag logging,
  geofenced reminders, voice intents (Siri/Assistant), focus garden, money
  jar on rewards, screen-time habits (Android-first), weekly digest email,
  temptation-bundle pills on the timer, motivation-wave cards, commitment
  cards (high guilt-drift risk — prototype carefully or drop).

## Rejected / hard-guarded (dark-pattern kill list)

- **Pets that suffer** (Forest's dying tree, "your pet misses you" pushes) —
  a companion, if ever, never sickens, never dies, grants no advantage.
- **Money stakes / escalating pledges** (Beeminder/stickK) — the precommitment
  *ritual* may survive as a self-authored card; enforcement never.
- **Boss damage from teammates' misses** (Habitica) — co-op adds only.
- **Silent auto-rescheduling** (Motion) — every move is user-confirmed.
- **Raw-points leaderboards, fake competitors, variable rewards with economy
  value** — variability stays cosmetic garnish, disclosed in settings.

## Sequencing rationale

NOW items share three properties: they need no backend, they reuse surfaces
users already understand, and each one plugs a churn hole (broken-streak
despair, lapse shame, capture friction, plan-vs-reality mismatch) rather than
adding delight for already-retained users. The calendar overlay leads because
it's the owner's explicit ask and the timeline is already calendar-shaped.
UX specifics deliberately deferred — roadmap first, then per-feature UX.
