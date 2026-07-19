import 'package:flutter/material.dart';

/// Progress bar that SURGES to its new value with an easeOutBack spring
/// instead of jumping (goal-gradient effect: the animated push toward the
/// end of the bar amplifies perceived progress). Fill overshoot is clamped
/// at the container edge.
class SpringProgressBar extends StatelessWidget {
  final double value; // 0–1
  final double height;
  final Color color;
  final Color backgroundColor;

  const SpringProgressBar({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Container(color: backgroundColor),
              TweenAnimationBuilder<double>(
                tween: Tween(end: value.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 550),
                curve: Curves.easeOutBack,
                builder: (_, v, __) => Container(
                  width: constraints.maxWidth * v.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
