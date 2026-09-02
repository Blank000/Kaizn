import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/database.dart';
import '../../core/services/app_prefs.dart';
import '../../core/services/notification_scheduler.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';
import '../../shared/models/recurrence_rule.dart';
import '../../shared/providers/database_provider.dart';
import '../../shared/widgets/pico_figure.dart';

/// The AI bridge (V1 of "connect my own AI"): no servers, no API keys —
/// works with any chat AI the user already pays for (ChatGPT, Claude,
/// Gemini).
///
/// Export: a CONTEXT PACK — the user's live data plus instructions and the
/// exact plan-JSON schema — pasted into the AI of their choice.
/// Import: the AI's plan JSON pasted back, parsed, PREVIEWED, and only then
/// applied through the same insert APIs the forms use. The AI proposes; the
/// user approves; the app executes.

// ─── The app manual ───────────────────────────────────────────────────────
// Ships inside every prompt (chat + export) so the model knows exactly what
// Yatta! can do, HOW the user does it, and — just as important — what it
// cannot do. The NOT SUPPORTED list is belt; the real suspenders is that
// the plan pipeline can only CREATE new milestones/tasks.

const String kAppManual = '''
── APP MANUAL: what Yatta! can and cannot do ──
NAVIGATION: 4 tabs — Home, Milestones, Rewards, Stats — plus Settings (gear
icon on Home).

MILESTONES (goals/projects/habit groups): create via Milestones tab → +.
Fields: name, description, target date, completion-bonus points, color.
Marking a milestone complete (from its detail page) awards the bonus.
Deleting one deletes its tasks. Quick-added tasks land in a built-in
"Inbox" milestone.

TASKS: create from Home's ADD TASK or a milestone's detail. Recurrence:
once / daily / weekly (pick weekdays — each chosen day counts separately) /
monthly (day-of-month or Nth-weekday), with intervals (e.g. every 2 weeks)
and an optional end date. Optional per task: start time + duration (places
it on the timeline), a reminder, a 2-minute tiny version (half points, full
streak credit), points per completion (default 10), and stacking ("after X
do Y" — chains run in the Stack Runner with a countdown, pause, and +5min).

LOGGING: tap the circle on a task tile = done now (+points). Tap again =
undo (today). Multi-day weekly tasks show M/T/W/T/F/S/S chips and past
chips of the CURRENT week can be retro-logged. Long-press a tile: "Skip
today" (intentional rest — streak safe, no points) or "Mark as missed"
(asks what got in the way; those reasons feed the Sunday review).

STREAK: any real completion keeps the day alive; one empty day is forgiven,
two breaks it. A Streak Shield (costs points) can restore a just-broken
streak. Rest mode = a guilt-free multi-day pause, streak safe, no pings.

POINTS & REWARDS: completions + milestone bonuses earn points. The user
defines their own rewards with point thresholds (Rewards tab) and claims
them when the balance covers it.

HOME: Ren's Sensei Post (daily accountability line; tap it for the day's
ledger), week board, progress card with this week's "one claw" intention,
Up next / Done / Missed / Skipped sections, and a timeline view with a
Google Calendar overlay (tasks can be dragged to times; Google events show
as busy blocks and can be edited if the user owns them).

STATS & REVIEW: activity heatmap, daily points chart, time-of-day pattern,
top tasks, achievements/badges. The Sunday weekly review (from Stats or
the Sunday Home invite): what burned, what slipped (with miss reasons),
then pick exactly ONE adjustment ("one claw") for next week.

SETTINGS: theme, notification times, sounds, Master Ren toggle, Google
sign-in + Drive backup/restore, AI export/import, the AI key.

NOT SUPPORTED — never pretend otherwise:
- Editing or deleting past completions/history of any kind.
- Back-dating a completion (sole exception: current-week chips on
  multi-day weekly tasks).
- YOU editing, renaming, or deleting EXISTING milestones or tasks.
- YOU marking anything done/skipped/missed, claiming rewards, or changing
  points/streaks on the user's behalf.
- Social features or leaderboards.

YOUR ONE ACTION POWER: proposing NEW milestones + tasks + rewards via the
JSON plan block, which the user previews and applies themselves. Everything else you
offer is words: answers, summaries, coaching, and exact in-app directions
(e.g. "Home → long-press the task → Skip today").
WHEN ASKED FOR SOMETHING UNSUPPORTED: say so plainly in one sentence, then
offer the closest supported path. Never invent buttons or flows.
''';

