import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// App-wide typography using Nunito font (Google Fonts)
/// Inspired by Duolingo's bold and rounded aesthetic
class AppTypography {
  // Private constructor to prevent instantiation
  AppTypography._();

  // Base font family
  static TextTheme get textTheme => GoogleFonts.nunitoTextTheme();

  // Display - Used for streak numbers, points balance
  // Color intentionally omitted so the text inherits the theme's text color
  // (light mode = near-black, dark mode = white). Override via copyWith for
  // brand-colored displays (primary green, gold, etc.).
  static TextStyle display = GoogleFonts.nunito(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    height: 1.2,
  );

  // Heading 1 - Screen titles
  static TextStyle heading1 = GoogleFonts.nunito(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  // Heading 2 - Section headers, card titles
  static TextStyle heading2 = GoogleFonts.nunito(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.4,
  );

  // Body - Main content, descriptions
  static TextStyle body = GoogleFonts.nunito(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  // Caption - Subtitles, timestamps, labels.
  // Light-mode color baked in here; override with context.appTextSecondary
  // in dark mode (or any explicit color via copyWith).
  static TextStyle caption = GoogleFonts.nunito(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // Button - All CTAs
  static TextStyle button = GoogleFonts.nunito(
    fontSize: 16,
    fontWeight: FontWeight.w800, // ExtraBold
    color: Colors.white,
    height: 1.2,
  );

  // Utility: Color variants for common use cases
  static TextStyle displayWithColor(Color color) => display.copyWith(color: color);
  static TextStyle heading1WithColor(Color color) => heading1.copyWith(color: color);
  static TextStyle heading2WithColor(Color color) => heading2.copyWith(color: color);
  static TextStyle bodyWithColor(Color color) => body.copyWith(color: color);
  static TextStyle captionWithColor(Color color) => caption.copyWith(color: color);
  static TextStyle buttonWithColor(Color color) => button.copyWith(color: color);
}
