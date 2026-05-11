import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/achievement_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late Future<List<AchievementBadge>> _future;

  @override
  void initState() {
    super.initState();
    _future = AchievementService.getAllBadges();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Achievements', style: AppTypography.heading1),
      ),
      body: FutureBuilder<List<AchievementBadge>>(
        future: _future,
        builder: (context, snapshot) {
          final badges = snapshot.data ?? const <AchievementBadge>[];
          final unlockedCount = badges.where((b) => b.isUnlocked).length;
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProgressHeader(unlocked: unlockedCount, total: badges.length),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: badges.length,
                itemBuilder: (_, i) => _BadgeCard(badge: badges[i]),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int unlocked;
  final int total;

  const _ProgressHeader({required this.unlocked, required this.total});

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : unlocked / total;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appPageBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('UNLOCKED',
                  style: AppTypography.caption.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                    color: context.appTextSecondary,
                  )),
              Text(
                '$unlocked / $total',
                style: AppTypography.body
                    .copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: context.appBorder.withValues(alpha: 0.4),
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final AchievementBadge badge;
  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    final isUnlocked = badge.isUnlocked;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUnlocked ? context.appCardSurface : context.appPageBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnlocked
              ? AppColors.primary.withValues(alpha: 0.4)
              : context.appBorder.withValues(alpha: 0.5),
          width: isUnlocked ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: isUnlocked ? 1.0 : 0.25,
            child: Text(
              badge.emoji,
              style: const TextStyle(fontSize: 40),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            badge.name,
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w800,
              color: isUnlocked
                  ? context.appTextPrimary
                  : context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              badge.description,
              style: AppTypography.caption.copyWith(
                color: context.appTextSecondary,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (isUnlocked && badge.unlockedAt != null)
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat.MMMd().format(badge.unlockedAt!),
                  style: AppTypography.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            )
          else
            Text(
              'LOCKED',
              style: AppTypography.caption.copyWith(
                fontSize: 9,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
                color: context.appTextTertiary,
              ),
            ),
        ],
      ),
    );
  }
}
