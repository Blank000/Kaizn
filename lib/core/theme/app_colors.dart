import 'package:flutter/material.dart';

/// App-wide color palette inspired by Duolingo
/// Bold, gamified, and energetic
class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // Primary Colors
  static const Color primary = Color(0xFF58CC02); // Vivid Green
  static const Color primaryDark = Color(0xFF45A800); // Deep Green
  static const Color background = Color(0xFFF7F7F7); // Off White
  static const Color surface = Color(0xFFFFFFFF); // Pure White

  // Accent Colors
  static const Color streakOrange = Color(0xFFFF9600); // Flame Orange
  static const Color rewardsGold = Color(0xFFFFD700); // Golden Yellow
  static const Color missedRed = Color(0xFFFF4B4B); // Soft Red
  static const Color skipOrange = Color(0xFFFF9B35); // Muted Orange
  static const Color infoBlue = Color(0xFF1CB0F6); // Sky Blue

  // Dark Mode
  static const Color darkBackground = Color(0xFF131F24); // Dark Navy
  static const Color darkSurface = Color(0xFF1F3340); // Dark Card
  static const Color darkTextPrimary = Color(0xFFFFFFFF); // White
  static const Color darkTextSecondary = Color(0xFFAFAFAF); // Muted White
  static const Color darkTextTertiary = Color(0xFF707070); // More muted
  static const Color darkBorder = Color(0xFF2D4252); // Darker than surface
  static const Color darkDivider = Color(0xFF253744); // Subtle divider

  // Text Colors (Light Mode)
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textTertiary = Color(0xFF9B9B9B);

  // Functional Colors
  static const Color success = primary;
  static const Color warning = skipOrange;
  static const Color error = missedRed;
  static const Color info = infoBlue;

  // Border and Divider
  static const Color border = Color(0xFFE5E5E5);
  static const Color divider = Color(0xFFEEEEEE);

  // Per-milestone palette — index stored in milestones.color_index. Default 0
  // (primary green). Order is fixed so saved indexes don't drift over time;
  // append new colors at the end if the palette grows.
  static const List<Color> milestonePalette = [
    primary,            // 0 — green (default)
    infoBlue,           // 1 — blue
    streakOrange,       // 2 — orange
    rewardsGold,        // 3 — gold
    missedRed,          // 4 — red
    Color(0xFFCE82FF),  // 5 — purple
    Color(0xFFFF86C8),  // 6 — pink
    Color(0xFF93A1B5),  // 7 — slate
  ];

  static Color milestoneColor(int index) {
    if (index < 0 || index >= milestonePalette.length) {
      return milestonePalette[0];
    }
    return milestonePalette[index];
  }
}
