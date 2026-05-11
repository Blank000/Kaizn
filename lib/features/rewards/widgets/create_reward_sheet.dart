import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_colors.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../shared/widgets/reward_unlock_snackbar.dart';
import '../reward_unlock_service.dart';

void showCreateRewardSheet(BuildContext context, {Reward? reward}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CreateRewardSheet(reward: reward),
  );
}

class CreateRewardSheet extends ConsumerStatefulWidget {
  final Reward? reward;
  const CreateRewardSheet({super.key, this.reward});

  @override
  ConsumerState<CreateRewardSheet> createState() => _CreateRewardSheetState();
}

class _CreateRewardSheetState extends ConsumerState<CreateRewardSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _pointsController;
  bool _isSaving = false;

  bool get _isEditing => widget.reward != null;

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      (int.tryParse(_pointsController.text.trim()) ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.reward?.name ?? '');
    _descController =
        TextEditingController(text: widget.reward?.description ?? '');
    _pointsController = TextEditingController(
      text: widget.reward != null ? '${widget.reward!.pointsThreshold}' : '',
    );
    _nameController.addListener(() => setState(() {}));
    _pointsController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final name = _nameController.text.trim();
    final points = int.parse(_pointsController.text.trim());
    final desc = _descController.text.trim();

    setState(() => _isSaving = true);
    final db = ref.read(databaseProvider);

    if (_isEditing) {
      await db.updateReward(widget.reward!.copyWith(
        name: name,
        description: Value(desc.isEmpty ? null : desc),
        pointsThreshold: points,
      ));
    } else {
      await db.insertReward(RewardsCompanion.insert(
        id: 'r${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        description: Value(desc.isEmpty ? null : desc),
        pointsThreshold: points,
      ));
    }

    // If the saved reward (or any other unannounced unclaimed reward) is
    // already at-or-below the user's current balance, surface it now.
    final unlocked = await RewardUnlockService.checkAfterPointsChange(db);

    if (!mounted) return;
    Navigator.of(context).pop();
    if (mounted) showRewardUnlockSnackbar(context, unlocked);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: BoxDecoration(
        color: context.appCardSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 20),
          Text(
            _isEditing ? 'Edit Reward' : 'New Reward',
            style: AppTypography.heading2,
          ),
          const SizedBox(height: 20),
          Text('Reward name', style: AppTypography.caption),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration:
                const InputDecoration(hintText: 'e.g. Movie Night, Cheat Meal'),
          ),
          const SizedBox(height: 16),
          Text('Description (optional)', style: AppTypography.caption),
          const SizedBox(height: 6),
          TextField(
            controller: _descController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Any notes...'),
          ),
          const SizedBox(height: 16),
          Text('Points required to claim', style: AppTypography.caption),
          const SizedBox(height: 6),
          TextField(
            controller: _pointsController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: 'e.g. 500',
              suffixText: 'pts',
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving || !_canSave ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEditing ? 'SAVE CHANGES' : 'CREATE REWARD'),
            ),
          ),
        ],
      ),
    );
  }
}
