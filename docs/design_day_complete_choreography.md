# Day Complete — Post-Completion Choreography (Storyboard)

*2026-08-19. Duolingo-style sequenced celebration replacing the single
"ALL DONE TODAY!" dialog. Fires at most once per day, at the moment the
last scheduled task completes. The per-task loop stays snackbar-fast —
choreography belongs to the day's curtain call, not every check.*

## Interaction rules (before any beats)

- **Tap anywhere = skip to next beat.** Impatient users burn through the
  whole thing in ~1s. Nothing is ever gated behind watching.
- **One per day** (existing `lastAllDoneCelebrationDate` guard), never in
  rest mode, never for retro/past-date completions, suppressed while a
  higher dialog (level-up/PB) is already showing — those beats ABSORB into
  this sequence instead when they coincide.
- **Reduced motion** (`MediaQuery.disableAnimations`): render the final
  static summary card only.
- Confetti uses the user's equipped cosmetic style (classic/goldStars/ember).
- Haptics: one `mediumImpact` per beat landing; `heavyImpact` only on the
  streak beat.

## The beats (~6.5s untouched, ~1s tap-through)

| # | Beat | What animates | Time |
|---|------|---------------|------|
| 0 | **Curtain** | Dim scrim; "DAY COMPLETE" slams in with a Victory-Burst starburst behind it (brand motif); confetti burst in equipped style | 1.0s |
| 1 | **Points roll** | "+87 pts today" — counter rolls 0→87 (AnimatedNumber), tick haptic every ~20%; if any clutch bonus today, the counter flashes gold at the end with "⚡ clutch ×2" | 1.4s |
| 2 | **Task recap** | A row of small green check-chips pops in, one per completed task, staggered 70ms scale-ins (cap 8, then "+3 more"); ⚡ chips for tiny wins | 1.0s |
| 3 | **Streak flame** | Flame scales up from ember with "Day 12" rolling; IF milestone (7/30/…) or personal best: beat extends +1s, ember-rain confetti, "NEW RECORD" ribbon — replaces the separate dialog that currently fires | 1.4s (2.4s big) |
| 4 | **Quest & chest** | If today's quest completed: quest chip fills (spring bar) + its weekly chain dot pops in; if the chest just became claimable: chest wiggles with "OPEN" — tapping runs the existing chest flow inline | 1.2s |
| 5 | **Outro** | Identity line if one is pending ("Another vote for *a writer* 🗳"), thin level bar fills by today's sliver, CONTINUE button breathes | hold |

Beats with nothing to show are dropped automatically (no quest state → no
beat 4; streak 0 → flame beat becomes a small "Day 1 starts now" spark).

## What it replaces / absorbs

- Replaces: `showCelebrationDialog` call in `_maybeAllDoneCelebration`.
- Absorbs when coincident: streak-milestone dialog, personal-best dialog
  (from `surfaceDialogMoments`) — the LAST completion of the day routes its
  moment payload into beat 3 instead of stacking two takeovers.
- Untouched: per-task snackbar/floater/burst, reward-unlock and badge
  snackbars (they queue after the sequence closes), chest-claim flow
  (invoked, not duplicated), stack-runner chain-end celebration (gets a
  2-beat mini version later).

## Implementation shape

- `lib/shared/widgets/day_complete_sequence.dart` — full-screen
  `showGeneralDialog`; a beat index driven by per-beat `Timer`s; global
  `GestureDetector` advances the index; each beat is an `AnimatedSwitcher`
  child with its own intro curves (easeOutBack scale + fade).
- Payload struct built in `home_screen._maybeAllDoneCelebration`:
  `{doneCount, tinyCount, pointsToday, clutchToday, streakDay,
  streakMilestoneHit, isNewBest, questDoneToday, questWeekDots,
  chestReady, identityLine, levelProgress}` — all computed from providers
  already watched on Home.
- Completionist badge check stays after the sequence, as today.
