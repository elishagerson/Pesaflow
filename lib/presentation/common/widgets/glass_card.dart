import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color? backgroundColor;
  final double borderWidth;
  final Color? borderColor;
  final Gradient? borderGradient;
  final bool hasShadow;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double blurSigma;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = AppTheme.radiusCard,
    this.backgroundColor,
    this.borderWidth = 1.0,
    this.borderColor,
    this.borderGradient,
    this.hasShadow = true,
    this.margin,
    this.padding,
    this.onTap,
    this.blurSigma = 6,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = backgroundColor ??
        (isDark ? AppTheme.surfaceContainerDark : AppTheme.surfaceLight);
    final border = borderColor ??
        (isDark ? const Color(0x1FFFFFFF) : const Color(0x1A000000));
    final shadowColor = isDark
        ? AppTheme.primaryDark.withValues(alpha: 0.08)
        : AppTheme.primaryLight.withValues(alpha: 0.10);

    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border, width: borderWidth),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      foregroundDecoration: borderGradient != null
          ? ShapeDecoration(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              gradient: borderGradient!,
            )
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: child,
          ),
        ),
      ),
    );

    final padded = margin != null
        ? Padding(padding: margin!, child: card)
        : card;

    if (onTap != null) {
      return TactileSpringContainer(onTap: onTap, child: padded);
    }
    return padded;
  }
}