// ─── Export: the context pack ─────────────────────────────────────────────

Future<String> buildContextPack(AppDatabase db) async {
  final milestones = await db.getActiveMilestones();
  final tasks = await db.getAllActiveTasks();
  final completions = await db.getRecentCompletions(const Duration(days: 7));
  final streak = await db.getStreak();

  final real = completions.where((c) => !c.isSkip && !c.isNd).toList();
  final misses = completions.where((c) => c.isNd).toList();
  final reasons = <String, int>{};
  for (final m in misses) {
    if (m.missReason != null) {
      reasons[m.missReason!] = (reasons[m.missReason!] ?? 0) + 1;
    }
  }

  String hhmm(int? minute) => minute == null
      ? ''
      : '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

  final b = StringBuffer();
  b.writeln('=== YATTA! CONTEXT PACK · ${DateTime.now().toString().substring(0, 16)} ===');
  b.writeln('You are my accountability assistant for "Yatta!", my gamified');
  b.writeln('habit tracker (milestones → recurring tasks → points → rewards).');
  b.writeln('Answer questions using MY DATA below. Be concise and specific.');
  b.writeln();
  b.writeln('── MY DATA ──');
  b.writeln('Streak: ${streak?.currentStreak ?? 0} days (best ${streak?.longestStreak ?? 0})');
  b.writeln('Last 7 days: ${real.length} completions, ${misses.length} misses'
      '${reasons.isEmpty ? '' : ' (${reasons.entries.map((e) => '${e.value}× ${e.key}').join(', ')})'}');
  if (AppPrefs.weeklyClawSync != null) {
    b.writeln('This week\'s focus: ${AppPrefs.weeklyClawSync}');
  }
  b.writeln();
  final byMilestone = <String?, List<Task>>{};
  for (final t in tasks) {
    byMilestone.putIfAbsent(t.milestoneId, () => []).add(t);
  }
  for (final m in milestones) {
    b.writeln('MILESTONE: ${m.name}'
        '${m.targetDate != null ? ' · target ${m.targetDate.toString().substring(0, 10)}' : ''}'
        '${m.completionPoints > 0 ? ' · bonus ${m.completionPoints} pts' : ''}');
    for (final t in byMilestone[m.id] ?? const <Task>[]) {
      final rule = RecurrenceRule.fromTask(t);
      b.writeln('  - ${t.name} · ${t.recurrence == TaskRecurrence.none ? 'once${t.dueDate != null ? ' (due ${t.dueDate.toString().substring(0, 10)})' : ''}' : rule.summary()}'
          '${t.startMinute != null ? ' · starts ${hhmm(t.startMinute)}' : ''}'
          ' · ~${t.durationMinutes}m · ${t.pointsPerCompletion} pts'
          '${t.reminderEnabled ? ' · reminder ${hhmm(t.reminderMinute) == '' ? 'at start time' : hhmm(t.reminderMinute)}' : ''}'
          '${t.tinyName != null ? ' · 2-min version: ${t.tinyName}' : ''}');
    }
  }
  final adhoc = byMilestone[null] ?? const <Task>[];
  if (adhoc.isNotEmpty) {
    b.writeln('ADHOC TASKS (no milestone):');
    for (final t in adhoc) {
      b.writeln('  - ${t.name}');
    }
  }
  b.writeln();
  b.writeln(kAppManual);
  b.writeln('── WHAT YOU CAN DO ──');
  b.writeln('1) Answer any question about the data (schedules use 24h times).');
  b.writeln('2) Design plans. When I ask you to plan or add milestones/tasks,');
  b.writeln('   reply with ONE ```json code block matching EXACTLY this schema');
  b.writeln('   (no extra keys, no commentary inside the block):');
  b.writeln('''
{
  "milestones": [
    {
      "name": "Run a 10K",
      "description": "optional",
      "target_date": "2026-12-01",
      "completion_bonus": 300,
      "tasks": [
        {
          "name": "Morning run",
          "recurrence": "weekly",
          "interval": 1,
          "days_of_week": ["mon", "wed", "fri"],
          "start_time": "07:00",
          "duration_minutes": 30,
          "points": 15,
          "reminder": "06:45",
          "tiny_version": "Put on running shoes"
        }
      ]
    }
  ],
  "rewards": [
    {
      "name": "Movie night",
      "description": "optional",
      "points_threshold": 500
    }
  ]
}''');
  b.writeln('"milestones" and "rewards" are both optional (at least one).');
  b.writeln('Schema rules: recurrence ∈ daily|weekly|monthly|once.');
  b.writeln('weekly needs days_of_week (mon..sun); monthly may set "day_of_month" (1-31);');
  b.writeln('once may set "due_date" (YYYY-MM-DD). All fields except name+recurrence are optional.');
  b.writeln('Points 5-25 by effort. Keep plans humane: 1-4 tasks per milestone,');
  b.writeln('start small (the app has a 2-minute-version culture).');
  b.writeln('I will paste your JSON into Yatta\'s "Import AI plan" screen.');
  return b.toString();
}

