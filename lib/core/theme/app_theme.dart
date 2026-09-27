import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_colors_theme.dart';
import 'app_typography_theme.dart';
import 'package:pesaflow/presentation/common/widgets/squircle_border.dart';

export 'app_typography_theme.dart';
import 'package:pesaflow/core/utils/spacing.dart';

class AppTheme {
  // ── Bundled typefaces ──
  //
  // Fonts ship in the binary. Nothing is fetched at runtime, so an offline
  // cold start renders identical type to a warm start. Three cuts:
  //   Inter         — text workhorse, 5 static weights
  //   InterDisplay  — optical display cut of Inter, correct fit at >= 24px
  //   BebasNeue     — condensed poster display, all-caps, reserved for the
  //                   biggest moment on a screen and nothing else
  static const String fontText = 'Inter';
  static const String fontDisplay = 'InterDisplay';
  static const String fontPoster = 'BebasNeue';

  // ── Brand identity ──
  //
  // Exactly one loud accent in the entire app. The four financial semantics
  // (income / expense / transfer / warning) are deliberately far away from it
  // on the wheel so a brand-coloured surface can never be misread as a
  // transaction. A screen may show the accent on at most one primary action.

  // Light — deep electric indigo. White on it measures 7.1:1.
  static const Color brandPrimaryLight = Color(0xFF5B2EE5);
  static const Color brandOnPrimaryLight = Color(0xFFFFFFFF);
  static const Color brandContainerLight = Color(0xFFEDE7FE);
  static const Color brandOnContainerLight = Color(0xFF2E1065);

  // Dark — lifted violet. Ink on it measures 6.3:1, and on OLED black the
  // accent itself measures 6.7:1, so it stays legible as text too.
  static const Color brandPrimaryDark = Color(0xFF9D7BFF);
  static const Color brandOnPrimaryDark = Color(0xFF0A0416);
  static const Color brandContainerDark = Color(0xFF2A1B57);
  static const Color brandOnContainerDark = Color(0xFFDCCCFF);

  // Accent gradient — the only gradient allowed to carry brand meaning.
  static const Color brandGradientFromLight = Color(0xFF5B2EE5);
  static const Color brandGradientToLight = Color(0xFF9B5CFF);
  static const Color brandGradientFromDark = Color(0xFF9D7BFF);
  static const Color brandGradientToDark = Color(0xFFD3B8FF);

  // ── Calm & Clean — Budjetly-inspired palette ──

  // Light — airy blue-grey canvas
  static const Color primaryLight = Color(0xFF3B82F6); // Clean blue
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color primaryContainerLight = Color(0xFFDBEAFE);
  static const Color onPrimaryContainerLight = Color(0xFF1E3A5F);

  static const Color secondaryLight = Color(0xFF64748B); // Slate
  static const Color onSecondaryLight = Color(0xFFFFFFFF);
  static const Color secondaryContainerLight = Color(0xFFE2E8F0);
  static const Color onSecondaryContainerLight = Color(0xFF1E293B);

  static const Color tertiaryLight = Color(0xFFF59E0B); // Warm amber
  static const Color tertiaryLightVariant = Color(0xFFFBBF24);
  static const Color onTertiaryLight = Color(0xFFFFFFFF);
  static const Color tertiaryContainerLight = Color(0xFFFEF3C7);
  static const Color onTertiaryContainerLight = Color(0xFF451A03);

  static const Color bgLight = Color(0xFFF1F5F9); // Slate-100
  static const Color onBgLight = Color(0xFF0F172A); // Slate-900
  static const Color surfaceLight = Color(0xFFFFFFFF); // Pure white cards
  static const Color onSurfaceLight = Color(0xFF0F172A);
  static const Color surfaceHighLight = Color(
    0xFFFFFFFF,
  ); // Pure white for elevated surfaces

  // Dark — OLED black base
  static const Color bgDark = Color(0xFF000000); // Pure OLED black
  static const Color onBgDark = Color(0xFFF8FAFC);
  static const Color surfaceDark = Color(0xFF0F0F0F); // Very dark gray
  static const Color onSurfaceDark = Color(0xFFF8FAFC);
  static const Color surfaceHighDark = Color(
    0xFF1C1C1E,
  ); // Apple system dark gray

