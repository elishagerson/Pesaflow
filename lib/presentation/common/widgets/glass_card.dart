import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/presentation/common/widgets/liquid_glass.dart';

enum CardElevation { none, low, medium, high }

class GlassCard extends StatefulWidget {
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
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color glassColor;
    if (widget.backgroundColor != null) {
      glassColor = widget.backgroundColor!;
    } else if (widget.backgroundGradient != null) {
      glassColor = Colors.transparent;
    } else {
      glassColor = isDark
          ? (widget.accentColor != null
                ? widget.accentColor!.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.08))
          : (widget.accentColor != null
                ? widget.accentColor!.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.65));
    }

    final List<BoxShadow> shadows = switch (widget.elevation) {
      CardElevation.low => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
      CardElevation.medium => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
      CardElevation.high => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.10 : 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
      CardElevation.none => [],
    };

    Widget body = Container(
      decoration: BoxDecoration(
        color: glassColor,
        gradient: widget.backgroundGradient,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: shadows.isEmpty ? null : shadows,
      ),
      foregroundDecoration: widget.accentColor != null
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: widget.accentColor!.withValues(
                  alpha: isDark ? 0.20 : 0.12,
                ),
                width: 0.5,
              ),
            )
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Stack(
          children: [
            if (widget.frosted)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: widget.blurSigma,
                    sigmaY: widget.blurSigma,
                  ),
                  child: Container(color: Colors.transparent),
                ),
              ),
            if (widget.accentColor != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: widget.accentColor!.withValues(
                      alpha: isDark ? 0.5 : 0.4,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(widget.borderRadius),
                      topRight: Radius.circular(widget.borderRadius),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: (widget.padding ?? EdgeInsets.zero).add(
                widget.accentColor != null
                    ? const EdgeInsets.only(top: 3 + 2)
                    : EdgeInsets.zero,
              ),
              child: widget.child,
            ),
          ],
        ),
      ),
    );

    body = LiquidGlassOverlay(child: body);

    if (widget.margin != null) {
      body = Padding(padding: widget.margin!, child: body);
    }

    if (widget.onTap != null) {
      return Semantics(
        container: true,
        label: 'Card',
        button: true,
        child: GestureDetector(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) => _controller.reverse(),
          onTapCancel: () => _controller.reverse(),
          onTap: widget.onTap,
          child: ScaleTransition(scale: _scaleAnimation, child: body),
        ),
      );
    }
    return Semantics(container: true, label: 'Card', child: body);
  }
}
