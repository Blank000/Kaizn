## B=MAP miss diagnosis (Behavior = Motivation + Ability + Prompt) [habit-science]
SRC: Tiny Habits â€” BJ Fogg (Fogg Behavior Model)
IDEA: A behavior happens only when Motivation, Ability, and Prompt converge at the same moment; every failure is a deficit in exactly one of the three. Diagnosing WHICH one failed tells you the fix â€” a stronger prompt, an easier version, or a motivation reframe â€” instead of generic 'try harder'.
WHO: Users stuck in miss-loops on a specific habit who can't articulate why; analytical users who like root-cause fixes
FEATURE: When a task is marked missed (or misses 3x in a week), show a one-tap triage chip row: 'Didn't see it / Too hard right now / Didn't feel like it'. Each answer routes to an EXISTING tool: reminder/time-slot editor, the 2-minute fallback version, or the identity-vote framing card. Store the answer to power Goldilocks coach suggestions.
COVERED: partial (Goldilocks coach and 2-min fallbacks exist as fixes, but nothing diagnoses which fix a given miss needs â€” they're unrouted) | RISK: low â€” appears only at the moment of a miss, one tap, reuses existing features as the treatment

## Life anchors / Tiny Habits recipes [habit-science]
SRC: Tiny Habits â€” BJ Fogg (anchor prompts: 'After I [existing routine], I will [new tiny behavior]')
IDEA: The most reliable prompt is an existing rock-solid routine (brushing teeth, morning coffee), not a clock time or notification â€” the old behavior's completion becomes the cue. Fogg's recipes explicitly phrase habits as After-X-I-will-Y sentences.
WHO: Notification-fatigued users; people with irregular schedules for whom clock-based reminders misfire
FEATURE: Let a habit-stack chain be headed by a custom untracked 'life anchor' ('after morning coffee', 'when I get home') instead of another app task. The task tile and reminder copy then render as the recipe sentence: 'After I pour my coffee â†’ Meditate 2 min'. Anchor is just a label + optional rough time for sorting the Up Next list.
COVERED: partial (habit stacking chains with derived time slots exist, but chain heads must be app tasks with times â€” no real-world routine anchors, no recipe phrasing) | RISK: low â€” one extra option in the existing chain-head picker; ignorable by everyone else

## Celebration / 'Shine' [habit-science]
SRC: Tiny Habits â€” BJ Fogg
IDEA: Fogg argues emotion, not repetition, wires habits: a felt positive emotion within seconds of the behavior tells the brain 'do that again'. Crucially the celebration must be the user's own (fist pump, 'I'm awesome!'), performed immediately â€” app-generated confetti alone is weaker because the user is passive.
WHO: Users for whom points feel abstract; anyone building brand-new habits in the fragile first weeks
FEATURE: Per-user (or per-milestone) pickable check-off 'signature': a haptic pattern + short sound + personal victory phrase that fires within ~300ms of tapping done, plus a one-time coach card teaching 'pause and actually feel it'. Slot it into the existing confetti-cosmetics system as another cosmetic layer.
COVERED: partial (confetti cosmetics and +N point float exist; nothing prompts a user-owned, instant, felt celebration or teaches why it matters) | RISK: low â€” it's cosmetics; the coaching is one dismissible card

## Motivation wave capture [habit-science]
SRC: BJ Fogg (Motivation Wave, 2012; Tiny Habits)
IDEA: Motivation spikes are brief and shouldn't be spent doing the habit harder â€” they should be spent on one-time structural actions that lower future ability barriers (pre-scheduling, prepping environment, buying gear). When the wave subsides, the structure remains.
WHO: Enthusiasm-driven starters who burn hot then fade; ADHD-style users with bursty energy
FEATURE: Detect peak moments the app already knows about (level-up, 7/30-day streak, milestone completed, weekly chest opened) and surface a single 'Ride the wave' card offering one structural action: fill next week's timeline, add 2-min fallbacks to your 3 weakest habits, write an environment-prep checklist for a milestone. Never shown outside peak moments.
COVERED: none | RISK: medium â€” must be strictly rate-limited to peaks or it becomes another nag card competing for the home screen

## Cue tagging (five cue categories) [habit-science]
SRC: The Power of Habit â€” Charles Duhigg (cue-routine-reward; cues are location, time, emotional state, other people, or immediately preceding action)
IDEA: Every habit loop is triggered by a cue from one of five categories. Making the cue explicit turns a vague intention into a concrete trigger, and logging cue-vs-completion data reveals which trigger types actually work for this user.
WHO: Users whose habits are erratic across contexts; self-quantifiers who want to know what actually drives their behavior
FEATURE: Optional 'cue' field on a task: pick a category chip (place / time / feeling / person / after-action) + free text. Stats gains a 'cues that work' row: completion rate per cue type. When a habit's completion times are scattered, the app suggests attaching a cue. Ties directly into life anchors (after-action cue) and the timeline (time cue).
COVERED: none (time slots exist but are not framed or analyzed as cues; no place/emotion/social cues) | RISK: medium â€” a new optional field plus a stats row; must stay collapsed-by-default in the task form to protect form simplicity

## Keystone habit detection [habit-science]
SRC: The Power of Habit â€” Charles Duhigg (keystone habits: exercise, family dinners, making the bed cascade into unrelated wins)
IDEA: Some habits disproportionately trigger success elsewhere by providing structure, small wins, and identity evidence. Users rarely know which of their habits is the keystone â€” but completion data can reveal it as a cross-habit correlation.
WHO: Overwhelmed users tracking too many habits who need to know which ONE to protect; data-curious users
FEATURE: A computed Stats insight: for each habit with 30+ days of data, compare same-day completion rates of all OTHER tasks on days it was done vs not done; surface the top correlate as 'Keystone candidate: on days you run, you complete 38% more of everything else.' User can pin it as Keystone for a subtle crown accent on Home and priority placement in Up Next.
COVERED: none | RISK: low â€” pure read-only insight in Stats plus an optional pin; needs honest 'correlation, not magic' copy

