import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppTheme {
  // ── Liquid Glass iOS 26+ Palette ──

  // Light
  static const Color primaryLight = Color(0xFF609F8A);
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color primaryContainerLight = Color(0xFFE4F0EC);
  static const Color onPrimaryContainerLight = Color(0xFF122C23);

  static const Color secondaryLight = Color(0xFF609F8A); // Sage green
  static const Color onSecondaryLight = Color(0xFFFFFFFF);
  static const Color secondaryContainerLight = Color(0xFFD1FAE5);
  static const Color onSecondaryContainerLight = Color(0xFF003D24);

  static const Color tertiaryLight = Color(0xFFFF9F0A); // Apple system orange
  static const Color onTertiaryLight = Color(0xFFFFFFFF);

  static const Color bgLight = Color(0xFFF2F2F7);
  static const Color onBgLight = Color(0xFF1C1C1E);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color onSurfaceLight = Color(0xFF1C1C1E);

  // Dark — true black background per iOS 26 Liquid Glass
  static const Color bgDark = Color(0xFF000000);
  static const Color onBgDark = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1C1C1E);
  static const Color onSurfaceDark = Color(0xFFFFFFFF);
  static const Color surfaceHighDark = Color(0xFF2C2C2E);

  // Finance semantic colors — Apple system colors
  static const Color incomeColor = Color(0xFF609F8A);   // Sage green (light)
  static const Color expenseColor = Color(0xFFFF3B30);  // Apple system red (light)
  static const Color transferColor = Color(0xFF609F8A); // Sage green (light)

  static const Color incomeColorDark = Color(0xFF609F8A);   // Sage green (dark)
  static const Color expenseColorDark = Color(0xFFFF453A);  // Coral red (dark)
  static const Color transferColorDark = Color(0xFF609F8A); // Sage green (dark)

  static const Color errorLight = Color(0xFFFF3B30);
  static const Color onErrorLight = Color(0xFFFFFFFF);
  static const Color errorDark = Color(0xFFFF453A);
  static const Color onErrorDark = Color(0xFF000000);

  // Backward compat aliases
  static Color get surfaceContainerDark => surfaceHighDark;

  // Radii
  static const double radiusCard = 20.0;
  static const double radiusDialog = 24.0;
  static const double radiusInput = 16.0;
  static const double radiusButton = 100.0;

  static TextStyle getMonospaceStyle(TextStyle baseStyle) {
    return baseStyle.copyWith(
      fontFamilyFallback: const ['SF Mono', 'JetBrains Mono', 'Roboto Mono', 'Courier New'],
      fontWeight: FontWeight.w900,
    );
  }

  static TextTheme _buildTextTheme(Color textColor) {
    return TextTheme(
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
        fontWeight: FontWeight.w600,
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
        fontSize: 17,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        height: 1.5,
        color: textColor,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        height: 1.5,
        color: textColor,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
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
    );
  }

  static ThemeData get lightTheme => fromColorScheme(null, Brightness.light);

  static ThemeData get darkTheme => fromColorScheme(null, Brightness.dark);

  static ThemeData fromColorScheme(ColorScheme? cs, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = cs ?? _defaultColorScheme(brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: null, // system font (SF Pro on iOS, Roboto on Android)
      textTheme: _buildTextTheme(isLight ? onBgLight : onBgDark),
      colorScheme: scheme,
      scaffoldBackgroundColor: isLight ? bgLight : bgDark,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22.0,
          fontWeight: FontWeight.bold,
          color: isLight ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
        ),
        iconTheme: IconThemeData(
          color: isLight ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? const Color(0xFFF2F2F7)
            : const Color(0xFF2C2C2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(
            color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08),
            width: 0.8,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: scheme.error, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(
            color: isLight ? Colors.black.withValues(alpha: 0.02) : Colors.white.withValues(alpha: 0.03),
            width: 0.8,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
          textStyle: TextStyle(
            fontWeight: FontWeight.w700,
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
        thickness: 0,
        color: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide.none,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: isLight ? bgLight : surfaceHighDark,
        elevation: 0,
        headerBackgroundColor: isLight ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E),
        headerForegroundColor: isLight ? Colors.black : Colors.white,
        headerHeadlineStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        dayStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        weekdayStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isLight ? Colors.grey[700] : Colors.grey[400]),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
          side: BorderSide(
            color: isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return Colors.transparent;
        }),
        dayForegroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          if (states.contains(WidgetState.disabled)) {
            return isLight ? Colors.grey[300] : Colors.grey[700];
          }
          return isLight ? Colors.black : Colors.white;
        }),
        todayBackgroundColor: WidgetStateProperty.all(Colors.transparent),
        todayForegroundColor: WidgetStateProperty.all(scheme.primary),
        todayBorder: BorderSide(color: scheme.primary, width: 1.5),
        cancelButtonStyle: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(isLight ? Colors.grey[700] : Colors.grey[400]),
        ),
        confirmButtonStyle: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(scheme.primary),
        ),
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
      primary: isLight ? primaryLight : primaryLight,
      onPrimary: isLight ? onPrimaryLight : Colors.black,
      primaryContainer: isLight ? primaryContainerLight : primaryContainerLight,
      onPrimaryContainer: isLight ? onPrimaryContainerLight : onPrimaryContainerLight,
      secondary: isLight ? secondaryLight : secondaryLight,
      onSecondary: isLight ? onSecondaryLight : onSecondaryLight,
      secondaryContainer: isLight ? secondaryContainerLight : secondaryContainerLight,
      onSecondaryContainer: isLight ? onSecondaryContainerLight : onSecondaryContainerLight,
      tertiary: isLight ? tertiaryLight : tertiaryLight,
      onTertiary: isLight ? onTertiaryLight : Colors.black,
      surface: isLight ? bgLight : bgDark,
      onSurface: isLight ? onBgLight : onBgDark,
      surfaceContainerHigh: isLight ? surfaceLight : surfaceHighDark,
      surfaceContainerLow: isLight ? bgLight : bgDark,
      outline: isLight ? const Color(0x1A000000) : const Color(0x1AFFFFFF),
      outlineVariant: isLight ? const Color(0x0F000000) : const Color(0x0FFFFFFF),
      error: isLight ? errorLight : errorDark,
      onError: isLight ? onErrorLight : onErrorDark,
    );
  }
}
