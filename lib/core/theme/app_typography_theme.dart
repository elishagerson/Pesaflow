import 'package:flutter/material.dart';

@immutable
class AppTypographyTheme extends ThemeExtension<AppTypographyTheme> {
  final TextStyle monospace;
  final TextStyle labelMicro;

  const AppTypographyTheme({
    required this.monospace,
    required this.labelMicro,
  });

  factory AppTypographyTheme.base(TextTheme textTheme) => AppTypographyTheme(
        monospace: textTheme.bodyMedium?.copyWith(
              fontFamilyFallback: const [
                'SF Mono',
                'JetBrains Mono',
                'Roboto Mono',
                'Courier New',
              ],
              fontWeight: FontWeight.w900,
            ) ??
            const TextStyle(),
        labelMicro: textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ) ??
            const TextStyle(),
      );

  @override
  AppTypographyTheme copyWith({
    TextStyle? monospace,
    TextStyle? labelMicro,
  }) {
    return AppTypographyTheme(
      monospace: monospace ?? this.monospace,
      labelMicro: labelMicro ?? this.labelMicro,
    );
  }

  @override
  AppTypographyTheme lerp(
    ThemeExtension<AppTypographyTheme>? other,
    double t,
  ) {
    if (other is! AppTypographyTheme) return this;
    return AppTypographyTheme(
      monospace: TextStyle.lerp(monospace, other.monospace, t)!,
      labelMicro: TextStyle.lerp(labelMicro, other.labelMicro, t)!,
    );
  }
}
