# P4-01 — Tech Stack Decisions

Defines the technology choices for v1 of the app. All decisions prioritise cross-platform support, low learning curve, and suitability for a gamified, animation-heavy UI.

---

## Platform Target

| Platform | Supported in v1 |
|---|---|
| Android | Yes |
| iOS | Yes |
| Web | No (v2 consideration) |
| Desktop | No |

---

## Framework — Flutter

**Decision: Flutter (with Dart)**

Flutter is the primary framework. A single codebase ships to both Android and iOS with no platform-specific rewrites needed.

### Why Flutter over React Native — Reasoning for This App

#### 1. Duolingo is built in Flutter
The exact visual style targeted — bold UI, smooth animations, gamified feel — was built by Duolingo's team using Flutter. The toolset is proven for exactly this outcome.

#### 2. Animations are first-class, not an afterthought
This app lives and dies on animations — confetti on milestones, streak flame pulse, points floating up, progress bars filling. In Flutter, animations are built into the core framework. In React Native, smooth animations require a separate library (Reanimated) and careful threading to avoid jank. Flutter runs animations on its own rendering engine, bypassing the native UI layer entirely — no bridge, no dropped frames.

#### 3. Pixel-perfect consistency across iOS and Android
Flutter draws every pixel itself using its own engine (Impeller). What is designed is exactly what renders on both platforms — same fonts, same animations, same feel. React Native delegates to native components, so buttons, inputs, and transitions can look and behave slightly differently on iOS vs Android, requiring platform-specific fixes.

#### 4. Dart is easier to learn from scratch than JavaScript
Dart is statically typed (catches errors before runtime), has no `this` confusion, no `undefined` vs `null` chaos, and a straightforward async model. JavaScript's flexibility is powerful but notorious for surprising new learners.

#### 5. One rendering engine = fewer surprises
React Native's new architecture (JSI) is better than the old bridge, but still newer and less battle-tested. Flutter's rendering pipeline has been stable and consistent for years.

#### 6. The package ecosystem covers everything this app needs
Every package needed — Drift for SQLite, fl_chart for graphs, confetti, Riverpod — is Flutter-first, well-maintained, and widely used. No workarounds needed.

> **When React Native would win instead:** if the team already knows JavaScript/React well. Since this is a greenfield project, Flutter is the cleaner choice.

### Other Flutter Advantages
- Hot reload = fast iteration during development
- Strong Google backing, large community, well-maintained packages

### Flutter Version
- Use the latest stable release at time of development
- Target: Flutter 3.x+

---

## Language — Dart

- Dart is statically typed, object-oriented, and easy to read
- No prior mobile development experience required to get started
- Official learning path: flutter.dev/learn

---

## Local Storage — SQLite via Drift

**Decision: Drift (formerly Moor) — a type-safe SQLite wrapper for Flutter**

### Why Drift over alternatives
| Option | Verdict |
|---|---|
| Drift (SQLite) | Best for structured, relational data with queries |
| Hive | Good for simple key-value but weak for relational data |
| SharedPreferences | Too simple — only for small config values |
| Firebase | Overkill — backend not needed in v1 |

### What goes in SQLite
- Projects and their metric definitions
- All log entries (per project, per day)
- Points history
- Rewards (defined + claimed)
- Streak data (current streak, personal best, last log date)

---

## Key Flutter Packages

| Package | Purpose |
|---|---|
| `drift` | Local SQLite database ORM |
| `provider` or `riverpod` | State management |
| `go_router` | Navigation and routing |
| `fl_chart` | Charts and graphs in Stats tab |
| `confetti` | Confetti animation for milestones and reward claims |
| `shared_preferences` | Small config values (e.g., onboarding completed flag) |
| `google_fonts` | Nunito font from Google Fonts |
| `intl` | Date and number formatting |
| `uuid` | Unique IDs for all database records |

---

## State Management — Riverpod

**Decision: Riverpod**

- More scalable than Provider for a multi-screen app
- Works well with async data (database reads/writes)
- Clean separation of UI and business logic

---

## Project Structure

```
lib/
├── main.dart
├── app/
│   └── router.dart           ← go_router navigation setup
├── core/
│   ├── database/             ← Drift DB schema and DAOs
│   ├── models/               ← Data models (Project, Entry, Reward, Streak)
│   └── utils/                ← Date helpers, formatters
├── features/
│   ├── home/                 ← Home screen, Quick Log sheet
│   ├── projects/             ← Project list, detail, create/edit
│   ├── rewards/              ← Rewards dashboard, create, history
│   └── stats/                ← Stats overview, Weekly Review
└── shared/
    └── widgets/              ← Reusable UI components (buttons, cards, progress bars)
```

---

## Development Tools

| Tool | Purpose |
|---|---|
| Android Studio or VS Code | Primary IDE (both have Flutter plugins) |
| Flutter DevTools | Performance and layout debugging |
| GitHub | Version control |
| Physical device or emulator | Testing — prefer physical device for animation feel |
