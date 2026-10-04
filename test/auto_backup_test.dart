import 'package:flutter_test/flutter_test.dart';

import 'package:habit_reward_tracker/core/services/auto_backup.dart';
import 'package:habit_reward_tracker/core/services/backup_service.dart';

void main() {
  group('when is a backup due', () {
    final now = DateTime(2026, 10, 4, 14, 0);

    test('never backed up -> due', () {
      expect(BackupService.isBackupDue(lastSuccess: null, now: now), isTrue);
    });

    test('backed up 23h ago -> not due', () {
      expect(
          BackupService.isBackupDue(
              lastSuccess: now.subtract(const Duration(hours: 23)), now: now),
          isFalse);
    });

    test('backed up exactly 24h ago -> due', () {
      expect(
          BackupService.isBackupDue(
              lastSuccess: now.subtract(const Duration(hours: 24)), now: now),
          isTrue);
    });

    test('a backup timestamped in the future (clock moved back) -> due', () {
      expect(
          BackupService.isBackupDue(
              lastSuccess: now.add(const Duration(hours: 3)), now: now),
          isTrue,
          reason: 'never trust a backup the clock says has not happened yet');
    });
  });

  group('failure back-off on app open', () {
    final now = DateTime(2026, 10, 4, 14, 0);

    test('no failure on record -> not throttled', () {
      expect(BackupService.recentlyFailed(lastErrorAt: null, now: now),
          isFalse);
    });

    test('failed 10 minutes ago -> throttled', () {
      expect(
          BackupService.recentlyFailed(
              lastErrorAt: now.subtract(const Duration(minutes: 10)),
              now: now),
          isTrue);
    });

    test('failed 40 minutes ago -> try again', () {
      expect(
          BackupService.recentlyFailed(
              lastErrorAt: now.subtract(const Duration(minutes: 40)),
              now: now),
          isFalse);
    });
  });

  group('anchoring the nightly run at 2 AM', () {
    test('afternoon -> tonight at 2 AM tomorrow', () {
      final d = AutoBackup.delayUntilNext(DateTime(2026, 10, 4, 14, 0),
          hour: 2);
      expect(d, const Duration(hours: 12));
    });

    test('1:30 AM -> in 30 minutes, not tomorrow', () {
      final d = AutoBackup.delayUntilNext(DateTime(2026, 10, 4, 1, 30),
          hour: 2);
      expect(d, const Duration(minutes: 30));
    });

    test('exactly 2:00 -> the next day, never zero', () {
      final d = AutoBackup.delayUntilNext(DateTime(2026, 10, 4, 2, 0),
          hour: 2);
      expect(d, const Duration(hours: 24));
    });
  });

  group('the stale-backup warning', () {
    final now = DateTime(2026, 10, 4, 9, 0);

    test('fresh backup -> no warning even if never warned', () {
      expect(
          AutoBackup.shouldWarnStale(
              lastSuccess: now.subtract(const Duration(hours: 5)),
              warnedOn: null,
              now: now),
          isFalse);
    });

    test('stale and not warned today -> warn', () {
      expect(
          AutoBackup.shouldWarnStale(
              lastSuccess: now.subtract(const Duration(days: 2)),
              warnedOn: DateTime(2026, 10, 3),
              now: now),
          isTrue);
    });

    test('stale but already warned today -> stay quiet', () {
      expect(
          AutoBackup.shouldWarnStale(
              lastSuccess: now.subtract(const Duration(days: 2)),
              warnedOn: DateTime(2026, 10, 4),
              now: now),
          isFalse,
          reason: 'once a day, never a nag');
    });
  });

  group('error messages a person can act on', () {
    test('socket failure -> no internet', () {
      expect(
          BackupService.describeError(
              Exception('SocketException: Failed host lookup')),
          'No internet connection');
    });

    test('expired auth -> sign in again', () {
      expect(BackupService.describeError(Exception('401 Unauthorized')),
          contains('sign in again'));
    });

    test('long unknown errors are clipped', () {
      final out = BackupService.describeError(Exception('x' * 400));
      expect(out.length, lessThanOrEqualTo(120));
    });
  });
}
