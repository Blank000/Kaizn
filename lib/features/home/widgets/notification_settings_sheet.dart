import 'package:flutter/material.dart';

import '../../../core/services/notification_prefs.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_colors.dart';

void showNotificationSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _NotificationSettingsSheet(),
  );
}

class _NotificationSettingsSheet extends StatefulWidget {
  const _NotificationSettingsSheet();

  @override
  State<_NotificationSettingsSheet> createState() =>
      _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState
    extends State<_NotificationSettingsSheet> {
  bool _dailyEnabled = false;
  TimeOfDay _dailyTime = const TimeOfDay(hour: 8, minute: 0);
  bool _streakAlertEnabled = false;
  bool _weeklyRecapEnabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dailyEnabled = await NotificationPrefs.isDailyEnabled();
    final dailyTime = await NotificationPrefs.getDailyTime();
    final streakEnabled = await NotificationPrefs.isStreakAlertEnabled();
    final weeklyEnabled = await NotificationPrefs.isWeeklyRecapEnabled();
    if (mounted) {
      setState(() {
        _dailyEnabled = dailyEnabled;
        _dailyTime = TimeOfDay(hour: dailyTime.hour, minute: dailyTime.minute);
        _streakAlertEnabled = streakEnabled;
        _weeklyRecapEnabled = weeklyEnabled;
        _loading = false;
      });
    }
  }

  Future<void> _toggleDaily(bool value) async {
    setState(() => _dailyEnabled = value);
    await NotificationPrefs.setDailyEnabled(value);
    if (value) {
      await NotificationService.scheduleDailyReminder(
          _dailyTime.hour, _dailyTime.minute);
    } else {
      await NotificationService.cancelDailyReminder();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dailyTime,
    );
    if (picked == null || !mounted) return;
    setState(() => _dailyTime = picked);
    await NotificationPrefs.setDailyTime(picked.hour, picked.minute);
    if (_dailyEnabled) {
      await NotificationService.scheduleDailyReminder(
          picked.hour, picked.minute);
    }
  }

  Future<void> _toggleStreakAlert(bool value) async {
    setState(() => _streakAlertEnabled = value);
    await NotificationPrefs.setStreakAlertEnabled(value);
    if (value) {
      await NotificationService.scheduleStreakAlert();
    } else {
      await NotificationService.cancelStreakAlert();
    }
  }

  Future<void> _toggleWeeklyRecap(bool value) async {
    setState(() => _weeklyRecapEnabled = value);
    await NotificationPrefs.setWeeklyRecapEnabled(value);
    if (value) {
      await NotificationService.scheduleWeeklyRecap();
    } else {
      await NotificationService.cancelWeeklyRecap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 40,
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
          Row(
            children: [
              const Text('🔔', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Text('Notifications', style: AppTypography.heading2),
            ],
          ),
          const SizedBox(height: 24),

          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            // ── Daily Reminder ──
            Text(
              'DAILY REMINDER',
              style: AppTypography.caption.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _ToggleRow(
              label: 'Enable daily reminder',
              subtitle: 'Remind me to log my habits',
              value: _dailyEnabled,
              onChanged: _toggleDaily,
            ),
            if (_dailyEnabled) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: context.appPageBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.appBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Reminder time',
                        style: AppTypography.body,
                      ),
                      const Spacer(),
                      Text(
                        _dailyTime.format(context),
                        style: AppTypography.body.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: context.appTextTertiary),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // ── Streak Alert ──
            Text(
              'STREAK PROTECTION',
              style: AppTypography.caption.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _ToggleRow(
              label: 'Streak-at-risk alert',
              subtitle: 'Fires at 9 PM if you haven\'t logged today',
              value: _streakAlertEnabled,
              onChanged: _toggleStreakAlert,
            ),
            const SizedBox(height: 8),
            Text(
              'Keeps your streak alive by nudging you before midnight.',
              style: AppTypography.caption
                  .copyWith(color: context.appTextTertiary),
            ),
            const SizedBox(height: 24),

            // ── Weekly Recap ──
            Text(
              'WEEKLY RECAP',
              style: AppTypography.caption.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _ToggleRow(
              label: 'Sunday recap notification',
              subtitle: 'Weekly summary every Sunday at 8 PM',
              value: _weeklyRecapEnabled,
              onChanged: _toggleWeeklyRecap,
            ),
          ],
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.body),
              Text(
                subtitle,
                style: AppTypography.caption
                    .copyWith(color: context.appTextSecondary),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ],
    );
  }
}
