# Gamification Plan — Duolingo-Inspired, Integrity-Checked

*2026-07-19. Output of a 5-agent brainstorm: codebase gamification audit,
Duolingo mechanic dissection, Flutter animation audit, leagues design, and an
integrity critique that ranked everything and killed the dark patterns.
Kaizn is a productivity app — the "content" is the user's real life — so the
bar is: does this make the user's life better, not just the app stickier.*

---

## 1. The league question, answered

**Real leagues are a Phase-3 (backend) feature; don't fake them now.**
Simulated competitors are permanently killed — the moment a user notices bots
(they always do), every number in the app becomes suspect.

What ships instead, honestly:

| Now | Later (backend) |
|---|---|
| **Weekly recap card** on Stats (points, active days, completion ratio, tier-free trend line) | Real friends-first leagues (5–15 known people, invite links) |
| **Ghost race vs last week** — cumulative line vs the same line last week, shown **only when at-or-ahead** (behind = neutral copy, no ambient guilt) | Rank on the **normalized metric** (activeDays × completionRatio, quests) — NEVER raw points: point values are user-defined, so raw-point ranking is meaningless + gameable. Killed forever. |
| **`league_weeks` Drift table + pure close-out function**, written through change_log — pure option value so real leagues slot in with zero rework | Same Stats card: your row becomes row 1 of 15 |

Personal tiers (Bronze→Diamond vs your own trailing average) were designed in
full but ranked **low**: self-demotion is a weak motivator with a real anxiety
tail (a sick week reads as losing a possession). If ever built: 0.7–1.1 hold
band, demote only after 2 consecutive weak weeks, baseline growth capped at
1.15×/week (anti-treadmill), zero-activity week = frozen not scored, one quiet
sentence, never red. Decision deferred until real cohorts exist.

## 2. The kill list (dark patterns caught by the critique)

- **Melting/dying widget flame** → state-reflective only: bright flame when done today, neutral outline when not. No decay animation, no countdown copy.
- **Escalating streak-terror notifications + parasocial guilt goodbyes** → max ONE factual line per day; auto-quiet after N ignored reminders with a plain goodbye.
- **Randomized chest points** → FIXED +50; anticipation lives in the animation, not the amount. Total system bonuses capped ≤ ~20% of trailing weekly base — **protects the user's self-priced reward economy from inflation**.
- **Quest failure states / streak-touching quests** → quests have NO missed state, no history of failures, and never reference the streak (one loss-aversion stake is enough).
- **Badge gallery with visibly missing months** → show only earned months. No guilt monuments.
- **Hearts/penalties, gems second currency, Rive mascot, celebration-piggybacked permission asks** → killed (rationales in critique).

## 3. What the audit found

**Well-juiced already:** completion tap (haptic + floater + composed
snackbar), the big-three confetti moments (reward claim, milestone complete,
all-done), streak popup with shield offer.

