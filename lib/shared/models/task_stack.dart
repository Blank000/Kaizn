import '../../core/database/database.dart';

/// Helpers for habit-stack chains ("task queues"). A queue is a chain of
/// tasks linked by `stackedAfterTaskId`; only the head is actionable at any
/// moment, the rest surface link by link as the chain completes.
///
/// A task counts as a QUEUE MEMBER only when it has an anchor AND no start
/// time of its own — a stacked task's start time IS "when the anchor
/// finishes". (Tasks with their own startMinute are legacy/independent and
/// are treated as normal scheduled tasks everywhere.)
bool isQueueMember(Task t) =>
    t.stackedAfterTaskId != null && t.startMinute == null;

/// anchor id → active queue-member tasks stacked directly on it.
Map<String, List<Task>> stackChildrenByAnchor(List<Task> tasks) {
  final map = <String, List<Task>>{};
  for (final t in tasks) {
    if (t.status != TaskStatus.active) continue;
    if (!isQueueMember(t)) continue;
    (map[t.stackedAfterTaskId!] ??= []).add(t);
  }
  return map;
}

/// All queue members behind [head] (its whole downstream chain, breadth
/// first), filtered to the ones [countsToday] says are part of today's
/// queue. Cycle-safe via visited set + hard cap.
List<Task> queueBehind(
  Task head,
  Map<String, List<Task>> childrenByAnchor,
  bool Function(Task) countsToday,
) {
  final out = <Task>[];
  final visited = <String>{head.id};
  var frontier = <String>[head.id];
  while (frontier.isNotEmpty && visited.length < 50) {
    final next = <String>[];
    for (final id in frontier) {
      for (final child in childrenByAnchor[id] ?? const <Task>[]) {
        if (!visited.add(child.id)) continue;
        if (countsToday(child)) out.add(child);
        next.add(child.id);
      }
    }
    frontier = next;
  }
  return out;
}

/// Total minutes for [head] plus its queue — what the merged timeline block
/// and the "~45m" hint show.
int queueTotalMinutes(Task head, List<Task> queue) =>
    head.durationMinutes +
    queue.fold<int>(0, (sum, t) => sum + t.durationMinutes);

/// Compact duration for meta lines: "45m", "1h 30m".
String formatQueueMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
