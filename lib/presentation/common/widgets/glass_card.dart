import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/liquid_glass.dart';

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
    this.elevation = CardElevation.none,
    this.hasBorder = false,
    this.margin,
    this.padding,
    this.onTap,
    this.blurSigma = 15,
    this.frosted = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color glassColor;
    if (backgroundColor != null) {
      glassColor = backgroundColor!;
    } else if (backgroundGradient != null) {
      glassColor = Colors.transparent;
    } else {
      glassColor = isDark
          ? (accentColor != null
              ? accentColor!.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.08))
          : (accentColor != null
              ? accentColor!.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.65));
    }

    Widget body = Container(
      decoration: BoxDecoration(
        color: glassColor,
        gradient: backgroundGradient,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      foregroundDecoration: accentColor != null
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: accentColor!.withValues(alpha: isDark ? 0.20 : 0.12),
                width: 0.5,
              ),
            )
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            if (frosted)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: Container(color: Colors.transparent),
                ),
              ),
            if (accentColor != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: accentColor!.withValues(alpha: isDark ? 0.5 : 0.4),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(borderRadius),
                      topRight: Radius.circular(borderRadius),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: (padding ?? EdgeInsets.zero).add(
                accentColor != null
                    ? const EdgeInsets.only(top: 3 + 2)
                    : EdgeInsets.zero,
              ),
              child: child,
            ),
          ],
        ),
      ),
    );

    body = LiquidGlassOverlay(child: body);

    if (margin != null) {
      body = Padding(padding: margin!, child: body);
    }

    if (onTap != null) {
      return TactileSpringContainer(onTap: onTap, child: body);
    }
    return body;
  }
}