// ─── Import: parse → preview → apply ──────────────────────────────────────

class AiPlanTask {
  final String name;
  final TaskRecurrence recurrence;
  final int interval;
  final List<int> daysOfWeek; // 1=Mon..7=Sun
  final int? dayOfMonth;
  final DateTime? dueDate;
  final int? startMinute;
  final int durationMinutes;
  final int points;
  final int? reminderMinute;
  final String? tinyVersion;

  AiPlanTask({
    required this.name,
    required this.recurrence,
    required this.interval,
    required this.daysOfWeek,
    required this.dayOfMonth,
    required this.dueDate,
    required this.startMinute,
    required this.durationMinutes,
    required this.points,
    required this.reminderMinute,
    required this.tinyVersion,
  });

  RecurrenceRule rule() => switch (recurrence) {
        TaskRecurrence.daily => RecurrenceRule.daily(interval: interval),
        TaskRecurrence.weekly => RecurrenceRule.weekly(
            interval: interval,
            daysOfWeek:
                daysOfWeek.isEmpty ? [DateTime.now().weekday] : daysOfWeek),
        TaskRecurrence.monthly => RecurrenceRule.monthlyByDay(
            interval: interval,
            dayOfMonth: dayOfMonth ?? DateTime.now().day),
        TaskRecurrence.none => RecurrenceRule.once(),
      };

  String summary() => recurrence == TaskRecurrence.none
      ? 'Once${dueDate != null ? ' · due ${dueDate.toString().substring(0, 10)}' : ''}'
      : rule().summary();
}

class AiPlanMilestone {
  final String name;
  final String? description;
  final DateTime? targetDate;
  final int completionBonus;
  final List<AiPlanTask> tasks;

  AiPlanMilestone({
    required this.name,
    required this.description,
    required this.targetDate,
    required this.completionBonus,
    required this.tasks,
  });
}

class AiPlanReward {
  final String name;
  final String? description;
  final int pointsThreshold;

  AiPlanReward({
    required this.name,
    required this.description,
    required this.pointsThreshold,
  });
}

class AiPlan {
  final List<AiPlanMilestone> milestones;
  final List<AiPlanReward> rewards;

  AiPlan({required this.milestones, required this.rewards});

  int get taskCount => milestones.fold(0, (s, m) => s + m.tasks.length);
  bool get isEmpty => milestones.isEmpty && rewards.isEmpty;
}

const _dayNames = {
  'mon': 1, 'tue': 2, 'wed': 3, 'thu': 4, 'fri': 5, 'sat': 6, 'sun': 7,
};

int? _parseHhmm(dynamic v) {
  if (v is! String) return null;
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!), min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

