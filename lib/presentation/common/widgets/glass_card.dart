import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/app_theme.dart';

/// A glassmorphic card with frosted glass effect, subtle border, and shadow.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color? backgroundColor;
  final double borderWidth;
  final Color? borderColor;
  final bool hasShadow;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const GlassCard({
    Key? key,
    required this.child,
    this.borderRadius = AppTheme.radiusCard,
    this.backgroundColor,
    this.borderWidth = 1.0,
    this.borderColor,
    this.hasShadow = true,
    this.margin,
    this.padding,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final bgColor = backgroundColor ?? 
        (isDark ? AppTheme.surfaceContainerDark : AppTheme.surfaceLight);
    final border = borderColor ?? 
        (isDark ? const Color(0x1FFFFFFF) : const Color(0x1F000000));

    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: border,
          width: borderWidth,
        ),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: theme.colorScheme.onSurface.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );

    if (margin != null || onTap != null) {
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: onTap != null
            ? GestureDetector(onTap: onTap, child: card)
            : card,
      );
    }
    return card;
  }
}