import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_prefs.dart';

/// Drives `MaterialApp.themeMode`. Initial value is read from
/// `AppPrefs.themeModeSync` (hydrated at startup). Update via the standard
/// `ref.read(themeModeProvider.notifier).state = newMode` pattern; the
/// settings screen also persists to `AppPrefs.setThemeMode` in parallel.
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return _stringToThemeMode(AppPrefs.themeModeSync);
});

ThemeMode _stringToThemeMode(String value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

String themeModeToString(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}