/// Parses the AI's reply. Tolerant of the usual model habits: markdown
/// fences, leading prose before the block, single-milestone objects.
/// Throws [FormatException] with a human message on anything unusable —
/// including wrong-typed fields (models sometimes emit "2" for 2), which
/// would otherwise surface as TypeErrors.
AiPlan parseAiPlan(String raw) {
  try {
    return _parseAiPlanInner(raw);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException(
        'The plan JSON had unexpected field types — copy the whole block and try again.');
  }
}

AiPlan _parseAiPlanInner(String raw) {
  var text = raw.trim();
  // Prefer the fenced block if one exists anywhere in the paste.
  final fence =
      RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
  if (fence != null) text = fence.group(1)!.trim();
  // Fall back to the outermost {...} span.
  if (!text.startsWith('{')) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end <= start) {
      throw const FormatException(
          'No JSON found — paste the AI\'s ```json block.');
    }
    text = text.substring(start, end + 1);
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(text);
  } catch (_) {
    throw const FormatException(
        'That JSON didn\'t parse — copy the whole block and try again.');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Expected a JSON object at the top level.');
  }
  // A bare single-milestone object still parses; otherwise "milestones"
  // and/or "rewards" arrays, both optional.
  final rawMilestones = decoded['milestones'] ??
      (decoded.containsKey('rewards') ? const [] : [decoded]);
  if (rawMilestones is! List) {
    throw const FormatException('"milestones" must be a list.');
  }

  final out = <AiPlanMilestone>[];
  for (final rm in rawMilestones) {
    if (rm is! Map<String, dynamic>) continue;
    final name = (rm['name'] as String?)?.trim();
    if (name == null || name.isEmpty) {
      throw const FormatException('A milestone is missing its "name".');
    }
    final rawTasks = rm['tasks'];
    final tasks = <AiPlanTask>[];
    if (rawTasks is List) {
      for (final rt in rawTasks) {
        if (rt is! Map<String, dynamic>) continue;
        final tName = (rt['name'] as String?)?.trim();
        if (tName == null || tName.isEmpty) {
          throw FormatException('A task in "$name" is missing its "name".');
        }
        final recRaw = (rt['recurrence'] as String?)?.trim() ?? 'daily';
        final rec = switch (recRaw) {
          'daily' => TaskRecurrence.daily,
          'weekly' => TaskRecurrence.weekly,
          'monthly' => TaskRecurrence.monthly,
          'once' || 'none' => TaskRecurrence.none,
          _ => throw FormatException(
              'Task "$tName": unknown recurrence "$recRaw".'),
        };
        final days = <int>[
          for (final d in (rt['days_of_week'] as List? ?? const []))
            if (d is String && _dayNames.containsKey(d.toLowerCase()))
              _dayNames[d.toLowerCase()]!,
        ];
        final dom = (rt['day_of_month'] as num?)?.toInt();
        tasks.add(AiPlanTask(
          name: tName,
          recurrence: rec,
          interval: min(12, max(1, (rt['interval'] as num?)?.toInt() ?? 1)),
          daysOfWeek: days,
          dayOfMonth: dom == null ? null : min(31, max(1, dom)),
          dueDate: rt['due_date'] is String
              ? DateTime.tryParse(rt['due_date'] as String)
              : null,
          startMinute: _parseHhmm(rt['start_time']),
          durationMinutes: min(
              480, max(1, (rt['duration_minutes'] as num?)?.toInt() ?? 30)),
          points: min(100, max(1, (rt['points'] as num?)?.toInt() ?? 10)),
          reminderMinute: _parseHhmm(rt['reminder']),
          tinyVersion: (rt['tiny_version'] as String?)?.trim(),
        ));
      }
    }
    out.add(AiPlanMilestone(
      name: name,
      description: (rm['description'] as String?)?.trim(),
      targetDate: rm['target_date'] is String
          ? DateTime.tryParse(rm['target_date'] as String)
          : null,
      completionBonus:
          min(10000, max(0, (rm['completion_bonus'] as num?)?.toInt() ?? 0)),
      tasks: tasks,
    ));
  }

  final rewards = <AiPlanReward>[];
  final rawRewards = decoded['rewards'];
  if (rawRewards is List) {
    for (final rr in rawRewards) {
      if (rr is! Map<String, dynamic>) continue;
      final rName = (rr['name'] as String?)?.trim();
      if (rName == null || rName.isEmpty) {
        throw const FormatException('A reward is missing its "name".');
      }
      rewards.add(AiPlanReward(
        name: rName,
        description: (rr['description'] as String?)?.trim(),
        pointsThreshold: min(100000,
            max(1, (rr['points_threshold'] as num?)?.toInt() ?? 100)),
      ));
    }
  }

  final plan = AiPlan(milestones: out, rewards: rewards);
  if (plan.isEmpty) {
    throw const FormatException('The plan has no milestones or rewards.');
  }
  return plan;
}

