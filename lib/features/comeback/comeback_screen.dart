import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database.dart';
import '../../core/services/app_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';
import '../../shared/models/recurrence_rule.dart';
import '../../shared/providers/database_provider.dart';
import '../../shared/widgets/zen_spark.dart';

/// Gentle re-entry after 7+ days away (fresh-start effect + Finch's
/// no-guilt return). NO missed-task wall, NO broken-streak framing — the
/// gap is a page turn, not an audit. The user travels light: keep what
/// still matters, shelve the rest (restorable from milestone detail).
class ComebackScreen extends ConsumerStatefulWidget {
  const ComebackScreen({super.key});

  @override
  ConsumerState<ComebackScreen> createState() => _ComebackScreenState();
}

class _ComebackScreenState extends ConsumerState<ComebackScreen> {
  List<Task>? _tasks;
  final _toShelve = <String>{};
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final all = await db.getAllActiveTasks();
    if (!mounted) return;
    setState(() => _tasks = all);
  }

  Future<void> _apply() async {
    if (_applying) return;
    setState(() => _applying = true);
    final db = ref.read(databaseProvider);
    for (final t in _tasks ?? const <Task>[]) {
      if (_toShelve.contains(t.id)) {
        await db.updateTask(t.copyWith(status: TaskStatus.archived));
      }
    }
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_toShelve.isEmpty
          ? 'Welcome back. New chapter starts now 🌱'
          : 'Traveling light — ${_toShelve.length} shelved. New chapter starts now 🌱'),
    ));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _tasks;
    final keeping = (tasks?.length ?? 0) - _toShelve.length;
    return Scaffold(
      backgroundColor: context.appPageBackground,
      body: SafeArea(
        child: tasks == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
                      children: [
                        // The one-off ZENKAI BOOST: returning is the
                        // dramatic moment, never leaving.
                        if (AppPrefs.zenEnabledSync)
                          const Center(
                            child: ZenSpark(
                              mood: ZenMood.cheer,
                              streak: 30,
                              size: 88,
                              line: 'ZENKAI BOOST!',
                            ),
                          )
                        else
                          const Text('👋',
                              style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text('Welcome back',
                            style: AppTypography.display),
                        const SizedBox(height: 8),
                        Text(
                          "It's been a while — that's life, not failure. "
                          'The gap is a page turn: pick what still matters '
                          'and start the new chapter light.',
                          style: AppTypography.body.copyWith(
                              color: context.appTextSecondary),
                        ),
                        const SizedBox(height: 24),
                        if (tasks.isEmpty)
                          Text(
                            'A clean slate — add your first task from Home.',
                            style: AppTypography.body.copyWith(
                                color: context.appTextSecondary),
                          )
                        else ...[
                          Text(
                            'KEEP WHAT STILL MATTERS',
                            style: AppTypography.caption.copyWith(
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: context.appTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Shelved tasks leave your day but keep their '
                            'history — restore them anytime from their '
                            'milestone. Starting with 1–3 keepers beats '
                            'restarting everything.',
                            style: AppTypography.caption.copyWith(
                                color: context.appTextTertiary),
                          ),
                          const SizedBox(height: 12),
                          ...tasks.map((t) {
                            final shelved = _toShelve.contains(t.id);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: SwitchListTile(
                                value: !shelved,
                                activeColor: AppColors.primary,
                                onChanged: (keep) => setState(() {
                                  if (keep) {
                                    _toShelve.remove(t.id);
                                  } else {
                                    _toShelve.add(t.id);
                                  }
                                }),
                                title: Text(
                                  t.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.body.copyWith(
                                    color: shelved
                                        ? context.appTextTertiary
                                        : context.appTextPrimary,
                                    decoration: shelved
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                subtitle: Text(
                                  t.recurrence == TaskRecurrence.none
                                      ? 'Once'
                                      : RecurrenceRule.fromTask(t)
                                          .summary(),
                                  style: AppTypography.caption.copyWith(
                                      color: context.appTextSecondary),
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          onPressed: _applying ? null : _apply,
                          style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16)),
                          child: Text(tasks.isEmpty
                              ? "LET'S GO"
                              : _toShelve.isEmpty
                                  ? 'KEEP ALL $keeping · START FRESH'
                                  : 'KEEP $keeping · SHELVE ${_toShelve.length}'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
