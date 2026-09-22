/// The companion's voice.
///
/// Lifted out of the retired `ren_figure.dart` when Master Ren was
/// cut and Zuzu took over every surface. The lines themselves never
/// referenced a fox: they are composed from real data (remaining task
/// names, counts, hour of day, yesterday's misses), which is exactly
/// why the character could change without rewriting a word of copy.
class ZuzuLines {
  static const _rest = [
    'Even fire rests. That is how it stays fire.',
    'Stillness is also training.',
    'A bow kept strung loses its spring.',
  ];
  static const _comeback = [
    'You returned. That is the whole lesson.',
    'The path waited. It always does.',
    'Tea first. Then one small step.',
  ];
  static const _empty = [
    'A blank scroll is not empty. It is ready.',
    'One task. Choose it well.',
    'A fox does not chase two rabbits.',
  ];

  static String rest() => _pick(_rest);
  static String comeback() => _pick(_comeback);
  static String empty() => _pick(_empty);

  static String _pick(List<String> pool) {
    final d = DateTime.now();
    return pool[(d.year * 372 + d.month * 31 + d.day) % pool.length];
  }

  /// The Sensei Post: Ren's accountability line, computed from the actual
  /// state of the day. Specific over generic — he names counts and tasks,
  /// notices yesterday's falls, and marks the hour. Watchful, never guilting.
  static String accountability({
    required int hour,
    required int done,
    required int remaining,
    required int missedToday,
    required int missedYesterday,
    required List<String> nextNames,
  }) {
    String names() {
      if (nextNames.isEmpty) return '';
      final shown = nextNames.take(2).join(', ');
      final more = nextNames.length - 2;
      return more > 0 ? '$shown +$more more' : shown;
    }

    if (remaining == 0 && missedToday == 0 && done > 0) {
      return '“Everything done. Today I have nothing to teach.”';
    }
    if (remaining == 0 && missedToday > 0) {
      return '“The day closes with $missedToday missed. Tomorrow we stand ${missedToday == 1 ? 'it' : 'them'} back up.”';
    }
    if (missedYesterday > 0 && done == 0 && hour < 12) {
      return '“Yesterday took ${missedYesterday == 1 ? 'a fall' : '$missedYesterday falls'}. Today stands ${missedYesterday == 1 ? 'it' : 'them'} up — start with ${nextNames.isNotEmpty ? nextNames.first : 'one task'}.”';
    }
    if (done == 0 && hour >= 17) {
      return '“The scroll is still blank and the sun is low. One line: ${names()}.”';
    }
    if (done == 0 && hour < 12) {
      return '“$remaining ${remaining == 1 ? 'task stands' : 'tasks stand'} before you: ${names()}. Begin with the smallest.”';
    }
    if (done == 0) {
      return '“Nothing logged yet. The day is still yours — barely. ${names()} waits.”';
    }
    if (hour >= 17) {
      return '“$done down. ${names()} ${remaining == 1 ? 'remains' : 'remain'}. Finish the day standing.”';
    }
    return '“$done down, $remaining to go. I am watching — keep walking.”';
  }
}