Future<({int milestones, int tasks, int rewards})> applyAiPlan(
    AppDatabase db, AiPlan plan) async {
  var mCount = 0, tCount = 0, rCount = 0;
  for (final (i, m) in plan.milestones.indexed) {
    final mId = _generateId();
    await db.insertMilestone(MilestonesCompanion.insert(
      id: mId,
      name: m.name,
      description: Value(m.description?.isEmpty ?? true ? null : m.description),
      targetDate: Value(m.targetDate),
      completionPoints: Value(m.completionBonus),
      colorIndex: Value(i % 8),
    ));
    mCount++;
    for (final t in m.tasks) {
      await db.insertTask(TasksCompanion.insert(
        id: _generateId(),
        milestoneId: Value(mId),
        name: t.name,
        pointsPerCompletion: Value(t.points),
        recurrence: Value(t.recurrence),
        recurrenceConfig: Value(t.rule().toJsonString()),
        dueDate: Value(t.recurrence == TaskRecurrence.none ? t.dueDate : null),
        startMinute: Value(t.startMinute),
        durationMinutes: Value(t.durationMinutes),
        reminderEnabled: Value(t.reminderMinute != null),
        reminderMinute: Value(t.reminderMinute),
        tinyName: Value(
            (t.tinyVersion?.isEmpty ?? true) ? null : t.tinyVersion),
      ));
      tCount++;
    }
  }
  for (final r in plan.rewards) {
    await db.insertReward(RewardsCompanion.insert(
      id: _generateId(),
      name: r.name,
      description:
          Value(r.description?.isEmpty ?? true ? null : r.description),
      pointsThreshold: r.pointsThreshold,
    ));
    rCount++;
  }
  await NotificationScheduler.reschedule();
  return (milestones: mCount, tasks: tCount, rewards: rCount);
}

String _generateId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final r = Random.secure();
  return List.generate(20, (_) => chars[r.nextInt(chars.length)]).join();
}

// ─── UI ────────────────────────────────────────────────────────────────────

/// Builds the pack, copies it, and offers the share sheet.
Future<void> exportContextPack(BuildContext context, WidgetRef ref) async {
  final db = ref.read(databaseProvider);
  final pack = await buildContextPack(db);
  await Clipboard.setData(ClipboardData(text: pack));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: const Text(
        '🦊 Context pack copied — paste it into ChatGPT/Claude/Gemini.'),
    action: SnackBarAction(
      label: 'SHARE',
      onPressed: () => Share.share(pack, subject: 'Yatta! context pack'),
    ),
  ));
}

/// Paste → parse → preview → apply. [initialText] (e.g. a Pico chat reply)
/// skips the paste step and lands straight on the preview.
Future<void> showAiPlanImportSheet(BuildContext context, WidgetRef ref,
    {String? initialText}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _AiPlanImportSheet(hostRef: ref, initialText: initialText),
  );
}

class _AiPlanImportSheet extends StatefulWidget {
  final WidgetRef hostRef;
  final String? initialText;
  const _AiPlanImportSheet({required this.hostRef, this.initialText});

  @override
  State<_AiPlanImportSheet> createState() => _AiPlanImportSheetState();
}

