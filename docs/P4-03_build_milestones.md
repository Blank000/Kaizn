# P4-03 — Build Milestones

Breaks the app into 4 sequential milestones, each producing something testable on a real device. Ordered so that the core loop works first and polish layers are added progressively.

---

## What Is Expected from the PM (Alok) at Each Milestone

At the end of every milestone:
1. **Install and test** the build on your phone
2. **Verify the acceptance criteria** listed below
3. **Give feedback** — what feels off, what's missing, what can improve
4. **Sign off** before the next milestone begins

You do not write code. You test, react, and decide.

---

## Milestone 1 — The Skeleton

**Goal:** Core navigation and data layer working. No UI polish yet — this is about making sure the foundation is solid.

**What gets built:**
- Flutter project set up with go_router navigation
- Bottom nav bar with all 4 tabs (Home, Projects, Rewards, Stats)
- SQLite database with all 6 tables set up via Drift
- Riverpod state management wired in
- Basic screen shells for all 15 screens (empty but navigable)
- Nunito font + base color palette applied globally

**Acceptance Criteria (PM sign-off):**
- [ ] App opens on Android and iOS without crashing
- [ ] All 4 tabs are tappable and navigate correctly
- [ ] Can create a project (any template) and see it persist after closing the app
- [ ] Can add a log entry and see it saved

**What it looks like:** Functional but ugly. Grey boxes, placeholder text, no animations.

---

## Milestone 2 — The Core Loop

**Goal:** The daily habit of opening the app, seeing the streak, quick-logging, and earning points works end-to-end.

**What gets built:**
- Streak Popup (modal on every app open)
- Streak logic (increment, break, personal best tracking)
- Milestone celebration screen (7, 14, 30, 60, 100, 365 days)
- Home screen with Today's Summary card
- Quick Log bottom sheet with smart suggestions
- Log entry form (context-aware per metric unit type)
- Points float-up animation on log submit
- Green checkmark burst on log submit
- Points balance calculating correctly

**Acceptance Criteria (PM sign-off):**
- [ ] Streak popup shows every time the app is opened
- [ ] Streak increments correctly on first log of each day
- [ ] Streak breaks correctly if a day is missed
- [ ] Milestone popup fires at 7 days with confetti
- [ ] Quick Log sheet shows unlogged metrics for today
- [ ] Logging a habit entry awards points and updates balance
- [ ] Points balance on Home is accurate after each log

**What it looks like:** Starting to feel real. Core gamification loop is playable.

---

## Milestone 3 — Projects & Rewards

**Goal:** All 4 project templates are fully usable. The rewards engine is live and claimable.

**What gets built:**
- Project List screen with template cards
- Create Project wizard (template → name → metrics → points setup)
- Project Detail screen (log history, stats, settings)
- Habit Routine template: skip days, threshold tracking, % coverage
- Task Board template: task status, priority scoring, completion %
- Job Hunt template: application list, status updates, recruiter log
- Weekly Review: auto-aggregation from daily logs (read-only)
- Rewards Dashboard (balance, locked/claimable rewards, progress bars)
- Create/Edit Reward screen
- Confirm Claim modal
- Reward Claimed celebration (confetti)
- Claimed History screen
- Reward unlocked alert (when balance crosses threshold)

**Acceptance Criteria (PM sign-off):**
- [ ] Can create all 4 project types with custom metrics
- [ ] Habit Routine respects skip day rules (max 2/week)
- [ ] Threshold coverage % is calculated and displayed correctly
- [ ] Task Board auto-scores tasks by priority formula
- [ ] Weekly Review populates automatically from this week's logs
- [ ] Can define a reward with a point threshold
- [ ] Reward shows as claimable when balance is sufficient
- [ ] Claiming a reward deducts points and moves to Claimed History
- [ ] Confetti fires on reward claim

**What it looks like:** Feature complete. The full product as designed is usable.

---

## Milestone 4 — Polish & Duolingo Feel

**Goal:** Transform the app from functional to delightful. Every interaction should feel rewarding.

**What gets built:**
- All animations refined (streak flame pulse, progress bar fills, card transitions)
- Confetti tuned (particle count, duration, colours)
- Points float-up animation polished
- Empty state illustrations (no projects yet, no rewards yet, no entries today)
- Onboarding flow (first-time user: name entry, first project setup walkthrough)
- Stats tab: charts and graphs via fl_chart (habit trends, points over time)
- App icon and splash screen
- Haptic feedback on key actions (log submit, reward claim)
- Performance audit (smooth 60fps scrolling, no jank on animations)
- Edge case handling (what if streak data is corrupted, what if all rewards are claimed)

**Acceptance Criteria (PM sign-off):**
- [ ] App feels as snappy and polished as a commercial app
- [ ] No lag or jank on any screen transition or animation
- [ ] First-time user flow is smooth and welcoming
- [ ] Stats charts display meaningful data after 1 week of use
- [ ] App icon is set and looks great on home screen
- [ ] Haptics fire on log submit and reward claim

**What it looks like:** Shippable. Ready for real daily use.

---

## Milestone Summary

| Milestone | Focus | Output |
|---|---|---|
| M1 — Skeleton | Foundation | Navigable app, data layer working |
| M2 — Core Loop | Daily habit | Streak + quick log + points working |
| M3 — Projects & Rewards | Full features | All templates + rewards engine live |
| M4 — Polish | Delight | Animations, onboarding, stats, icon |

---

## PM Responsibilities by Milestone

| Milestone | Your role |
|---|---|
| M1 | Install build, confirm navigation and data persistence |
| M2 | Test the daily loop every day for 3–5 days. Break the streak intentionally. Hit 7 days. |
| M3 | Set up all 4 project types with real data. Define and claim your first reward. |
| M4 | Use the app as your real daily tracker for 1–2 weeks. Report anything that feels off. |
