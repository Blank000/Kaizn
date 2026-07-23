import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_colors.dart';
import '../../../shared/providers/database_provider.dart';

/// Frictionless capture (GTD "ubiquitous capture" / ADHD brain dump):
/// ONE text field, zero other decisions. Everything lands in the Inbox
/// milestone as an undated one-shot — it surfaces in Up Next immediately
/// and can be triaged into a real schedule later via the normal edit form.
///
/// The sheet stays open after each add for burst capture; swipe down or
/// tap DONE to leave.
Future<void> showQuickCaptureSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true, // rides above the keyboard
    backgroundColor: Colors.transparent,
    builder: (_) => const _QuickCaptureSheet(),
  );
}

class _QuickCaptureSheet extends ConsumerStatefulWidget {
  const _QuickCaptureSheet();

  @override
  ConsumerState<_QuickCaptureSheet> createState() =>
      _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends ConsumerState<_QuickCaptureSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _lastCaptured;
  int _capturedCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    final db = ref.read(databaseProvider);
    // Captures ALWAYS land in an Inbox milestone — create it if the user
    // deleted it (or the seed only ran against a non-empty milestone list).
    final milestones = await db.getActiveMilestones();
    var inbox = milestones.where((m) => m.name == 'Inbox').firstOrNull;
    if (inbox == null) {
      final id = _generateId();
      await db.insertMilestone(MilestonesCompanion.insert(
        id: id,
        name: 'Inbox',
        description:
            const Value('Quick captures and miscellaneous tasks'),
      ));
      inbox = (await db.getActiveMilestones())
          .firstWhere((m) => m.id == id);
    }

    await db.insertTask(TasksCompanion.insert(
      id: _generateId(),
      milestoneId: Value(inbox.id),
      name: name,
    ));

    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() {
      _lastCaptured = name;
      _capturedCount++;
      _controller.clear();
    });
    _focus.requestFocus(); // burst capture: keep typing
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: BoxDecoration(
          color: context.appCardSurface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
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
            Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text('Quick capture', style: AppTypography.heading2),
                const Spacer(),
                if (_capturedCount > 0)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('DONE'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Get it out of your head — sort it later from the Inbox.',
              style: AppTypography.caption
                  .copyWith(color: context.appTextSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _capture(),
              decoration: InputDecoration(
                hintText: "What's on your mind?",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add_circle_rounded,
                      color: AppColors.primary),
                  tooltip: 'Add',
                  onPressed: _capture,
                ),
              ),
            ),
            if (_lastCaptured != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.check_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Captured '$_lastCaptured'"
                      '${_capturedCount > 1 ? ' · $_capturedCount so far' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _generateId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final r = Random.secure();
  return 't${List.generate(19, (_) => chars[r.nextInt(chars.length)]).join()}';
}
