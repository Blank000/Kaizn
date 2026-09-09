import 'package:flutter/material.dart';

import '../../core/database/database.dart';
import '../../core/services/timer_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';

/// One reconstructed stopwatch session: the events that share a session id,
/// plus the numbers worth reading at a glance.
class TimerSessionRun {
  final String sessionId;
  final String taskId;
  final String taskName;
  final List<TimerEvent> events;

  const TimerSessionRun({
    required this.sessionId,
    required this.taskId,
    required this.taskName,
    required this.events,
  });

  DateTime get startedAt => events.first.at;
  DateTime get lastEventAt => events.last.at;

  /// Still on the clock — no terminal event recorded.
  bool get isOpen => !TimerEventKind.isTerminal(events.last.kind);

  /// Seconds actually spent working, i.e. excluding paused stretches.
  ///
  /// Every event carries the clock reading at that moment, so the high-water
  /// mark is the total — plus, if the session is still ticking, the time
  /// since that last event. Without that tail a two-hour session in progress
  /// would read as 00:00, because `start` logs a zero.
  int get activeSeconds {
    var best = 0;
    for (final e in events) {
      if (e.elapsedSeconds > best) best = e.elapsedSeconds;
    }
    final last = events.last;
    if (last.kind == TimerEventKind.start ||
        last.kind == TimerEventKind.resume) {
      final since = DateTime.now().difference(last.at).inSeconds;
      if (since > 0) best += since;
    }
    return best;
  }

  /// Wall-clock span from first to last event — active time plus every
  /// interruption. The gap between the two is the interesting part.
  int get spanSeconds => lastEventAt.difference(startedAt).inSeconds.abs();

  int get pausedSeconds {
    final gap = spanSeconds - activeSeconds;
    return gap > 0 ? gap : 0;
  }

  int get pauseCount =>
      events.where((e) => e.kind == TimerEventKind.pause).length;

  int get interruptionCount => events
      .where((e) =>
          e.kind == TimerEventKind.pause || e.kind == TimerEventKind.autoPause)
      .length;

  /// How the session ended, or null while it's still open.
  String? get outcome => isOpen ? null : events.last.kind;
}

/// Groups a flat event list into sessions, newest first.
List<TimerSessionRun> groupTimerSessions(List<TimerEvent> events) {
  final byId = <String, List<TimerEvent>>{};
  for (final e in events) {
    byId.putIfAbsent(e.sessionId, () => []).add(e);
  }
  final runs = <TimerSessionRun>[];
  for (final entry in byId.entries) {
    final list = [...entry.value]..sort((a, b) => a.at.compareTo(b.at));
    runs.add(TimerSessionRun(
      sessionId: entry.key,
      taskId: list.first.taskId,
      taskName: list.last.taskName,
      events: list,
    ));
  }
  runs.sort((a, b) => b.startedAt.compareTo(a.startedAt));
  return runs;
}

/// The per-task time ledger: every session, every pause, every resume.
Future<void> showTimeLedgerSheet(
  BuildContext context,
  AppDatabase db,
  Task task,
) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _TimeLedgerSheet(task: task, db: db),
  );
}

class _TimeLedgerSheet extends StatelessWidget {
  final Task task;

  /// The database, not a WidgetRef: the tile that opened this sheet may be
  /// disposed while it's up, and `ref.read` after that throws.
  final AppDatabase db;

