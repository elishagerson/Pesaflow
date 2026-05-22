import 'package:flutter/material.dart';

class AppTheme {
  // ── Noir & Amethyst — Full Explicit Palette ──

  // Light
  static const Color primaryLight = Color(0xFF7C3AED);
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color primaryContainerLight = Color(0xFFEDE9FE);
  static const Color onPrimaryContainerLight = Color(0xFF1E1029);

  static const Color secondaryLight = Color(0xFF6D28D9);
  static const Color onSecondaryLight = Color(0xFFFFFFFF);
  static const Color secondaryContainerLight = Color(0xFFE2D5F7);
  static const Color onSecondaryContainerLight = Color(0xFF1E1029);

  static const Color tertiaryLight = Color(0xFFF59E0B);
  static const Color onTertiaryLight = Color(0xFFFFFFFF);

  static const Color bgLight = Color(0xFFF5F5F7);
  static const Color onBgLight = Color(0xFF1C1C1E);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color onSurfaceLight = Color(0xFF1C1C1E);
  static const Color surfaceHighLight = Color(0xFFFFFFFF);
  static const Color surfaceLowLight = Color(0xFFEEEEF2);

  static const Color outlineLight = Color(0xFFC2C0CC);
  static const Color outlineVariantLight = Color(0xFFE2E0E8);

  // Dark
  static const Color primaryDark = Color(0xFFA78BFA);
  static const Color onPrimaryDark = Color(0xFF0A0A0F);
  static const Color primaryContainerDark = Color(0xFF2E1065);
  static const Color onPrimaryContainerDark = Color(0xFFEDE9FE);

  static const Color secondaryDark = Color(0xFF8B5CF6);
  static const Color onSecondaryDark = Color(0xFF0A0A0F);
  static const Color secondaryContainerDark = Color(0xFF3B1D8E);
  static const Color onSecondaryContainerDark = Color(0xFFE2D5F7);

  static const Color tertiaryDark = Color(0xFFFBBF24);
  static const Color onTertiaryDark = Color(0xFF0A0A0F);

  static const Color bgDark = Color(0xFF0A0A0F);
  static const Color onBgDark = Color(0xFFF5F5F7);
  static const Color surfaceDark = Color(0xFF1C1C1E);
  static const Color onSurfaceDark = Color(0xFFF5F5F7);
  static const Color surfaceHighDark = Color(0xFF1C1C1E);
  static const Color surfaceLowDark = Color(0xFF121214);

  static const Color outlineDark = Color(0xFF3F3F46);
  static const Color outlineVariantDark = Color(0xFF27272A);

  // Finance semantic colors
  static const Color incomeColor = Color(0xFF059669);
  static const Color expenseColor = Color(0xFFE11D48);
  static const Color transferColor = Color(0xFF0284C7);

  static const Color incomeColorDark = Color(0xFF34D399);
  static const Color expenseColorDark = Color(0xFFFB7185);
  static const Color transferColorDark = Color(0xFF38BDF8);

  static const Color errorLight = Color(0xFFE11D48);
  static const Color onErrorLight = Color(0xFFFFFFFF);
  static const Color errorDark = Color(0xFFFB7185);
  static const Color onErrorDark = Color(0xFF0A0A0F);

  // Backward compat aliases (previously named)
  static Color get surfaceContainerDark => surfaceHighDark;

  // Radii
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
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: primaryLight,
        onPrimary: onPrimaryLight,
        primaryContainer: primaryContainerLight,
        onPrimaryContainer: onPrimaryContainerLight,
        secondary: secondaryLight,
        onSecondary: onSecondaryLight,
        secondaryContainer: secondaryContainerLight,
        onSecondaryContainer: onSecondaryContainerLight,
        tertiary: tertiaryLight,
        onTertiary: onTertiaryLight,
        surface: bgLight,
        onSurface: onBgLight,
        surfaceContainerHigh: surfaceHighLight,
        surfaceContainerLow: surfaceLowLight,
        outline: outlineLight,
        outlineVariant: outlineVariantLight,
        error: errorLight,
        onError: onErrorLight,
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
          color: Color(0xFF1C1C1E),
        ),
        iconTheme: IconThemeData(color: Color(0xFF1C1C1E)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceHighLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: Color(0x0A000000), width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHighLight,
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
          foregroundColor: onPrimaryLight,
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
          selectedForegroundColor: onPrimaryLight,
        ),
      ),
      dividerTheme: const DividerThemeData(
        space: 0,
        thickness: 0.5,
        color: Color(0x1A000000),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide(color: outlineLight.withOpacity(0.4)),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: primaryDark,
        onPrimary: onPrimaryDark,
        primaryContainer: primaryContainerDark,
        onPrimaryContainer: onPrimaryContainerDark,
        secondary: secondaryDark,
        onSecondary: onSecondaryDark,
        secondaryContainer: secondaryContainerDark,
        onSecondaryContainer: onSecondaryContainerDark,
        tertiary: tertiaryDark,
        onTertiary: onTertiaryDark,
        surface: bgDark,
        onSurface: onBgDark,
        surfaceContainerHigh: surfaceHighDark,
        surfaceContainerLow: surfaceLowDark,
        outline: outlineDark,
        outlineVariant: outlineVariantDark,
        error: errorDark,
        onError: onErrorDark,
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
          color: Color(0xFFF5F5F7),
        ),
        iconTheme: IconThemeData(color: Color(0xFFF5F5F7)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceHighDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: Color(0x15FFFFFF), width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHighDark,
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
          backgroundColor: primaryDark,
          foregroundColor: onPrimaryDark,
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
          selectedForegroundColor: onPrimaryDark,
        ),
      ),
      dividerTheme: const DividerThemeData(
        space: 0,
        thickness: 0.5,
        color: Color(0x1AFFFFFF),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide(color: outlineDark.withOpacity(0.4)),
      ),
    );
  }
}
