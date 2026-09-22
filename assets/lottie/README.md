# Lottie drop-ins

Download free animations from https://lottiefiles.com (Lottie JSON format),
name them as below, drop them in this folder, and rebuild — the app picks
them up automatically and falls back to its built-in drawn animation when a
file is missing.

| Filename | Used for |
|---|---|
| `streak_flame.json` | The streak fire on Home's header (replaces the code-drawn LivingFlame) |

Slots that are specced but not yet filled — drop a file with one of these
names and it goes live: `zuzu_idle`, `zuzu_cheer`, `zuzu_encourage`,
`task_complete_burst`, `level_up`, `reward_unlock`, `day_complete`,
`empty_state`. Sizes, durations and the beat each one has to hit are in
**`docs/ANIMATION_BRIEF.md`**, which is also the file to hand an external
designer or AI agent.

Tip: on any LottieFiles animation page, use "Edit" to recolor layers to the
brand palette (#58CC02 green, #FF9600 orange, #FFD700 gold) before download.
Check the license on each file (most free ones are Lottie Simple License —
commercial use OK).
