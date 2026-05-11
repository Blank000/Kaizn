import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A `Text` widget whose integer value animates smoothly between updates.
///
/// On first mount the number tweens from 0 → value (a satisfying first-open
/// fanfare). On subsequent rebuilds with a new `value`, it tweens from the
/// previous value to the new one. Pass [formatter] for thousands separators
/// or other decimal patterns.
class AnimatedNumber extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  final NumberFormat? formatter;
  final String? prefix;
  final String? suffix;

  const AnimatedNumber({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 600),
    this.formatter,
    this.prefix,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // begin omitted (null) so subsequent rebuilds animate from the current
      // animated value to the new end, instead of jumping back to 0.
      tween: Tween<double>(end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) {
        final i = v.toInt();
        final text = formatter?.format(i) ?? '$i';
        return Text(
          '${prefix ?? ''}$text${suffix ?? ''}',
          style: style,
        );
      },
    );
  }
}
