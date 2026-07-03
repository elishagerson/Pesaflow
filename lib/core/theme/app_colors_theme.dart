import 'package:flutter/material.dart';
import 'app_theme.dart';

@immutable
class AppColorsTheme extends ThemeExtension<AppColorsTheme> {
  final Color incomeColor;
  final Color expenseColor;
  final Color transferColor;
  final Color surfaceLow;
  final Color surfaceHigh;
  final Color surfaceContainer;
  final Color surfaceContainerHighest;
  final Color bgColor;
  final Color onBgColor;
  final Color textMedium;
  final Color textLow;
  final Color scaffoldLine;

  const AppColorsTheme({
    required this.incomeColor,
    required this.expenseColor,
    required this.transferColor,
    required this.surfaceLow,
    required this.surfaceHigh,
    required this.surfaceContainer,
    required this.surfaceContainerHighest,
    required this.bgColor,
    required this.onBgColor,
    required this.textMedium,
    required this.textLow,
    required this.scaffoldLine,
  });

  factory AppColorsTheme.light() => const AppColorsTheme(
    incomeColor: AppTheme.incomeColor,
    expenseColor: AppTheme.expenseColor,
    transferColor: AppTheme.transferColor,
    surfaceLow: AppTheme.bgLight,
    surfaceHigh: AppTheme.surfaceHighLight,
    surfaceContainer: AppTheme.surfaceLight,
    surfaceContainerHighest: Color(0xFFF0F1F4),
    bgColor: AppTheme.bgLight,
    onBgColor: AppTheme.onBgLight,
    textMedium: Color(0xFF9E9E9E),
    textLow: Color(0xFFBDBDBD),
    scaffoldLine: Color(0x1A000000),
  );

  factory AppColorsTheme.dark() => const AppColorsTheme(
    incomeColor: AppTheme.incomeColorDark,
    expenseColor: AppTheme.expenseColorDark,
    transferColor: AppTheme.transferColorDark,
    surfaceLow: AppTheme.bgDark,
    surfaceHigh: AppTheme.surfaceHighDark,
    surfaceContainer: AppTheme.surfaceDark,
    surfaceContainerHighest: Color(0xFF21262D),
    bgColor: AppTheme.bgDark,
    onBgColor: AppTheme.onBgDark,
    textMedium: Color(0xFF9E9E9E),
    textLow: Color(0xFF757575),
    scaffoldLine: Color(0x1AFFFFFF),
  );

  @override
  AppColorsTheme copyWith({
    Color? incomeColor,
    Color? expenseColor,
    Color? transferColor,
    Color? surfaceLow,
    Color? surfaceHigh,
    Color? surfaceContainer,
    Color? surfaceContainerHighest,
    Color? bgColor,
    Color? onBgColor,
    Color? textMedium,
    Color? textLow,
    Color? scaffoldLine,
  }) {
    return AppColorsTheme(
      incomeColor: incomeColor ?? this.incomeColor,
      expenseColor: expenseColor ?? this.expenseColor,
      transferColor: transferColor ?? this.transferColor,
      surfaceLow: surfaceLow ?? this.surfaceLow,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHighest:
          surfaceContainerHighest ?? this.surfaceContainerHighest,
      bgColor: bgColor ?? this.bgColor,
      onBgColor: onBgColor ?? this.onBgColor,
      textMedium: textMedium ?? this.textMedium,
      textLow: textLow ?? this.textLow,
      scaffoldLine: scaffoldLine ?? this.scaffoldLine,
    );
  }

  @override
  AppColorsTheme lerp(ThemeExtension<AppColorsTheme>? other, double t) {
    if (other is! AppColorsTheme) return this;
    return AppColorsTheme(
      incomeColor: Color.lerp(incomeColor, other.incomeColor, t)!,
      expenseColor: Color.lerp(expenseColor, other.expenseColor, t)!,
      transferColor: Color.lerp(transferColor, other.transferColor, t)!,
      surfaceLow: Color.lerp(surfaceLow, other.surfaceLow, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      surfaceContainer: Color.lerp(
        surfaceContainer,
        other.surfaceContainer,
        t,
      )!,
      surfaceContainerHighest: Color.lerp(
        surfaceContainerHighest,
        other.surfaceContainerHighest,
        t,
      )!,
      bgColor: Color.lerp(bgColor, other.bgColor, t)!,
      onBgColor: Color.lerp(onBgColor, other.onBgColor, t)!,
      textMedium: Color.lerp(textMedium, other.textMedium, t)!,
      textLow: Color.lerp(textLow, other.textLow, t)!,
      scaffoldLine: Color.lerp(scaffoldLine, other.scaffoldLine, t)!,
    );
  }
}
