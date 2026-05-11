# P5-01 — Developer Handoff

This is the single document a developer reads on day one. It summarises everything decided across all phases and points to the right spec document for deeper detail.

---

## What We're Building

A cross-platform mobile app (iOS + Android) for Alok — a personal productivity and habit tracking system with a gamified rewards engine. Think Duolingo's energy applied to daily habits, task management, job hunting, and goal tracking.

The app replaces an existing Excel tracker (`UltimateHabitTracker.xlsm`) with a fast, delightful mobile experience.

---

## The One-Line Product Summary

> A customisable Personal Project Tracker where every logged action earns virtual points, and points unlock real self-defined rewards.

---

## Core Principles

1. **Quick-log anything in under 30 seconds** — the primary daily action
2. **Every action feels rewarding** — animations, points, and celebrations on every log
3. **Progress is always visible** — streak, points, and reward progress never hidden
4. **Bold and gamified** — visual language inspired by Duolingo, not a corporate dashboard

---

## User

Single user — **Alok**. No authentication, no accounts, no multi-user in v1.

---

## Tech Stack

| Layer | Choice | Reason |
|---|---|---|
| Framework | Flutter (Dart) | Cross-platform, first-class animations, Duolingo uses it |
| Local Storage | SQLite via Drift | Relational data, type-safe queries, no backend needed |
| State Management | Riverpod | Scalable, async-friendly, clean separation of UI and logic |
| Navigation | go_router | Declarative, handles deep links cleanly |
| Charts | fl_chart | Flutter-native charting |
| Font | Nunito (Google Fonts) | Rounded, bold, matches gamified aesthetic |

Full reasoning in `P4-01_tech_stack_decisions.md`

---

## App Structure — 4 Tabs, ~15 Screens

```
Bottom Nav
├── Home        → Streak popup + Quick Log + Today's Summary
├── Projects    → Project list, detail, create/edit (4 templates)
├── Rewards     → Points balance, reward list, claim, history
└── Stats       → Overall stats + Weekly Review (auto-aggregated)
```

Full screen list and navigation map in `P3-01_information_architecture.md`

---

## The 4 Project Templates

| Template | Replaces (Excel) | Key Behaviour |
|---|---|---|
| Habit Routine | Habit ScoreCard | Daily metrics with thresholds, skip days (max 2/week), % coverage |
| Task Board | Daily Tracker | Tasks with priority scoring formula, completion %, status |
| Weekly Review | Weekly Tracker | Read-only, auto-aggregates from Mon–Sun daily logs |
| Job Hunt | Job Applications | Applications, recruiters, portals, status tracking |

Each project has configurable metrics and its own points formula set by the user.

---

## Gamification System

### Points
- Earned on every log entry
- Configurable per project: base points + threshold bonus + multiplier
- Never deducted (only spent on reward claims)

### Streak
- Increments on first real log entry each calendar day
- Breaks if a full day passes with zero logs
- Popup shown on every app open (current streak + personal best)
- Milestones at: 7, 14, 30, 60, 100, 365 days → full-screen confetti celebration

### Rewards
- User-defined (name + point threshold)
- Claimable when balance ≥ threshold
- Claiming deducts points, fires confetti, moves to Claimed History
- Never expire

Full business rules in `P2-02_business_rules.md`

---

## Data Model — 6 Tables

| Table | Purpose |
|---|---|
| `projects` | Each project Alok creates |
| `metrics` | Configurable fields within a project |
| `entries` | Every log entry ever made |
| `points_history` | Audit log of all points earned |
| `rewards` | All defined rewards + claimed state |
| `streak` | Single-row streak state |

All data stored locally on-device. No backend, no sync, no auth.

Full schema in `P4-02_data_model.md`

---

## Design System Summary

| Element | Spec |
|---|---|
| Font | Nunito (Black for display, Bold for headings, SemiBold for body) |
| Primary color | `#58CC02` Vivid Green |
| Streak color | `#FF9600` Flame Orange |
| Rewards color | `#FFD700` Golden Yellow |
| Missed/ND color | `#FF4B4B` Soft Red |
| Button style | Hard shadow `0px 4px 0px #45A800` — Duolingo signature |
| Card radius | 16dp |
| Base spacing unit | 8dp |
| Milestone animation | Full-screen confetti, ~1.5s, dismissible |

Full design system in `P3-03_design_system.md`

---

## Key Screen Flows (3 Critical Journeys)

1. **App open → Streak popup → Quick log an entry** — 4 taps max
2. **Create a new project from a template** — 4-screen linear wizard
3. **Earn points → Claim a reward** — 2 taps from Rewards tab

Full wireframes (ASCII) in `P3-02_screen_flows_and_wireframes.md`

---

## Build Order — 4 Milestones

| Milestone | Focus | PM Sign-off Gate |
|---|---|---|
| M1 — Skeleton | Navigation + data layer | App opens, data persists |
| M2 — Core Loop | Streak + Quick Log + Points | Daily loop works end-to-end |
| M3 — Projects & Rewards | All 4 templates + rewards engine | Full feature set usable |
| M4 — Polish | Animations, onboarding, stats, icon | Feels shippable |

Full acceptance criteria per milestone in `P4-03_build_milestones.md`

---

## Document Index

| Document | Contents |
|---|---|
| `P0-01_product_discovery_process.md` | Phase map and document naming convention |
| `P1-01_scope_and_mvp.md` | What's in v1, what's out, key decisions |
| `P2-01_user_stories.md` | 25 user stories across 8 feature areas |
| `P2-02_business_rules.md` | Points, streaks, thresholds, rewards logic |
| `P3-01_information_architecture.md` | All screens and navigation structure |
| `P3-02_screen_flows_and_wireframes.md` | 3 journeys, 11 ASCII wireframes |
| `P3-03_design_system.md` | Colors, typography, components, animations |
| `P4-01_tech_stack_decisions.md` | Flutter rationale, packages, project structure |
| `P4-02_data_model.md` | 6 tables, all fields, relationships |
| `P4-03_build_milestones.md` | 4 milestones with acceptance criteria |
| `P5-01_developer_handoff.md` | This document |

---

## Out of Scope for v1

- Multi-user / Chi's profile
- Backend / cloud sync
- Excel data migration
- Real money / financial accountability
- Social or sharing features
- DSA Question Tracker (revisit in v2)
- Dedicated Exercise Tracker (revisit in v2)
