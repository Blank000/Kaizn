# P3-03 — Design System

Defines the visual language of the app. Inspired by Duolingo — bold, gamified, energetic, and rewarding. Every design decision should make Alok feel like he's playing a game he's winning.

---

## Design Principles

1. **Bold over subtle** — Large type, strong colors, high contrast. Nothing should feel passive.
2. **Every action feels rewarding** — Animations, sounds (optional), and visual feedback on every log entry.
3. **Progress is always visible** — Streaks, points, and progress bars are never hidden.
4. **Celebrate wins loudly** — Milestones and unlocked rewards get full-screen moments, not toasts.
5. **Minimal friction** — The path to logging should never require more than 2 taps from any screen.

---

## Color Palette

### Primary Colors
| Role | Color | Hex |
|---|---|---|
| Primary (action, CTA) | Vivid Green | `#58CC02` |
| Primary Dark | Deep Green | `#45A800` |
| Background | Off White | `#F7F7F7` |
| Surface (cards) | Pure White | `#FFFFFF` |

### Accent Colors
| Role | Color | Hex |
|---|---|---|
| Streak / Fire | Flame Orange | `#FF9600` |
| Rewards / Gold | Golden Yellow | `#FFD700` |
| Warning / Missed | Soft Red | `#FF4B4B` |
| Skip Day | Muted Orange | `#FF9B35` |
| Info / Neutral | Sky Blue | `#1CB0F6` |

### Dark Mode (optional v2)
| Role | Color | Hex |
|---|---|---|
| Background | Dark Navy | `#131F24` |
| Surface | Dark Card | `#1F3340` |
| Text Primary | White | `#FFFFFF` |
| Text Secondary | Muted White | `#AFAFAF` |

---

## Typography

Inspired by Duolingo's use of rounded, bold fonts.

| Level | Font | Weight | Size | Usage |
|---|---|---|---|---|
| Display | Nunito | Black (900) | 32sp | Streak number, points balance |
| Heading 1 | Nunito | Bold (700) | 24sp | Screen titles |
| Heading 2 | Nunito | Bold (700) | 18sp | Section headers, card titles |
| Body | Nunito | SemiBold (600) | 16sp | Main content, descriptions |
| Caption | Nunito | Regular (400) | 13sp | Subtitles, timestamps, labels |
| Button | Nunito | ExtraBold (800) | 16sp | All CTAs |

> **Font**: Nunito — free on Google Fonts, highly readable, rounded and friendly.

---

## Iconography

- Style: **Filled, rounded icons** (not outline)
- Library: **Material Symbols Rounded** or custom illustrations for key moments
- Key custom icons:
  - Streak flame (animated when active)
  - Reward trophy / chest
  - Project type icons (habit leaf, task checkmark, calendar, briefcase)
  - XP/points coin

---

## Component Library

### Buttons
```
Primary CTA:
  Background: #58CC02  |  Text: White  |  Corner radius: 16dp
  Shadow: 0px 4px 0px #45A800 (hard shadow — Duolingo signature)

Secondary:
  Background: White  |  Border: 2dp #E5E5E5  |  Text: Dark

Destructive:
  Background: #FF4B4B  |  Text: White
```

### Cards
```
Default card:
  Background: White
  Border radius: 16dp
  Shadow: subtle (elevation 2)
  Border: none

Highlighted card (claimable reward, milestone):
  Border: 2dp #FFD700
  Glow effect: soft golden shadow
```

### Progress Bars
```
Habit threshold progress:
  Track: #E5E5E5  |  Fill: #58CC02  |  Height: 10dp  |  Rounded ends

Reward progress:
  Track: #E5E5E5  |  Fill: #FFD700  |  Height: 12dp  |  Rounded ends
  Shows: "X / Y pts" label inline
```

### Streak Display
```
Large streak counter on Home:
  Flame icon (animated pulse when streak is active)
  Number: Display size, Flame Orange (#FF9600)
  Label: "Day Streak" in Caption

Streak popup (modal):
  Full-width card with flame illustration
  Current streak (large)
  Personal best (smaller, below)
  Dismiss: tap anywhere
```

---

## Motion & Animation

| Moment | Animation |
|---|---|
| Log entry submitted | Points "+X" float up and fade, green checkmark burst |
| Streak popup opens | Slide up from bottom, flame pulses |
| Milestone hit | Full-screen confetti / fireworks, hold for 2s |
| Reward unlocked | Gold shimmer on reward card, bell chime (optional) |
| Reward claimed | Card flips to "Claimed" state with checkmark |
| Progress bar fills | Smooth fill animation on every update |

All animations should be:
- Under **400ms** for micro-interactions
- Under **1.5s** for celebrations
- **Skippable** — a single tap should dismiss any celebration

---

## Gamification Visual Language

| Element | Visual Treatment |
|---|---|
| Points | Gold coin icon + bold number, always visible on Home |
| Streak | Flame icon, orange color, prominent on Home and popup |
| Milestone badges | Shield/badge shape, earned badges shown in Stats |
| Level (future v2) | XP bar under points balance |
| Locked reward | Greyed out with padlock icon + progress bar |
| Claimable reward | Glowing gold border, pulsing "Claim!" button |

---

## Screen Spacing & Layout

- Base unit: **8dp**
- Content padding: **16dp** horizontal
- Card padding: **16dp** all sides
- Section spacing: **24dp** between sections
- Bottom nav height: **64dp**
- Safe area respected top and bottom (Android notch / gesture bar)
