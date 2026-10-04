import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/app_prefs.dart';
import 'core/services/auth_service.dart';
import 'core/services/auto_backup.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Nothing here may keep the first frame from appearing: a plugin that
  // hangs or throws (Google Play services, a notification channel) used to
  // leave the user on a blank white screen. Each step gets a deadline and
  // its errors are swallowed; the app copes with any of them missing.
  await Future.wait([
    _startupStep('notifications', NotificationService.init()),
    _startupStep('prefs', AppPrefs.hydrate()),
    // Try to restore prior Google Sign-In so the router can redirect
    // sync on the first frame (signed-in users skip /login).
    _startupStep('sign-in', AuthService.trySilentSignIn()),
  ]);
  // Nightly ~2 AM Drive backup (Android). Not awaited: scheduling must never
  // delay the first frame, and it swallows its own errors.
  unawaited(AutoBackup.init());

  runApp(
    const ProviderScope(
      child: HabitRewardTrackerApp(),
    ),
  );
}

Future<void> _startupStep(String name, Future<Object?> step) async {
  try {
    await step.timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('startup: $name skipped - $e');
  }
}