class _AiPlanImportSheetState extends State<_AiPlanImportSheet> {
  final _ctrl = TextEditingController();
  AiPlan? _plan;
  String? _error;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    final t = widget.initialText;
    if (t != null) {
      _ctrl.text = t;
      try {
        _plan = parseAiPlan(t);
      } on FormatException catch (e) {
        _error = e.message;
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static String _createLabel(AiPlan plan) {
    final parts = [
      if (plan.milestones.isNotEmpty)
        '${plan.milestones.length} MILESTONE${plan.milestones.length == 1 ? '' : 'S'}',
      if (plan.taskCount > 0)
        '${plan.taskCount} TASK${plan.taskCount == 1 ? '' : 'S'}',
      if (plan.rewards.isNotEmpty)
        '${plan.rewards.length} REWARD${plan.rewards.length == 1 ? '' : 'S'}',
    ];
    return 'CREATE ${parts.join(' + ')}';
  }

  void _parse() {
    try {
      setState(() {
        _plan = parseAiPlan(_ctrl.text);
        _error = null;
      });
    } on FormatException catch (e) {
      setState(() {
        _plan = null;
        _error = e.message;
      });
    }
  }

  Future<void> _apply() async {
    final plan = _plan;
    if (plan == null || _applying) return;
    setState(() => _applying = true);
    try {
      final db = widget.hostRef.read(databaseProvider);
      final n = await applyAiPlan(db, plan);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.of(context).pop();
      final parts = [
        if (n.milestones > 0)
          '${n.milestones} milestone${n.milestones == 1 ? '' : 's'}',
        if (n.tasks > 0) '${n.tasks} task${n.tasks == 1 ? '' : 's'}',
        if (n.rewards > 0)
          '${n.rewards} reward${n.rewards == 1 ? '' : 's'}',
      ].join(', ');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🤖 Plan loaded — $parts created. Beep.'),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _applying = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Could not create the plan: ${e.runtimeType}. Try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.appCardSurface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.appBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(child: PicoFigure(size: 64)),
                const SizedBox(height: 8),
                Text('Import AI plan',
                    style: AppTypography.heading2,
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(
                  'Paste the ```json block your AI produced from the context pack.',
                  style: AppTypography.caption
                      .copyWith(color: context.appTextSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                if (plan == null) ...[
                  TextField(
                    controller: _ctrl,
                    maxLines: 8,
                    style: AppTypography.caption,
                    decoration: InputDecoration(
                      hintText: '{ "milestones": [ ... ] }',
                      hintStyle: AppTypography.caption
                          .copyWith(color: context.appTextTertiary),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.missedRed),
                        textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _parse,
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('PREVIEW PLAN'),
                  ),
                ] else ...[
                  for (final m in plan.milestones) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.appPageBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.appBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.name,
                              style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.w800)),
                          if (m.targetDate != null ||
                              m.completionBonus > 0)
                            Text(
                              [
                                if (m.targetDate != null)
                                  'target ${m.targetDate.toString().substring(0, 10)}',
                                if (m.completionBonus > 0)
                                  'bonus ${m.completionBonus} pts',
                              ].join(' · '),
                              style: AppTypography.caption.copyWith(
                                  color: context.appTextSecondary),
                            ),
                          const SizedBox(height: 6),
                          for (final t in m.tasks)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '• ${t.name} — ${t.summary()}'
                                ' · ~${t.durationMinutes}m · ${t.points} pts'
                                '${t.reminderMinute != null ? ' · ⏰' : ''}',
                                style: AppTypography.caption.copyWith(
                                    color: context.appTextSecondary),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (plan.rewards.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.appPageBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.rewardsGold
                                .withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rewards',
                              style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          for (final r in plan.rewards)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '🎁 ${r.name} — ${r.pointsThreshold} pts'
                                '${r.description != null && r.description!.isNotEmpty ? ' · ${r.description}' : ''}',
                                style: AppTypography.caption.copyWith(
                                    color: context.appTextSecondary),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _plan = null),
                          child: const Text('BACK'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _applying ? null : _apply,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white),
                          child: Text(_createLabel(plan)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