  // Finance semantic colors — desaturated, premium tones.
  // Transfer is cyan, not indigo: the brand accent now owns the violet end of
  // the wheel, and a transfer pill must never be mistaken for a brand surface.
  static const Color incomeColor = Color(0xFF16A34A); // Muted green, not neon
  static const Color expenseColor = Color(0xFFDC2626); // Softer red, not fire
  static const Color transferColor = Color(0xFF0891B2); // Deep cyan

  static const Color incomeColorDark = Color(0xFF4ADE80); // Softer light green
  static const Color expenseColorDark = Color(0xFFF87171); // Pastel red
  static const Color transferColorDark = Color(0xFF38BDF8); // Sky

  static const Color errorLight = Color(0xFFDC2626);
  static const Color onErrorLight = Color(0xFFFFFFFF);
  static const Color errorDark = Color(0xFFF87171);
  static const Color onErrorDark = Color(0xFF000000);

  // Backward compat aliases
  static Color get surfaceContainerDark => surfaceHighDark;

  // Radii — generous, soft corners (Budjetly feel)
  static const double radiusTiny = 4.0;
  static const double radiusSmall = 8.0;
  static const double radiusCompact = 10.0;
  static const double radiusInput = 12.0;
  static const double radiusCard = 16.0;
  static const double radiusHero = 20.0;
  static const double radiusDialog = 24.0;
  static const double radiusButton = 28.0;
  static const double radiusPill = 100.0;

  static TextStyle getMonospaceStyle(TextStyle baseStyle) {
    return baseStyle.copyWith(
      fontFamilyFallback: const [
        'SF Mono',
        'JetBrains Mono',
        'Roboto Mono',
        'Courier New',
      ],
      fontWeight: FontWeight.w700,
    );
  }

  static TextTheme _buildTextTheme(Color textColor) {
    // The poster cut. Bebas Neue is a single-weight all-caps face; it is used
    // for the single largest element on a screen and nowhere else. Line height
    // is pulled below 1.0 because the glyphs already fill the em box.
    TextStyle poster(double size, {double tracking = 0.0}) => TextStyle(
      fontFamily: fontPoster,
      fontSize: size,
      fontWeight: FontWeight.w400,
      letterSpacing: tracking,
      height: 0.92,
      color: textColor,
    );

    // The optical display cut of Inter. Correct aperture for type >= 24px.
    TextStyle interDisplay(
      double size,
      FontWeight weight,
      double tracking,
      double height,
    ) => TextStyle(
      fontFamily: fontDisplay,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: tracking,
      height: height,
      color: textColor,
    );

    TextStyle inter(
      double size,
      FontWeight weight,
      double tracking,
      double height,
    ) => TextStyle(
      fontFamily: fontText,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: tracking,
      height: height,
      color: textColor,
    );

    // Line heights are inherited unchanged from the previous scale so the
    // vertical rhythm of every existing screen stays exactly where it was.
    return TextTheme(
      displayLarge: poster(72),
      displayMedium: poster(52),
      displaySmall: poster(40),
      headlineLarge: interDisplay(32, FontWeight.w800, -0.8, 1.25),
      headlineMedium: interDisplay(28, FontWeight.w800, -0.6, 1.3),
      headlineSmall: interDisplay(24, FontWeight.w700, -0.4, 1.35),
      titleLarge: interDisplay(22, FontWeight.w700, -0.4, 1.4),
      titleMedium: inter(16, FontWeight.w600, -0.2, 1.45),
      titleSmall: inter(14, FontWeight.w600, -0.1, 1.5),
      bodyLarge: inter(17, FontWeight.w400, 0.1, 1.5),
      bodyMedium: inter(15, FontWeight.w400, 0.0, 1.55),
      bodySmall: inter(13, FontWeight.w400, 0.05, 1.55),
      labelLarge: inter(14, FontWeight.w700, 0.1, 1.2),
      labelMedium: inter(12, FontWeight.w700, 0.2, 1.2),
      labelSmall: inter(11, FontWeight.w600, 0.3, 1.2),
    );
  }

