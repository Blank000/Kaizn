import 'package:flutter/material.dart';

/// One-shot entrance: the child fades in and rises ~8% of its height,
/// delayed by [index] steps — so a list ARRIVES (dominoes) instead of
/// appearing. Plays once per element lifetime: stream-driven rebuilds of
/// the same keyed child never replay it, while genuinely new items (a
/// fresh capture landing in Up Next) get their own little entrance.
///
/// Put the list-diffing key ON THIS WIDGET (not the child) so Flutter
/// matches rows the same way it did before wrapping.
class StaggerIn extends StatefulWidget {
  final int index;
  final Widget child;

  const StaggerIn({super.key, required this.index, required this.child});

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  static const _stepMs = 40;
  static const _maxSteps = 12; // late rows shouldn't wait forever

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(
      Duration(milliseconds: _stepMs * widget.index.clamp(0, _maxSteps)),
      () {
        if (mounted) _ctrl.forward();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(curve),
        child: widget.child,
      ),
    );
  }
}
