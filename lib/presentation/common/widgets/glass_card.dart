import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

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
    this.hasBorder = true,
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
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    // Clean solid background — Budjetly style
    final Color cardColor;
    if (widget.backgroundColor != null) {
      cardColor = widget.backgroundColor!;
    } else if (widget.backgroundGradient != null) {
      cardColor = Colors.transparent;
    } else if (widget.accentColor != null) {
      cardColor = widget.accentColor!.withValues(alpha: 0.07);
    } else {
      cardColor = appColors.cardBackground;
    }

    final bool isDark = context.isDark;

    // Single clean shadow — no ornate multi-layer
    final List<BoxShadow> shadows = switch (widget.elevation) {
      CardElevation.low => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.20)
              : Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
      CardElevation.medium => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.28)
              : Colors.black.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
      CardElevation.high => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.35)
              : Colors.black.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
      CardElevation.none => [],
    };

    // Clean card — standard rounded rect, optional thin border
    Widget body = RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: widget.backgroundGradient == null ? cardColor : null,
          gradient: widget.backgroundGradient,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: widget.hasBorder
              ? Border.all(
                  color: widget.accentColor?.withValues(alpha: 0.20) ??
                      appColors.cardBorder,
                  width: 1.0,
                )
              : null,
          boxShadow: shadows,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
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
                    color: widget.accentColor!.withValues(alpha: 0.30),
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
                    return Transform.scale(
                      scale: 1.0 - (_controller.value * 0.02),
                      child: child,
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

