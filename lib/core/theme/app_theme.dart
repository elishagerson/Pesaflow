import 'package:flutter/material.dart';

class AppTheme {
  // ── Noir & Amethyst Palette ──
  static const Color primaryLight = Color(0xFF7C3AED);
  static const Color primaryLightAccent = Color(0xFF6D28D9);
  static const Color primaryDark = Color(0xFFA78BFA);
  static const Color primaryDarkAccent = Color(0xFF8B5CF6);

  static const Color bgLight = Color(0xFFF5F5F7);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDimLight = Color(0xFFEBEAF0);

  static const Color bgDark = Color(0xFF0A0A0F);
  static const Color surfaceDark = Color(0xFF1C1C1E);
  static const Color surfaceContainerDark = Color(0xFF242428);

  // Finance semantic colors (shared light/dark)
  static const Color incomeColor = Color(0xFF059669);
  static const Color expenseColor = Color(0xFFE11D48);
  static const Color transferColor = Color(0xFF0284C7);

  static const Color incomeColorDark = Color(0xFF34D399);
  static const Color expenseColorDark = Color(0xFFFB7185);
  static const Color transferColorDark = Color(0xFF38BDF8);

  // Accent
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color warningColorDark = Color(0xFFFBBF24);

  // Apple squircle radii
  static const double radiusCard = 16.0;
  static const double radiusDialog = 20.0;
  static const double radiusInput = 14.0;
  static const double radiusButton = 14.0;

  static TextStyle getMonospaceStyle(TextStyle baseStyle) {
    return baseStyle.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: ['JetBrains Mono', 'Roboto Mono', 'Courier New'],
      fontWeight: FontWeight.w600,
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryLight,
        brightness: Brightness.light,
        primary: primaryLight,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFEDE9FE),
        secondary: primaryLightAccent,
        surface: bgLight,
        surfaceContainerLow: surfaceLight,
        surfaceContainer: surfaceDimLight,
        error: expenseColor,
      ),
      scaffoldBackgroundColor: bgLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(
          fontSize: 22.0,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        iconTheme: IconThemeData(color: Colors.black),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: Color(0x0A000000), width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          selectedBackgroundColor: primaryLight,
          selectedForegroundColor: Colors.white,
        ),
      ),
      dividerTheme: const DividerThemeData(
        space: 0,
        thickness: 0.5,
        color: Color(0x1A000000),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryDark,
        brightness: Brightness.dark,
        primary: primaryDark,
        onPrimary: bgDark,
        primaryContainer: Color(0xFF2E1065),
        secondary: primaryDarkAccent,
        surface: bgDark,
        surfaceContainerLow: surfaceDark,
        surfaceContainer: surfaceContainerDark,
        error: expenseColorDark,
      ),
      scaffoldBackgroundColor: bgDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(
          fontSize: 22.0,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceContainerDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: Color(0x15FFFFFF), width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: primaryDark, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          selectedBackgroundColor: primaryDark,
          selectedForegroundColor: bgDark,
        ),
      ),
      dividerTheme: const DividerThemeData(
        space: 0,
        thickness: 0.5,
        color: Color(0x1AFFFFFF),
      ),
    );
  }
}
