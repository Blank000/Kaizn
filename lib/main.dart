import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/app_prefs.dart';
import 'core/services/auth_service.dart';
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

  runApp(
    const ProviderScope(
      child: HabitRewardTrackerApp(),
    ),
  );
}
