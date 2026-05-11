import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Context-aware accessors for the neutral color palette so widgets render
/// correctly in both light and dark themes.
///
/// Brand colors (primary, streakOrange, rewardsGold, missedRed, skipOrange,
/// infoBlue) stay on `AppColors` as static constants — they're the same in
/// both modes.
extension AppColorsContext on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  /// Card / sheet / dialog background.
  Color get appCardSurface =>
      _isDark ? AppColors.darkSurface : AppColors.surface;

  /// Scaffold / page background (slightly off from card surface).
  Color get appPageBackground =>
      _isDark ? AppColors.darkBackground : AppColors.background;

  /// Primary text (titles, body).
  Color get appTextPrimary =>
      _isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;

  /// Secondary text (captions, subtitles).
  Color get appTextSecondary =>
      _isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

  /// Tertiary text (least emphasized — placeholders, "LOCKED" labels).
  Color get appTextTertiary =>
      _isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;

  /// Border / outline color.
  Color get appBorder => _isDark ? AppColors.darkBorder : AppColors.border;

  /// Divider lines (slightly fainter than border).
  Color get appDivider =>
      _isDark ? AppColors.darkDivider : AppColors.divider;
}
