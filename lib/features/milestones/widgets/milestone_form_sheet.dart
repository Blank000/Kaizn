import 'dart:math';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_colors.dart';
import '../../../shared/providers/database_provider.dart';

Future<void> showMilestoneFormSheet(
  BuildContext context, {
  Milestone? milestone,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MilestoneFormSheet(milestone: milestone),
  );
}

class _MilestoneFormSheet extends ConsumerStatefulWidget {
  final Milestone? milestone;
  const _MilestoneFormSheet({this.milestone});

  @override
  ConsumerState<_MilestoneFormSheet> createState() =>
      _MilestoneFormSheetState();
}

class _MilestoneFormSheetState extends ConsumerState<_MilestoneFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _bonusController;
  DateTime? _targetDate;
  int _colorIndex = 0;
  bool _saving = false;

  bool get _isEdit => widget.milestone != null;

  @override
  void initState() {
    super.initState();
    final m = widget.milestone;
    _nameController = TextEditingController(text: m?.name ?? '');
    _descController = TextEditingController(text: m?.description ?? '');
    _bonusController =
        TextEditingController(text: (m?.completionPoints ?? 0).toString());
    _targetDate = m?.targetDate;
    _colorIndex = m?.colorIndex ?? 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _bonusController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your milestone a name')),
      );
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final desc = _descController.text.trim();
    final bonus = int.tryParse(_bonusController.text.trim()) ?? 0;

    if (_isEdit) {
      final m = widget.milestone!;
      await db.updateMilestone(m.copyWith(
        name: name,
        description: Value(desc.isEmpty ? null : desc),
        targetDate: Value(_targetDate),
        completionPoints: bonus,
        colorIndex: _colorIndex,
      ));
    } else {
      await db.insertMilestone(MilestonesCompanion.insert(
        id: _generateId(),
        name: name,
        description: Value(desc.isEmpty ? null : desc),
        targetDate: Value(_targetDate),
        completionPoints: Value(bonus),
        colorIndex: Value(_colorIndex),
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: BoxDecoration(
          color: context.appCardSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: SingleChildScrollView(
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
                _isEdit ? 'Edit milestone' : 'New milestone',
                style: AppTypography.heading2,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                autofocus: !_isEdit,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Trek 5 peaks this year',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Target date (optional)',
                    suffixIcon: _targetDate == null
                        ? const Icon(Icons.calendar_today_outlined)
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () =>
                                setState(() => _targetDate = null),
                          ),
                  ),
                  child: Text(
                    _targetDate == null
                        ? 'No deadline'
                        : DateFormat.yMMMMd().format(_targetDate!),
                    style: AppTypography.body.copyWith(
                      color: _targetDate == null
                          ? context.appTextSecondary
                          : context.appTextPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bonusController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Completion bonus (points)',
                  helperText:
                      'Awarded once when you mark the milestone complete',
                ),
              ),
              const SizedBox(height: 20),
              Text('Color', style: AppTypography.caption),
              const SizedBox(height: 8),
              _ColorPickerRow(
                selectedIndex: _colorIndex,
                onChanged: (i) => setState(() => _colorIndex = i),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_isEdit ? 'SAVE CHANGES' : 'CREATE MILESTONE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorPickerRow extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _ColorPickerRow({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(AppColors.milestonePalette.length, (i) {
        final color = AppColors.milestonePalette[i];
        final isSelected = i == selectedIndex;
        return InkWell(
          onTap: () => onChanged(i),
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(
                      color: context.appTextPrimary,
                      width: 2.5,
                    )
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded,
                    size: 18, color: Colors.white)
                : null,
          ),
        );
      }),
    );
  }
}

String _generateId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final r = Random.secure();
  return 'm${List.generate(19, (_) => chars[r.nextInt(chars.length)]).join()}';
}
