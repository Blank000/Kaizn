# First-Win Ignition — approved motion spec

*2026-08-26. The winner of the three-option motion pitch (Option B,
"Ignition"), approved by Alok. Interactive demo preserved at
`docs/motion/first_win_motion_pitch.html` (open in any browser) and at the
pitch artifact: https://claude.ai/code/artifact/85168861-cc3d-4ac8-bfd5-e39c89dfd5bb*

## What it is

The celebration for the **first real completion of the day** — the moment
the streak advances. The fire is the hero: the exact flame **extracted from
Alok's reference Lottie** (one seamless 60-frame loop, on transparency —
`assets/lottie/streak_flame.json`); everything around it is original
choreography.

## Beats (~2.6s, auto-dismiss ~3.05s, tap anywhere dismisses)

| t | Beat |
|---|------|
| 0.00s | Scrim fades in; small fire (scale .5); "Day N−1"; the REAL week strip (past real-completion days ticked, today outlined, unticked) |
| 0.38s | Growth: fire scales .5 → 1.18 → 1.02 (elastic overshoot, 820ms) — the streak physically grows; rising gold embers |
| 1.25s | A glowing spark arcs (sine, 46px lift, 520ms) from the fire down to today's letter |
| 1.78s | **Impact**: today's letter ticks (elastic pop + check), 8-dot radial burst (green/gold), counter flips to "Day N 🔥" with elastic pop + golden "+1" floater, fire gives one proud pump, medium haptic, tick sound (if sounds on) |
| 3.05s | Auto-dismiss |

## Rules (enforced in `moment_celebrations.surfaceDialogMoments`)

- Trigger: `CompletionResult.streakDay != null` (set only when
  `StreakService.recordDayLogged` advanced the streak — inherently once/day).
- **Yields** to bigger dialogs: skipped when a streak milestone, personal
  best, or level-up fires for the same completion (those own the moment).
- Never in rest mode; never under reduced motion (the completion snackbar
  still carries "🔥 Day N").
- The counter never lies: N−1 → N, one honest increment.
- Falls back to the code-drawn LivingFlame if the Lottie asset is missing.

## Files

- `lib/shared/widgets/first_win_ignition.dart` — the overlay
- `assets/lottie/streak_flame.json` — the extracted fire (also used by
  Home's streak header and the Day Complete streak beat via StreakFlame)
- `tools`/scratch: extraction recipe — the reference scene's fire was five
  60-frame plays of one precomp; layer ind7 (frames 0–60) was lifted with
  all assets, recentered (`ks.p → [160,386]`), rescaled (`ks.s → 30%`) onto
  a 320×400 canvas.
