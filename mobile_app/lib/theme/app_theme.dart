import 'package:flutter/material.dart';

class AppPalette {
  // Brand & Channel Accents
  static const whatsappGreen = Color(0xFF22C55E);
  static const whatsappDeep = Color(0xFF15803D);
  static const alarmCoral = Color(0xFFFF6B35);
  static const notifIndigo = Color(0xFF6366F1);
  static const cyanAccent = Color(0xFF06B6D4);
  static const amberAccent = Color(0xFFF59E0B);
  static const violetAccent = Color(0xFFA855F7);
  static const roseAccent = Color(0xFFF43F5E);

  // Dark Surface Palette
  static const darkBg = Color(0xFF0A0F1C);
  static const darkCard = Color(0xFF131B2E);
  static const darkCardElevated = Color(0xFF1A243D);
  static const darkBorder = Color(0xFF23304D);

  // Light Surface Palette
  static const lightBg = Color(0xFFF3F6FA);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE2E8F0);

  static Color categoryColor(String category) {
    switch (category) {
      case 'Study / Class':
        return notifIndigo;
      case 'Work / Meeting':
        return amberAccent;
      case 'Fitness / Gym':
        return whatsappGreen;
      case 'Health / Medicine':
        return roseAccent;
      case 'Prayer / Routine':
        return cyanAccent;
      case 'Personal':
        return violetAccent;
      default:
        return const Color(0xFF3B82F6);
    }
  }
}

class AppTheme {
  static ThemeData darkTheme() {
    const colorScheme = ColorScheme.dark(
      primary: AppPalette.whatsappGreen,
      onPrimary: Color(0xFF042611),
      primaryContainer: Color(0xFF123622),
      onPrimaryContainer: Color(0xFF86EFAC),
      secondary: AppPalette.notifIndigo,
      onSecondary: Colors.white,
      surface: AppPalette.darkCard,
      onSurface: Color(0xFFF1F5F9),
      onSurfaceVariant: Color(0xFF94A3B8),
      outlineVariant: AppPalette.darkBorder,
      error: AppPalette.roseAccent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppPalette.darkBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: Color(0xFFF8FAFC),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.darkCardElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppPalette.whatsappGreen, width: 1.6),
        ),
        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
        hintStyle: const TextStyle(color: Color(0xFF64748B)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppPalette.darkCardElevated,
        contentTextStyle: const TextStyle(
          color: Color(0xFFF8FAFC),
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static ThemeData lightTheme() {
    const colorScheme = ColorScheme.light(
      primary: Color(0xFF16A34A),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDCFCE7),
      onPrimaryContainer: Color(0xFF14532D),
      secondary: AppPalette.notifIndigo,
      onSecondary: Colors.white,
      surface: AppPalette.lightCard,
      onSurface: Color(0xFF0F172A),
      onSurfaceVariant: Color(0xFF64748B),
      outlineVariant: AppPalette.lightBorder,
      error: AppPalette.roseAccent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppPalette.lightBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: Color(0xFF0F172A),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
