import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// App-wide theme configuration. Light and dark variants share button shapes,
/// corner radii, and typography; they differ on surface/background/text
/// colors. Brand accent colors (primary, gold, orange, etc.) are identical
/// across modes.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _build(
        brightness: Brightness.light,
        scaffoldBg: AppColors.background,
        surface: AppColors.surface,
        textOnSurface: AppColors.textPrimary,
        textSecondary: AppColors.textSecondary,
        border: AppColors.border,
        divider: AppColors.divider,
        systemOverlay: SystemUiOverlayStyle.dark,
      );

  static ThemeData get darkTheme => _build(
        brightness: Brightness.dark,
        scaffoldBg: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        textOnSurface: AppColors.darkTextPrimary,
        textSecondary: AppColors.darkTextSecondary,
        border: AppColors.darkBorder,
        divider: AppColors.darkDivider,
        systemOverlay: SystemUiOverlayStyle.light,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color scaffoldBg,
    required Color surface,
    required Color textOnSurface,
    required Color textSecondary,
    required Color border,
    required Color divider,
    required SystemUiOverlayStyle systemOverlay,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            secondary: AppColors.infoBlue,
            onSecondary: Colors.white,
            surface: surface,
            onSurface: textOnSurface,
            error: AppColors.error,
            onError: Colors.white,
            outline: border,
          )
        : ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            secondary: AppColors.infoBlue,
            onSecondary: Colors.white,
            surface: surface,
            onSurface: textOnSurface,
            error: AppColors.error,
            onError: Colors.white,
            outline: border,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textOnSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.heading1.copyWith(color: textOnSurface),
        systemOverlayStyle: systemOverlay,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: AppTypography.button,
          shadowColor: AppColors.primaryDark,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textOnSurface,
          side: BorderSide(color: border, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: AppTypography.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTypography.button,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: AppTypography.body.copyWith(
          color: isDark
              ? AppColors.darkTextTertiary
              : AppColors.textTertiary,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: border,
      ),
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: AppColors.primary,
        selectedLabelStyle: AppTypography.caption.copyWith(color: AppColors.primary),
        unselectedItemColor: textSecondary,
        unselectedLabelStyle:
            AppTypography.caption.copyWith(color: textSecondary),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      textTheme: AppTypography.textTheme.apply(
        bodyColor: textOnSurface,
        displayColor: textOnSurface,
      ),
      iconTheme: IconThemeData(color: textOnSurface, size: 24),
      dialogTheme: DialogThemeData(backgroundColor: surface),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface),
      popupMenuTheme: PopupMenuThemeData(color: surface),
    );
  }
}
