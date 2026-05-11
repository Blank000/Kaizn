import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/services/app_prefs.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/backup_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/context_colors.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/database_provider.dart';
import '../../shared/providers/theme_mode_provider.dart';
import '../home/widgets/notification_settings_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final user = ref.watch(currentUserProvider).valueOrNull ??
        AuthService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: AppTypography.heading1),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionLabel('Account'),
          const SizedBox(height: 8),
          _AccountCard(user: user),
          const SizedBox(height: 24),
          _SectionLabel('Backup'),
          const SizedBox(height: 8),
          _BackupCard(),
          const SizedBox(height: 24),
          _SectionLabel('Theme'),
          const SizedBox(height: 8),
          _Card(
            children: [
              _ThemeOption(
                label: 'System',
                subtitle: 'Match your device',
                value: ThemeMode.system,
                groupValue: mode,
                onChanged: (m) => _setTheme(ref, m),
              ),
              _Divider(),
              _ThemeOption(
                label: 'Light',
                subtitle: null,
                value: ThemeMode.light,
                groupValue: mode,
                onChanged: (m) => _setTheme(ref, m),
              ),
              _Divider(),
              _ThemeOption(
                label: 'Dark',
                subtitle: null,
                value: ThemeMode.dark,
                groupValue: mode,
                onChanged: (m) => _setTheme(ref, m),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel('Notifications'),
          const SizedBox(height: 8),
          _Card(
            children: [
              ListTile(
                leading:
                    const Icon(Icons.notifications_outlined),
                title: Text('Reminders', style: AppTypography.body),
                subtitle: Text(
                  'Daily, streak alerts, weekly recap',
                  style: AppTypography.caption.copyWith(
                    color: context.appTextSecondary,
                  ),
                ),
                trailing: Icon(Icons.chevron_right_rounded,
                    color: context.appTextSecondary),
                onTap: () => showNotificationSettingsSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel('More'),
          const SizedBox(height: 8),
          _Card(
            children: [
              ListTile(
                leading: const Icon(Icons.emoji_events_outlined),
                title: Text('Achievements', style: AppTypography.body),
                trailing: Icon(Icons.chevron_right_rounded,
                    color: context.appTextSecondary),
                onTap: () => context.go('/stats/achievements'),
              ),
              _Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text('About', style: AppTypography.body),
                subtitle: Text(
                  'Version 1.0.0',
                  style: AppTypography.caption.copyWith(
                    color: context.appTextSecondary,
                  ),
                ),
                trailing: Icon(Icons.chevron_right_rounded,
                    color: context.appTextSecondary),
                onTap: () => _showAbout(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _setTheme(WidgetRef ref, ThemeMode? mode) async {
    if (mode == null) return;
    ref.read(themeModeProvider.notifier).state = mode;
    await AppPrefs.setThemeMode(themeModeToString(mode));
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Habit Reward Tracker',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.check_rounded,
            color: Colors.white, size: 32),
      ),
      applicationLegalese:
          'Gamified personal productivity. Log anything, earn points, '
          'unlock the rewards you set for yourself.',
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 0),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.caption.copyWith(
          letterSpacing: 1.5,
          fontWeight: FontWeight.w800,
          color: context.appTextSecondary,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        color: context.appBorder.withValues(alpha: 0.5),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final dynamic user; // GoogleSignInAccount? — kept dynamic to avoid leaking the type into call sites
  const _AccountCard({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      // Shouldn't happen — settings is gated by login — but guard anyway.
      return _Card(children: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text('Not signed in', style: AppTypography.body),
        ),
      ]);
    }
    return _Card(
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundImage: user.photoUrl != null
                ? NetworkImage(user.photoUrl!)
                : null,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: user.photoUrl == null
                ? const Icon(Icons.person_outline,
                    color: AppColors.primary)
                : null,
          ),
          title: Text(
            user.displayName ?? user.email,
            style: AppTypography.body,
          ),
          subtitle: user.displayName != null
              ? Text(
                  user.email,
                  style: AppTypography.caption.copyWith(
                    color: context.appTextSecondary,
                  ),
                )
              : null,
        ),
        _Divider(),
        ListTile(
          leading: Icon(Icons.logout_rounded,
              color: AppColors.missedRed),
          title: Text(
            'Sign out',
            style: AppTypography.body
                .copyWith(color: AppColors.missedRed),
          ),
          onTap: () => _confirmSignOut(context),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            "Your data stays in your Google Drive backup. Sign back in on this or another device to restore it."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.missedRed),
            child: const Text('SIGN OUT'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AuthService.signOut();
    // Router redirect handles bouncing to /login.
  }
}

class _BackupCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends ConsumerState<_BackupCard> {
  DateTime? _lastBackupAt;
  bool _loadingTime = true;
  bool _busy = false;
  String? _busyAction; // "Backing up…" / "Restoring…"

  @override
  void initState() {
    super.initState();
    _refreshLastBackupTime();
  }

  Future<void> _refreshLastBackupTime() async {
    setState(() => _loadingTime = true);
    try {
      final t = await BackupService.lastBackupAt();
      if (mounted) setState(() => _lastBackupAt = t);
    } catch (_) {
      // Network or auth error; leave as null.
    } finally {
      if (mounted) setState(() => _loadingTime = false);
    }
  }

  Future<void> _backup() async {
    setState(() {
      _busy = true;
      _busyAction = 'Backing up…';
    });
    try {
      final db = ref.read(databaseProvider);
      await BackupService.backup(db);
      await _refreshLastBackupTime();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backed up to Google Drive')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyAction = null;
        });
      }
    }
  }

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text(
            "Replaces all current data on this device with your latest Drive backup. This can't be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('RESTORE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _busyAction = 'Restoring…';
    });
    try {
      final db = ref.read(databaseProvider);
      await BackupService.restore(db);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restored from backup')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyAction = null;
        });
      }
    }
  }

  String _formatLastBackup(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.yMMMd().format(t);
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _busy
        ? _busyAction ?? '…'
        : _loadingTime
            ? 'Checking…'
            : _lastBackupAt == null
                ? 'No backup yet'
                : 'Last backup ${_formatLastBackup(_lastBackupAt!)}';

    return _Card(
      children: [
        ListTile(
          leading: const Icon(Icons.cloud_upload_outlined),
          title: Text('Back up now', style: AppTypography.body),
          subtitle: Text(
            subtitle,
            style: AppTypography.caption.copyWith(
              color: context.appTextSecondary,
            ),
          ),
          trailing: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.chevron_right_rounded,
                  color: context.appTextSecondary),
          onTap: _busy ? null : _backup,
        ),
        _Divider(),
        ListTile(
          leading: const Icon(Icons.cloud_download_outlined),
          title: Text('Restore from backup', style: AppTypography.body),
          subtitle: Text(
            'Replaces local data with the Drive copy',
            style: AppTypography.caption.copyWith(
              color: context.appTextSecondary,
            ),
          ),
          trailing: Icon(Icons.chevron_right_rounded,
              color: context.appTextSecondary),
          onTap: _busy ? null : _restore,
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final String? subtitle;
  final ThemeMode value;
  final ThemeMode groupValue;
  final ValueChanged<ThemeMode?> onChanged;

  const _ThemeOption({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<ThemeMode>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      title: Text(label, style: AppTypography.body),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: AppTypography.caption.copyWith(
                color: context.appTextSecondary,
              ),
            ),
      activeColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
