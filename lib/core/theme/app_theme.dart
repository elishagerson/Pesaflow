import 'package:flutter/material.dart';

class AppTheme {
  // Brand color tokens (One App Premium Inspired Tones)
  static const Color primaryLight = Color(0xFF006B4F); // Deep emerald green
  static const Color primaryLightAccent = Color(0xFF006B4F);
  static const Color primaryDark = Color(0xFF2AD0A6); // High-fidelity neon-mint teal
  
  static const Color bgLight = Color(0xFFF9F9FB);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDimLight = Color(0xFFEBEBEF);
  
  static const Color bgDark = Color(0xFF080808); // Absolute deep carbon dark
  static const Color surfaceDark = Color(0xFF121212); // Carbon surface
  static const Color surfaceContainerDark = Color(0xFF161616); // High-contrast bento card background

  static const Color incomeColor = Color(0xFF2AD0A6); // Bright mint
  static const Color expenseColor = Color(0xFFFF5A5F); // Coral pink/red
  static const Color transferColor = Color(0xFF42A5F5); // Blue
  
  static const Color incomeColorDark = Color(0xFF2AD0A6);
  static const Color expenseColorDark = Color(0xFFFF5A5F);
  static const Color transferColorDark = Color(0xFF42A5F5);

  // Border radius configurations matching Apple squircle principles
  static const double radiusCard = 16.0;
  static const double radiusDialog = 20.0;
  static const double radiusInput = 14.0;
  static const double radiusButton = 14.0; // Modern squircle buttons

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
          side: const BorderSide(color: Color(0x14000000), width: 1.0),
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
          side: const BorderSide(color: Color(0x15FFFFFF), width: 0.8), // Thin translucent border for premium aesthetic
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
          backgroundColor: Colors.white, // Stark premium white CTA like Mobbin "One" App Continue button
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
    );
  }
}
