import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/level_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_colors.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../shared/widgets/living_flame.dart';

/// Share your progress with a PERSON you choose — a witness, not a
/// leaderboard (SDT relatedness, kill-list compliant: nothing compares you
/// to anyone). Renders a branded card, then hands a PNG to the OS share
/// sheet. No accounts, no backend — the image is generated on-device.
Future<void> showShareProgressSheet(
    BuildContext context, WidgetRef ref) async {
  final db = ref.read(databaseProvider);
  final streak = await db.getStreak();
  final weekPoints = await db.watchThisWeekPoints().first;
  final weekTasks = await db.watchThisWeekCompletionCount().first;
  final lifetime = await db.getLifetimeEarnedPoints();
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ShareSheet(
      streakDay: streak?.currentStreak ?? 0,
      weekPoints: weekPoints,
      weekTasks: weekTasks,
      level: LevelService.getLevel(lifetime),
    ),
  );
}

class _ShareSheet extends StatefulWidget {
  final int streakDay;
  final int weekPoints;
  final int weekTasks;
  final LevelInfo level;

  const _ShareSheet({
    required this.streakDay,
    required this.weekPoints,
    required this.weekTasks,
    required this.level,
  });

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/yatta_week_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      HapticFeedback.lightImpact();
      await Share.shareXFiles(
        [XFile(file.path)],
        text: widget.streakDay > 0
            ? 'Day ${widget.streakDay} of my streak on Yatta! 🔥'
            : 'My week on Yatta! ⭐',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appCardSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Text('Share your progress',
                style: AppTypography.heading2,
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              'A snapshot for someone who cheers for you 📣',
              style: AppTypography.caption
                  .copyWith(color: context.appTextSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // The card itself — captured at 3x for a crisp share image.
            Center(
              child: RepaintBoundary(
                key: _cardKey,
                child: _ProgressCard(
                  streakDay: widget.streakDay,
                  weekPoints: widget.weekPoints,
                  weekTasks: widget.weekTasks,
                  level: widget.level,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _sharing ? null : _share,
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: Text(_sharing ? 'PREPARING…' : 'SHARE'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The shareable image: dark brand card, flame front and center. Colors are
/// hardcoded (not theme-dependent) so the export looks identical for
/// everyone, in any app theme.
class _ProgressCard extends StatelessWidget {
  final int streakDay;
  final int weekPoints;
  final int weekTasks;
  final LevelInfo level;

  const _ProgressCard({
    required this.streakDay,
    required this.weekPoints,
    required this.weekTasks,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF15202B), Color(0xFF0E1621)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LivingFlame(streak: streakDay, size: 64),
          const SizedBox(height: 10),
          Text(
            streakDay > 0 ? 'DAY $streakDay STREAK' : 'BUILDING MOMENTUM',
            style: AppTypography.heading1.copyWith(
              color: AppColors.streakOrange,
              fontSize: 22,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Stat(value: '$weekTasks', label: 'TASKS THIS WEEK'),
              Container(
                width: 1,
                height: 30,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: Colors.white12,
              ),
              _Stat(value: '+$weekPoints', label: 'PTS THIS WEEK'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '🎖️ Level ${level.level} · ${level.title}',
            style: AppTypography.caption.copyWith(
                color: Colors.white70, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Text(
            'Yatta! 💥',
            style: AppTypography.body.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: AppTypography.heading1
                .copyWith(color: Colors.white, fontSize: 24)),
        const SizedBox(height: 2),
        Text(label,
            style: AppTypography.caption.copyWith(
              color: Colors.white54,
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            )),
      ],
    );
  }
}
