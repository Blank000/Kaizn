# P1-01 — Scope & MVP Definition

This document captures the agreed scope for v1 of the Android app, based on Phase 1 discovery. All decisions here were made jointly and serve as the foundation for the product spec in Phase 2.

---

## Who Is This For

**Single user — Alok only.**
Chi and multi-profile support are explicitly out of scope for v1. The app is designed around one person's daily routine and goals.

---

## The Core Idea

Rather than building separate screens for habits, exercise, questions, and jobs — the app is built around one flexible primitive:

> **A customisable Project Tracker**, where each "project" has its own metrics, logging structure, and progress tracking.

The Excel tabs are not individual features — they are **pre-built project templates** powered by the same underlying engine.

### Pre-built Templates in v1

| Template Name | Replaces (Excel) | What It Tracks |
|---|---|---|
| Habit Routine | Habit ScoreCard | Daily habits with units, thresholds, skip days |
| Task Board | Daily Tracker | Tasks with priority, status, completion % |
| Weekly Review | Weekly Tracker | Weekly goals, hours planned vs completed |
| Job Hunt | Job Applications | Companies, recruiters, portals, apply dates |

> New project types can be added in future versions. The engine is flexible; the templates make it immediately useful.

---

## Core Daily Action

**Quick-log anything.**

When Alok opens the app, he should be able to log a habit value, update a task status, or mark a job application — whichever is relevant at that moment — in under 30 seconds. The app is a fast capture tool first, not a rigid checklist.

---

## Rewards — Separate Feature

Rewards are a standalone motivational layer that sits on top of the Project Tracker.

### How It Works
- Every logged action across any project earns **virtual points**
- Alok defines his own **custom rewards** (e.g., "Movie Night", "Cheat Meal", "Buy a book")
- Each reward has a **point threshold** to unlock it
- Once enough points are earned, the reward is marked as available to claim
- Purely motivational — no real money involved

### Rewards are NOT
- A financial accountability system
- Tied to penalties or loss of money
- Automatic — Alok manually claims a reward when he feels he's earned it

---

## Explicitly Out of Scope for v1

| Feature | Reason |
|---|---|
| Chi's profile / multi-user | Adds complexity, not needed for v1 |
| Question Tracker (DSA) | Overlaps with Task Board; revisit in v2 |
| Exercise Track (dedicated) | Can be a custom project template in v2 |
| Historical Excel data migration | Start fresh in v1 |
| Real money / financial accountability | Not the intent of the rewards system |
| Social / sharing features | No mention of need |

---

## Open Questions (Carry into Phase 2)

- How are points calculated per project type? Is the formula the same across all templates or configurable per project?
- Does the weekly tracker pull data automatically from daily logs, or is it logged separately?
- What happens to unclaimed rewards — do they expire?
- Should there be a streak mechanic tied to habits?
