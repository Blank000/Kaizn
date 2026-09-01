import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/context_colors.dart';
import '../../shared/widgets/ren_figure.dart';

/// The floating Ask-Ren control: a small Ren medallion pinned to the right
/// edge above the bottom nav, draggable vertically (position remembered for
/// the session), tap → the chat. Lives in the nav shell so it floats over
/// every tab.
class AskRenBubble extends StatefulWidget {
  const AskRenBubble({super.key});

  @override
  State<AskRenBubble> createState() => _AskRenBubbleState();
}

class _AskRenBubbleState extends State<AskRenBubble> {
  /// Vertical position as a fraction of the safe height; session-remembered.
  static double _yFraction = 0.62;

  static DateTime _lastOpen = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      // Keyboard/split-screen can shrink the body below the drag band —
      // hide rather than clamp with inverted bounds (which throws).
      if (box.maxHeight < 280) return const SizedBox.shrink();
      // Keep the bubble clear of the app bar and the FAB corner.
      const minY = 90.0;
      final maxY = box.maxHeight - 170.0;
      final y = (_yFraction * box.maxHeight).clamp(minY, maxY);
      return Stack(
        children: [
          Positioned(
            right: 10,
            top: y,
            child: GestureDetector(
              onPanUpdate: (d) => setState(() {
                _yFraction =
                    ((y + d.delta.dy).clamp(minY, maxY)) / box.maxHeight;
              }),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    // Debounce: a double-tap must not stack two chats.
                    final now = DateTime.now();
                    if (now.difference(_lastOpen).inMilliseconds < 600) {
                      return;
                    }
                    _lastOpen = now;
                    HapticFeedback.selectionClick();
                    context.push('/ask-ren');
                  },
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.appCardSurface,
                      border: Border.all(
                          color:
                              AppColors.primary.withValues(alpha: 0.5),
                          width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                        child: RenFigure(size: 40, respectToggle: false)),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
