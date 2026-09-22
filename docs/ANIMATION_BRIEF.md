# Zuzu — animation brief for an external agent

*Companion to `docs/AI_CONTEXT.md`. Hand over both: that file explains the
product, this one explains what to make and the exact shape it must arrive
in. Written 2026-09-22.*

---

## 1. Deliverable format: Lottie JSON, nothing else

Zuzu is a **Flutter** app using the `lottie` package (v3.1.3). Ship
**`.json` Lottie files**, one per animation. Do not ship After Effects
projects, GIFs, MP4s, sprite sheets, or Flutter code — the app has a
drop-in pipeline that takes JSON files by filename:

1. Drop the file into `assets/lottie/` using the exact filename from the
   slot table in section 5.
2. The folder is wildcard-declared in `pubspec.yaml`, so no registration is
   needed.
3. Rebuild. The app picks it up automatically.

**A missing or broken file is non-fatal.** Every Lottie slot has a
code-drawn fallback wired through `errorBuilder`, so a file that fails to
parse degrades to the built-in drawing rather than crashing. Ship
incrementally; nothing has to land all at once.

## 2. Hard technical constraints

Flutter's Lottie renderer is not the same as the web player. These are the
things that actually break, in the order they bite:

- **Shape layers only. No embedded or linked raster images.** Image assets
  either fail outright or bloat the file. Everything must be vector.
- **No expressions.** Bake them into keyframes before export.
- **Convert text to outlines.** Text layer support is poor and font
  resolution is unreliable.
- **Avoid merge paths** — support is partial and silently wrong when it
  fails. Boolean-combine shapes at design time instead.
- **Avoid track mattes beyond simple alpha.** Luma mattes are unreliable.
- **Gradient fills are fine; gradient strokes are not.** Use solid strokes.
- **No layer effects** — blur, glow, drop shadow. Fake a glow with a
  low-opacity shape.
- **No time remapping, no auto-orient.**
- Export at **30fps** (60 only if the motion genuinely needs it).
- **Square canvas**, typically 512×512. The app sizes with
  `BoxFit.contain`, so the composition's own aspect ratio is what matters,
  not its pixel dimensions.
- **Keep each file under ~60KB.** The existing streak flame is 29KB. Large
  files stall the first frame on mid-range Android.
- Export via **Bodymovin/LottieFiles**, Lottie schema 5.x.

## 3. Palette

| Role | Hex |
|---|---|
| Primary green | `#58CC02` |
| Streak orange | `#FF9600` |
| Rewards gold | `#FFD700` |
| Info blue | `#1CB0F6` |
| Brand teal (icon ground) | `#034749` |
| Cream (mascot line work) | `#F4F1E8` |

**Animations must read on both light and dark backgrounds.** The app is
fully themed and the same asset plays in both. Do not rely on a background
fill — export with a transparent canvas, and avoid near-white or near-black
as the *only* colour in a shape.

## 4. Reduced motion is a hard requirement

The app respects `MediaQuery.disableAnimations` in ten widgets already.
Every Lottie slot is played with `animate: !still`, so when the user has
reduced motion switched on, **the animation freezes on its current frame.**

Practical consequence for you: **frame 0 must be a good still image.** If
your animation starts from nothing — zero scale, zero opacity, off-canvas —
a reduced-motion user sees an empty box. Start from the composed, readable
state and animate around it.

## 5. The slots

Existing, already wired:

| Filename | Where | Size | Loop | Notes |
|---|---|---|---|---|
| `streak_flame.json` | Home header, streak popup, milestone dialog, Day Complete | 30–120px | yes | Present. Only plays when streak > 0; zero-streak uses a drawn ember. |

Wanted, in rough priority order. Filenames are the contract — use exactly
these:

| Filename | Moment | Size | Loop | Target duration | The beat |
|---|---|---|---|---|---|
| `zuzu_idle.json` | Mascot at rest on Home / empty states | 120px | yes | 3–4s | Alive but calm. Breathing, a blink, a small head tilt. Must not pull focus from the task list. |
| `zuzu_cheer.json` | Task completed, reward claimed | 140px | no | 0.8–1.2s | Short, sharp delight. Fires many times a day, so it must never feel slow or repetitive. |
| `zuzu_encourage.json` | Comeback screen, first task of the day | 160px | no | 1.5s | Warm and inviting, not pushy. **No guilt cues** — no frowning, no arms crossed, no tapping foot. |
| `task_complete_burst.json` | The check button on completion | 44px | no | 0.5s | Currently a code-drawn 8-dot radial burst in green and gold. A Lottie version must be equally punchy at 44px. |
| `level_up.json` | Level threshold crossed | 200px | no | 1.5s | Ascending. Gold-led. |
| `reward_unlock.json` | A reward becomes claimable | 160px | no | 1.2s | The gold moment of the app. Treasure opening, not confetti — confetti already exists as a separate package. |
| `day_complete.json` | Last scheduled task of the day | 240px | no | 2s | The biggest beat in the product. Fire-led, earned, triumphant. |
| `empty_state.json` | No tasks yet | 160px | yes | 4s | Quiet and inviting. Ren's territory — see section 6. |

## 6. Cast rules — these constrain what you may animate

Four characters exist, and **their roles do not overlap.** Getting this
wrong is the most likely way to have work rejected:

- **Zuzu**, the bird (the brand mascot, on the app icon) — greetings,
  encouragement, celebration.
- **Master Ren**, a fox sensei — reflection only: rest days, comebacks,
  empty states, missed check-ins, the weekly review. **Ren never appears in
  a celebration frame and never guilts the user.**
- **Pico**, a gadget robot — the AI assistant's face, nothing else.
- **The fire** — owns every streak visual. Streaks are not Zuzu's job.

So: do not animate Ren celebrating, do not animate Zuzu on a streak, do not
put Pico anywhere outside an AI surface.

## 7. Art direction

Flat vector, confident cream line work on solid fills, one gold accent per
composition. Look at `images/App Icon/Zuzu App Icon.png` and
`images/App Icon/Tick App Icon.png` for the established style of the bird,
and `images/Character/` for three in-app moment concepts the owner made
(starting out, building a streak, streak achieved).

Tone, in the owner's words: **professional, lifestyle, aspirational.** A
previous cartoon-fox icon was rejected for reading as a kids' app. Warm and
optimistic is right; babyish is not. No big glossy anime eyes, no blush
circles, no wobbling.

Motion should feel **earned and physical** — ease-out for things arriving,
a slight overshoot on landing, never linear. The app's existing code
animations use `Curves.easeOutCubic` for rises and `Curves.elasticOut` for
settles, and new work should sit alongside them without clashing.

## 8. What to send back

For each animation:

1. The `.json` file, named exactly as in section 5.
2. A looping GIF or MP4 **preview** so it can be reviewed without a build.
3. A one-line note on licensing/provenance. If any part is sourced from
   LottieFiles or similar, state the licence — commercial use must be
   permitted.
4. Confirmation that frame 0 is a readable still (section 4).

## 9. How it gets verified here

Each file is dropped in, the app is rebuilt, and the animation is checked on
a real device at its real size — not at preview scale. Anything that turns
to mush at its actual rendered size gets sent back. That is the single most
common failure, because 512px previews flatter everything and the streak
flame actually renders at 30px.
