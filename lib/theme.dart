import 'package:flutter/material.dart';

/// Brand palette — mirrors the website (dark "ink" + gold accent).
class AppColors {
  static const ink = Color(0xFF0B0B0D);
  static const ink800 = Color(0xFF141416);
  static const ink700 = Color(0xFF1B1B1F);
  static const ink600 = Color(0xFF232329);
  static const gold = Color(0xFFF9B233);
  static const goldDark = Color(0xFFC67D0D);
  static const textMuted = Color(0xFF9AA0A6);
}

ThemeData buildAppTheme() {
  const gold = AppColors.gold;

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.ink,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: gold,
      secondary: gold,
      surface: AppColors.ink700,
      onPrimary: AppColors.ink,
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ink800,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.ink,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: gold, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: AppColors.ink,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    ),
  );
}