**Dopamine-dead zones (all TIME-based wins):**
- Streak advancing mid-day → completely silent
- Streak milestones (7/30/…) → celebrate a day late (next morning's app open)
- Personal-best streak → never celebrated
- Shield saving your streak → no relief moment
- Retro chip completion → no floater
- Badge unlock → plain 3s snackbar (feels nothing like a badge)

**Buried treasure:** two complete-but-unwired services from the early build:
- `level_service.dart` — drop-in revivable, but caps at 6,000 pts (a 6-month user would hit it — replace table with a curve)
- `challenge_service.dart` — daily-quest engine ~40% revivable (rotation + persistence good; conditions speak the deleted project/metric model)

## 4. The v1 package — three sessions

**Theme: make the loop the user already runs feel complete before adding any
new loop.**

### Session 1 — "Pay the debts" (core-loop juice + dead zones)
1. **Check-button morph + micro-burst** — tapDown scale, elasticOut overshoot, 6-8 dot radial burst (`task_tile.dart:647` _CheckButton; scaled-down for day chips). The highest-frequency moment in the app is currently the flattest.
2. **Floater physics** — easeOutCubic rise + scale pop, origin over the check button, gold tint on clutch; add to retro chips.
3. **Progress-bar spring fill** with overshoot + allDone shimmer (shared `_SpringProgressBar` for Home + Rewards).
4. **Attention-slot choreography** — AnimatedSize/Switcher wrapper; kills the most visible jank on Home (banner teleport). **ValueKeys on task tiles** so animations survive the Up-next→Done reorder + green send-off pulse.
5. **Streak dead zones**: `🔥 Day N` trailing segment in the done-snackbar on the day's first real completion; same-day streak-milestone + personal-best celebrations (moved into `recordDayLogged`); shield-save relief confetti; badge snackbar gets haptic + tap-through to the gallery.
6. **Celebration entrance + confetti variety** — scale-in entrance; per-moment palettes (gold stars = rewards, ember rain = streaks, burst = all-done). A 6-month user has seen identical confetti ~200 times; habituation has eaten the celebration tier.

### Session 2 — "The unloseable number" (levels + cosmetics)
1. **Levels on lifetime earned points** (never the spendable balance — claims can't de-level you). Curve `T(n) = 50·n²`: L2 in week one, L10 ≈ 6 months, L20 ≈ 2 years. Titles every 5 levels. Level-up fires the (now-varied) celebration dialog. Level chip on Stats.
   *Why levels matter at month six: streaks are fragile, points are spendable, badges are finite — levels are the only monotonic, unloseable progression.*
2. **Cosmetic unlock registry** — confetti styles, check-button animations, extra milestone palette colors, alternate app icons. Unlocks every ~3 levels + weekly chests. Settings → Style picker. **Hard rule: never gate behavior features behind levels.** Cosmetics are the inflation-proof payout that makes chests/seasons safe.

### Session 3 — "The weekly rhythm" (quests → chest → flywheel)
1. **Daily quest, de-fanged** — port `challenge_service` to the task model with a **feasibility filter**: the quest must be satisfiable by tasks the user already planned (never "do an extra thing"). One quest/day as a quiet row under Today's progress (NOT the banner slot). Progress via AppEventBus; bonus via `PointsReason.questBonus`. Pool: complete N tasks / one before noon / 30 timer minutes / clear one milestone today / complete your struggling habit (Goldilocks tie-in) / "Just show up" +10 on recovery days.
2. **Weekly chain + chest** — 5-of-7 dots (2 free misses = guilt-quiet), chest opens in-card with the Session-1 burst kit: fixed +50 + one cosmetic drop.
3. **`league_weeks` table + pure close-out** written quietly during the same week-boundary work; surfaced as a tier-free Monday recap line.

**The flywheel:** doing your own tasks feels great (S1) → completes the day's
quest (S3) → fills the weekly chest (S3) → pays a cosmetic (S2) that makes
tomorrow's completions look better → every point climbs a level (S2) that can
never be lost. No new anxiety surface, no economy inflation, no obligation
that isn't satisfied by the user's existing plan.

## 5. Follow-ons after v1 (in order)
1. Shield inventory (cap 2) + auto-consume before grace + save-reveal moment — the healthiest points sink.
2. Monthly season recap card + fresh-start prompt (merged with monthly cosmetic drop; earned-months-only gallery).
3. De-fanged widget flame (two-state, no decay).
4. Chest-style hold-to-claim reward flow (also deletes a confirm dialog — constitution win).
5. Streak flame that grows/breathes with tier glow (pulse pauses at streak 0).
6. Haptic grammar service (success double-tap / clutch ascending ticks / claim heavy+echo) — one file, future sound host.
7. Shareable recap image card (win-surfaces only) — growth, not retention.
8. Notification auto-quiet + guilt-stripped copy pools.

## 6. Animation debt found (fix opportunistically)
- Timeline resize rebuilds the whole 24h grid per drag frame (`timeline_view.dart` `_onResizeUpdate`) → ValueNotifier scoped to the dragged card.
- ActiveTimerBanner ticks every second even with no timer.
- Milestone card → detail is a hard cut → `CustomTransitionPage` + Hero on the color strip (keeps deep links).
- Packages: `flutter_animate` (pure Dart, negligible) yes; Rive/Lottie no (1MB+ for nothing we need); sound only after the haptic service exists, opt-in.

## 7. Design laws this plan obeys (from the constitution + critique)
1. One attention slot; quests are a list row, league/levels live on Stats.
2. Celebrate loud, guilt quiet — no failure states on system-authored goals.
3. Fixed bonus values; system bonuses ≤ ~20% of trailing weekly base.
4. Cosmetics over currency for recurring payouts.
5. Never gate behavior features behind progression.
6. No fake competitors, ever. No raw-point social ranking, ever.
7. The streak is the only loss-aversion stake; nothing else may threaten loss.
