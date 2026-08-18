# Yatta! Mascot — Character Design Brief

**Working name: "Zen" — the Victory Spark.**
*2026-08-19. This brief is self-contained: an illustrator/animator should be
able to work from this document alone. Product context in one line: Yatta!
(Japanese "I did it!") is a gamified habit tracker whose brand IS the
completion moment — every checked task fires a radial burst of green and gold
dots. The mascot is born from that burst.*

---

## 1. Concept & backstory

When a task is completed in Yatta!, the check button explodes into an
eight-dot burst of green and gold. **Zen is what lives inside that burst** — a
small spark-spirit thrown off by a finished task, who stuck around because it
liked the feeling. It is made of victory energy: it exists *because* the user
does things, and its whole purpose is to witness wins and hype them. It has no
life of its own to lose — which is why it can never be harmed, disappointed,
or neglected. It simply burns brighter the more you show up, and it saves its
biggest transformation for the day you come back.

## 2. Personality

- **Voice:** a hype-friend, not a coach. Two-to-five-word exclamations
  ("YATTA!", "CLUTCH!", "You're back!!", "Day 12?!"), never full lectures.
  Punctuation does the acting.
- **Energy:** shōnen-protagonist optimism — bouncy, slightly ridiculous,
  celebrates small things at maximum sincerity. Thinks one push-up is worthy
  of fireworks.
- **It would NEVER:** guilt, sulk, cry, get sick, "miss you," look at a
  calendar disapprovingly, comment on gaps, or ask for anything. Zen has no
  needs. It reacts only to what the user DID, never to what they didn't do.
- Comic register: Saturday-morning anime, not corporate mascot. Big eyes,
  bigger reactions, zero smugness.

## 3. Visual direction

**Anime-inspired, strictly original.** No resemblance to any existing IP —
no Pikachu silhouette, no Duolingo owl shape, no Calcifer flame-face
(Ghibli), no Soot Sprite. Silhouette must be distinct enough to trademark.

- **Shape language:** a teardrop/flame body — round bottom, one flicked tip
  at the top that acts as its "hair spike" and main expression device (points
  up when excited, curls when charging up). Two large oval eyes, no visible
  mouth by default (the mouth appears only in big-reaction poses — anime
  style: tiny dot → giant open shout). Stubby arm-nubs that appear when
  needed (fist pump, thumbs-up) and vanish otherwise. No legs — it hovers,
  with a faint bounce.
- **Proportions:** ~1:1.2 width:height, 70% of the mass is head/body blob.
  Must read at **24 px** (tab-bar size): at that size it should reduce to
  body shape + eyes + tip. Design the silhouette FIRST at 24 px, then add
  detail upward.
- **Palette — locked to app brand colors (do not restyle):**
  - Body core: Vivid Green `#58CC02` (shadow tone: Deep Green `#45A800`)
  - Inner glow / cheeks / energy: Golden Yellow `#FFD700`
  - Power-up stages introduce Flame Orange `#FF9600`
  - Eyes: near-black on a white catch-light; NO pure black fills elsewhere
  - Accent (rare, e.g. water-break pose): Sky Blue `#1CB0F6`
- **Surfaces:** must sit on both light (`#FFFFFF`-ish cards) and dark
  (`#0F1B24`-ish) backgrounds — deliver with a subtle 1.5–2 px darker
  self-outline (not pure black) so it never dissolves into either.
- **Rendering:** flat vector with 2-tone cel shading max. No gradients
  except the aura stages. Line weight consistent with a rounded, friendly
  system (the app uses Nunito-style rounded typography).

## 4. The Zenkai power-up ladder

