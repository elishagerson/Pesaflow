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
  final Color warningColor;
  // Shadow tokens — dark-mode-aware
  final Color shadowSubtle;
  final Color shadowMedium;
  final Color shadowStrong;
  // Budget group semantic colors
  final Color needsColor;
  final Color wantsColor;
  final Color investColor;
  final Color dangerColor;
  final Color neutralColor;

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
    required this.warningColor,
    required this.shadowSubtle,
    required this.shadowMedium,
    required this.shadowStrong,
    required this.needsColor,
    required this.wantsColor,
    required this.investColor,
    required this.dangerColor,
    required this.neutralColor,
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
    warningColor: Color(0xFFF59E0B), // Amber-500
    shadowSubtle: Color(0x0A000000),
    shadowMedium: Color(0x14000000),
    shadowStrong: Color(0x24000000),
    needsColor: Color(0xFF2196F3), // Blue
    wantsColor: Color(0xFFFF9800), // Orange
    investColor: Color(0xFF4CAF50), // Green
    dangerColor: Color(0xFFE11D48), // Rose-600
    neutralColor: Color(0xFF6B7280), // Gray-500
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
    warningColor: Color(0xFFFBBF24), // Amber-400
    shadowSubtle: Color(0x0AFFFFFF),
    shadowMedium: Color(0x14FFFFFF),
    shadowStrong: Color(0x24FFFFFF),
    needsColor: Color(0xFF60A5FA), // Blue-400
    wantsColor: Color(0xFFFBBF24), // Amber-400
    investColor: Color(0xFF4ADE80), // Green-400
    dangerColor: Color(0xFFF87171), // Rose-400
    neutralColor: Color(0xFF9CA3AF), // Gray-400
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
    Color? warningColor,
    Color? shadowSubtle,
    Color? shadowMedium,
    Color? shadowStrong,
    Color? needsColor,
    Color? wantsColor,
    Color? investColor,
    Color? dangerColor,
    Color? neutralColor,
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
      warningColor: warningColor ?? this.warningColor,
      shadowSubtle: shadowSubtle ?? this.shadowSubtle,
      shadowMedium: shadowMedium ?? this.shadowMedium,
      shadowStrong: shadowStrong ?? this.shadowStrong,
      needsColor: needsColor ?? this.needsColor,
      wantsColor: wantsColor ?? this.wantsColor,
      investColor: investColor ?? this.investColor,
      dangerColor: dangerColor ?? this.dangerColor,
      neutralColor: neutralColor ?? this.neutralColor,
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
      warningColor: Color.lerp(warningColor, other.warningColor, t)!,
      shadowSubtle: Color.lerp(shadowSubtle, other.shadowSubtle, t)!,
      shadowMedium: Color.lerp(shadowMedium, other.shadowMedium, t)!,
      shadowStrong: Color.lerp(shadowStrong, other.shadowStrong, t)!,
      needsColor: Color.lerp(needsColor, other.needsColor, t)!,
      wantsColor: Color.lerp(wantsColor, other.wantsColor, t)!,
      investColor: Color.lerp(investColor, other.investColor, t)!,
      dangerColor: Color.lerp(dangerColor, other.dangerColor, t)!,
      neutralColor: Color.lerp(neutralColor, other.neutralColor, t)!,
    );
  }
}
