import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/squircle_border.dart';

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
  final bool showAccentStrip;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = AppTheme.radiusCard,
    this.backgroundColor,
    this.backgroundGradient,
    this.accentColor,
    this.accentWidth = 2,
    this.elevation = CardElevation.none,
    this.hasBorder = false,
    this.margin,
    this.padding,
    this.onTap,
    this.showAccentStrip = false,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color glassColor;
    if (widget.backgroundColor != null) {
      glassColor = widget.backgroundColor!;
    } else if (widget.backgroundGradient != null) {
      glassColor = Colors.transparent;
    } else {
      if (widget.accentColor != null) {
        glassColor = widget.accentColor!.withValues(alpha: 0.09);
      } else {
        glassColor = theme.colorScheme.surfaceContainerHigh;
      }
    }

    final bool isDark = context.isDark;

    // Premium multi-layered 3D shadows (ambient + sharp occlusion shadows)
    final List<BoxShadow> shadows = switch (widget.elevation) {
      CardElevation.low => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.03),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.35)
              : Colors.black.withValues(alpha: 0.02),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
        if (isDark)
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
      ],
      CardElevation.medium => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.35)
              : Colors.black.withValues(alpha: 0.05),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.20)
              : Colors.black.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
        if (isDark)
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, -1),
          ),
      ],
      CardElevation.high => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.45)
              : Colors.black.withValues(alpha: 0.08),
          blurRadius: 48,
          offset: const Offset(0, 20),
        ),
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
        if (isDark)
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
      ],
      CardElevation.none => [],
    };

    // Premium 3D Bevel border gradient (light source coming from top-left)
    final double borderWidth = widget.hasBorder ? 1.0 : 0.8;
    Widget body = RepaintBoundary(
      child: Container(
        decoration: ShapeDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: isDark ? 0.15 : 0.4),
              Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            ],
          ),
          shape: SquircleBorder(
            borderRadius: widget.borderRadius,
          ),
          shadows: shadows,
        ),
        child: Padding(
          padding: EdgeInsets.all(borderWidth),
          child: Container(
            decoration: ShapeDecoration(
              color: glassColor,
              gradient: widget.backgroundGradient,
              shape: SquircleBorder(
                borderRadius: widget.borderRadius - borderWidth,
              ),
            ),
            foregroundDecoration: widget.accentColor != null
                ? ShapeDecoration(
                    shape: SquircleBorder(
                      side: BorderSide(
                        color: widget.accentColor!.withValues(alpha: 0.25),
                        width: 1.0,
                      ),
                      borderRadius: widget.borderRadius - borderWidth,
                    ),
                  )
                : null,
            child: ClipPath(
              clipper: ShapeBorderClipper(
                shape: SquircleBorder(borderRadius: widget.borderRadius - borderWidth),
              ),
              child: Stack(
                children: [
                  if (widget.accentColor != null &&
                      widget.onTap != null &&
                      widget.showAccentStrip)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: widget.accentWidth,
                        decoration: BoxDecoration(
                          color: widget.accentColor!.withValues(alpha: 0.30),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(widget.borderRadius - borderWidth),
                            topRight: Radius.circular(widget.borderRadius - borderWidth),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: (widget.padding ?? EdgeInsets.zero).add(
                      widget.accentColor != null &&
                              widget.onTap != null &&
                              widget.showAccentStrip
                          ? EdgeInsets.only(top: widget.accentWidth + 2)
                          : EdgeInsets.zero,
                    ),
                    child: widget.child,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.margin != null) {
      body = Padding(padding: widget.margin!, child: body);
    }

    if (widget.onTap != null) {
      final reducedMotion = context.isReducedMotion;
      return Semantics(
        container: true,
        label: 'Card',
        button: true,
        child: GestureDetector(
          onTapDown: reducedMotion ? null : (_) => _controller.forward(),
          onTapUp: reducedMotion ? null : (_) => _controller.reverse(),
          onTapCancel: reducedMotion ? null : () => _controller.reverse(),
          onTap: widget.onTap,
          child: reducedMotion
              ? body
              : AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _controller.value * 2.5),
                      child: Transform.scale(
                        scale: 1.0 - (_controller.value * 0.03),
                        child: child,
                      ),
                    );
                  },
                  child: body,
                ),
        ),
      );
    }
    return Semantics(container: true, label: 'Card', child: body);
  }
}
