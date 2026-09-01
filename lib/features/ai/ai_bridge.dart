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
import '../../shared/widgets/ren_figure.dart';

/// The AI bridge (V1 of "connect my own AI"): no servers, no API keys —
/// works with any chat AI the user already pays for (ChatGPT, Claude,
/// Gemini).
///
/// Export: a CONTEXT PACK — the user's live data plus instructions and the
/// exact plan-JSON schema — pasted into the AI of their choice.
/// Import: the AI's plan JSON pasted back, parsed, PREVIEWED, and only then
/// applied through the same insert APIs the forms use. The AI proposes; the
/// user approves; the app executes.

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
  ]
}''');
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
/// Throws [FormatException] with a human message on anything unusable.
List<AiPlanMilestone> parseAiPlan(String raw) {
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
  final rawMilestones = decoded['milestones'] ?? [decoded];
  if (rawMilestones is! List || rawMilestones.isEmpty) {
    throw const FormatException('The plan has no milestones.');
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
  return out;
}

Future<({int milestones, int tasks})> applyAiPlan(
    AppDatabase db, List<AiPlanMilestone> plan) async {
  var mCount = 0, tCount = 0;
  for (final (i, m) in plan.indexed) {
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
  await NotificationScheduler.reschedule();
  return (milestones: mCount, tasks: tCount);
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

/// Paste → parse → preview → apply.
Future<void> showAiPlanImportSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AiPlanImportSheet(hostRef: ref),
  );
}

class _AiPlanImportSheet extends StatefulWidget {
  final WidgetRef hostRef;
  const _AiPlanImportSheet({required this.hostRef});

  @override
  State<_AiPlanImportSheet> createState() => _AiPlanImportSheetState();
}

class _AiPlanImportSheetState extends State<_AiPlanImportSheet> {
  final _ctrl = TextEditingController();
  List<AiPlanMilestone>? _plan;
  String? _error;
  bool _applying = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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
    final db = widget.hostRef.read(databaseProvider);
    final n = await applyAiPlan(db, plan);
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          '🦊 “Name the mountain — watch the steps.” ${n.milestones} milestone${n.milestones == 1 ? '' : 's'}, ${n.tasks} task${n.tasks == 1 ? '' : 's'} created.'),
    ));
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
                const Center(child: RenFigure(size: 64)),
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
                  for (final m in plan) ...[
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
                          child: Text(
                              'CREATE ${plan.fold<int>(0, (s, m) => s + m.tasks.length)} TASKS'),
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