*(Named for the Dragon Ball concept — Saiyans return from defeat stronger.
Zen's rule: absence changes NOTHING; RETURNING triggers a power-up.)*

| Stage | Name | Trigger | Visual |
|---|---|---|---|
| 0 | **Ember** | New user / streak 0 | Small, soft-green, tip barely flickering, gold cheek dots |
| 1 | **Spark** | Streak 1–6 | Brighter green, tip flicks upward, faint gold inner glow |
| 2 | **Flame** | Streak 7–29 | Gold glow fills the body, tip becomes a two-tongue flame licking orange `#FF9600` |
| 3 | **Blaze** | Streak 30–99 | Orange-tipped crown of 3 flames, thin gold aura ring |
| 4 | **Aura** | Streak 100+ / Lv 20+ | Full radiant aura (green→gold gradient permitted here only), eyes get anime "determined" highlights |
| ⚡ | **Zenkai Moment** | The comeback screen (first open after 7+ days away) | One-off transformation animation: Zen does a tiny power-up shout — burst rays, screen-shake-worthy — then settles at the user's earned stage. Copy: "You're BACK?! ZENKAI BOOST!" The gap itself is never referenced. |

Stage changes are always UPGRADES on screen. A broken streak silently renders
the lower stage next time — never shown as a de-transformation animation.

## 5. Expression / pose sheet (10 poses)

| # | Pose name | Description | Used when |
|---|---|---|---|
| 1 | **Idle Hover** | Default float, slow bob, occasional blink, tip sways | Empty states, outro screens |
| 2 | **The Yatta** | Both arm-nubs up, mouth wide open shouting, eyes closed happy-arcs | Day-complete "DAY COMPLETE" beat |
| 3 | **Fist Pump** | One nub punching up, determined eyes | Single task completed (future check-off reaction) |
| 4 | **Clutch** | Sunglasses-drop / narrowed cool eyes, gold lightning crack behind | Clutch-bonus completion |
| 5 | **Streak Carry** | Cradling a tiny 🔥 flame like a torch, proud | Streak popup / streak beat |
| 6 | **Chest Wiggle** | Hugging a treasure chest, vibrating with anticipation | Weekly chest ready |
| 7 | **Zenkai Roar** | Power-up stance: braced, aura rays, tip fully vertical | Comeback screen transformation |
| 8 | **Zzz-Peace** | Meditating/floating cross-"legged", serene closed eyes, tiny 😴 bubble | Rest mode banner — calm, NOT abandoned-sad |
| 9 | **Notebook** | Peering curiously at a small clipboard, one eyebrow-tip raised | Empty lists ("nothing planned yet") / quick-capture sheet |
| 10 | **Cheer-On** | Leaning forward, pom-pom nubs, sparkle eyes | Stack-runner running state / active timer |

All poses share one rule: **no negative valence.** Pose 8 (rest) is serene by
design — it is the only low-energy pose allowed and must read as contentment.

## 6. Placement map (where Zen appears in the app)

Phase 1 — static art:
- **Day Complete outro beat** — `lib/shared/widgets/day_complete_sequence.dart`
  (`_OutroBeat`): Pose 2 above "Beautiful work. See you tomorrow".
- **Comeback screen** — `lib/features/comeback/comeback_screen.dart`: replaces
  the 👋 emoji; Pose 7 with the Zenkai Moment.
- **Empty states** — Home's `_NothingTodayState`
  (`lib/features/home/home_screen.dart`), timeline `_EmptyTimeline`
  (`lib/features/home/widgets/timeline_view.dart`): Pose 9/1.
- **Streak popup** — `lib/shared/widgets/streak_popup.dart`: Pose 5 at the
  user's current ladder stage.
- **Rest mode banner** — `lib/features/home/home_screen.dart`
  (`_RestBanner`): Pose 8 replacing the 😴 emoji.

Phase 2 — Rive rig:
- Check-off reactions beside the task tile burst
  (`lib/shared/widgets/task_tile.dart`), stack-runner companion
  (`lib/features/focus/stack_runner_screen.dart`), idle life on Home.

A Settings toggle ("Show Zen") hides every placement; emoji fallbacks remain.

## 7. Future Rive rig (phase 2 spec)

State machine named `zen`:
- **Inputs:** `stage` (int 0–4), `trigger_celebrate`, `trigger_clutch`,
  `trigger_zenkai`, `trigger_cheer`, `bool resting`, `bool idle_bored`
- **States:** `idle` (loop, stage-aware glow) → `celebrate` (one-shot, exits
  to idle) · `clutch` (one-shot) · `zenkai` (one-shot, longest, 2.5 s) ·
  `cheer` (loop while timer runs) · `rest` (loop) · `blink`/`sway` as idle
  sub-layers.
- **Transitions:** all one-shots return to `idle`; `stage` changes mid-idle
  crossfade over 400 ms (upgrade sparkle allowed; no downgrade animation).
- Target: single `.riv` under 300 KB, 60 fps on mid-range Android.

## 8. Hard rules (the dark-pattern kill list — contractual)

1. Zen is **never** sad, sick, dying, crying, disappointed, or lonely. No
   pose, sticker, or marketing art may depict it negatively.
2. Zen **never** references absence, missed tasks, or broken streaks — in
   art or copy. Returning = power-up; leaving = nothing.
3. Zen appears in **zero** notifications that pressure the user ("Zen misses
   you" is banned by name).
4. Purely cosmetic: no points, streaks, or unlocks depend on Zen; hiding it
   costs the user nothing.
5. One master toggle removes it everywhere.

## 9. Commissioning package

**Deliverables (Milestone 1 — static, engage first):**
1. Character sheet: front/side/¾ turnaround at Stage 1, silhouette study incl.
   24 px reduction test, on light AND dark swatches.
2. The 5-stage ladder (Section 4) as separate full renders.
3. The 10 poses (Section 5) at Stage 1; poses 2, 5, 7 additionally at Stage 3.
4. Formats: source (AI/Figma/SVG), plus transparent PNG exports at 512 px,
   256 px, 128 px, 48 px per asset. Vector must survive 24 px.
5. Style guide page: allowed palette (hex codes above), outline weight,
   do/don't examples incl. the kill-list rules.

**Milestone 2 (later, possibly different specialist):** Rive rig per
Section 7, reusing Milestone-1 vectors.

**Suggested engagement order:** silhouette/turnaround approval → ladder →
poses → exports. Written approval gate after the turnaround so style is
locked before volume work. Rights: full commercial buyout including
trademark registration of the character.
