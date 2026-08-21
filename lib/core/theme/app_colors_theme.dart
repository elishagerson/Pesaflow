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
  // Budjetly-inspired tokens
  final Color cardBackground;
  final Color cardBorder;
  final Color sectionHeader;
  final Color accentSubtle;

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
    required this.cardBackground,
    required this.cardBorder,
    required this.sectionHeader,
    required this.accentSubtle,
  });

  factory AppColorsTheme.light() => const AppColorsTheme(
    incomeColor: AppTheme.incomeColor,
    expenseColor: AppTheme.expenseColor,
    transferColor: AppTheme.transferColor,
    surfaceLow: AppTheme.bgLight,
    surfaceHigh: AppTheme.surfaceHighLight,
    surfaceContainer: AppTheme.surfaceLight,
    surfaceContainerHighest: Color(0xFFE2E8F0), // Slate-200
    bgColor: AppTheme.bgLight,
    onBgColor: AppTheme.onBgLight,
    textMedium: Color(0xFF64748B), // Slate-500
    textLow: Color(0xFF94A3B8), // Slate-400
    scaffoldLine: Color(0x14000000),
    cardBackground: Color(0xFFFFFFFF), // Pure white
    cardBorder: Color(0xFFE2E8F0), // Slate-200
    sectionHeader: Color(0xFF475569), // Slate-600
    accentSubtle: Color(0xFFEFF6FF), // Blue-50
  );

  factory AppColorsTheme.dark() => const AppColorsTheme(
    incomeColor: AppTheme.incomeColorDark,
    expenseColor: AppTheme.expenseColorDark,
    transferColor: AppTheme.transferColorDark,
    surfaceLow: AppTheme.bgDark,
    surfaceHigh: AppTheme.surfaceHighDark,
    surfaceContainer: AppTheme.surfaceDark,
    surfaceContainerHighest: Color(0xFF2C2C2E), // Dark gray
    bgColor: AppTheme.bgDark,
    onBgColor: AppTheme.onBgDark,
    textMedium: Color(0xFF8E8E93), // System gray
    textLow: Color(0xFF636366), // System gray 2
    scaffoldLine: Color(0x14FFFFFF),
    cardBackground: Color(0xFF1C1C1E), // Apple secondary dark
    cardBorder: Color(0xFF2C2C2E), // Apple tertiary dark
    sectionHeader: Color(0xFF8E8E93), // System gray
    accentSubtle: Color(0xFF2C2C2E), // Subtle gray
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
    Color? cardBackground,
    Color? cardBorder,
    Color? sectionHeader,
    Color? accentSubtle,
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
      cardBackground: cardBackground ?? this.cardBackground,
      cardBorder: cardBorder ?? this.cardBorder,
      sectionHeader: sectionHeader ?? this.sectionHeader,
      accentSubtle: accentSubtle ?? this.accentSubtle,
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
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      sectionHeader: Color.lerp(sectionHeader, other.sectionHeader, t)!,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
    );
  }
}
