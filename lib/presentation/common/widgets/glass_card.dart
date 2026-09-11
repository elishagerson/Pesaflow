import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/haptics.dart';

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
  final bool frosted;

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
    this.frosted = false,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _hasShimmered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MotionTokens.durationFast,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Shadow parameters that respond to press state.
  /// When pressed, shadow offset decreases and blur shrinks
  /// → creates "card pushed into surface" illusion.
  _ShadowParams _resolveShadows(
    CardElevation elevation,
    bool isDark,
    double pressT,
  ) {
    final base = switch (elevation) {
      CardElevation.low => _ShadowParams(
        color: isDark
            ? Colors.black.withValues(alpha: 0.20)
            : Colors.black.withValues(alpha: 0.04),
        blur: 8.0,
        offsetY: 2.0,
      ),
      CardElevation.medium => _ShadowParams(
        color: isDark
            ? Colors.black.withValues(alpha: 0.28)
            : Colors.black.withValues(alpha: 0.06),
        blur: 16.0,
        offsetY: 4.0,
      ),
      CardElevation.high => _ShadowParams(
        color: isDark
            ? Colors.black.withValues(alpha: 0.35)
            : Colors.black.withValues(alpha: 0.08),
        blur: 24.0,
        offsetY: 8.0,
      ),
      CardElevation.none => null,
    };

    if (base == null) return _ShadowParams.none;

    // Lerp shadow down on press — card "sinks into" surface
    return _ShadowParams(
      color: base.color,
      blur: lerpDouble(base.blur, base.blur * 0.5, pressT)!,
      offsetY: lerpDouble(base.offsetY, base.offsetY * 0.25, pressT)!,
    );
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

    // Clean card — standard rounded rect
    Widget innerContent = Container(
      decoration: BoxDecoration(
        color: widget.backgroundGradient == null ? cardColor : null,
        gradient: widget.backgroundGradient,
        borderRadius: BorderRadius.circular(widget.borderRadius),
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
          // Shimmer — fires only once on first tap
          if (widget.onTap != null && !context.isReducedMotion)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    if (_controller.value == 0) return const SizedBox.shrink();
                    if (_hasShimmered) return const SizedBox.shrink();
                    return FractionalTranslation(
                      translation: Offset((_controller.value * 1.8) - 0.9, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(
                                alpha: isDark ? 0.1 : 0.3,
                              ),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                            stops: const [0.3, 0.5, 0.7],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );

    if (widget.frosted) {
      innerContent = ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: innerContent,
        ),
      );
    }

    if (widget.onTap != null) {
      final reducedMotion = context.isReducedMotion;
      return Semantics(
        container: true,
        label: 'Card',
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: reducedMotion
              ? null
              : (_) {
                  _controller.forward();
                  if (!_hasShimmered) {
                    _hasShimmered = true;
                  }
                },
          onTapUp: reducedMotion ? null : (_) => _controller.reverse(),
          onTapCancel: reducedMotion ? null : () => _controller.reverse(),
          onTap: () {
            PesaHaptics.selection();
            widget.onTap?.call();
          },
          child: reducedMotion
              ? _buildBody(isDark, 0.0)
              : AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return _buildBody(isDark, _controller.value, child: child);
                  },
                  child: innerContent,
                ),
        ),
      );
    }

    // Non-interactive card
    Widget body = RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: _resolveShadows(widget.elevation, isDark, 0.0).toList(),
        ),
        child: CustomPaint(
          foregroundPainter: widget.hasBorder
              ? _GradientBorderPainter(widget.borderRadius, isDark)
              : null,
          child: innerContent,
        ),
      ),
    );

    if (widget.margin != null) {
      body = Padding(padding: widget.margin!, child: body);
    }

    return Semantics(container: true, label: 'Card', child: body);
  }

  Widget _buildBody(bool isDark, double pressT, {Widget? child}) {
    final shadow = _resolveShadows(widget.elevation, isDark, pressT);
    final scale = 1.0 - (pressT * (1.0 - MotionTokens.scaleCardPress));
    final opacity = 1.0 - (pressT * (1.0 - MotionTokens.opacityPress));

    Widget body = RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: shadow.toList(),
        ),
        child: CustomPaint(
          foregroundPainter: widget.hasBorder
              ? _GradientBorderPainter(widget.borderRadius, isDark)
              : null,
          child: child,
        ),
      ),
    );

    if (widget.margin != null) {
      body = Padding(padding: widget.margin!, child: body);
    }

    return Opacity(
      opacity: opacity,
      child: Transform.scale(scale: scale, child: body),
    );
  }
}

/// Shadow parameters that animate with press state.
class _ShadowParams {
  final Color color;
  final double blur;
  final double offsetY;

  const _ShadowParams({
    required this.color,
    required this.blur,
    required this.offsetY,
  });

  static const none = _ShadowParams(
    color: Colors.transparent,
    blur: 0,
    offsetY: 0,
  );

  List<BoxShadow> toList() {
    if (blur == 0 && offsetY == 0) return [];
    return [
      BoxShadow(color: color, blurRadius: blur, offset: Offset(0, offsetY)),
    ];
  }
}

class _GradientBorderPainter extends CustomPainter {
  final double radius;
  final bool isDark;

  _GradientBorderPainter(this.radius, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.35 : 0.8),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
