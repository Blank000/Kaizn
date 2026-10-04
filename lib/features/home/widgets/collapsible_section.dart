import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_colors.dart';

/// A Home section that opens and closes — the design approved from the
/// collapse mockup.
///
/// The whole header row is the tap target, not just the chevron, so it is
/// easy to hit with a thumb. And **closed is not hidden**: a closed section
/// shrinks to a one-line [peek] so you never lose sight of what's there.
class CollapsibleSection extends StatelessWidget {
  final String label;
  final int count;

  /// Short right-aligned note, e.g. "~1h 20m". Optional.
  final String? meta;

  /// Green count pill for the section that matters today; grey otherwise.
  final bool accent;

  final bool open;
  final ValueChanged<bool> onToggle;

  /// What a closed section still says about itself.
  final Widget peek;

  final List<Widget> children;

  const CollapsibleSection({
    super.key,
    required this.label,
    required this.count,
    required this.open,
    required this.onToggle,
    required this.peek,
    required this.children,
    this.meta,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    final dur = still ? Duration.zero : const Duration(milliseconds: 220);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: open,
          label: '$label, $count. ${open ? 'Collapse' : 'Expand'}',
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              splashColor: AppColors.primary.withValues(alpha: 0.10),
              highlightColor: AppColors.primary.withValues(alpha: 0.08),
              onTap: () {
                HapticFeedback.selectionClick();
                onToggle(!open);
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 2, 8),
                child: Row(
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: AppTypography.caption.copyWith(
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800,
                        color: context.appTextSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CountPill(count: count, accent: accent),
                    const Spacer(),
                    if (meta != null) ...[
                      Text(
                        meta!,
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: context.appTextTertiary,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      width: 28,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.appBorder.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: AnimatedRotation(
                        // Points down when closed, up when open.
                        turns: open ? 0.5 : 0,
                        duration: dur,
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedSize(
          duration: dur,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: still ? Duration.zero : const Duration(milliseconds: 160),
            child: open
                ? Column(
                    key: const ValueKey('open'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  )
                : Padding(
                    key: const ValueKey('closed'),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      // Tapping the peek opens the section too — it's the
                      // obvious thing to try.
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onToggle(true);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: _PeekBox(child: peek),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  final int count;
  final bool accent;
  const _CountPill({required this.count, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: accent
            ? AppColors.primary.withValues(alpha: 0.16)
            : context.appBorder.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: AppTypography.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: accent ? AppColors.primaryDark : context.appTextSecondary,
        ),
      ),
    );
  }
}

class _PeekBox extends StatelessWidget {
  final Widget child;
  const _PeekBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorder(color: context.appBorder),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.appCardSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }
}

/// The dashed outline that marks a peek as "folded away", so it never reads
/// as a task card you could tap to complete.
class _DashedBorder extends CustomPainter {
  final Color color;
  _DashedBorder({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

/// One-line "first name bold, then the rest, then +N" summary used by every
/// closed section.
Widget peekLine(
  BuildContext context, {
  String? prefix,
  required List<String> names,
  String? firstSuffix,
  int show = 3,
}) {
  final base = AppTypography.caption.copyWith(
    color: context.appTextSecondary,
    fontSize: 12.5,
  );
  if (names.isEmpty) return Text('Nothing here', style: base);
  final rest = names.skip(1).take(show - 1).toList();
  final more = names.length - 1 - rest.length;
  return Text.rich(
    TextSpan(
      style: base,
      children: [
        if (prefix != null) TextSpan(text: '$prefix '),
        TextSpan(
          text: names.first,
          style: base.copyWith(
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
        ),
        if (firstSuffix != null) TextSpan(text: ' · $firstSuffix'),
        if (rest.isNotEmpty)
          TextSpan(
            text: prefix != null
                ? ', then ${rest.join(', ')}'
                : ', ${rest.join(', ')}',
          ),
        if (more > 0) TextSpan(text: ' +$more'),
      ],
    ),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  );
}
