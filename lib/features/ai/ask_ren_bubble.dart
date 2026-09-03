import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/app_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/context_colors.dart';
import '../../shared/widgets/pico_figure.dart';

/// The floating AI companion: Pico himself (no medallion), hovering over
/// every tab, draggable ANYWHERE on screen — left, right, top, bottom.
/// Position is remembered for the session. Tap → the chat.
class AskRenBubble extends StatefulWidget {
  const AskRenBubble({super.key});

  @override
  State<AskRenBubble> createState() => _AskRenBubbleState();
}

class _AskRenBubbleState extends State<AskRenBubble> {
  /// Position as fractions of the body size; session-remembered.
  static Offset _frac = const Offset(0.97, 0.60);

  static DateTime _lastOpen = DateTime.fromMillisecondsSinceEpoch(0);

  // Big enough to notice, small enough to never block a task tile.
  static const _h = 76.0;
  static const _w = _h * 210 / 250;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      // Keyboard/split-screen can shrink the body — hide rather than
      // clamp with inverted bounds.
      if (box.maxHeight < 280 || box.maxWidth < 160) {
        return const SizedBox.shrink();
      }
      final minX = 4.0, maxX = math.max(minX, box.maxWidth - _w - 4);
      final minY = 8.0, maxY = math.max(minY, box.maxHeight - _h - 12);
      final pos = Offset(
        (_frac.dx * box.maxWidth).clamp(minX, maxX),
        (_frac.dy * box.maxHeight).clamp(minY, maxY),
      );
      return Stack(
        children: [
          Positioned(
            left: pos.dx,
            top: pos.dy,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => setState(() {
                _frac = Offset(
                  ((pos.dx + d.delta.dx).clamp(minX, maxX)) / box.maxWidth,
                  ((pos.dy + d.delta.dy).clamp(minY, maxY)) / box.maxHeight,
                );
              }),
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
              child: SizedBox(
                width: _w,
                height: _h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const PicoFigure(size: _h),
                    // "Needs your key" hint until the chat is set up.
                    if ((AppPrefs.aiApiKeySync ?? '').isEmpty)
                      Positioned(
                        right: -2,
                        top: 0,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.streakOrange,
                            border: Border.all(
                                color: context.appPageBackground,
                                width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
