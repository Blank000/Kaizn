import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/services/timer_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';
import '../../shared/providers/active_timer_provider.dart';
import '../../shared/providers/database_provider.dart';
import '../../shared/widgets/stop_timer_sheet.dart';
import '../../shared/widgets/time_ledger_sheet.dart';

/// The whole time ledger, across every task — the screen that exists so the
/// question "when do I actually work, and what keeps interrupting me?" has an
/// answer months from now.
class TimeLedgerScreen extends ConsumerStatefulWidget {
  const TimeLedgerScreen({super.key});

  @override
  ConsumerState<TimeLedgerScreen> createState() => _TimeLedgerScreenState();
}

class _TimeLedgerScreenState extends ConsumerState<TimeLedgerScreen> {
  /// Lookback window, in days. 0 = everything.
  int _days = 30;

  /// Held in state, not recomputed in build — a `DateTime.now()` in build
  /// would hand StreamBuilder a new stream on every rebuild and flash the
  /// spinner each time.
  late Stream<List<TimerEvent>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _buildStream();
  }

  Stream<List<TimerEvent>> _buildStream() {
    final since = _days == 0
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : DateTime.now().subtract(Duration(days: _days));
    return ref.read(databaseProvider).watchTimerEventsSince(since);
  }

  void _setRange(int days) {
    if (days == _days) return;
    setState(() {
      _days = days;
      _stream = _buildStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Time log')),
      body: StreamBuilder<List<TimerEvent>>(
        stream: _stream,
        builder: (context, snap) {
          final events = snap.data;
          if (events == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final runs = groupTimerSessions(events);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _RangePicker(days: _days, onChanged: _setRange),
              const SizedBox(height: 16),
              const _LiveSessions(),
              if (runs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Column(
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 44, color: context.appTextTertiary),
                      const SizedBox(height: 12),
                      Text(
                        'Nothing timed in this window.',
                        style: AppTypography.body
                            .copyWith(color: context.appTextSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Run the stopwatch on a task and its whole '
                        'start-pause-resume story lands here.',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption
                            .copyWith(color: context.appTextTertiary),
                      ),
                    ],
                  ),
                )
              else ...[
                _PatternCard(runs: runs),
                const SizedBox(height: 20),
                Text('Sessions',
                    style: AppTypography.caption.copyWith(
                      color: context.appTextSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    )),
                const SizedBox(height: 8),
                for (final run in runs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TimerSessionCard(run: run, showTaskName: true),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Every session currently on the clock, running or paused.
///
/// This is the safety net for orphans: a paused session whose task isn't
/// rendered anywhere today (a weekly task outside its day, a task in another
/// milestone) would otherwise be invisible and impossible to end. Here it is
/// always reachable.
class _LiveSessions extends ConsumerWidget {
  const _LiveSessions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(timerSessionsProvider).valueOrNull ?? const [];
    if (live.isEmpty) return const SizedBox.shrink();
    final tasks = ref.watch(allTasksProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('On the clock',
            style: AppTypography.caption.copyWith(
              color: context.appTextSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            )),
        const SizedBox(height: 8),
        for (final s in live)
          Builder(builder: (context) {
            final task = tasks?.where((t) => t.id == s.taskId).firstOrNull;
            final color =
                s.isPaused ? AppColors.streakOrange : AppColors.primary;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                        s.isPaused
                            ? Icons.pause_rounded
                            : Icons.timer_rounded,
                        size: 18,
                        color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        task?.name ?? 'Task no longer listed',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      TimerService.formatElapsed(
                          TimerService.cappedElapsedSeconds(s)),
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: task == null
                          ? () => TimerService.clear(s.taskId,
                              kind: TimerEventKind.vanished)
                          : () => showStopTimerSheet(context, ref,
                              taskId: s.taskId),
                      child: const Text('END'),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _RangePicker extends StatelessWidget {
  final int days;
  final ValueChanged<int> onChanged;
  const _RangePicker({required this.days, required this.onChanged});

  static const _options = [
    (7, '7 days'),
    (30, '30 days'),
    (90, '90 days'),
    (0, 'All'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final (value, label) in _options)
          ChoiceChip(
            label: Text(label),
            selected: days == value,
            onSelected: (_) => onChanged(value),
          ),
      ],
    );
  }
}

/// The actual analysis: where the time went, when it happens, and what keeps
/// breaking it up.
class _PatternCard extends StatelessWidget {
  final List<TimerSessionRun> runs;
  const _PatternCard({required this.runs});

  @override
  Widget build(BuildContext context) {
    var active = 0;
    var away = 0;
    var interruptions = 0;
    final byTask = <String, int>{};
    final byHour = <int, int>{};
    for (final r in runs) {
      active += r.activeSeconds;
      away += r.pausedSeconds;
      interruptions += r.interruptionCount;
      byTask[r.taskName] = (byTask[r.taskName] ?? 0) + r.activeSeconds;
      byHour[r.startedAt.hour] = (byHour[r.startedAt.hour] ?? 0) + 1;
    }
    final topTasks = byTask.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final peakHour = byHour.entries.isEmpty
        ? null
        : (byHour.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first;
    final avg = active ~/ runs.length;
    final open = runs.where((r) => r.isOpen).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_rounded,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                TimerService.formatElapsed(active),
                style:
                    AppTypography.heading1.copyWith(color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'across ${runs.length} session'
                  '${runs.length == 1 ? '' : 's'}'
                  '${open == 0 ? '' : ' · $open still on the clock'}',
                  style: AppTypography.caption
                      .copyWith(color: context.appTextSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Line(
            label: 'Typical session',
            value: TimerService.formatElapsed(avg),
          ),
          if (peakHour != null)
            _Line(
              label: 'Most often started',
              value: '${_hourLabel(peakHour.key)} '
                  '(${peakHour.value} session${peakHour.value == 1 ? '' : 's'})',
            ),
          _Line(
            label: 'Interruptions',
            value: interruptions == 0
                ? 'none'
                : '$interruptions · ${TimerService.formatElapsed(away)} away',
          ),
          if (topTasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: context.appBorder),
            const SizedBox(height: 12),
            for (final e in topTasks.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(e.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body),
                    ),
                    Text(
                      TimerService.formatElapsed(e.value),
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _hourLabel(int hour) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h${hour < 12 ? 'am' : 'pm'}';
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  const _Line({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: AppTypography.caption
                    .copyWith(color: context.appTextSecondary)),
          ),
          Text(value,
              style: AppTypography.caption
                  .copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
