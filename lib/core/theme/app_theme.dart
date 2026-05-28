import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  static const Color primaryDark = Color(0xFFA78BFA); // Amethyst purple-300 for dark mode
  static const Color onPrimaryDark = Color(0xFFFFFFFF);
  static const Color primaryContainerDark = Color(0xFF0038A8);
  static const Color onPrimaryContainerDark = Color(0xFFD0E2FF);

  static const Color secondaryDark = Color(0xFF30D158); // Apple iOS vibrant green
  static const Color onSecondaryDark = Color(0xFF000000);
  static const Color secondaryContainerDark = Color(0xFF0F521B);
  static const Color onSecondaryContainerDark = Color(0xFFC7F3D6);

  static const Color tertiaryDark = Color(0xFFFF9F0A); // Apple iOS vibrant orange
  static const Color onTertiaryDark = Color(0xFF000000);

  static const Color bgDark = Color(0xFF000000); // True Pitch Black for ultra-premium AMOLED contrast
  static const Color onBgDark = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF161618); // Modern charcoal grey cards
  static const Color onSurfaceDark = Color(0xFFFFFFFF);
  static const Color surfaceHighDark = Color(0xFF161618);
  static const Color surfaceLowDark = Color(0xFF09090A);

  static const Color outlineDark = Color(0xFF2C2C2E); // Subtle dark outlines
  static const Color outlineVariantDark = Color(0xFF1C1C1E);

  // Finance semantic colors
  static const Color incomeColor = Color(0xFF0A84FF); // Vibrant blue
  static const Color expenseColor = Color(0xFFE11D48);
  static const Color transferColor = Color(0xFF0284C7);

  static const Color incomeColorDark = Color(0xFF00E5FF); // Premium neon cyan/blue
  static const Color expenseColorDark = Color(0xFFFF453A); // Vibrant red
  static const Color transferColorDark = Color(0xFF0A84FF); // Vibrant blue

  static const Color errorLight = Color(0xFFE11D48);
  static const Color onErrorLight = Color(0xFFFFFFFF);
  static const Color errorDark = Color(0xFFFF453A);
  static const Color onErrorDark = Color(0xFF000000);

  // Backward compat aliases (previously named)
  static Color get surfaceContainerDark => surfaceHighDark;

  // Radii
  static const double radiusCard = 20.0; // Premium highly-rounded card corners
  static const double radiusDialog = 24.0;
  static const double radiusInput = 16.0;
  static const double radiusButton = 100.0; // Pill-shape by default for premium buttons

  static TextStyle getMonospaceStyle(TextStyle baseStyle) {
    return baseStyle.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['JetBrains Mono', 'Roboto Mono', 'Courier New'],
      fontWeight: FontWeight.w700,
    );
  }

  static TextTheme _buildTextTheme(Color textColor) {
    return GoogleFonts.outfitTextTheme(
      TextTheme(
        displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w900,
        letterSpacing: -2.0,
        height: 1.1,
        color: textColor,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.5,
        height: 1.15,
        color: textColor,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        height: 1.2,
        color: textColor,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.8,
        height: 1.25,
        color: textColor,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        height: 1.3,
        color: textColor,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        height: 1.35,
        color: textColor,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        height: 1.4,
        color: textColor,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.45,
        color: textColor,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.5,
        color: textColor,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        height: 1.5,
        color: textColor,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        height: 1.5,
        color: textColor,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        height: 1.5,
        color: textColor,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: textColor,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: textColor,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: textColor,
      ),
    ));
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.outfit().fontFamily,
      textTheme: _buildTextTheme(onBgLight),
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
          fontFamily: 'system-ui',
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
        side: BorderSide(color: outlineLight.withValues(alpha: 0.4)),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.outfit().fontFamily,
      textTheme: _buildTextTheme(onBgDark),
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: primaryDark,
        onPrimary: Colors.black,
        primaryContainer: primaryContainerDark,
        onPrimaryContainer: onPrimaryContainerDark,
        secondary: primaryDark,
        onSecondary: onPrimaryDark,
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
          fontFamily: 'system-ui',
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
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          textStyle: const TextStyle(
            fontFamily: 'system-ui',
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          selectedBackgroundColor: primaryDark,
          selectedForegroundColor: Colors.black,
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
        side: BorderSide(color: outlineDark.withValues(alpha: 0.4)),
      ),
    );
  }
}
