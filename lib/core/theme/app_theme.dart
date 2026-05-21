import 'package:flutter/material.dart';

class AppTheme {
  // Brand color tokens (Emerald & Navy/Charcoal)
  static const Color primaryLight = Color(0xFF006B4F); // Emerald Green #006B4F
  static const Color primaryLightAccent = Color(0xFF006B4F);
  static const Color primaryDark = Color(0xFF4CD9A8); // Mint Green
  
  static const Color bgLight = Color(0xFFFFFBFE);
  static const Color surfaceLight = Color(0xFFF3EDF7);
  static const Color surfaceDimLight = Color(0xFFDED8E1);
  
  static const Color bgDark = Color(0xFF141218); // Deep charcoal
  static const Color surfaceDark = Color(0xFF1C1B1F);
  static const Color surfaceContainerDark = Color(0xFF211F26);

  static const Color incomeColor = Color(0xFF2E7D32); // Green
  static const Color expenseColor = Color(0xFFC62828); // Red
  static const Color transferColor = Color(0xFF1565C0); // Blue
  
  static const Color incomeColorDark = Color(0xFF66BB6A);
  static const Color expenseColorDark = Color(0xFFEF5350);
  static const Color transferColorDark = Color(0xFF42A5F5);

  // Border radius configurations matching Apple squircle principles
  static const double radiusCard = 12.0;
  static const double radiusDialog = 16.0;
  static const double radiusInput = 8.0;
  static const double radiusButton = 28.0;

  // Custom typography scale
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
        seedColor: primaryLightAccent,
        brightness: Brightness.light,
        primary: primaryLightAccent,
        surface: bgLight,
        surfaceContainer: surfaceLight,
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
          side: const BorderSide(color: Color(0x1F000000), width: 1),
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
          borderSide: const BorderSide(color: primaryLightAccent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLightAccent,
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
          selectedBackgroundColor: primaryLightAccent,
          selectedForegroundColor: Colors.white,
        ),
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
        surface: bgDark,
        surfaceContainer: surfaceDark,
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
          side: const BorderSide(color: Color(0x1FFFFFFF), width: 1),
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
          borderSide: const BorderSide(color: primaryDark, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: bgDark,
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
          selectedBackgroundColor: primaryDark,
          selectedForegroundColor: bgDark,
        ),
      ),
    );
  }
}