## Habit replacement (Golden Rule of habit change) [habit-science]
SRC: The Power of Habit â€” Charles Duhigg
IDEA: You can't extinguish a bad habit's loop, but you can keep the same cue and reward while swapping the routine (smoker keeps the 3pm break cue and social reward, swaps cigarette for a walk). This is the evidence-based route to breaking habits, which pure 'build' trackers ignore.
WHO: The large user segment whose real goal is quitting something (doomscrolling, snacking, smoking) â€” currently unserved by the app
FEATURE: A 'Replace a habit' task template: name the bad habit, tag its cue and its payoff (Duhigg's reward), then define the replacement routine as a normal recurring task. Completing the replacement logs an identity vote ('a person who handles stress without X'); the tile shows 'instead of: doomscrolling'. No shame stats, no failure tracking of the bad habit itself â€” consistent with the dark-pattern kill list.
COVERED: none (app is entirely build-oriented today) | RISK: medium â€” it's a new template concept, but it compiles down to an ordinary recurring task so downstream UI stays unchanged

## Investment phase (stored value loads the next trigger) [habit-science]
SRC: Hooked â€” Nir Eyal (Trigger â†’ Action â†’ Variable Reward â†’ Investment)
IDEA: The moment right after a reward is when users are most willing to put something in â€” and that small investment (data, setup, content) both increases the product's stored value and pre-loads the next trigger, closing the loop for tomorrow.
WHO: Users who fall off between sessions; evening planners who do better when tomorrow is pre-committed
FEATURE: After the 'All done today' celebration (peak moment), offer ONE micro-investment: 'Set tomorrow's first task' (drops it at the top of tomorrow's timeline) or 'One line: what worked today?' (a per-milestone reflection log that later renders on the milestone detail as a journal). Skippable in one tap, never blocks the celebration.
COVERED: partial (points/rewards/streaks are stored value, but nothing captures the post-reward moment to pre-load the next session's trigger) | RISK: low â€” one optional prompt at one existing moment; reflection log is append-only text

## Reminder fading (external â†’ internal trigger handoff) [habit-science]
SRC: Hooked â€” Nir Eyal (external vs internal triggers) + Lally et al. 2010 automaticity research
IDEA: Mature habits should be cued by context and internal states, not notifications; staying on push reminders forever means the habit binds to the phone buzz, which is fragile. As automaticity rises, deliberately weaning the external trigger transfers control to real-world cues.
WHO: Long-term users drowning in notifications; anyone whose goal is the habit becoming effortless rather than app-dependent
FEATURE: When a habit's automaticity estimate crosses a threshold (e.g. 90%+ completion for 6+ weeks in a stable slot), suggest downgrading its reminder one notch: full notification â†’ silent badge â†’ none, with copy 'This one looks automatic â€” want to let it fly without the ping?' One-tap revert if completions dip. Rare app that reduces its own notifications â€” strong trust signal aligned with the no-dark-patterns stance.
COVERED: none (reminders exist but only ever escalate â€” last-call alerts â€” never fade) | RISK: low â€” a suggestion on an existing setting; the risk is only in tuning the threshold conservatively

## Automaticity meter (asymptotic habit-strength curve) [habit-science]
SRC: Lally, van Jaarsveld, Potts & Wardle 2010, European Journal of Social Psychology (median 66 days, range 18â€“254, to reach automaticity plateau; single misses barely dent the curve)
IDEA: Habit strength grows along an asymptotic curve driven by repetitions-in-consistent-context, not a linear streak count â€” and a missed day reduces automaticity by less than half a point with quick recovery. Showing this curve reframes progress from fragile streaks to durable accumulation.
WHO: Perfectionists demoralized by broken streaks; patient users who want to know 'when does this get easy?'
FEATURE: Per-habit 'Autopilot' meter (0â€“100%) computed from an asymptotic function of repetitions weighted by context consistency (same slot/cue), rendered as a small filling ring on the milestone detail. Copy at meter milestones: 'Roughly two-thirds automatic â€” misses barely dent this now.' Directly reinforces the existing never-miss-twice banner with a scientific 'here's why one miss is fine'.
COVERED: none (streaks and heatmaps measure consistency, but nothing models habit STRENGTH or its forgiveness of single misses) | RISK: medium â€” the meter itself is simple, but the estimate must be honest about being an approximation or it invites over-trust

## Context stability score [habit-science]
SRC: Wendy Wood (Good Habits, Bad Habits; ~43% of daily behavior repeats in stable contexts) + Lally 2010 'consistent context' condition; validated by 2022 field study (context stability â†’ higher automaticity and goal attainment)
IDEA: Habits form measurably faster when the behavior repeats in the same time/place because the stable context does the remembering. Time-of-completion variance is a computable proxy the app already has data for.
WHO: Users who complete habits but at random times and wonder why it never feels automatic; timeline power-users
FEATURE: Per-habit consistency indicator computed from the variance of completion timestamps (and cue tag if set): 'steady slot' vs 'scattered'. For scattered habits with decent completion rates, one nudge: 'You do this anywhere between 7am and 10pm â€” anchoring it to one slot makes it automatic faster. Pin to timeline?' Feeds the automaticity meter's context weight.
COVERED: partial (global hourly-distribution chart exists in Stats; nothing per-habit, no variance score, no nudge into the timeline) | RISK: low â€” a computed label plus one contextual suggestion reusing the existing drag-drop timeline

## Fresh start effect / habit discontinuity windows [habit-science]
SRC: Dai, Milkman & Riis 2014, Management Science (temporal landmarks: +33% gym visits at week starts, spikes at month/year/birthday) + Verplanken's habit discontinuity hypothesis (life disruptions unfreeze old habits)
IDEA: Temporal landmarks open new 'mental accounting periods' that relegate past failures to a previous self, making people measurably more likely to start aspirational behaviors; big life changes (move, new job) similarly break old context cues, creating a window where new habits install cheaply.
WHO: Lapsed users returning after absence; procrastinating starters waiting for 'the right moment'; anyone post-streak-break
FEATURE: Three touchpoints: (1) the new-habit date picker highlights upcoming landmarks (Monday, 1st of month, user's birthday) with a 'fresh start' tag; (2) returning after 7+ days away triggers a warm 'New chapter' screen â€” archive-or-keep each stale habit, zero guilt, framed as a page turn; (3) optional 'life change?' prompt in settings (moved / new job / new term) that suggests re-anchoring habit cues since old contexts are gone.
COVERED: none (never-miss-twice handles single misses; nothing handles long lapses or leverages landmark dates) | RISK: low â€” decorations on an existing date picker plus one re-entry flow that replaces what would otherwise be a shame-inducing dead heatmap

## Implementation intentions with obstacle plans (if-then / WOOP) [habit-science]
SRC: Gollwitzer & Sheeran 2006 meta-analysis (94 studies, d = 0.65 on goal attainment); Oettingen's WOOP (mental contrasting + implementation intentions)
IDEA: Pre-deciding 'if situation X arises, then I do Y' delegates initiation to the environment and roughly doubles success odds versus bare intentions; the strongest variant pre-plans the OBSTACLE ('if I'm exhausted after work, then I do the 2-minute version') so the failure mode has a scripted response.
WHO: Users who plan well but crumble at friction points; evening-habit users whose willpower is depleted by execution time
FEATURE: Optional 'obstacle plan' on a task: pick a common obstacle chip (tired / no time / not home / low mood) + a pre-chosen response, defaulting to the task's existing 2-minute fallback. When the B=MAP miss-triage answer matches the obstacle, or the last-call alert fires, surface the plan verbatim: 'Your plan: if too tired â†’ 2-min version. Do that instead?'
COVERED: partial (timeline slots are when-plans and 2-min fallbacks are the perfect then-response, but no if-obstacle-then linkage exists and fallbacks aren't proactively offered at friction moments) | RISK: low â€” one collapsed optional row in the task form; the payoff surfaces only inside already-existing alerts

## Temptation bundling [habit-science]
SRC: Katy Milkman (2014 Management Science field study; How to Change) â€” restricting a 'want' (audiobooks) to co-occur with a 'should' (gym) raised gym attendance ~29-51%
IDEA: Pairing an indulgence exclusively with an avoided behavior imports immediate gratification into a delayed-reward task, solving the present-bias problem that makes 'good' habits unrewarding in the moment.
WHO: Users with dreaded, effortful tasks (exercise, chores, study grinds); reward-driven users for whom points aren't visceral enough
FEATURE: Optional 'pair with a treat' field per task ('only: podcast / Netflix episode / fancy coffee'). The treat renders as a small pill on the task tile and, crucially, on the existing stopwatch timer screen ('â–¶ your podcast goes with this'). Complements the self-defined rewards system: rewards are earn-and-claim, bundles are during-the-task fuel.
COVERED: none (pointsâ†’rewards is delayed gratification; nothing addresses in-the-moment reward pairing) | RISK: low â€” a single optional text field surfaced as a pill; no logic, no enforcement, purely a commitment the user makes visible

## Ubiquitous Quick Capture [time-systems]
SRC: Getting Things Done â€” David Allen
IDEA: Get every open loop out of your head into one trusted inbox within seconds; clarifying (schedule, milestone, points) happens later, so capture friction must be near zero. Closes Zeigarnik-style open loops that otherwise leak attention.
WHO: Scattered / ADHD-leaning users; anyone who abandons trackers because adding a task takes six taps and four decisions.
FEATURE: One-field quick capture (Android home-screen widget, share sheet, and a lightning-add on Home) that accepts just a title and dumps it into the existing auto-seeded Inbox milestone with zero other required fields; a small Inbox badge nudges later triage.
COVERED: partial â€” quick-add from Home pre-selects the last-used milestone, and an Inbox milestone is auto-seeded, but quick-add still opens the full task form (recurrence, milestone, duration); no widget/share-sheet or true zero-decision path | RISK: low â€” it removes fields and decisions rather than adding concepts

## Weekly Review [time-systems]
SRC: Getting Things Done â€” David Allen
IDEA: A recurring ritual â€” empty the inbox, prune stale commitments, preview the coming week â€” is what keeps the system trusted; without it lists rot and users churn. Allen calls it the 'critical success factor' of GTD.
WHO: Committed users whose task lists have gone stale; anyone juggling 3+ milestones.
FEATURE: Optional guided Sunday flow: triage Inbox captures, surface tasks untouched for N weeks (reschedule / shelve / delete), glance at each milestone's week, preview next week's timeline. Completing the review can be what opens the existing weekly chest, piggybacking on an already-built reward loop.
COVERED: none â€” the weekly chest exists but is a reward drop, not a review; nothing surfaces stale tasks or drives inbox triage | RISK: medium â€” a multi-step wizard; must be fully skippable, never a quest requirement, and each step one screen

## Contexts (do-able-now filters) [time-systems]
SRC: Getting Things Done â€” David Allen
IDEA: Tag next actions by the place/tool/state they require (@home, @errands, @computer) so at any moment you only see what is actually doable, cutting choice overload â€” the exact to-do-list failure mode the timeboxing research describes.
WHO: Users mixing personal, work, and errand tasks; mobile users deciding 'what can I do in the next 20 minutes from here'.
FEATURE: Optional flat freeform tags on tasks plus filter chips on Up Next and the timeline; the whole feature stays invisible until the user creates their first tag, so non-taggers never see it.
COVERED: none â€” effort tags exist only as a backlog idea in project notes | RISK: medium â€” tags are safe as an optional layer, but tag-management UI bloats fast; cap at flat tags, no hierarchies or colors

## Someday/Maybe shelf [time-systems]
SRC: Getting Things Done â€” David Allen
IDEA: A sanctioned parking lot for aspirations you're not acting on keeps the active list honest without forcing deletion; shelved items get reconsidered at review time instead of generating daily guilt.
WHO: Idea hoarders; users with 15 milestones and quiet guilt about 12 of them (guilt reduction aligns with the dark-pattern kill list).
FEATURE: A 'Shelved' state for milestones and tasks: hidden from Up Next, quests, streak math, and the timeline; a quiet 'Someday' section at the bottom of the Milestones tab; the weekly review offers to shelve stale items and revive shelved ones.
COVERED: none | RISK: low â€” one extra state that subtracts on-screen clutter rather than adding it

## Timeboxing / calendar migration [time-systems]
SRC: Marc Zao-Sanders, HBR 2018 (ranked #1 of 100 hacks in his survey); Cal Newport's time-block planning in Deep Work
IDEA: Moving to-dos onto a calendar as committed time blocks beats list-checking because it adds the missing context of available time plus a commitment device; lists alone bias us toward easy, urgent items.
WHO: Overplanners and chronic underestimators; people whose 30-item list never maps to their actual 6 free hours.
FEATURE: The drag-and-drop day timeline IS this already â€” add the ritual around it: a 'Plan my day' sweep with an unscheduled-tasks tray above the timeline (drag to place, or auto-place by duration), plus a gentle end-of-block 'did this happen?' reconciliation that feeds plan-vs-actual stats.
COVERED: partial â€” Google-Calendar-style day timeline, task durations, and stack-derived time slots exist; missing the planning ritual, the unscheduled tray, and plan-vs-actual reconciliation | RISK: low â€” builds directly on an existing surface, no new concepts

## Deep Work blocks + focus budget [time-systems]
SRC: Deep Work â€” Cal Newport
IDEA: Cognitively demanding work needs long, distraction-free blocks, and keeping a visible weekly tally of deep hours (Newport's scoreboard) trains you to protect them; deep vs shallow is the key classification.
WHO: Knowledge workers, students, makers with big creative milestones ('become a writer' identity users).
FEATURE: Optional 'deep' flag on a task or timeline block; starting its timer offers Do-Not-Disturb and swaps to a minimal full-screen focus view; Stats gains a 'Deep hours this week' ring against a self-set weekly budget (a target, never a punishment).
COVERED: partial â€” per-task stopwatch and time-invested stats exist; no deep/shallow distinction, weekly budget, or focus screen | RISK: medium â€” a second timer mode and a new flag; keep it to one toggle on the existing timer and hide the budget until a deep task exists

## Shutdown ritual [time-systems]
SRC: Deep Work â€” Cal Newport
IDEA: An explicit end-of-day routine â€” review incompletes, park each with a plan, then declare 'shutdown complete' â€” closes open loops so the mind actually rests; backed by the same if-then planning evidence (Gollwitzer & Sheeran meta-analysis, dâ‰ˆ0.65, that parked plans stop intruding).
WHO: Ruminators; users who reopen the app at 11pm anxious about leftovers; streak-anxious users.
FEATURE: Optional evening 'Close the day' flow: sweep remaining Up Next items (move to tomorrow / skip / mark missed â€” reusing the existing skip-vs-missed honesty), preview tomorrow's timeline, then a satisfying 'Day closed' stamp. Doubles as the natural host for Ivy Lee planning.
COVERED: partial â€” the 'All done today' celebration and skip/missed states exist, but there is no ritual for un-done days, which is exactly when closure matters most | RISK: low â€” one optional evening notification plus a 3-step sheet built from existing actions

## Pomodoro [time-systems]
SRC: The Pomodoro Technique â€” Francesco Cirillo
IDEA: Fixed 25-minute sprints with 5-minute breaks make starting cheap, externalize the clock, and make interruptions countable; the pomodoro also becomes a humane estimation unit for tasks.
WHO: Procrastinators and ADHD-style users who struggle to start; chronic task-switchers.
FEATURE: A mode on the existing per-task stopwatch: choose 'Pomodoro' to get interval cycling, break prompts, an interruption tally, and an 'N pomodoros today' count; pomodoros can also appear as an alternative daily-quest type for timer-oriented users.
COVERED: partial â€” stopwatch-lite per task exists; no intervals, breaks, or interruption tracking | RISK: low â€” hides entirely behind the timer users already have; plain stopwatch stays the default

## Eat That Frog / MIT [time-systems]
SRC: Eat That Frog! â€” Brian Tracy
IDEA: Name the single most important (usually most aversive) task and do it first; the day counts as a win even if nothing else ships, and everything after the frog feels easier. Directly counters the easy-task bias of raw lists.
WHO: Avoiders who fill days with cheap wins while the scary important task rolls over for weeks.
FEATURE: Optional morning prompt to crown one task the day's 'frog'; it becomes a pinned hero card atop Up Next with distinct styling, and finishing it before a user-chosen cutoff triggers extra celebration and a small capped bonus (consistent with the bonus-cap rule).
COVERED: none | RISK: low â€” one flag and one card; skipping the prompt costs nothing

## Ivy Lee method [time-systems]
SRC: Ivy Lee (1918, via the Charles Schwab / Bethlehem Steel story; popularized by James Clear)
IDEA: Each evening write exactly six tasks for tomorrow in strict priority order; work them in order and roll unfinished ones forward. The hard cap of six plus forced ranking defeats overload and decision fatigue at the moment of action.
WHO: List-maximalists with 30-item days; users who want ordering discipline without full timeboxing.
FEATURE: A step inside the shutdown ritual: 'Pick tomorrow's six' â€” a reorderable list capped at 6 that overrides tomorrow's Up Next ordering; unfinished items auto-carry into slot 1 the next evening.
COVERED: none â€” Up Next ordering is schedule-derived, not user-ranked | RISK: medium â€” introduces a second ordering concept for Up Next; ship it as one selectable 'day-plan style' rather than a standalone feature

## 1-3-5 rule [time-systems]
SRC: 1-3-5 rule (popularized by The Muse / Alex Cavoulacos)
IDEA: Plan each day as 1 big + 3 medium + 5 small tasks â€” a realistic portfolio shape that guarantees both meaningful progress and quick wins, and implicitly forces size-honesty about tasks.
WHO: People who find 'six ranked tasks' or full timeboxing too rigid; variety-seekers who need guaranteed small wins to keep momentum.
FEATURE: An alternative day-plan template: big/medium/small size on tasks and a planner showing 1/3/5 slots to fill. Deliberately overlaps Frog and Ivy Lee â€” ship all three as ONE 'Daily plan style' picker (None / Frog / Ivy Six / 1-3-5) so the app gains one concept with three skins, not three features.
COVERED: none | RISK: medium alone, low if unified into the single day-plan-style picker; the size tag can double as the backlog 'effort tag' idea

## The ONE Thing (focusing question + goal cascade) [time-systems]
SRC: The ONE Thing â€” Gary Keller & Jay Papasan
IDEA: Repeatedly ask 'What's the ONE thing I can do such that everything else becomes easier or unnecessary?' and cascade goals from someday down to right now; leverage tasks act as lead dominoes for a whole milestone.
WHO: Goal-driven users with big identity milestones; people overwhelmed by parallel goals who need permission to ignore most of the list.
FEATURE: Per-milestone weekly spotlight: milestone detail asks the focusing question once a week, and the chosen task gets a 'leverage' badge plus top placement in that milestone and in Up Next. Distinct from the daily frog: this is per-milestone and weekly, connecting the built identity framing to daily action.
COVERED: partial â€” identity-based milestones supply the top of the cascade ('become a writer'); no leverage/spotlight mechanism links them to today's task choice | RISK: low-medium â€” overlaps the frog conceptually; keep copy clearly weekly/per-milestone or fold it into the milestone detail screen only

## 12-Week Year execution scoring [time-systems]
SRC: The 12 Week Year â€” Brian Moran & Michael Lennington
IDEA: Replace annual goals with 12-week cycles scored weekly on execution (target â‰¥85% of planned actions completed); the short horizon creates urgency and the score measures process fidelity, not outcomes, which is exactly what a habit tracker can compute honestly.
WHO: Goal-setters whose milestones drift past target dates; data-lovers who live in the Stats tab.
FEATURE: Optional 'sprint' on a milestone: pick a 12-week window and the app computes weekly execution % from already-tracked scheduled-vs-completed data, rendered as a 12-cell scorecard strip on milestone detail; â‰¥85% weeks earn chest/badge celebration, low weeks show neutrally with zero punishment (kill-list compliant).
COVERED: partial â€” milestones have target dates and all scheduled/completed/skip data exists; no cycles, weekly execution %, or scorecard | RISK: medium â€” a new derived metric to explain, though it is purely computed from existing behavior and lives only on milestones that opt in

## Energy management / ultradian oscillation [time-systems]
SRC: The Power of Full Engagement â€” Jim Loehr & Tony Schwartz
IDEA: Manage energy, not time: work in ~90-minute waves with deliberate recovery, and match demanding tasks to your personal peak-energy windows; renewal is framed as performance, not slacking.
WHO: Burnout-prone users; people whose streaks die from overload and exhaustion rather than forgetfulness.
FEATURE: Two thin layers: (a) a peak-hours insight mined from the existing hourly-distribution stats that becomes a timeline suggestion ('you finish hard tasks best 8â€“10am â€” schedule your deep block there?') plus an optional high/low energy tag; (b) first-class 'recovery' tasks (walk, nap, stretch) that award points and are skip-friendly, legitimizing rest inside the reward economy.
COVERED: partial â€” the hourly-distribution chart exists but is descriptive only; skip-vs-missed handles rest honesty but nothing rewards renewal or feeds timing back into planning | RISK: medium â€” energy tags add a new axis; keep it to two values, auto-suggest only, and never block scheduling

## Self-Determination Theory (autonomy / competence / relatedness) [motivation-psych]
SRC: Deci & Ryan (2000); mHealth gamification SDT studies (JMIR 2021)
IDEA: Motivation sustains when three innate needs are fed: autonomy (I chose this), competence (I'm getting better), relatedness (someone sees me). Gamification that uses points as controlling levers ('do X to earn Y') can undermine intrinsic motivation; informational feedback strengthens it.
WHO: Everyone long-term; especially users who abandon apps once the novelty of points wears off (extrinsic-reward burnout).
FEATURE: Two moves: (1) an SDT audit of existing copy â€” frame points/levels as feedback about progress, never as the reason to act ('47 votes for Writer You' vs 'earn 10 pts'); (2) add the missing relatedness leg as an optional layer: a shareable weekly recap card (image export, no backend) so one chosen person can see and cheer progress.
COVERED: partial â€” autonomy is strong (self-defined rewards, optional layers, self-chosen milestones) and competence is strong (levels, Goldilocks coach, identity votes); relatedness is entirely absent | RISK: low â€” recap-card export is one share button; the copy audit adds no UI

## Flow theory (challengeâ€“skill balance) [motivation-psych]
SRC: Csikszentmihalyi, 'Flow' (1990)
IDEA: Deep engagement happens when task difficulty sits just above current skill â€” too easy is boring, too hard is anxious. Apps induce flow by removing distraction, giving clear goals, and giving immediate feedback while calibrating difficulty.
WHO: Deep-work users and students doing long timed sessions; also ADHD users who need help staying in a started task.
FEATURE: 'Focus mode': full-screen distraction-free view of the running task stopwatch, then a one-tap post-session rating ('too easy / just right / too hard') that feeds the existing Goldilocks difficulty coach so its suggestions come from real session data instead of completion counts alone.
COVERED: partial â€” Goldilocks coach, per-task durations, and stopwatch exist; there is no distraction-free session mode and no perceived-difficulty signal back into the coach | RISK: low â€” reuses the timer; one optional screen and one rating chip

## Implementation intentions (if-then planning) [motivation-psych]
SRC: Gollwitzer (1999); Gollwitzer & Sheeran 2006 meta-analysis (94 studies, d â‰ˆ 0.65)
IDEA: Pre-deciding 'if situation X, then I do Y' hands behavior initiation to environmental cues instead of in-the-moment willpower. Effect size on goal attainment is medium-to-large â€” one of the best-evidenced techniques in the whole space.
WHO: Planners and anyone whose habits fail at the initiation step ('I meant to but the moment passed').
FEATURE: Optional 'if-then cue' field on a task â€” both positive cues ('If I finish lunch, then I write 200 words') and coping cues ('If I feel like skipping, then I do the 2-minute version'). The cue text becomes the reminder notification body, so the notification fires the exact if-then the user authored.
COVERED: partial â€” habit stacking ('after X do Y') and the timeline's time-slots ARE implementation intentions in disguise; missing are obstacle/coping if-thens and cue-worded reminders | RISK: low â€” one optional text field that upgrades notification copy

## Mental contrasting / WOOP (Wishâ€“Outcomeâ€“Obstacleâ€“Plan) [motivation-psych]
SRC: Oettingen, 'Rethinking Positive Thinking' (2014); MCII RCTs incl. VA MOVE! weight program
IDEA: Vividly imagining the desired outcome AND then the concrete inner obstacle (mental contrasting), then attaching an if-then plan to that obstacle, outperforms pure positive visualization. It pre-loads the exact failure mode with a response.
WHO: Users with aspirational milestones who repeatedly stall on the same obstacle (the 'become a writer' identity crowd).
FEATURE: Optional 60-second WOOP wizard offered when creating a milestone (fully skippable): wish â†’ best outcome â†’ biggest inner obstacle â†’ plan. The plan auto-populates the task's if-then cue; the named obstacle is resurfaced gently in the miss check-in ('Was it the obstacle you predicted?').
COVERED: none â€” milestones capture name/description/target date but no outcome visualization or obstacle plan | RISK: medium â€” a 4-step wizard is real surface area; must stay a skippable 'Plan deeper?' link, never a gate on milestone creation

## Fresh-start effect (temporal landmarks) [motivation-psych]
SRC: Dai, Milkman & Riis, Management Science (2014)
IDEA: Aspirational behavior spikes after temporal landmarks (new week, month, year, birthday, semester) because the landmark psychologically separates people from their past imperfect self. Apps can manufacture these clean-slate moments.
WHO: Lapsed users and anyone carrying shame about an abandoned milestone; also the New-Year's-resolution personality.
FEATURE: 'Fresh start' moments: on Mondays / 1st of month / user's birthday / after a streak break, a banner offers 'New month, new chapter â€” revive a paused milestone or start fresh,' with one-tap revive of dormant milestones. After a break, next Monday is explicitly framed as the restart line rather than the broken streak being the story.
COVERED: none â€” never-miss-twice covers day-after recovery, but nothing leverages calendar landmarks or offers a clean-slate revival flow | RISK: low â€” banner + notification triggered by dates; no new concepts for the user to learn

## Temptation bundling [motivation-psych]
SRC: Milkman, Minson & Volpp, Management Science (2014) â€” gym-locked audiobooks, +51% gym visits; 2020 field experiment follow-up
IDEA: Pair a 'want' (guilty pleasure) with a 'should' (avoided task) and allow the want ONLY during the should. The contingent access â€” not the treat itself â€” creates craving for the habit.
WHO: Users with dreaded recurring tasks (exercise, chores, admin) who currently rely on willpower; complements delayed point-rewards with an in-the-moment pull.
FEATURE: Optional 'bundle a treat' field on a task ('podcast only while running', 'fancy coffee only while doing weekly review'). The treat shows on the task tile and in the reminder ('Your podcast is waiting â€” it only plays during this'), and starting the stopwatch is framed as unlocking the treat.
COVERED: none â€” points-to-rewards is delayed exchange, not contingent simultaneous pairing; nothing links a pleasure to the act itself | RISK: low â€” one optional text field plus copy changes; the app never enforces the rule, the user does

## Commitment devices (soft / self-authored) [motivation-psych]
SRC: stickK (Karlan & Ayres, Yale); Beeminder; Kahneman & Tversky loss aversion
IDEA: Precommitting with something at stake dramatically raises follow-through (money-stake platforms report 2.8â€“3.4x success on staked goals). But hard loss-aversion stakes are a guilt mechanic â€” the ethical residue is the precommitment ritual itself: a written, witnessed pledge raises follow-through without punishment.
WHO: High-conscientiousness users who ask for teeth ('make me do it'); Beeminder-refugees who want stakes without the payment processor.
FEATURE: Optional 'commitment card' on a milestone: user writes a pledge in their own words, optionally names a witness (share the card image to them), and picks their own outside-the-app consequence. Kaizn only records and periodically resurfaces the pledge ('You wrote this on May 3'), never enforces, charges, or shames.
COVERED: none | RISK: high â€” precommitment framing drifts toward guilt easily; must be user-authored, resurfaced neutrally, and deletable without ceremony to respect the kill list

## Goal-gradient effect [motivation-psych]
SRC: Hull (1932); Kivetz, Urminsky & Zheng, JMR (2006) â€” cafÃ© reward-card acceleration
IDEA: Effort accelerates as perceived distance to a goal shrinks â€” coffee-card customers buy faster near the free cup. Making proximity visible converts the last stretch into the most motivating stretch.
WHO: Reward-oriented users and anyone with long point-thresholds where the middle feels flat.
FEATURE: Progress rings on reward cards, and when a reward is within ~15% of the balance, it surfaces on Home with 'almost there â€” 2 more workouts' translated into concrete task counts rather than abstract points. Same treatment for milestone target dates ('3 tasks from done').
COVERED: partial â€” 'X pts to next reward' text preview and a claimable-rewards Home section exist; no visual gradient, no proximity-triggered surfacing, no points-to-tasks translation | RISK: low â€” visual layer over data the app already computes

## Endowed progress effect (honest variant) [motivation-psych]
SRC: Nunes & DrÃ¨ze, JCR (2006) â€” 10-stamp card vs 12-stamp with 2 free; faster completion (10 vs 15 days median)
IDEA: A goal framed as 'already begun' gets completed more often and faster than one framed as 'not yet started.' The classic version uses fake stamps; the honest version credits real preparatory work as visible progress.
WHO: New users at onboarding and anyone starting an intimidating milestone â€” the blank-slate dropout crowd.
FEATURE: Milestones render as 'step 1 of N complete' the moment the plan is made â€” creating the milestone, defining its first tasks, and doing the 2-minute version each count as real, labeled progress ('Plan made âœ“'). New reward progress bars start pre-filled with the user's existing point balance instead of at zero.
COVERED: none â€” no progress framing exists for setup work; reward previews show remaining points but not endowed framing | RISK: low â€” pure framing/rendering change; caveat: only credit real actions, never phantom progress, to stay honest

## Variable rewards, ethically bounded [motivation-psych]
SRC: Skinner variable-ratio schedules; Eyal 'Hooked' (2014) critiqued via SDT undermining research
IDEA: Unpredictable rewards produce the strongest engagement of any reinforcement schedule â€” which is exactly why they're the core dark pattern of slot machines. The ethical line: keep earnings deterministic and confine variability to celebration garnish that has no economy value.
WHO: Novelty-seeking users (incl. ADHD) for whom identical confetti every day habituates to invisible.
FEATURE: Rare surprise cosmetic-only drops after completions â€” a new confetti style, tile theme, or celebration animation â€” with points untouched and rules disclosed in settings ('surprises are cosmetic, never points'). Weekly chest stays the predictable anchor; drops are the spice.
COVERED: partial â€” weekly chest and confetti cosmetics exist and bonuses are already capped; completion celebration itself is currently uniform | RISK: low â€” extends the existing cosmetics system; disclosure keeps it kill-list-clean

## Social accountability (witness, not competitor) [motivation-psych]
SRC: Accountability-partner literature (Karlan's Beeminder-adjacent field work; Focusmate model); Dai/Milkman commitment research
IDEA: Telling a specific person your goal and reporting to them measurably raises follow-through â€” the mechanism is a promised appointment with a witness, not competition. Distinct from leaderboards, which the kill list correctly bans.
WHO: Extrinsically-wired and relatedness-driven users; people whose habits survive only when someone is watching.
FEATURE: Phase 1 (no backend): 'send my Sunday recap' â€” a scheduled nudge to share the weekly recap card to one self-chosen person via the OS share sheet. Phase 2: a read-only live link for a single milestone's progress that a partner can open. Never shows the partner's data back; there is no comparison surface.
COVERED: none â€” the app is fully single-player today | RISK: medium â€” phase 1 is trivial (image export + share intent); phase 2 needs hosting/backend and is where scope creep lives

## Body doubling (parallel presence for task initiation) [motivation-psych]
SRC: ADHD clinical/community practice; Focusmate; 2024 neurodivergent survey (~85% report initiation help; experimental evidence still mixed)
IDEA: Working with another person merely present â€” not collaborating â€” externalizes executive function enough to get ADHD brains past task initiation. Evidence is community-strong / trial-weak, so ship it cheap and optional rather than as a pillar.
WHO: ADHD and executive-dysfunction users whose bottleneck is starting, not knowing or wanting.
FEATURE: 'Start together': a deep-link invite that starts matching stopwatch sessions on two phones for the same duration, with a check-in prompt at the end. Minimal fallback version: tag a task 'with Priya' so the reminder says 'Priya is expecting you at 7' using data the user typed themselves.
COVERED: none â€” timer is solo; no notion of another person exists anywhere | RISK: high for synced sessions (needs realtime plumbing); low for the tag-a-person fallback, which is just reminder copy

## Self-compassion after lapses (defusing the what-the-hell effect) [motivation-psych]
SRC: Neff (2003); Wohl, Pychyl & Bennett (2010) â€” self-forgiveness for procrastinating reduced future procrastination; abstinence-violation-effect literature
IDEA: Shame after a lapse fuels avoidance and the 'what-the-hell' spiral (one miss â†’ abandon everything); self-forgiveness cuts the negative affect that drives avoidance, so lapsers return sooner. The intervention moment is immediately after a recorded failure.
WHO: Perfectionists and all-or-nothing users â€” the segment most likely to delete a habit app after one bad week.
FEATURE: When a task is marked missed, an optional one-tap check-in: 'what got in the way?' chips (tired / no time / forgot / too hard) plus a genuinely kind line ('One miss is data, not a verdict â€” tomorrow's the one that counts'). Tags feed a Stats obstacle view and suggest WOOP/if-then plans when one tag repeats 3+ times.
COVERED: partial â€” never-miss-twice banner, skip-vs-missed honesty, and the no-guilt kill list are exactly this philosophy; missing is the post-miss check-in, obstacle tagging, and the tag-to-plan loop | RISK: low â€” one optional chip row on an existing flow; the loop into suggestions can ship later

## Body doubling (ambient accountability presence) [adhd-neurodivergent]
SRC: How to ADHD (Jessica McCabe); ADDA; Focusmate
IDEA: Working in the (physical or virtual) presence of another person acts as an external anchor that supplies the activation energy ADHD brains lack for task initiation. The double does nothing â€” social facilitation and 'someone expects me to show up' regulate attention.
WHO: Users who can plan fine but cannot start; people who work alone and drift off-task within minutes.
FEATURE: A 'Focus Room' full-screen session mode: pick one task, state your intention ('I will draft the intro'), timer runs with optional ambient soundscape, and a gentle end-of-session check-in ('Did the thing happen?'). Phase 2: schedule a session with a real friend via shared link â€” never fake companions, per the dark-pattern kill list.
COVERED: partial (per-task stopwatch timer exists, but no full-screen single-task session mode, no intention statement, no end-of-session check-in) | RISK: low for solo Focus Room (it's just a skin over the existing timer); medium if social sessions are added (accounts, invites, scheduling)

## Visual countdown timers (make time physical) [adhd-neurodivergent]
SRC: Time Timer; ADDitude; Llama Life
IDEA: ADHD time blindness means duration cannot be felt internally; a shrinking colored disk externalizes remaining time into something watchable, turning '20 minutes' from abstraction into perception.
WHO: Time-blind users who lose hours in tasks or can't gauge 'how long is left'; also helps kids/teens and Pomodoro users.
FEATURE: Add a countdown mode to the existing per-task timer that renders a Time-Timer-style shrinking pie sized from the task's stored duration, available full-screen. Toggle between stopwatch (count-up) and countdown per task; countdown is the default when a duration exists.
COVERED: partial (task durations and a count-up stopwatch exist; no countdown, no visual disk representation) | RISK: low â€” reuses existing duration + timer plumbing, purely presentational

## 5-4-3-2-1 launch countdown [adhd-neurodivergent]
SRC: Mel Robbins, The 5 Second Rule; ADHD coaching adaptations (Untapped Brilliance)
IDEA: Counting backward 5-4-3-2-1 then acting immediately occupies working memory so the brain can't generate objections, and engages the prefrontal cortex before the freeze response wins. It converts 'start the task' into a 5-second ritual.
WHO: Procrastinators and freeze-response users staring at a task they know they should start.
FEATURE: An optional 'LAUNCH' button on any task tile / Focus Room: tap â†’ animated 5-4-3-2-1 countdown with haptics â†’ timer auto-starts and the task is marked 'started'. A settings toggle enables it globally; never shown unless opted in.
COVERED: none | RISK: low â€” one animation + auto-start of the existing timer

## Defined first action ('just open the file') [adhd-neurodivergent]
SRC: ADHD task-initiation coaching (ADDitude patterns; GTD next-action)
IDEA: Task names describe outcomes ('write report'), but initiation needs a physical first motion ('open the doc, type one sentence'). Pre-deciding the first action removes the in-the-moment planning step that triggers paralysis.
WHO: Users with tasks that sit untouched for days because the entry point is undefined; complements the 2-minute fallback for tasks that can't be shrunk.
FEATURE: Optional 'first step' text field on a task ('Open Figma file'). When the task is launched (Focus Room / LAUNCH button), the first step is shown instead of the task name for the first 2 minutes. Distinct from the existing fallback version: fallback replaces the task; first-step is how you enter the full task.
COVERED: partial (2-minute-rule fallback versions exist â€” a downsized alternative task â€” but there is no 'entry point' prompt on the full task) | RISK: low â€” one nullable text column + display logic; invisible if unused

## Dopamine menu (dopamenu) [adhd-neurodivergent]
SRC: Jessica McCabe / How to ADHD (2020); ADDitude 5-step dopamenu; CHADD
IDEA: A pre-curated menu of healthy stimulation activities (appetizers = 5-min boosts, mains = longer restorative activities) removes the double decision load ('what should I do?' + 'how do I start?') when the brain is understimulated and about to doomscroll.
WHO: Users who stall between tasks, reach for their phone when bored, or need a structured break that doesn't derail the day.
FEATURE: A 'Menu' list the user curates (name + emoji + duration tier: appetizer/main/dessert). Surfaced in three places: a 'Need a boost?' card when nothing is due, a break suggestion between timeline blocks, and after a heavy task completes. Items are activities, not point-rewards â€” sits beside, not inside, the existing rewards system.
COVERED: none (rewards are point-gated purchases; this is free, instant, stimulation-focused) | RISK: medium â€” a new user-facing concept and list to maintain, though fully optional and self-contained

## Choice reduction / 'pick for me' (task paralysis breaker) [adhd-neurodivergent]
SRC: Talkspace / Cleveland Clinic ADHD-paralysis guidance; random task picker tools
IDEA: An overwhelming list triggers a freeze response; reducing visible options to one externalizes prioritization and breaks decision paralysis. Letting the app choose removes the meta-decision entirely.
WHO: Users who open the app, see 12 due tasks, feel the wall of dread, and close it.
FEATURE: A 'Just pick one' button atop Up Next: weighted-random selection among due tasks (bias toward shortest duration or lowest effort), presented alone full-screen with Start / 'not this one, next' (max 2 re-rolls to prevent shuffle-scrolling). Pairs naturally with the Focus Room.
COVERED: none (Up Next orders tasks but always shows the full list) | RISK: low â€” one button and a selection heuristic over data that already exists

## Energy / spoons-based planning [adhd-neurodivergent]
SRC: Spoon theory (Christine Miserandino), adapted for ADHD by Neurodivergent Insights, ADDA, Tiimo
IDEA: ADHD energy is spikier and more depletable than time; tagging tasks by energy cost instead of only duration lets planning match capacity, preventing the shame spiral of scheduling a heavy day the body can't execute.
WHO: AuDHD and burnout-prone users; anyone whose good days and bad days differ wildly in capacity.
FEATURE: Optional per-task effort tag (light / medium / heavy â€” 1-3 dots). A 'Low battery' toggle on Home filters Up Next to light tasks only and mutes quest pressure for the day. No mandatory daily check-in; the toggle IS the check-in.
COVERED: none (effort tags are on the project's own polish wishlist but unbuilt) | RISK: medium â€” a second planning dimension risks conceptual clutter, mitigated by making the tag optional and the filter a single toggle

## Projected finish time + time-estimate calibration [adhd-neurodivergent]
SRC: Llama Life (projected finish time, total list time); time-blindness research (ADDA, Time Timer)
IDEA: Time-blind users cannot sum durations mentally; showing 'if you start now you'll finish at 6:40 PM' makes the day's remaining load concrete, and comparing planned vs actual duration after each timed session trains estimation over time.
WHO: Chronic under-estimators who plan 8 hours of tasks into 3; users who avoid starting because 'no idea how long this takes'.
FEATURE: (a) Header line on Up Next: total remaining duration + projected finish clock time, recomputed live. (b) After a timed session ends, a one-line 'planned 30m, took 48m' note, and a per-task average shown in the duration picker next time ('usually takes ~45m').
COVERED: partial (durations, day timeline with slots, and time-invested stats exist; no forward projection and no planned-vs-actual feedback loop) | RISK: low â€” arithmetic over existing duration + timer-session data

## Hyperfocus exit ramps (over-run nudges + next-step bridge) [adhd-neurodivergent]
SRC: Tiimo, ADDA, Brain Brakes hyperfocus guidance
IDEA: Hyperfocus makes people miss meals, meetings, and bedtime; a gentle escalating cue when a session exceeds its planned length, plus a pre-written 'what comes next' bridge, lets the brain disengage without the cliff-edge of a hard alarm.
WHO: Hyperfocusers who blow through the rest of their timeline once absorbed; complements last-call alerts, which fire on deadlines, not on session length.
FEATURE: When an active timer passes ~125% of the task's duration, a soft haptic notification: 'You planned 30m â€” 50m in. Wrap up, or +15 more?' with the next timeline item shown as the bridge ('Up next: stretch, 5m'). Snoozable; never shaming; off by default per task type.
COVERED: partial (last-call alerts and the timeline exist; nothing watches a running session against its planned duration) | RISK: low â€” a threshold check on the already-running timer plus one notification

## Guided routine autopilot (chain runner) [adhd-neurodivergent]
SRC: Routinery; RoutineFlow
IDEA: Executing a routine step-by-step with a per-step timer and auto-advance removes the transition decision between steps â€” the app carries the sequence so working memory doesn't have to, turning a morning routine into follow-the-leader.
WHO: Users who lose 40 minutes between shower and breakfast; anyone whose habit chains exist on paper but fall apart between steps.
FEATURE: A 'Play' button on an existing habit-stack chain: full-screen one-step-at-a-time runner with countdown per step, chime + auto-advance to the next task in the queue, skip/extend controls, and a chain-complete celebration. Purely a runtime view over chains that already exist.
COVERED: partial (habit stacking with task queues and derived time slots is built; there is no guided sequential execution mode) | RISK: low-medium â€” new screen with real state (pause/resume, interruptions), but zero new data model

## Frictionless brain dump (externalized working memory) [adhd-neurodivergent]
SRC: ADDitude (working memory & executive function); GTD capture; Executive Function Toolkit
IDEA: ADHD working memory is a leaky whiteboard; a zero-friction capture inbox that separates capture from organization ('dump first, sort later') frees cognitive resources and stops the 'I'll forget this' anxiety loop.
WHO: Users with racing thoughts mid-task; anyone who loses ideas because the add-task form asks too many questions.
FEATURE: A one-tap capture: text field only, dumps raw lines into the existing Inbox milestone with no recurrence/points/duration questions. Android quick-settings tile or home-screen widget + persistent notification action. A soft 'Inbox: 6 items to sort' chip on Home (optionally a daily quest) prompts later triage.
COVERED: partial (Inbox milestone auto-seeds and quick-add exists, but the task form is multi-field â€” capture is not friction-free and there is no outside-the-app entry point) | RISK: low â€” writes to existing tables; the widget is the only platform work

## Gentle re-entry after abandonment (comeback flow) [adhd-neurodivergent]
SRC: Finch (pet never dies, no guilt for absence); Fabulous ('Your story isn't finishedâ€¦'); fresh-start effect (Milkman et al.)
IDEA: Returning to a habit app after weeks means facing a wall of red misses, which triggers shame and immediate re-abandonment; a warm welcome-back that wipes the slate and shrinks scope converts the return into a fresh-start moment instead of an audit.
WHO: Every lapsed user â€” the single largest silent cohort of any habit app; ADHD users especially, whose interest cycles naturally.
FEATURE: Detect a gap of 7+ days on open: instead of Home, show a 'Welcome back' screen â€” no missed-task list, no broken-streak framing. Offers: archive-or-keep sweep of stale tasks (bulk, 2 taps), pick 1-3 habits to restart this week, and a 'Comeback' badge that celebrates returning rather than mourning the gap. Missed history is quietly marked as a 'break', not a wall of red on the heatmap.
COVERED: partial (never-miss-twice banner handles a 1-day lapse and skip-vs-missed handles honesty, but a multi-week gap currently lands the user on a graveyard of overdue tasks) | RISK: medium â€” the flow itself is simple, but bulk-archiving and 'break' semantics touch streak, heatmap, and stats logic

## Novelty rotation (variant shuffle for stale habits) [adhd-neurodivergent]
SRC: ADHD novelty-seeking literature (Chennai Minds, ADDitude patterns); Habitica's freshness effect
IDEA: ADHD dopamine systems disengage from repetition before a habit automates; rotating between pre-approved variants of the same habit ('exercise' = run / yoga / cycle) supplies novelty inside boundaries, so the identity vote continues even when the specific activity gets boring.
WHO: Serial restarters who nail a habit for 3 weeks then drop it out of boredom; novelty-seekers who abandon rigid routines.
FEATURE: Optional 'variants' list on a recurring task; each due day the tile shows one variant ('Today: yoga') with a shuffle icon to re-roll. All variants count identically toward the habit's streak and identity votes. Optionally a monthly 'freshen up?' nudge on habits completed 20+ times whose completion rate is declining.
COVERED: none (daily quests and weekly chest add system-level novelty, but individual habits are fixed-definition) | RISK: medium â€” nested list inside a task edges toward the mandatory-concept trap; must stay a single optional field with the plain task name as default

## AI-assisted task breakdown with adjustable granularity [adhd-neurodivergent]
SRC: Goblin Tools Magic ToDo (spiciness levels); Llama Life AI breakdown
IDEA: Breaking a dreaded task into micro-steps is itself an executive-function task, so it doesn't happen; outsourcing the decomposition (with a 'spiciness' dial controlling how micro the steps get) removes the hardest meta-step and makes overwhelming tasks enterable.
WHO: Users paralyzed by big vague tasks ('do taxes', 'clean apartment'); overlaps with but exceeds what the 2-minute fallback can shrink.
FEATURE: A 'Break it down' action on a task: generates a checklist of sub-steps inside the task (checkable, no points each â€” completing all checks completes the task), with a 1-3 pepper granularity dial. Ship manual checklists first; add the AI generation as an optional online enhancement later.
COVERED: none (milestoneâ†’task exists, but tasks have no internal sub-steps) | RISK: high â€” adds a nesting level to the data model and, with AI, a network/API dependency and cost; recommend manual-checklist-first sequencing

## Habit Strength Score (decay-based, streak-complementary) [competitors]
SRC: Loop Habit Tracker (open-source; formula verified: exponential smoothing, S_n = (1-a)S_{n-1} + a on done days, decays on misses, bounded 0-1)
IDEA: A weighted average over the habit's entire history where recent completions matter most: one missed day dents the score slightly instead of zeroing it, and low scores rise fast while high scores demand consistency. It fixes the core fragility of streaks â€” a single bad day after 60 good ones no longer erases visible progress.
WHO: Perfectionist / all-or-nothing users who abandon the app after a broken streak; long-term maintainers whose streak number stops being motivating.
FEATURE: Per-task (and rolled-up per-milestone) 'strength' ring, 0-100, computed in Dart from task_completions with skips excluded from decay (consistent with existing skip-vs-missed honesty). Show it on the milestone detail header and as a small ring on TaskTile's meta area; pairs naturally with the identity-vote count ('92% strong Â· 148 votes'). Purely informational â€” no points or quests attached.
COVERED: none â€” streaks, never-miss-twice banner, and skip/missed states exist, but there is no forgiving long-horizon metric; streak remains the only consistency signal | RISK: low â€” one read-only number derived from existing completion data, no new user actions or concepts to learn

## Sensor / health-data auto-completion [competitors]
SRC: Streaks (iOS; HealthKit-linked tasks auto-complete from water, steps, workouts, mindful minutes)
IDEA: Tasks linked to phone health data mark themselves done, removing the logging tax entirely for physical habits. The habit gets tracked even on days the user never opens the app, which protects streak/strength data integrity.
WHO: Fitness and health habit users; low-friction users who do the habit but forget to log it and then get falsely dinged as 'missed'.
FEATURE: Optional per-task 'auto-complete from Health' source picker (steps >= N, workout minutes, sleep, mindful minutes) via health package (HealthKit + Health Connect). A background check at app-open completes qualifying tasks through the existing TaskCompletionService so points, streaks, and quests fire normally, with a distinct 'auto' glyph on the tile.
COVERED: none â€” all completions are manual taps or timer stops | RISK: medium â€” platform permission plumbing and edge cases (data arriving late), but the UI footprint is one optional field in task_form_sheet

## Negative habits (avoidance tasks) [competitors]
SRC: Streaks ('negative task' type) and Way of Life (red/green journal works equally for quit-habits)
IDEA: Track things you want to NOT do: the day succeeds by default and fails only if you admit doing the thing. Inverting the default turns willpower absence into visible success, which do-task trackers can't represent at all.
WHO: Users quitting something â€” smoking, doomscrolling, late-night snacking â€” a huge habit-tracking audience the app currently can't serve.
FEATURE: New optional task type 'Avoid' on the existing form: tile shows a shield that auto-confirms at day end (awarding points via the normal pipeline) unless the user taps 'I slipped', which records an honest miss with zero shame copy â€” reuse the missed state, never red-alert push notifications. Do NOT copy any app's habit of nagging 'don't forget not to X' reminders mid-day; reminders stay opt-in and neutral.
COVERED: none â€” schema and streak logic assume positive completions only | RISK: medium â€” inverts completion/streak semantics (success = no event), needing careful handling in TaskCompletionService and the day-rollover check, though the visible surface is just one more type chip

## Rest / vacation mode [competitors]
SRC: Todoist Karma vacation mode (verified: pauses goals and streaks for time off, no Karma loss); Duolingo streak freeze is the consumer-famous variant
IDEA: A planned, guilt-free pause: while active, nothing counts against streaks, quests, or goals. It acknowledges that life includes travel, illness, and burnout, and that punishing absence is how apps lose users permanently.
WHO: Travelers, sick users, and burnout-prone users who currently must either skip every task daily by hand or watch everything decay.
FEATURE: Settings + Home banner 'Rest mode' with an optional end date: while on, scheduled tasks are auto-marked skipped (existing is_skip path preserves streaks), daily quests and last-call alerts are suppressed, and habit-strength decay pauses. One AppPrefs date-range field plus a check in the day-build logic. Do NOT copy Duolingo's monetization of streak repair (buying freezes with gems/money).
COVERED: partial â€” per-task per-day 'Skip today' exists and preserves the streak, but there is no one-tap multi-day, all-tasks pause | RISK: low â€” one toggle that composes the already-built skip semantics; main care point is making re-entry (mode ends) obvious

## Natural-language quick capture [competitors]
SRC: Todoist (its NL date/recurrence parser â€” 'every weekday 7am' â€” is the category benchmark)
IDEA: Typing 'meditate daily 7am 10pts' creates a fully-scheduled task in one line, collapsing a multi-field form into a single text input. Capture speed is the difference between a thought becoming a task or being lost.
WHO: Power users and keyboard-first capturers; anyone adding tasks on the go who finds the (rich) recurrence builder heavyweight for simple cases.
FEATURE: A text field at the top of the existing task_form_sheet that parses locally (regex/chrono-style, no LLM needed) and PRE-FILLS the form fields below â€” the user still sees and confirms the parsed recurrence via the existing live schedule-preview chip, so misparses are visible before saving. The form remains the source of truth; NL is a shortcut layer, never the only path.
COVERED: none â€” quick-add opens the full form with the recurrence builder | RISK: medium â€” parser edge cases are endless, but constraining it to a pre-fill (never silent creation) caps the damage of misparsing

## Starter journeys / habit-ladder templates [competitors]
SRC: Fabulous (guided 3-12 week 'journeys' that build one ritual at a time via graduated steps)
IDEA: Instead of a blank slate, offer curated programs that start absurdly small and escalate weekly (drink water â†’ morning ritual â†’ deep work). Sequencing and pre-authored progression remove the 'what do I even track?' cold-start problem.
WHO: Beginners and the overwhelmed who don't know how to decompose 'become a writer' into a schedule; users who churn in week one from blank-slate paralysis.
FEATURE: A 'Start from a template' option in milestone creation: ~8 hardcoded JSON templates (each = identity-framed milestone + a ladder of tasks where week 1 is the 2-minute version and later weeks unlock the full version â€” directly reusing the existing 2-minute-rule fallback and Goldilocks coach). Do NOT copy Fabulous's lock-step coercion (locked content, daily letters, heavy upsell); templates are fully editable normal milestones the moment they're created.
COVERED: partial â€” 2-minute fallbacks, habit stacking, and the Goldilocks difficulty coach are the exact building blocks, but nothing composes them into a guided starting path | RISK: medium â€” zero new mechanics (it's just seeded data), but template content needs authoring care so it doesn't feel like a self-help course bolted onto a tracker

## Routine runner (guided stack execution) [competitors]
SRC: Routinery (verified: voice-guided sequential timers per routine step, pause/skip/adjust on the fly; Forbes Health 'Best ADHD App')
IDEA: Turn an ordered routine into a full-screen, one-step-at-a-time countdown player â€” the app tells you what to do NOW and for how long, eliminating between-task decision points where routines die. Exceptionally effective for time-blindness.
WHO: ADHD / time-blindness users; anyone with a morning or evening routine who loses 20 minutes between steps.
FEATURE: A 'Run stack' play button on any existing habit-stack chain: full-screen player showing current task + countdown (from the task's existing duration), auto-advancing and auto-completing each step through the normal completion pipeline (points/confetti fire per step), with pause/skip/extend controls. This is almost pure composition of the already-built stack model + per-task stopwatch.
COVERED: partial â€” habit stacking with derived time slots and a per-task stopwatch exist, but each task must be run and completed individually | RISK: low â€” one new screen composing existing primitives; the stack concept already exists so no new mental model

## Daily planning + shutdown ritual with capacity check [competitors]
SRC: Sunsama (guided 10-min morning plan, overcommitment warnings, evening shutdown reflection â€” the 'calm productivity' benchmark)
IDEA: Bookend the day: a short morning moment to consciously choose a REALISTIC load (with the app summing task durations against available hours and warning when overcommitted), and an evening shutdown that celebrates what got done and pre-seeds tomorrow. Planning becomes the habit that carries all other habits.
WHO: Overplanners and the chronically overwhelmed; users who stack 6 hours of tasks into a 3-hour evening and then feel like failures.
FEATURE: Optional, dismissible: (1) a morning 'Plan today' card on Home that lists scheduled tasks with summed durations vs. a rough free-hours estimate ('5.2h planned Â· that's a lot for a workday') and offers one-tap defer per task; (2) an evening shutdown card after the existing all-done celebration slot showing the day recap + tomorrow preview. Both are cards, never blocking wizards â€” Sunsama's ritual works because it's guided, but Kaizn's must stay skippable to honor the optional-layers constraint.
COVERED: partial â€” Up Next, drag-drop day timeline, and task durations provide all the data; there is no planning moment, capacity math, or shutdown reflection | RISK: medium â€” rituals drift toward feeling mandatory; keeping them as two dismissible cards (with a settings kill-switch) is the guardrail

## Prompted roll-forward of slipped tasks [competitors]
SRC: Motion (verified: missed tasks are automatically rebooked into the next free slot; at-risk deadline warnings)
IDEA: When a scheduled one-time task slips, the system re-places it instead of letting an overdue pile accumulate as ambient guilt. Motion does this silently via AI; the adaptable core is 'slipped work gets one cheap, explicit re-decision instead of rotting'.
WHO: Deadline-driven users of one-time tasks; anyone whose Up Next list grows a shame-inducing backlog of stale items.
FEATURE: A once-per-morning prompt when overdue one-shots exist: '3 tasks slipped â€” move to today / this weekend / pick times on the timeline', batch-applying due-date changes and optionally dropping them into free gaps on the existing drag-drop timeline. Do NOT copy Motion's silent auto-rescheduling â€” on a manual-control timeline, unrequested moves destroy trust; every move is user-confirmed.
COVERED: partial â€” overdue one-shots already keep surfacing in Up Next and last-call alerts warn before the miss, but there is no batch re-decision moment, so stale items accumulate | RISK: low â€” one dismissible morning prompt reusing existing due-date editing

## Care-based companion (nurture framing) [competitors]
SRC: Finch (verified: pet grows and goes on adventures fueled by your self-care; deliberately no punishment â€” the bird never suffers when you lapse)
IDEA: Completions become acts of care for a creature that visibly grows, reframing motivation from self-discipline to nurturing something. Finch's evidence is that care-framing reaches users (especially anxious/depressed ones) that points and streaks never touch â€” and it works WITHOUT the pet ever being harmed by inactivity.
WHO: Users motivated by nurture rather than optimization; self-care-oriented users for whom points feel corporate and streaks feel like pressure.
FEATURE: An optional 'companion' cosmetic layer (off by default, one toggle): a small creature/plant on Home that grows through stages fed by identity votes, with weekly-chest items as accessories. Hard rules from the dark-pattern kill list: it never gets sick, sad, or dies (do NOT copy Forest's tree-death or any 'your pet misses you' guilt notifications â€” Finch itself flirts with these in pushes), and it grants zero gameplay advantage so ignoring it costs nothing.
COVERED: partial â€” levels, weekly chest, and confetti cosmetics exist as reward surfaces, but nothing offers a nurture/care emotional register | RISK: high â€” art assets, growth-stage design, and the gravitational pull of a mascot becoming the app's identity rather than an optional layer; scope it as strictly cosmetic or skip

## Focus garden (permanent session artifacts) [competitors]
SRC: Forest (each focus session grows a tree; your accumulated forest is a tangible visualization of invested attention)
IDEA: Every focus session leaves a permanent visual artifact, so invested time compounds into something you can look at â€” a forest, not a log table. The collection view is the motivator; Forest's punishment (tree dies if you leave the app) is separable and unnecessary.
WHO: Deep-work and timer-centric users; visual thinkers for whom a 'time invested: 14h' stat is inert but a growing garden is compelling.
FEATURE: Timer sessions >= 15 min plant a tile (sprout/tree/rare variant by duration, colored by the milestone's existing palette color) in a monthly 'focus garden' grid on the Stats screen â€” a pure re-visualization of already-recorded timer data. Do NOT copy the dying tree / app-leaving punishment, which is exactly the guilt mechanic the kill list bans.
COVERED: partial â€” per-task stopwatch, time-invested stats, and heatmap exist; sessions currently produce numbers, not artifacts | RISK: low â€” additive Stats panel over existing data; no new user actions

## Co-op quests without friendly fire [competitors]
SRC: Habitica parties/guilds (verified mechanic: party boss quests where your missed dailies damage teammates â€” powerful accountability, textbook guilt mechanic)
IDEA: Shared goals with real people are the strongest adherence lever in the category â€” Habitica parties keep people logging for years. The extractable core is COLLECTIVE PROGRESS (everyone's completions fill one shared bar); the part to amputate is collective punishment (your miss hurting friends).
WHO: Socially motivated users; accountability-seekers; aligns with the product vision's future leaderboards and public rewards.
FEATURE: Future 'co-op challenge': invite 1-4 friends to a shared goal ('200 combined completions this month') where a shared progress bar rises with every member's completions and completing it unlocks a cosmetic for all. Misses and skips are invisible to teammates â€” contributions only ever add. Do NOT copy boss damage from others' missed dailies, member 'slacker' visibility, or public shame ledgers.
COVERED: none â€” fully single-player today (local DB + Drive backup, no accounts beyond Google sign-in) | RISK: high â€” first feature requiring a backend/sync layer and social UX; park it on the roadmap until the offline core is done

## Pace line + akrasia horizon (commitment lite, no money) [competitors]
SRC: Beeminder (verified: 'bright red line' pace tracking toward a rate-based goal; the akrasia horizon â€” goal changes only take effect after 7 days, so you can't weaken a commitment in a moment of weakness)
IDEA: Two separable ideas: (1) show whether you're ON PACE for a rate goal ('3x/week') days before the week is lost, converting vague intention into a visible trajectory; (2) let users voluntarily delay-lock their own schedule changes by a week, a commitment device with zero punishment. Beeminder's money pledges prove stakes work but are the wrong tool here.
WHO: Quantified-self and commitment-driven users; people whose weekly-frequency habits ('gym 3x/week') silently fail by Thursday.
FEATURE: (1) On weekly/monthly interval tasks, a small on-pace indicator on the tile and milestone detail ('1 of 3 this week â€” 2 days left'), plus a per-milestone weekly pace sparkline in Stats. (2) An opt-in per-task 'commitment mode' toggle where reducing frequency or deleting takes effect next Monday (with an always-available emergency off in Settings â€” never trap the user). Do NOT copy monetary pledges, escalating charges, or derailment emails.
COVERED: partial â€” Goldilocks coach adjusts difficulty and last-call alerts warn same-day, but nothing projects mid-week pace, and schedule edits are always instant | RISK: medium â€” the pace indicator is low-risk; commitment mode adds a real concept and must stay buried as an advanced per-task option

## Per-completion notes + mood context [competitors]
SRC: Habitify (verified: per-check-in notes and mood tracking, 'rich notes' with images) and Way of Life (per-day journal notes on each habit)
IDEA: Attaching a one-line note or 1-tap mood to a completion turns the tracker into a lightweight lab notebook â€” later you can see WHY a habit thrives or dies (context, obstacles, energy), which raw checkmarks can never reveal.
WHO: Reflective journalers; users debugging a failing habit; anyone whose Stats screen says 'what' but never 'why'.
FEATURE: Long-press on a completed TaskTile â†’ 'Add note' (one text line + optional 5-emoji mood row), stored on the existing task_completions row (schema: nullable note + mood columns). Surface notes in the heatmap's day-detail view and a 'mood by habit' line in Stats once enough data exists. Entirely opt-in per completion â€” zero prompts.
COVERED: none â€” completions store timestamp/points/flags only | RISK: low â€” one nullable column and a long-press affordance that already has a menu to extend

## Google Calendar read-only overlay (calendar-as-busy-time) [integrations]
SRC: Google Calendar API sync guide (developers.google.com); Nango/Nylas calendar-sync engineering write-ups; pattern used by Sunsama/Reclaim/Fhynix
IDEA: Pull the user's Google Calendar events and render them as untouchable 'busy' blocks behind the app's own drag-and-drop day timeline. Read-only means no conflict handling at all â€” the app only needs events.list with incremental syncToken (persist token, handle 410 GONE with a full re-sync) plus periodic polling; habits get planned into real free gaps instead of a fantasy empty day.
WHO: Calendar-driven planners and working professionals whose day is meeting-shaped; anyone who abandons habit plans because they collide with real appointments
FEATURE: Phase 1: 'Connect Google Calendar' toggle in Settings (the app already holds a Google OAuth session for Drive backup â€” add the calendar.readonly scope) that draws gray, non-draggable event blocks on the existing day timeline, and lets the habit-stacking queue auto-derive time slots around them. Phase 2 adds a free-busy-aware 'suggest a slot' action when dragging a task.
COVERED: partial â€” the Google-Calendar-style day timeline, derived time slots, and Google sign-in (email + drive.appdata scopes) exist; no calendar data is read yet | RISK: low â€” one optional toggle, no write path, no conflict resolution; the timeline UI already exists

## Google Calendar write-back (two-way sync, app-owned calendar) [integrations]
SRC: Google Calendar API (events insert/patch, push channels); syncdate.app 'webhooks, polling & dedup' write-up; TickTick/Todoist two-way sync precedent
IDEA: Publish scheduled tasks/chains as events into a dedicated 'Kaizn' secondary calendar the app owns, and ingest edits made in Google Calendar back into the app. Owning a separate calendar sidesteps most conflict pain: the app is authoritative for its own events, external events stay read-only, and dedup uses the app's task ID stored in extendedProperties. Push notifications are 'not 100% reliable' per Google, so pair webhooks with hourly incremental polling.
WHO: Users who live in Google Calendar on desktop and want their habit plan visible (and reschedulable) there without opening the phone app
FEATURE: Phase 2 after the overlay: per-milestone or global 'publish to Google Calendar' switch that mirrors timeline-scheduled tasks into a Kaizn-named calendar; dragging an event in Google Calendar moves the task's slot in-app on next sync; completion state shown via emoji-prefixed titles. Conflict rule: latest edit wins, and completions never sync outward as deletions.
COVERED: none | RISK: high â€” background sync on mobile, token/410 recovery, dedup, and edit-loops are real engineering; must stay strictly opt-in and degrade to overlay-only on any sync failure

## Health auto-complete habits (HealthKit / Health Connect) [integrations]
SRC: Streaks, Habitra, HabitFinch, Habitify (Apple Health integrations); Apple HealthKit + Android Health Connect APIs
IDEA: Link a habit to a health metric (steps â‰¥ 8k, sleep â‰¥ 7h, any workout, mindful minutes) and auto-check it when the day's total crosses the threshold â€” the phone/wearable becomes the logger, removing the manual-logging tax entirely for body-based habits. Streaks proved this converts wearable owners into zero-friction trackers.
WHO: Fitness/sleep-focused users and low-conscientiousness users for whom manual logging is itself the failure point; wearable owners
FEATURE: New optional 'auto-track from Health' section in the task form: pick metric + threshold; a background check (on app open + periodic) inserts a normal task_completion with a 'via Health' meta tag, feeding existing points/streak/identity-vote flows. Phase 1 ships steps + workouts only (simplest read types), Phase 2 adds sleep and mindful minutes. Flutter `health` package wraps both platforms.
COVERED: none | RISK: medium â€” permission UX and per-platform quirks (Health Connect install prompt on older Android) are manageable, but auto-completions must be clearly labeled so users trust the streak math

## Interactive home-screen widgets (tap-to-complete) [integrations]
SRC: Streaks, HabitKit, Habitify, init.Habits widget suites; WidgetKit interactive widgets (iOS 17+) and Android Glance
IDEA: Put both the cue (today's habit list/heatmap) and the action (one-tap check) on the screen the user already looks at by reflex, removing the open-the-app step. Widgets are the single highest-leverage retention surface habit apps report; interactive completion (iOS 17+ App Intents, Android RemoteViews/Glance) closes the loop without an app launch.
WHO: Everyone, but especially glance-and-go users and people who forget the app exists after week two
FEATURE: Phase 1: small 'Up Next' widget (next task + streak flame) and medium 'Today checklist' widget with tap-to-complete via the existing TaskCompletionService; Phase 2: large heatmap/identity-votes widget. Flutter side uses the home_widget package with native WidgetKit/Glance shells; completions route through the same AppEventBus so points/quests fire normally.
COVERED: none | RISK: low â€” pure additive surface, no new concepts in-app; main cost is native platform code outside Flutter

## Lock-screen widgets + Live Activity for the running timer [integrations]
SRC: iOS Live Activities / Dynamic Island (ActivityKit); lock-screen widget patterns from Streaks/Habitify; Android ongoing foreground-service notification chips
IDEA: A Live Activity keeps the currently running task timer (or the active habit-chain step) persistently visible on the lock screen / Dynamic Island, turning an in-app stopwatch into an ambient commitment device â€” you see 'Writing â€” 12:41' every time you check your phone. Lock-screen widgets do the same for a single keystone habit or streak count.
WHO: Timer/deep-work users and habit-chain users; ADHD-leaning users who lose the thread when the phone locks
FEATURE: When the existing per-task stopwatch starts, launch a Live Activity (iOS) / ongoing notification with chronometer (Android) showing task name, elapsed time, and a stop button; chain mode shows 'step 2 of 4 â€” next: stretch'. Phase 1 timer-only, Phase 2 adds a circular lock-screen streak widget. Builds directly on the shipped stopwatch-lite feature.
COVERED: partial â€” per-task stopwatch timer and chains exist in-app; nothing persists to the lock screen when backgrounded | RISK: low-medium â€” invisible unless you start a timer; ActivityKit requires a native extension and update-budget care

## Siri / Google Assistant voice logging (App Intents + App Actions) [integrations]
SRC: Apple App Intents framework (Shortcuts, Siri, Spotlight, Action button); Android App Actions shortcuts.xml capabilities; HabitKit's iOS Shortcuts guide
IDEA: Expose 'log habit X', 'start timer for X', and 'what's up next' as system-level intents so users complete habits hands-free or from Spotlight/Action-button without opening the app. App Intents also make every habit automatable inside users' own Shortcuts automations (time, location, charger, alarm-dismissed triggers) â€” you inherit an entire automation platform for free.
WHO: Power users and automation tinkerers; hands-busy contexts (cooking, driving, gym); Action-button owners
FEATURE: Phase 1: three intents â€” CompleteHabit(task), StartTimer(task), GetUpNext â€” surfaced in Shortcuts and as Siri phrases, with Android App Actions mirroring via shortcuts.xml. Phase 2: donate frequently used habits so they appear in Spotlight/Assistant suggestions. All routes through TaskCompletionService so streak honesty and quests behave identically.
COVERED: none | RISK: low â€” zero in-app UI change; the work is native intent plumbing and keeping the entity list (tasks) synced to the platform

## NFC tags / QR codes for physical-context logging [integrations]
SRC: Habitify NFC check-in; TagTrack ('phygital' NFC habit tracker); timesheet.io NFC time-tracking automation
IDEA: A cheap NFC sticker on the water bottle, pill box, gym bag, or guitar case logs the habit in under two seconds by tapping the phone to the object â€” the physical object becomes both the cue and the logging device, and the tap is proof-of-presence that manual check-ins lack. QR fallback covers devices/contexts where NFC is awkward.
WHO: Tangible-ritual people (medication, hydration, instruments, gym); users who game their own check-ins and want honest friction
FEATURE: Task form gains an optional 'link a tag' step that writes a kaizn://complete/{taskId} deep link to an NFC tag (nfc_manager plugin) or generates a printable QR; tapping the tag completes the task (or opens a confirm sheet if points > threshold). Phase 1 complete-only; Phase 2 lets a tag start a timer or a whole habit chain.
COVERED: none | RISK: low â€” entirely invisible unless configured; deep-link handling already fits the router, and no server is involved

## Geofenced location reminders [integrations]
SRC: iOS Core Location region monitoring / Android Geofencing API; precedent in Apple Reminders, Todoist, Streaks location triggers
IDEA: Trigger a habit's reminder on arriving at (or leaving) a place â€” gym, office, home, grocery store â€” so the nudge lands exactly when the context makes action possible, instead of at an arbitrary clock time. Complements the existing last-call alerts: time says 'today is ending', location says 'you are literally here'.
WHO: Context-dependent habits (gym, errands, 'call mom when leaving work'); people whose schedules are too irregular for time-based reminders
FEATURE: Reminder editor gains an optional 'At a place' trigger: pick a saved place on a map + arrive/leave + radius; fires a normal notification with the existing complete-from-notification action. Phase 1: arrive-only with 3 saved places max; Phase 2: leave triggers and pairing with last-call ('if not done by the time you leave the gym area, last call').
COVERED: partial â€” a full reminder system incl. last-call alerts exists; all triggers are time-based today | RISK: medium â€” 'always allow location' permission is a trust hurdle and OS geofence reliability varies; must be framed as per-reminder opt-in with a clear privacy note (on-device only)

## Notion / Obsidian journal export [integrations]
SRC: Habit Space (markdown habit tracker with Obsidian interop); Obsidian habit-tracker plugins storing data as frontmatter markdown; Habitify-Notion Zapier connector
IDEA: Write the user's habit history out as plain markdown (daily notes with frontmatter: completions, points, time invested, reflections) so it lands in the systems where journaling/PKM people already do their weekly reviews. Markdown-with-frontmatter is the lingua franca â€” one exporter serves Obsidian, Logseq, and (via import) Notion, with zero ongoing sync liability.
WHO: PKM and journaling users (Obsidian/Notion power users) who will reject any tracker that silos their data; weekly-review practitioners
FEATURE: Settings > Export gains 'Markdown journal export': generates a zip of per-day .md files (frontmatter stats + human-readable checklist) shareable to any folder/app via the system share sheet. Phase 1 one-shot export; Phase 2 optional auto-export of yesterday's note to a chosen folder (SAF/iOS file bookmark). Explicitly not two-way sync.
COVERED: partial â€” full-database JSON backup to Google Drive exists (machine format, not human-readable, not per-day) | RISK: low â€” pure output path, one settings tile; no permissions beyond a folder picker

## CSV export + local API/webhook for tinkerers [integrations]
SRC: Habit Space's open REST API (OpenAPI 3.1); Zapier/Make webhook patterns; data-portability norms across Habitify/HabitKit
IDEA: Structured, documented data export (CSV per table: completions, points, time) plus an optional outbound webhook on completion events gives spreadsheet users and automation platforms (Zapier/Make/Home Assistant) a way in without you building N integrations. Data portability is also a trust signal that offsets gamification skepticism.
WHO: Spreadsheet analysts (the owner's own Excel heritage), quantified-self users, and anyone wiring Kaizn into Zapier/Home Assistant dashboards
FEATURE: Phase 1: 'Export CSV' next to the existing backup buttons (completions + points_history + tasks with stable IDs). Phase 2: per-app 'send completions to a webhook URL' toggle that POSTs a small JSON payload on each completion via the existing AppEventBus â€” effectively Zapier support without a partnership.
COVERED: partial â€” Drive JSON backup covers restore, not analysis; no CSV, no webhooks | RISK: low â€” CSV is trivial; webhook is one URL field hidden in an 'Advanced' section

## Weekly digest email (review recap) [integrations]
SRC: Slack's weekly activity-digest re-engagement pattern; GitHub/Strava weekly recap emails; digest-structure guidance (consistent scannable format)
IDEA: A once-weekly email summarizing points earned, streak status, identity votes cast, best day, and one gentle 'never-miss-twice' nudge reaches users during the exact window when app-abandonment happens â€” it re-engages lapsed users through a channel the app can't be deleted from, and doubles as a weekly-review artifact.
WHO: Lapsing users (the week-3 drop-off cohort) and weekly-review practitioners who want a Sunday summary without opening the app
FEATURE: Opt-in 'Weekly recap email' in Settings using the Google account address already on file; content mirrors the Stats screen (this-week card + heatmap strip + weekly-chest result). Requires the app's first backend component (or a scheduled cloud function reading an uploaded stats blob), so phase it late; a Phase-0 alternative is a rich local Sunday notification that deep-links to a shareable recap screen.
COVERED: partial â€” all the stats exist in-app (weekly cards, heatmap, weekly chest); nothing reaches users outside the app | RISK: medium â€” the feature itself is one toggle, but it drags in server infrastructure, email deliverability, and a privacy story for stats leaving the device

## MCP server / AI-assistant access to habits [integrations]
SRC: Model Context Protocol (modelcontextprotocol.io; July 2026 spec RC); MCP registry ecosystem; 'universal adapter' pattern for exposing app capabilities to Claude/ChatGPT
IDEA: Expose the habit graph (milestones, tasks, completions, stats) as MCP tools/resources so the user's AI assistant can answer 'how's my writing habit trending?', plan tomorrow's timeline into calendar gaps, or log a completion conversationally. One MCP server works with every compliant client, so it future-proofs the 'one stop solution' ambition without building a chatbot into the app.
WHO: AI-assistant power users who plan and reflect in Claude/ChatGPT; the coaching/reflection style that no in-app UI serves well
FEATURE: Phase 1: read-only â€” the Drive JSON backup already puts a full snapshot in the user's own AppData, so a small companion MCP server can serve stats/history from it with tools like get_week_summary and get_habit_history. Phase 2: write tools (log_completion, schedule_task) once a proper sync backend exists, with the same no-guilt guardrails encoded as tool descriptions.
COVERED: partial â€” the Drive JSON dump is an accidental read-only data plane; no MCP surface or API exists | RISK: medium â€” zero impact on in-app simplicity (it lives entirely outside the app), but auth (user-owned Drive token vs. hosted backend) and write-path safety need careful scoping

## Measurable habits & flexible weekly quotas (beyond binary fixed-day) []
SRC: Loop Habit Tracker / Streaks / Habitify (category-standard in every major competitor); BJ Fogg's scale-the-behavior principle
IDEA: Many habits are quantities ('read 20 pages', 'drink 2L') or floating frequencies ('gym 3x/week, any days'), not binary checks on fixed weekdays. Letting the target flex prevents false misses for irregular schedules and preserves the app's skip-vs-missed streak honesty.
WHO: Shift workers, parents, and anyone whose week doesn't fit fixed weekdays; fitness, reading, and hydration trackers who want partial-progress credit.
FEATURE: Two optional task target types: a numeric daily target with partial progress (log 3 of 8 glasses; tile shows a fill ring) and an 'N times per week, any days' quota whose weekly chip row fills in any order. Both feed the existing points, streak, and skip/missed logic unchanged.
COVERED: none â€” recurrence supports only fixed days/intervals and completions are binary; nothing in the sweep addresses quantity targets or floating frequency goals | RISK: medium â€” touches the tile, RecurrenceRule, and streak rules, but stays strictly per-task opt-in with binary fixed-day as the default

## Structured reflection journaling (gratitude / daily prompts) []
SRC: The Five Minute Journal (Ramdas & Cote); Bullet Journal (Ryder Carroll); interstitial journaling (Tony Stubblebine)
IDEA: Brief prompted writing (three gratitudes, 'what went well / what to improve') converts raw completions into meaning and consolidates learning; reflection is the mechanism that turns tracking data into actual behavior change rather than score-keeping.
WHO: Reflective/journaling-style users who churn off pure gamification; pairs naturally with self-compassion after lapses and the never-miss-twice recovery moment.
FEATURE: Optional evening reflection card attachable to the shutdown ritual: 2-3 configurable prompts, answers stored as dated journal entries linked to that day's completions, surfaced in the weekly review and included in the Notion/Obsidian export.
COVERED: partial â€” per-completion notes + mood context and Weekly Review are in the sweep, but there is no standing prompted daily journaling practice as a technique of its own | RISK: low â€” one optional card and one table; invisible unless enabled

## Chronotype-aware scheduling []
SRC: Daniel Pink, 'When: The Scientific Secrets of Perfect Timing'; Michael Breus, 'The Power of When'
IDEA: Cognitive performance follows a peak-trough-rebound daily curve whose timing varies by chronotype (lark/owl/etc.); matching task type to window â€” analytic at peak, admin at trough, creative at rebound â€” improves both output and adherence.
WHO: Night owls forced into morning-person defaults, students, and deep-work schedulers; complements the app's existing hourly-distribution stats.
FEATURE: A short chronotype quiz, or inference from the existing completions-by-hour data, yields personal peak/trough windows painted as subtle bands on the day timeline; the Goldilocks coach can suggest moving hard tasks into peak windows.
COVERED: partial â€” energy management/ultradian oscillation and the time-of-day stats chart exist, but nothing personalizes scheduling advice by chronotype | RISK: low â€” a read-only timeline overlay plus soft suggestions; introduces no new mandatory concept

## Deliberate rest & burnout-load monitoring (deload weeks) []
SRC: Alex Soojung-Kim Pang, 'Rest'; sports periodization (deload weeks); Maslach burnout research
IDEA: Sustainable performance requires programmed recovery, and rising scheduled load combined with a falling completion rate is a measurable leading indicator of burnout; reducing load proactively beats waiting for the user to collapse and abandon the app.
WHO: Overcommitters and high-achievers who quit in week six; anyone whose missed-task count trends up while task count also trends up.
FEATURE: A quiet load index computed from data the app already has (tasks-scheduled-per-day trend vs completion-rate trend); when it crosses a threshold, offer a one-tap 'deload week' that trims optional tasks and pre-applies streak-preserving skips.
COVERED: partial â€” rest/vacation mode and self-compassion after lapses exist as reactive tools, but nothing detects overload or proposes recovery proactively | RISK: medium â€” the nudge must be tuned as an offer, never a verdict, or it violates the no-guilt kill list and feels like the app policing the user

## Spaced repetition & exam backward planning (student workflows) []
SRC: 'Make It Stick' (Brown, Roediger & McDaniel); Ebbinghaus forgetting curve; Anki's SM-2 algorithm
IDEA: Retrieval practice at expanding intervals (1d, 3d, 7d, 16d...) is the most evidence-backed study technique, and scheduling reviews backward from an exam date turns a syllabus into a concrete daily plan. The sweep has zero support for the student/exam user style.
WHO: Students, certification and exam preppers, language learners â€” a large, distinct productivity style entirely absent from the current list.
FEATURE: A 'review' recurrence type that reschedules itself at expanding intervals after each completion, plus an exam-countdown milestone template that back-fills review tasks from a target date the user sets.
COVERED: none â€” no expanding-interval recurrence, retrieval-practice framing, or deadline-backward planning appears anywhere in the sweep | RISK: medium â€” expanding intervals break the fixed RecurrenceRule model; safest shipped as a template layer on existing tasks, not a new core concept

## Money & savings habits (no-spend streaks, save-on-complete) []
SRC: Qapital's save-when-you-complete rules; Ramit Sethi, 'I Will Teach You to Be Rich'; YNAB
IDEA: Money behaviors are habit-shaped (no-spend days, transfer $5 per workout), and pairing a completion with a small self-directed transfer makes reward value tangible; attaching real prices to rewards makes the points economy feel earned rather than arbitrary.
WHO: Budgeters and savers, plus any user whose self-defined rewards are real purchases â€” which is most of them, given the reward model.
FEATURE: Optional real-cost field on rewards ('new headphones â€” $89') plus a virtual savings-jar that accrues a self-set amount per completion, so claiming a reward means 'I earned this spend guilt-free'. Purely self-reported; no bank integration.
COVERED: partial â€” negative/avoidance habits can express no-spend days and rewards are self-defined, but nothing connects habits to money amounts or savings visualization | RISK: low â€” one optional field and a jar display; no financial APIs or accounts

## Screen-time & digital-minimalism habits []
SRC: Cal Newport, 'Digital Minimalism'; one sec (Grosser); iOS Screen Time API / Android Digital Wellbeing UsageStats
IDEA: Reduction goals ('under 30 min social media') only stick when measured automatically and when friction is inserted at the moment of impulse; self-reported abstinence habits are notoriously unreliable, so sensor-backed verification is the mechanism.
WHO: Doomscrollers, focus-seekers, digital-declutter users â€” one of the most-requested habit categories and a whole user style missing from the sweep.
FEATURE: A phone-usage habit type auto-completed from Digital Wellbeing / Screen Time data (mirroring the health auto-complete pattern already in the sweep), and optionally a focus-session mode where the running task's Live Activity replaces the phone during a pledged phone-free block.
COVERED: partial â€” negative habits give the avoidance frame and health auto-complete establishes the sensor-verification pattern, but screen-time data specifically appears nowhere | RISK: high â€” iOS Screen Time entitlements are restrictive and the two platforms diverge sharply; Android-first via UsageStats is the feasible slice

## Life-area balance audit (Wheel of Life / Covey roles) []
SRC: Wheel of Life (coaching standard, attributed to Paul J. Meyer); Stephen Covey, 'First Things First' roles-based weekly planning
IDEA: People systematically over-invest in one identity while others silently decay; a periodic view of effort across life areas (health, relationships, career, learning...) surfaces the neglected area so weekly planning can rebalance before it becomes a crisis.
WHO: The app's core identity-driven users, people juggling many milestones, and weekly reviewers who want a why behind the numbers.
FEATURE: Optional life-area tag on milestones plus a balance ring in Stats showing identity votes per area over the last 30 days, with a gentle weekly-review observation ('Health collected 0 votes this month') phrased as information, never a guilt banner.
COVERED: partial â€” identity votes per milestone and by-milestone stats exist, but there is no cross-area balance view or periodic audit ritual | RISK: low â€” one optional tag and one Stats card; ignorable by anyone who never tags

