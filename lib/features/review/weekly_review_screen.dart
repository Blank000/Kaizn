import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/app_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';
import '../../shared/providers/database_provider.dart';
import '../../shared/widgets/ren_figure.dart';

/// The Weekly Review — Ren's own room (Chapter Eight of the dojo storyline).
/// Three unhurried scrolls: what burned, what slipped (with the miss reasons
/// he collected all week), and ONE claw to sharpen next week. Quiet by
/// design: no confetti, no scores, no judgment — the fire and Kai stay home.
class WeeklyReviewScreen extends ConsumerStatefulWidget {
  const WeeklyReviewScreen({super.key});

  @override
  ConsumerState<WeeklyReviewScreen> createState() =>
      _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends ConsumerState<WeeklyReviewScreen> {
  final _pager = PageController();
  final _clawCtrl = TextEditingController();
  int _page = 0;
  String? _pickedSuggestion;
  bool _stamping = false;

  static const _reasonLabels = {
    'not_seen': "Didn't see it",
    'too_hard': 'Too hard that day',
    'no_time': 'No time',
    'no_mood': "Didn't feel like it",
  };

  static const _reasonCounsel = {
    'not_seen': '“The task hid from you. Give it a louder bell.”',
    'too_hard': '“It was too big on the hard days. Shrink it — keep it.”',
    'no_time': '“The days were crowded. Smaller steps fit crowded days.”',
    'no_mood': '“Mood arrives late. Action first; mood follows.”',
  };

  static const _reasonSuggestion = {
    'not_seen': 'Set a reminder on the task I keep missing',
    'too_hard': 'Give my hardest task a 2-minute version',
    'no_time': 'Shrink one task to fit a crowded day',
    'no_mood': 'Start with the easiest task each day',
  };

  @override
  void dispose() {
    _pager.dispose();
    _clawCtrl.dispose();
    super.dispose();
  }

  Future<void> _stamp() async {
    if (_stamping) return;
    final claw = _clawCtrl.text.trim().isNotEmpty
        ? _clawCtrl.text.trim()
        : _pickedSuggestion;
    if (claw == null || claw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pick or write the one thing — just one.')));
      return;
    }
    setState(() => _stamping = true);
    await AppPrefs.setWeeklyClaw(claw);
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('🦊 Stamped. One claw, all week — it lives on Home.')));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final completions =
        ref.watch(recentCompletionsAllProvider).valueOrNull;
    final tasks = ref.watch(allTasksProvider).valueOrNull;
    if (completions == null || tasks == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    // The week under review: the last 7 calendar days including today.
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 6));
    final week = completions
        .where((c) => !c.completedOn.isBefore(start))
        .toList();
    final real = week.where((c) => !c.isSkip && !c.isNd).toList();
    final misses = week.where((c) => c.isNd).toList();

    final points = real.fold<int>(0, (s, c) => s + c.pointsEarned);
    final daysShowed = real
        .map((c) =>
            '${c.completedOn.year}-${c.completedOn.month}-${c.completedOn.day}')
        .toSet()
        .length;

    final taskNames = {for (final t in tasks) t.id: t.name};
    String? topTask;
    var topCount = 0;
    final perTask = <String, int>{};
    for (final c in real) {
      final n = (perTask[c.taskId] ?? 0) + 1;
      perTask[c.taskId] = n;
      if (n > topCount) {
        topCount = n;
        topTask = taskNames[c.taskId];
      }
    }

    final reasonCounts = <String, int>{};
    for (final m in misses) {
      final r = m.missReason;
      if (r != null) reasonCounts[r] = (reasonCounts[r] ?? 0) + 1;
    }
    String? dominantReason;
    var domCount = 0;
    reasonCounts.forEach((r, n) {
      if (n > domCount) {
        domCount = n;
        dominantReason = r;
      }
    });

    final pages = [
      _scroll(
        context,
        title: 'What burned',
        renLine: daysShowed >= 5
            ? '“You showed up $daysShowed days of seven. I bow to that.”'
            : daysShowed > 0
                ? '“$daysShowed ${daysShowed == 1 ? 'day' : 'days'} of showing up. We build from here.”'
                : '“A quiet week. The path is still here.”',
        children: [
          _bigStat(context, '${real.length}',
              real.length == 1 ? 'task done' : 'tasks done'),
          _bigStat(context, '+$points', 'points earned'),
          _bigStat(context, '$daysShowed / 7', 'days showed up'),
          if (topTask != null) ...[
            const SizedBox(height: 16),
            Text('Strongest habit: $topTask ($topCount×)',
                style: AppTypography.body
                    .copyWith(color: context.appTextSecondary),
                textAlign: TextAlign.center),
          ],
        ],
      ),
      _scroll(
        context,
        title: 'What slipped',
        renLine: misses.isEmpty
            ? '“Nothing slipped this week. Walk on.”'
            : dominantReason != null
                ? _reasonCounsel[dominantReason]!
                : '“Falls happen. Naming them is optional.”',
        children: [
          if (misses.isEmpty)
            Text('No misses. Truly.',
                style: AppTypography.body
                    .copyWith(color: context.appTextSecondary),
                textAlign: TextAlign.center)
          else ...[
            _bigStat(context, '${misses.length}',
                misses.length == 1 ? 'miss — that is data' : 'misses — all data'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final e in reasonCounts.entries)
                  Chip(
                    label: Text(
                        '${e.value}× ${_reasonLabels[e.key] ?? e.key}',
                        style: AppTypography.caption),
                  ),
              ],
            ),
          ],
        ],
      ),
      _scroll(
        context,
        title: 'One claw',
        renLine: '“We do not fix the week. We sharpen one claw.”',
        children: [
          Text(
            'Pick ONE adjustment for next week. Not three. One.',
            style:
                AppTypography.body.copyWith(color: context.appTextSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final s in {
                if (dominantReason != null)
                  _reasonSuggestion[dominantReason]!,
                'Move one task to the morning',
                'Choose one rest day in advance',
              })
                ChoiceChip(
                  label: Text(s, style: AppTypography.caption),
                  selected: _pickedSuggestion == s,
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  onSelected: (sel) => setState(() {
                    _pickedSuggestion = sel ? s : null;
                    if (sel) _clawCtrl.clear();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _clawCtrl,
            textAlign: TextAlign.center,
            style: AppTypography.body,
            decoration: InputDecoration(
              hintText: '…or write your own',
              hintStyle: AppTypography.body
                  .copyWith(color: context.appTextTertiary),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onChanged: (v) {
              if (v.isNotEmpty && _pickedSuggestion != null) {
                setState(() => _pickedSuggestion = null);
              }
            },
          ),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(
        title: Text('Sunday review', style: AppTypography.heading2),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pager,
                onPageChanged: (i) => setState(() => _page = i),
                children: pages,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page
                          ? AppColors.primary
                          : context.appBorder,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _page < 2
                      ? () => _pager.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic)
                      : _stamping
                          ? null
                          : _stamp,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: Text(_page < 2 ? 'NEXT SCROLL' : '🦊 STAMP IT'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scroll(BuildContext context,
      {required String title,
      required String renLine,
      required List<Widget> children}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Column(
        children: [
          const Center(child: RenFigure(size: 108)),
          const SizedBox(height: 8),
          Text(renLine,
              style: AppTypography.body.copyWith(
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Text(title.toUpperCase(),
              style: AppTypography.caption.copyWith(
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
                color: context.appTextSecondary,
              )),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _bigStat(BuildContext context, String value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Text(value,
              style: AppTypography.display
                  .copyWith(fontSize: 40, color: AppColors.primary)),
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: context.appTextSecondary)),
        ],
      ),
    );
  }
}
