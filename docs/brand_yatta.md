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

## SHIPPED — the victory figure

**The mark:** a figure with both arms raised, which is also the letter **Y**.
"Yatta!" is the shout you make with your arms in the air, so the name, the
gesture and the letterform are one shape. Near-white limbs, a single gold
head, on a **deep emerald** ground.

**Why this and not a character.** Master Ren went on the launcher first and
was rejected in use: *"doesn't seem professional, it's like a kid icon."*
Cartoon eyes and a round muzzle set a children's-app register, which is the
wrong promise for an app about discipline and an ambitious life. Ren keeps
his job **inside** the app — he owns reflection, rest, misses and Sundays.
A mascot and a brand mark are different jobs, and this app needs the second
one on the home screen.

**Why deep emerald, not `#58CC02`.** The bright green stays the interface
colour everywhere in the UI. At launcher size it reads playful, and green
tiles are the most crowded shelf in the drawer. A deeper shade of the same
family keeps the lineage and buys an adult value. One gold accent, never a
second.

**Directions that were built and lost** (all rendered and judged at 192 / 96
/ 48 px, not argued about on paper):

| Direction | Why it lost |
|---|---|
| Fox crest / kamon (Ren, geometric) | The angled eye slits read villainous — a Batman-villain mask, not a sensei |
| Summit / mountain | Clean, but every meditation and fitness app owns it. Generic. |
| Ascent bars | Reads as signal strength or an analytics dashboard, not a life |
| Ensō + gold check | Genuinely strong runner-up; lost only because circle-plus-check is a crowded pattern and says nothing about *you* |
| Victory figure ✅ | Name, gesture and letter in one shape; nothing else in the category looks like it |

**Sizing rules that must survive future edits**

- Full-bleed square (`assets/icon.png`) is iOS + legacy Android; the mark
  runs at 1.10× and fills 54% × 67% of the canvas.
- The adaptive foreground (`assets/icon_foreground.png`) is transparent and
  drawn at **1.42×**, because `flutter_launcher_icons` wraps it in
  `android:inset="16%"`. Size it by the **true opaque-pixel radius**, not the
  bounding box — this mark's corners are empty, so the box overstates its
  reach by a wide margin.
- Target: furthest opaque pixel at **r ≈ 303 after the inset**, inside the
  66/108dp guaranteed-safe circle (r = 312) every OEM mask respects.
- Regenerate with `tools/generate_icon.py`, then
  `dart run flutter_launcher_icons`. Verify against simulated circle,
  squircle and square masks before shipping.

---

## Superseded (2026-09-17) — Master Ren's head, no burst

Shipped for part of a day, then rejected as a kids' icon (see above). Kept
because the burst post-mortem under it is still the reason no starburst
should go behind any character:

- **The burst and a character head cannot share an icon.** Both are radial.
  Stacked, every single attempt — enclosing starburst, thin impact rays,
  pale-green rays with gold sparkles, a chunky burst behind a white disc, a
  crown of spikes peeking from behind the head — read as a **lion's mane or a
  sunflower**, and each one shrank the face until 48px was a coloured blob.
  Five layouts, one verdict.
- **The burst hasn't been discarded** — it still fires in-app as
  `_BurstPainter` on every completion. It is the *moment*; the icon is the
  *identity*. Those are different jobs.
- **Why Ren wins the slot:** fox ears give a silhouette nothing else in a
  drawer has, the art was already built as primitives so it scales cleanly,
  and it converts a character the owner already paid ~17 iterations for into
  brand equity seen dozens of times a day. This is the Duolingo move.

### What the critic pass changed (v1 → shipped)

An adversarial critique of the first render drove every one of these, and
they are the reason the icon reads at 48px:

| Problem | Fix |
|---|---|
| Orange fur on `#58CC02` is ~1.3:1 — a texture, not a figure | **Dark brown keyline** (`#3E2A20`) around the whole head+ears silhouette. The brand green was kept rather than darkened. |
| Cream brows sat ~1 unit above a white sclera and fused into a **visor** below 120px | Brows recoloured to `#4A3226`, thinned, dropped to sit on the eye as a lid ridge |
| Eyes sized like a detail (17% of head) and blank, with white under the iris | Sclera widened, pupil enlarged to ~75% and dropped to the lower lid |
| Muzzle was **62% of head width** — that's a shiba, not a fox | Reduced to ~36%, raised, and tucked fully inside the jaw |
| Cranium was a plain circle; foxes read as triangles | Cranium redrawn as a **path that tapers from wide temples to a narrow jaw** — this does more for fox-ness than the ears do |
| Subject was only 45% of canvas — half the icon was empty green | Now 61% |
| Blush and whisker dots broke the silhouette / became specks | Deleted from the icon port |
| Hand-placed right-side shapes drifted from the left | Every right-side shape is now the left one **reflected about x=100** |

Closed "serene" eyes were tested and rejected: on a streak app, a closed-eyed
launcher icon reads as *asleep / you've lapsed*, and it leaves the upper face
with no dark anchor at all.

### Sizing rules that must survive future edits

- The **full-bleed square** (`assets/icon.png`) is iOS + legacy Android.
- The **adaptive foreground** (`assets/icon_foreground.png`) is transparent
  and drawn at **1.15×**, because `flutter_launcher_icons` wraps it in
  `android:inset="16%"`. Size it by the **true opaque-pixel radius**, not the
  bounding box — a head has empty corners, and measuring the box throws away
  ~19% of the allowance and leaves a small fox marooned in green.
- Target: furthest opaque pixel lands at **r ≈ 303 after the inset**, inside
  the 66/108dp guaranteed-safe circle (r = 312) that every OEM mask respects.
- Regenerate with `tools/generate_icon.py` (Python + SVG + Edge headless
  screenshot), **not** the old Dart `image`-package script, which is deleted.

---

## Primary concept — "The Victory Burst" (HISTORY — not shipped)

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

## Rename checklist — DONE 2026-09-17

1. ✅ Android: `android:label="Yatta!"` in `AndroidManifest.xml`.
2. ✅ iOS: `CFBundleDisplayName` = `Yatta!`.
3. ✅ `MaterialApp.title`, `AppConstants.appName`, the login screen wordmark,
   and the About dialog. (Onboarding carried no product name.)
4. ✅ Deliberately UNCHANGED, because each one orphans real user data or
   breaks upgrade paths: pubspec `name`, package id
   `com.alokraj.habit_reward_tracker`, the Drift database name, the Drive
   backup filename `habit_reward_tracker.json`, the iOS app-group id, and
   `CFBundleName`. Revisit only at store-release time.