  const _TimeLedgerSheet({required this.task, required this.db});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: context.appCardSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: StreamBuilder<List<TimerEvent>>(
            stream: db.watchTimerEventsForTask(task.id),
            builder: (ctx, snap) {
              final events = snap.data;
              if (events == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final runs = groupTimerSessions(events);
              return CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: Column(
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
                          Text('Time log',
                              style: AppTypography.heading2,
                              textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          Text(
                            task.name,
                            style: AppTypography.caption
                                .copyWith(color: context.appTextSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          if (runs.isNotEmpty) _Summary(runs: runs),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  if (runs.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.timer_outlined,
                                size: 40, color: context.appTextTertiary),
                            const SizedBox(height: 12),
                            Text(
                              'No timed sessions yet.',
                              style: AppTypography.body.copyWith(
                                  color: context.appTextSecondary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Start the stopwatch on this task and every '
                              'start, pause and resume lands here.',
                              style: AppTypography.caption.copyWith(
                                  color: context.appTextTertiary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => Padding(
                          padding: EdgeInsets.fromLTRB(
                              24, 0, 24, i == runs.length - 1 ? 24 : 12),
                          child: TimerSessionCard(run: runs[i]),
                        ),
                        childCount: runs.length,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final List<TimerSessionRun> runs;
  const _Summary({required this.runs});

  @override
  Widget build(BuildContext context) {
    var active = 0;
    var paused = 0;
    var interruptions = 0;
    for (final r in runs) {
      active += r.activeSeconds;
      paused += r.pausedSeconds;
      interruptions += r.interruptionCount;
    }
    final avg = runs.isEmpty ? 0 : active ~/ runs.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _Stat(label: 'Sessions', value: '${runs.length}'),
          _Stat(
              label: 'Active', value: TimerService.formatElapsed(active)),
          _Stat(label: 'Avg', value: TimerService.formatElapsed(avg)),
          _Stat(
            label: 'Away',
            value: paused == 0 ? '—' : TimerService.formatElapsed(paused),
            hint: interruptions == 0 ? null : '$interruptions breaks',
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  const _Stat({required this.label, required this.value, this.hint});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: context.appTextSecondary, fontSize: 11)),
          if (hint != null)
            Text(hint!,
                style: AppTypography.caption
                    .copyWith(color: context.appTextTertiary, fontSize: 10)),
        ],
      ),
    );
  }
}

/// One session, expanded into its timeline of events.
class TimerSessionCard extends StatelessWidget {
  final TimerSessionRun run;

  /// Prefix each card with the task name — used by the cross-task screen.
  final bool showTaskName;

  const TimerSessionCard({
    super.key,
    required this.run,
    this.showTaskName = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: context.appBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  showTaskName
                      ? run.taskName
                      : formatLedgerDate(run.startedAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                TimerService.formatElapsed(run.activeSeconds),
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w800,
                  color: run.isOpen
                      ? AppColors.primary
                      : context.appTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [
              if (showTaskName) formatLedgerDate(run.startedAt),
              '${formatLedgerTime(run.startedAt)} → '
                  '${run.isOpen ? 'now' : formatLedgerTime(run.lastEventAt)}',
              if (run.pausedSeconds > 30)
                '${TimerService.formatElapsed(run.pausedSeconds)} away',
              if (run.outcome != null &&
                  run.outcome != TimerEventKind.complete)
                TimerEventKind.label(run.outcome!).toLowerCase(),
            ].join(' · '),
            style: AppTypography.caption
                .copyWith(color: context.appTextTertiary),
          ),
          const SizedBox(height: 10),
          ...run.events.map((e) => _EventRow(event: e)),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final TimerEvent event;
  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _visual(context, event.kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          SizedBox(
            width: 58,
            child: Text(
              formatLedgerTime(event.at),
              style: AppTypography.caption.copyWith(
                color: context.appTextSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Text(
              TimerEventKind.label(event.kind),
              style: AppTypography.caption
                  .copyWith(color: context.appTextPrimary),
            ),
          ),
          Text(
            TimerService.formatElapsed(event.elapsedSeconds),
            style: AppTypography.caption.copyWith(
              color: context.appTextTertiary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _visual(BuildContext context, String kind) {
    switch (kind) {
      case TimerEventKind.start:
      case TimerEventKind.resume:
        return (Icons.play_arrow_rounded, AppColors.primary);
      case TimerEventKind.pause:
      case TimerEventKind.autoPause:
        return (Icons.pause_rounded, AppColors.streakOrange);
      case TimerEventKind.complete:
        return (Icons.check_rounded, AppColors.primary);
      case TimerEventKind.discard:
      case TimerEventKind.vanished:
        return (Icons.close_rounded, Colors.red.shade400);
      default:
        return (Icons.stop_rounded, context.appTextTertiary);
    }
  }
}

const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatLedgerDate(DateTime d) {
  final today = DateTime.now();
  final isToday =
      d.year == today.year && d.month == today.month && d.day == today.day;
  final y = today.subtract(const Duration(days: 1));
  final isYesterday = d.year == y.year && d.month == y.month && d.day == y.day;
  if (isToday) return 'Today';
  if (isYesterday) return 'Yesterday';
  return '${_weekdayNames[d.weekday - 1]}, '
      '${_monthNames[d.month - 1]} ${d.day}';
}

String formatLedgerTime(DateTime d) {
  final h24 = d.hour;
  final h = h24 % 12 == 0 ? 12 : h24 % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${h24 < 12 ? 'am' : 'pm'}';
}
