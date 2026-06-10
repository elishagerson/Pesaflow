import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';

enum CardElevation { none, low, medium, high }

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color? backgroundColor;
  final Gradient? backgroundGradient;
  final Color? accentColor;
  final double accentWidth;
  final CardElevation elevation;
  final bool hasBorder;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double blurSigma;
  final bool frosted;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = AppTheme.radiusCard,
    this.backgroundColor,
    this.backgroundGradient,
    this.accentColor,
    this.accentWidth = 4,
    this.elevation = CardElevation.low,
    this.hasBorder = true,
    this.margin,
    this.padding,
    this.onTap,
    this.blurSigma = 6,
    this.frosted = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final bgColor = backgroundColor ??
        (isDark
            ? AppTheme.surfaceContainerDark.withValues(alpha: 0.85)
            : AppTheme.surfaceLight);
    final borderColor = hasBorder
        ? (isDark
            ? (colorScheme.outline ?? Colors.grey).withValues(alpha: 0.15)
            : (colorScheme.outline ?? Colors.grey).withValues(alpha: 0.12))
        : Colors.transparent;
    final shadowList = _buildShadow(isDark, colorScheme);

    Widget body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundGradient != null ? null : bgColor,
        gradient: backgroundGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 0.5),
        boxShadow: shadowList,
      ),
      foregroundDecoration: accentColor != null
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: accentColor!.withValues(alpha: 0.3),
                width: 0,
              ),
            )
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            if (frosted)
              BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: blurSigma,
                  sigmaY: blurSigma,
                ),
                child: Container(color: Colors.transparent),
              ),
            if (accentColor != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: accentWidth,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(borderRadius),
                      topRight: Radius.circular(borderRadius),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: accentColor != null
                  ? EdgeInsets.only(top: accentWidth + 4)
                  : EdgeInsets.zero,
              child: child,
            ),
          ],
        ),
      ),
    );

    if (margin != null) {
      body = Padding(padding: margin!, child: body);
    }

    if (onTap != null) {
      return TactileSpringContainer(onTap: onTap, child: body);
    }
    return body;
  }

  List<BoxShadow> _buildShadow(bool isDark, ColorScheme colorScheme) {
    switch (elevation) {
      case CardElevation.none:
        return [];
      case CardElevation.low:
        return [
          BoxShadow(
            color: isDark
                ? AppTheme.primaryDark.withValues(alpha: 0.10)
                : AppTheme.primaryLight.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ];
      case CardElevation.medium:
        return [
          BoxShadow(
            color: isDark
                ? AppTheme.primaryDark.withValues(alpha: 0.12)
                : AppTheme.primaryLight.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.20)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ];
      case CardElevation.high:
        return [
          BoxShadow(
            color: isDark
                ? AppTheme.primaryDark.withValues(alpha: 0.15)
                : AppTheme.primaryLight.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.30)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ];
    }
  }
}
