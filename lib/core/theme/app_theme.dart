import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Sky & Emerald — Light Blue + Emerald Palette ──

  // Light
  static const Color primaryLight = Color(0xFF0A84FF); // Vibrant light blue
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color primaryContainerLight = Color(0xFFDCF0FF); // Very light blue
  static const Color onPrimaryContainerLight = Color(0xFF00325E);

  static const Color secondaryLight = Color(0xFF10B981); // Emerald
  static const Color onSecondaryLight = Color(0xFFFFFFFF);
  static const Color secondaryContainerLight = Color(0xFFD1FAE5); // Light emerald
  static const Color onSecondaryContainerLight = Color(0xFF003D24);

  static const Color tertiaryLight = Color(0xFFF59E0B);
  static const Color onTertiaryLight = Color(0xFFFFFFFF);

  static const Color bgLight = Color(0xFFF2F2F7);
  static const Color onBgLight = Color(0xFF1C1C1E);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color onSurfaceLight = Color(0xFF1C1C1E);
  static const Color surfaceHighLight = Color(0xFFFFFFFF);
  static const Color surfaceLowLight = Color(0xFFEEEEF2);

  static const Color outlineLight = Color(0xFFC2C0CC);
  static const Color outlineVariantLight = Color(0xFFE2E0E8);

  // Dark
  static const Color primaryDark = Color(0xFF30D158); // Neon emerald green for main dark accents
  static const Color onPrimaryDark = Color(0xFF000000);
  static const Color primaryContainerDark = Color(0xFF003D24);
  static const Color onPrimaryContainerDark = Color(0xFFD1FAE5);

  static const Color secondaryDark = Color(0xFF0A84FF); // Sky blue
  static const Color onSecondaryDark = Color(0xFFFFFFFF);
  static const Color secondaryContainerDark = Color(0xFF00325E);
  static const Color onSecondaryContainerDark = Color(0xFFDCF0FF);

  static const Color tertiaryDark = Color(0xFFFF9F0A);
  static const Color onTertiaryDark = Color(0xFF000000);

  static const Color bgDark = Color(0xFF090A0E); // Deep pitch black-gray background
  static const Color onBgDark = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF14151B); // Dark cards background
  static const Color onSurfaceDark = Color(0xFFFFFFFF);
  static const Color surfaceHighDark = Color(0xFF1C1D24); // Elevated cards background
  static const Color surfaceLowDark = Color(0xFF0E0F13);

  static const Color outlineDark = Color(0x1AFFFFFF); // Translucent border for glassy panels
  static const Color outlineVariantDark = Color(0x10FFFFFF);

  // Finance semantic colors
  static const Color incomeColor = Color(0xFF0A84FF); // Vibrant blue
  static const Color expenseColor = Color(0xFFE11D48);
  static const Color transferColor = Color(0xFF0284C7);

  static const Color incomeColorDark = Color(0xFF30D158); // Neon green/emerald
  static const Color expenseColorDark = Color(0xFFFF453A); // Coral red
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

  static ThemeData get lightTheme => fromColorScheme(null, Brightness.light);

  static ThemeData get darkTheme => fromColorScheme(null, Brightness.dark);

  static ThemeData fromColorScheme(ColorScheme? cs, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = cs ?? _defaultColorScheme(brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: GoogleFonts.outfit().fontFamily,
      textTheme: _buildTextTheme(isLight ? onBgLight : onBgDark),
      colorScheme: scheme,
      scaffoldBackgroundColor: isLight ? bgLight : bgDark,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(
          fontFamily: 'system-ui',
          fontSize: 22.0,
          fontWeight: FontWeight.bold,
          color: isLight ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
        ),
        iconTheme: IconThemeData(color: isLight ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isLight ? surfaceHighLight : surfaceHighDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(
            color: isLight ? const Color(0x0F000000) : const Color(0x12FFFFFF),
            width: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? surfaceHighLight : surfaceHighDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: scheme.primary, width: isLight ? 2 : 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: isLight ? 12.0 : 14.0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: isLight ? 14.0 : 16.0),
          textStyle: isLight ? null : const TextStyle(
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
          selectedBackgroundColor: scheme.primary,
          selectedForegroundColor: scheme.onPrimary,
        ),
      ),
      dividerTheme: DividerThemeData(
        space: 0,
        thickness: 0.5,
        color: isLight ? const Color(0x0F000000) : const Color(0x12FFFFFF),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ColorScheme _defaultColorScheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return ColorScheme(
      brightness: brightness,
      primary: isLight ? primaryLight : primaryDark,
      onPrimary: isLight ? onPrimaryLight : Colors.black,
      primaryContainer: isLight ? primaryContainerLight : primaryContainerDark,
      onPrimaryContainer: isLight ? onPrimaryContainerLight : onPrimaryContainerDark,
      secondary: isLight ? secondaryLight : secondaryDark,
      onSecondary: isLight ? onSecondaryLight : onSecondaryDark,
      secondaryContainer: isLight ? secondaryContainerLight : secondaryContainerDark,
      onSecondaryContainer: isLight ? onSecondaryContainerLight : onSecondaryContainerDark,
      tertiary: isLight ? tertiaryLight : tertiaryDark,
      onTertiary: isLight ? onTertiaryLight : Colors.black,
      surface: isLight ? bgLight : bgDark,
      onSurface: isLight ? onBgLight : onBgDark,
      surfaceContainerHigh: isLight ? surfaceHighLight : surfaceHighDark,
      surfaceContainerLow: isLight ? surfaceLowLight : surfaceLowDark,
      outline: isLight ? outlineLight : outlineDark,
      outlineVariant: isLight ? outlineVariantLight : outlineVariantDark,
      error: isLight ? errorLight : errorDark,
      onError: isLight ? onErrorLight : onErrorDark,
    );
  }
}
