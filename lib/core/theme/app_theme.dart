import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── "Ocean & Gold" — distinctive fintech palette ──

  // Light
  static const Color primaryLight = Color(0xFF0F4C5C);
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color primaryContainerLight = Color(0xFFC7E8ED);
  static const Color onPrimaryContainerLight = Color(0xFF061F26);

  static const Color secondaryLight = Color(0xFF3B8A8F);
  static const Color onSecondaryLight = Color(0xFFFFFFFF);
  static const Color secondaryContainerLight = Color(0xFFBEE3E6);
  static const Color onSecondaryContainerLight = Color(0xFF0A2F33);

  static const Color tertiaryLight = Color(0xFFD4942D);
  static const Color tertiaryLightVariant = Color(0xFFF4B740);
  static const Color onTertiaryLight = Color(0xFFFFFFFF);
  static const Color tertiaryContainerLight = Color(0xFFFCECC8);
  static const Color onTertiaryContainerLight = Color(0xFF3D2A06);

  static const Color bgLight = Color(0xFFF5F3F0);
  static const Color onBgLight = Color(0xFF1E202A);
  static const Color surfaceLight = Color(0xFFFEFDFB);
  static const Color onSurfaceLight = Color(0xFF1E202A);
  static const Color surfaceHighLight = Color(0xFFF0EEEA);

  // Dark — deep navy base
  static const Color bgDark = Color(0xFF0D1117);
  static const Color onBgDark = Color(0xFFF0F6FC);
  static const Color surfaceDark = Color(0xFF161B22);
  static const Color onSurfaceDark = Color(0xFFF0F6FC);
  static const Color surfaceHighDark = Color(0xFF21262D);

  // Finance semantic colors
  static const Color incomeColor = Color(0xFF10B981);
  static const Color expenseColor = Color(0xFFEF4444);
  static const Color transferColor = Color(0xFF6366F1);

  static const Color incomeColorDark = Color(0xFF34D399);
  static const Color expenseColorDark = Color(0xFFF87171);
  static const Color transferColorDark = Color(0xFF818CF8);

  static const Color errorLight = Color(0xFFEF4444);
  static const Color onErrorLight = Color(0xFFFFFFFF);
  static const Color errorDark = Color(0xFFF87171);
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
      fontFamilyFallback: const [
        'SF Mono',
        'JetBrains Mono',
        'Roboto Mono',
        'Courier New',
      ],
      fontWeight: FontWeight.w900,
    );
  }

  static TextTheme _buildTextTheme(Color textColor) {
    final base = GoogleFonts.interTextTheme();
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 57,
        fontWeight: FontWeight.w800,
        letterSpacing: -2.0,
        height: 1.1,
        color: textColor,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: 45,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
        height: 1.15,
        color: textColor,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        height: 1.2,
        color: textColor,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.25,
        color: textColor,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.3,
        color: textColor,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.35,
        color: textColor,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.4,
        color: textColor,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.45,
        color: textColor,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.5,
        color: textColor,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        height: 1.5,
        color: textColor,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        height: 1.5,
        color: textColor,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        height: 1.5,
        color: textColor,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: textColor,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: textColor,
      ),
      labelSmall: base.labelSmall?.copyWith(
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
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: _buildTextTheme(isLight ? onBgLight : onBgDark),
      colorScheme: scheme,
      scaffoldBackgroundColor: isLight ? bgLight : bgDark,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22.0,
          fontWeight: FontWeight.w700,
          color: isLight ? onBgLight : const Color(0xFFF0F6FC),
        ),
        iconTheme: IconThemeData(
          color: isLight ? onBgLight : const Color(0xFFF0F6FC),
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
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? const Color(0xFFF0F1F4) : const Color(0xFF21262D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(
            color: isLight
                ? Colors.black.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.08),
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
            color: isLight
                ? Colors.black.withValues(alpha: 0.02)
                : Colors.white.withValues(alpha: 0.03),
            width: 0.8,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 14.0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 2,
          shadowColor: scheme.primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
          minimumSize: const Size(48, 48),
          textStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        headerBackgroundColor: isLight
            ? const Color(0xFFF0F1F4)
            : const Color(0xFF161B22),
        headerForegroundColor: isLight ? onBgLight : Colors.white,
        headerHeadlineStyle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        dayStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        weekdayStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isLight ? Colors.grey[700] : Colors.grey[400],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
          side: BorderSide(
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.08),
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
          foregroundColor: WidgetStateProperty.all(
            isLight ? Colors.grey[700] : Colors.grey[400],
          ),
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
      primary: isLight ? primaryLight : const Color(0xFF83C5BE),
      onPrimary: isLight ? onPrimaryLight : Colors.black,
      primaryContainer: isLight
          ? primaryContainerLight
          : const Color(0xFF0A3A45),
      onPrimaryContainer: isLight
          ? onPrimaryContainerLight
          : const Color(0xFFC7E8ED),
      secondary: isLight ? secondaryLight : const Color(0xFF83C5BE),
      onSecondary: isLight ? onSecondaryLight : Colors.black,
      secondaryContainer: isLight
          ? secondaryContainerLight
          : const Color(0xFF1A4F52),
      onSecondaryContainer: isLight
          ? onSecondaryContainerLight
          : const Color(0xFFBEE3E6),
      tertiary: isLight ? tertiaryLight : const Color(0xFFF4B740),
      onTertiary: isLight ? onTertiaryLight : Colors.black,
      tertiaryContainer: isLight
          ? tertiaryContainerLight
          : const Color(0xFF4A350E),
      onTertiaryContainer: isLight
          ? onTertiaryContainerLight
          : const Color(0xFFFCECC8),
      surface: isLight ? bgLight : bgDark,
      onSurface: isLight ? onBgLight : onBgDark,
      surfaceContainerHigh: isLight ? surfaceHighLight : surfaceHighDark,
      surfaceContainerLow: isLight ? bgLight : bgDark,
      outline: isLight ? const Color(0x1A000000) : const Color(0x1AFFFFFF),
      outlineVariant: isLight
          ? const Color(0x0F000000)
          : const Color(0x0FFFFFFF),
      error: isLight ? errorLight : errorDark,
      onError: isLight ? onErrorLight : onErrorDark,
    );
  }
}
