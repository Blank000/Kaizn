import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';
import '../../shared/providers/database_provider.dart';
import '../../shared/widgets/animated_number.dart';
import 'claim_flow.dart';
import 'widgets/create_reward_sheet.dart';

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalPoints = ref.watch(totalPointsProvider).valueOrNull ?? 0;
    final unclaimed = ref.watch(unclaimedRewardsProvider).valueOrNull ?? [];
    final claimed = ref.watch(claimedRewardsProvider).valueOrNull ?? [];

    final claimable =
        unclaimed.where((r) => totalPoints >= r.pointsThreshold).toList();
    final locked =
        unclaimed.where((r) => totalPoints < r.pointsThreshold).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Rewards', style: AppTypography.heading1),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => showCreateRewardSheet(context),
            tooltip: 'Create reward',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BalanceCard(points: totalPoints, nextReward: _nextReward(unclaimed)),
          const SizedBox(height: 24),
          if (unclaimed.isEmpty && claimed.isEmpty)
            _EmptyState(onCreateTap: () => showCreateRewardSheet(context))
          else ...[
            if (claimable.isNotEmpty) ...[
              _sectionLabel('READY TO CLAIM'),
              const SizedBox(height: 8),
              ...claimable.map((r) => _ClaimableCard(
                    reward: r,
                    onClaim: () =>
                        claimReward(context, ref, r, totalPoints),
                    onEdit: () => showCreateRewardSheet(context, reward: r),
                    onDelete: () =>
                        ref.read(databaseProvider).deleteReward(r.id),
                  )),
              const SizedBox(height: 24),
            ],
            if (locked.isNotEmpty) ...[
              _sectionLabel('KEEP EARNING'),
              const SizedBox(height: 8),
              ...locked.map((r) => _LockedCard(
                    reward: r,
                    currentPoints: totalPoints,
                    onEdit: () => showCreateRewardSheet(context, reward: r),
                    onDelete: () =>
                        ref.read(databaseProvider).deleteReward(r.id),
                  )),
              const SizedBox(height: 24),
            ],
            if (claimed.isNotEmpty) ...[
              _sectionLabel('CLAIMED'),
              const SizedBox(height: 8),
              ...claimed.map((r) => _ClaimedCard(reward: r)),
              const SizedBox(height: 16),
            ],
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: AppTypography.caption.copyWith(
          letterSpacing: 1.2,
          fontWeight: FontWeight.w800,
        ),
      );

  /// Cheapest unclaimed reward — the next one the user is working toward.
  Reward? _nextReward(List<Reward> unclaimed) {
    if (unclaimed.isEmpty) return null;
    final sorted = [...unclaimed]
      ..sort((a, b) => a.pointsThreshold.compareTo(b.pointsThreshold));
    return sorted.first;
  }
}

// ─── Balance Card ─────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final int points;
  final Reward? nextReward;
  const _BalanceCard({required this.points, this.nextReward});

  @override
  Widget build(BuildContext context) {
    final remaining = nextReward != null
        ? (nextReward!.pointsThreshold - points).clamp(0, 999999)
        : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'POINTS BALANCE',
            style: AppTypography.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedNumber(
            value: points,
            style: AppTypography.display.copyWith(
              color: Colors.white,
              fontSize: 60,
            ),
          ),
          Text(
            'pts',
            style: AppTypography.body
                .copyWith(color: Colors.white.withValues(alpha: 0.8)),
          ),
          if (nextReward != null && remaining! > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$remaining pts to "${nextReward!.name}"',
                style: AppTypography.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Text('🎁', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text('No rewards yet', style: AppTypography.heading2),
            const SizedBox(height: 8),
            Text(
              'Define something to work towards.\nYou deserve it.',
              style: AppTypography.body
                  .copyWith(color: context.appTextSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('CREATE REWARD'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Claimable Card ───────────────────────────────────────────────────────────

class _ClaimableCard extends StatelessWidget {
  final Reward reward;
  final VoidCallback onClaim;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ClaimableCard({
    required this.reward,
    required this.onClaim,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.primary, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reward.name, style: AppTypography.body),
                  if (reward.description != null &&
                      reward.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        reward.description!,
                        style: AppTypography.caption
                            .copyWith(color: context.appTextSecondary),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${reward.pointsThreshold} pts',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onClaim,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: const Text('CLAIM'),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
              icon: Icon(
                Icons.more_vert_rounded,
                size: 20,
                color: context.appTextTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Locked Card ──────────────────────────────────────────────────────────────

class _LockedCard extends StatelessWidget {
  final Reward reward;
  final int currentPoints;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LockedCard({
    required this.reward,
    required this.currentPoints,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        (currentPoints / reward.pointsThreshold).clamp(0.0, 1.0);
    final remaining = reward.pointsThreshold - currentPoints;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(reward.name, style: AppTypography.body)),
                PopupMenuButton<String>(
                  onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                      value: 'delete',
                      child:
                          Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: context.appTextTertiary,
                  ),
                ),
              ],
            ),
            if (reward.description != null && reward.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  reward.description!,
                  style: AppTypography.caption
                      .copyWith(color: context.appTextSecondary),
                ),
              ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: context.appBorder,
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$currentPoints / ${reward.pointsThreshold} pts',
                  style: AppTypography.caption
                      .copyWith(color: context.appTextSecondary),
                ),
                Text(
                  '$remaining to go',
                  style: AppTypography.caption.copyWith(
                    color: context.appTextTertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Claimed Card ─────────────────────────────────────────────────────────────

class _ClaimedCard extends StatelessWidget {
  final Reward reward;
  const _ClaimedCard({required this.reward});

  @override
  Widget build(BuildContext context) {
    final dateStr = reward.claimedAt != null
        ? DateFormat('MMM d, yyyy').format(reward.claimedAt!)
        : '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: context.appPageBackground,
      child: ListTile(
        leading: const Icon(Icons.check_circle_rounded,
            color: AppColors.primary, size: 28),
        title: Text(
          reward.name,
          style: AppTypography.body.copyWith(color: context.appTextSecondary),
        ),
        subtitle: Text('Claimed $dateStr', style: AppTypography.caption),
        trailing: Text(
          '${reward.pointsThreshold} pts',
          style:
              AppTypography.caption.copyWith(color: context.appTextTertiary),
        ),
      ),
    );
  }
}
