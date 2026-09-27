import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Type roles that sit *outside* the Material `TextTheme` scale.
///
/// The Material scale answers "how big". These answer "what job is this doing":
///
///  * [poster]   — the one enormous condensed all-caps moment per screen.
///  * [numeral]  — money and counts at display sizes, in Inter's optical cut.
///  * [eyebrow]  — the tiny tracked uppercase label that balances [poster],
///                 the way a caption balances a poster's headline.
///  * [monospace]— tabular figures for dense numeric grids.
@immutable
class AppTypographyTheme extends ThemeExtension<AppTypographyTheme> {
  final TextStyle monospace;
  final TextStyle labelMicro;

  /// Condensed all-caps poster face. The visual signature of the app.
  final TextStyle poster;

  /// Condensed poster face at headline size, for the biggest moment on screen.
  final TextStyle posterLarge;

  /// Optical display cut of Inter — money and counts at >= 24px.
  final TextStyle numeral;

  /// Tiny uppercase tracked label. Always paired with [poster] or [numeral],
  /// never used alone as a heading.
  final TextStyle eyebrow;

  const AppTypographyTheme({
    required this.monospace,
    required this.labelMicro,
    required this.poster,
    required this.posterLarge,
    required this.numeral,
    required this.eyebrow,
  });

  factory AppTypographyTheme.base(TextTheme textTheme) => AppTypographyTheme(
    monospace:
        textTheme.bodyMedium?.copyWith(
          fontFamilyFallback: const [
            'SF Mono',
            'JetBrains Mono',
            'Roboto Mono',
            'Courier New',
          ],
          fontWeight: FontWeight.w900,
        ) ??
        const TextStyle(),
    labelMicro:
        textTheme.labelSmall?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ) ??
        const TextStyle(),
    poster: const TextStyle(
      fontFamily: AppTheme.fontPoster,
      fontSize: 40,
      fontWeight: FontWeight.w400,
      height: 0.92,
    ),
    posterLarge: const TextStyle(
      fontFamily: AppTheme.fontPoster,
      fontSize: 64,
      fontWeight: FontWeight.w400,
      height: 0.9,
    ),
    numeral:
        textTheme.displaySmall ??
        const TextStyle(fontFamily: AppTheme.fontDisplay),
    // Flutter 3.44 removed `TextStyle.textTransform`, so the tracked uppercase
    // is applied at the call site (`'income'.toUpperCase()`). Keep the style
    // itself free of case logic.
    eyebrow: const TextStyle(
      fontFamily: AppTheme.fontText,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
      height: 1.2,
    ),
  );

  @override
  AppTypographyTheme copyWith({
    TextStyle? monospace,
    TextStyle? labelMicro,
    TextStyle? poster,
    TextStyle? posterLarge,
    TextStyle? numeral,
    TextStyle? eyebrow,
  }) {
    return AppTypographyTheme(
      monospace: monospace ?? this.monospace,
      labelMicro: labelMicro ?? this.labelMicro,
      poster: poster ?? this.poster,
      posterLarge: posterLarge ?? this.posterLarge,
      numeral: numeral ?? this.numeral,
      eyebrow: eyebrow ?? this.eyebrow,
    );
  }

  @override
  AppTypographyTheme lerp(ThemeExtension<AppTypographyTheme>? other, double t) {
    if (other is! AppTypographyTheme) return this;
    return AppTypographyTheme(
      monospace: TextStyle.lerp(monospace, other.monospace, t)!,
      labelMicro: TextStyle.lerp(labelMicro, other.labelMicro, t)!,
      poster: TextStyle.lerp(poster, other.poster, t)!,
      posterLarge: TextStyle.lerp(posterLarge, other.posterLarge, t)!,
      numeral: TextStyle.lerp(numeral, other.numeral, t)!,
      eyebrow: TextStyle.lerp(eyebrow, other.eyebrow, t)!,
    );
  }
}
