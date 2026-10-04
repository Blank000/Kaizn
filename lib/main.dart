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
  await Future.wait([
    NotificationService.init(),
    AppPrefs.hydrate(),
    // Try to restore prior Google Sign-In so the router can redirect
    // sync on the first frame (signed-in users skip /login).
    AuthService.trySilentSignIn(),
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