  static ThemeData get lightTheme => fromColorScheme(null, Brightness.light);

  static ThemeData get darkTheme => fromColorScheme(null, Brightness.dark);

  static ThemeData fromColorScheme(ColorScheme? cs, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = cs ?? _defaultColorScheme(brightness);
    final txtTheme = _buildTextTheme(isLight ? onBgLight : onBgDark);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: txtTheme,
      colorScheme: scheme,
      extensions: [
        isLight ? AppColorsTheme.light() : AppColorsTheme.dark(),
        AppTypographyTheme.base(txtTheme),
      ],
      scaffoldBackgroundColor: isLight ? bgLight : bgDark,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: txtTheme.titleLarge!.copyWith(
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
        fillColor: isLight ? const Color(0xFFFFFFFF) : const Color(0xFF1E293B),
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
          horizontal: kSpacing16,
          vertical: kSpacing14,
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
          padding: EdgeInsets.symmetric(
            horizontal: kSpacing24,
            vertical: kSpacing14,
          ),
          minimumSize: const Size(48, 48),
          textStyle: txtTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.w700,
          ),
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
            borderRadius: BorderRadius.circular(AppTheme.radiusHero),
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
          borderRadius: BorderRadius.circular(AppTheme.radiusHero),
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
        headerBackgroundColor: isLight
            ? const Color(0xFFF1F5F9)
            : const Color(0xFF1E293B),
        headerForegroundColor: isLight ? onBgLight : Colors.white,
        headerHeadlineStyle: txtTheme.headlineSmall!.copyWith(
          fontWeight: FontWeight.bold,
        ),
        dayStyle: txtTheme.titleMedium!.copyWith(fontWeight: FontWeight.w500),
        weekdayStyle: txtTheme.titleSmall!.copyWith(
          fontWeight: FontWeight.bold,
          color: isLight ? Colors.grey[700] : Colors.grey[400],
        ),
        shape: SquircleBorder(
          borderRadius: 24.0,
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
      primary: isLight ? brandPrimaryLight : brandPrimaryDark,
      onPrimary: isLight ? brandOnPrimaryLight : brandOnPrimaryDark,
      primaryContainer: isLight
          ? brandContainerLight
          : brandContainerDark,
      onPrimaryContainer: isLight
          ? brandOnContainerLight
          : brandOnContainerDark,
      secondary: isLight
          ? secondaryLight
          : const Color(0xFF94A3B8), // Slate-400
      onSecondary: isLight ? onSecondaryLight : const Color(0xFF0F172A),
      secondaryContainer: isLight
          ? secondaryContainerLight
          : const Color(0xFF334155),
      onSecondaryContainer: isLight
          ? onSecondaryContainerLight
          : const Color(0xFFE2E8F0),
      tertiary: isLight ? tertiaryLight : const Color(0xFFFBBF24),
      onTertiary: isLight ? onTertiaryLight : const Color(0xFF0F172A),
      tertiaryContainer: isLight
          ? tertiaryContainerLight
          : const Color(0xFF451A03),
      onTertiaryContainer: isLight
          ? onTertiaryContainerLight
          : const Color(0xFFFEF3C7),
      surface: isLight ? surfaceLight : surfaceDark,
      onSurface: isLight ? onBgLight : onBgDark,
      surfaceContainerHigh: isLight ? surfaceHighLight : surfaceHighDark,
      surfaceContainerLow: isLight ? bgLight : bgDark,
      outline: isLight ? const Color(0x14000000) : const Color(0x14FFFFFF),
      outlineVariant: isLight
          ? const Color(0x0A000000)
          : const Color(0x0AFFFFFF),
      error: isLight ? errorLight : errorDark,
      onError: isLight ? onErrorLight : onErrorDark,
    );
  }

  /// Light theme. Built once — never call this from a `build` method.
  static final ThemeData lightTheme = fromColorScheme(null, Brightness.light);

  /// Dark theme. Built once — never call this from a `build` method.
  static final ThemeData darkTheme = fromColorScheme(null, Brightness.dark);
}
