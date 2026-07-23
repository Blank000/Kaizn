# Yatta! — Icon & Brand Brief

*2026-07-23. The app is named **Yatta!** (やった — "I did it!"), the Japanese
victory cry. The brand is the completion moment itself: celebration-loud,
guilt-quiet.*

---

## The core insight

The app already has a signature visual moment: the instant a task is checked,
`_BurstPainter` fires **eight dots radiating from the check — alternating
green and gold**. Every user sees it dozens of times a day. It is the single
most-repeated animation in the product, and it happens at the exact moment the
user would say "yatta!"

**The icon is that moment, frozen at its peak.** Not a new symbol — the app's
own celebration, promoted to the launcher. Users who tap the icon are tapping
the feeling they get inside it. That loop is the brand.

## Primary concept — "The Victory Burst"

A manga **shout-burst** (the spiky starburst speech bubble that manga uses to
draw a shouted word) wrapping a bold, confident **check**:

```
        \   |   /
     —  ✦ ╲ ✓ ╱ ✦  —        (schematic — spiky burst, check at heart,
        /   |   \             one gold spark at the top-right point)
```

- **Field:** primary green `#58CC02`, rounded square (iOS squircle handles
  itself). Keeps continuity with the current icon and the app's identity color.
- **Burst:** white, 8–10 irregular spikes — hand-drawn energy, NOT a perfect
  geometric star (perfect = corporate; irregular = shouted). The spikes are the
  manga "sound made visible."
- **Check:** heavy weight, slight upward kick on the tail — mid-celebration,
  not clerical. Sits at the burst's heart.
- **The one accent:** a single **gold** (`rewardsGold`) spark dot at the
  top-right spike tip — the same gold as clutch bonuses and the chest. One
  only; more reads as clutter at 48px.
- **Optional flourish for the store listing (not the launcher icon):** two tiny
  motion ticks under the check's tail, like a fist just pumped.

### Why it wins
1. **It's ownable.** The category is drowning in flat checkmarks, rings, and
   flames. Nobody has manga energy. At a glance in a folder, Yatta! is the
   loud one.
2. **It's the product thesis.** Celebration as identity — the icon literally
   depicts the reward moment the app is built around.
3. **It's the name.** A shout-burst IS "yatta!" typeset visually. Icon and
   name explain each other with zero text.
4. **It scales.** One glyph, two colors + accent; the burst silhouette
   survives 48px, the monochrome mask, and the notification tray.

## Variant concepts (bench, in case the primary doesn't land in render)

- **B. The ヤ mark** — katakana ヤ (the "ya" of やった) as a bold white glyph;
  it naturally resembles a slanted check with a cross-stroke. Striking,
  minimal, very "designed" — but illegible as a word to most users, and loses
  the celebration energy. Better as an in-app easter egg or watermark.
- **C. Fist + burst** — an abstracted raised fist inside the burst instead of
  the check. More human, more anime; but fists render muddy below 64px and
  carry unintended readings. Keep for splash/marketing art, not the icon.
- **D. Confetti check** — current check + scattered confetti dots. Safest,
  most generic; the fallback if the burst feels too loud.

## Technical deliverables

| Asset | Spec | Notes |
|---|---|---|
| Master | 1024×1024 PNG | via `tools/generate_icon.dart` (image package) |
| Android adaptive — background | `#58CC02` solid | already configured |
| Android adaptive — foreground | burst+check, sized for the 66/108 safe zone | spikes must NOT touch the mask edge — Android crops circles/squircles |
| Android 13 themed (monochrome) | single-color burst+check silhouette | test: the silhouette alone must still read as a shout |
| Notification small icon | white silhouette, transparent bg | replaces the default; ties pings to the brand |
| iOS | full-bleed square, no transparency | squircle mask is automatic |
| Splash | burst glyph centered on green | can animate later: dots fly IN → check lands → burst pops (the in-app animation, reversed) |

Regeneration flow (already in repo): draw in `tools/generate_icon.dart` →
`assets/icon.png` → `dart run flutter_launcher_icons`.

## Motion & voice extensions (free wins later)

- **App open:** splash replays the burst landing — the icon coming alive.
- **All-done celebration:** title already shouts; rename to "YATTA!" moment —
  the daily all-clear IS the brand moment.
- **Wordmark:** "Yatta!" set in a heavy rounded sans, exclamation dot in gold
  (the same single-gold-accent rule as the icon).
- **Mascot (someday):** a tiny spark-spirit born from the burst. Kill-list
  rule inherited: it powers UP when you return; it never sulks.

## Rename checklist (when we apply the brand)

1. Android: `android:label="Yatta!"` in `AndroidManifest.xml`.
2. iOS: `CFBundleDisplayName` = `Yatta!`.
3. About dialog + onboarding copy + README title.
4. Package id `com.alokraj.habit_reward_tracker` and pubspec `name` stay as-is
   (invisible to users; changing them breaks signing/upgrade paths — decide
   only at store-release time).
