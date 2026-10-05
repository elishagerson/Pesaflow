import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/presentation/common/widgets/hairline_border.dart';

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

  /// When true, the card gets an ambient colour wash behind it — a radial
  /// glow of [accentColor] that makes the card read as a light source on a
  /// dark canvas. One per screen region; two glowing cards cancel out.
  final bool accentGlow;

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
    this.accentGlow = false,
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
      duration: MotionTokens.durationFast,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Shadow parameters that respond to press state.
  /// Box Box-inspired multi-layer system:
  ///  1. Diffuse base shadow (large blur, high offset) → floating depth
  ///  2. Crisp near shadow (small blur, tight offset)  → edge definition
  /// When pressed, both compress → "card pushed into surface" illusion.
  _ShadowParams _resolveShadows(
    CardElevation elevation,
    bool isDark,
    double pressT,
  ) {
    final base = switch (elevation) {
      CardElevation.low => (
        diffuse: _SingleShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.22)
              : Colors.black.withValues(alpha: 0.04),
          blur: 16.0,
          offsetY: 4.0,
        ),
        crisp: _SingleShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.02),
          blur: 3.0,
          offsetY: 1.0,
        ),
      ),
      CardElevation.medium => (
        diffuse: _SingleShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.30)
              : Colors.black.withValues(alpha: 0.06),
          blur: 28.0,
          offsetY: 8.0,
        ),
        crisp: _SingleShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.16)
              : Colors.black.withValues(alpha: 0.03),
          blur: 4.0,
          offsetY: 2.0,
        ),
      ),
      CardElevation.high => (
        diffuse: _SingleShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.38)
              : Colors.black.withValues(alpha: 0.08),
          blur: 40.0,
          offsetY: 12.0,
        ),
        crisp: _SingleShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.20)
              : Colors.black.withValues(alpha: 0.04),
          blur: 6.0,
          offsetY: 3.0,
        ),
      ),
      CardElevation.none => null,
    };

    if (base == null) return _ShadowParams.none;

    // Lerp both layers down on press — card "sinks into" surface
    return _ShadowParams(
      diffuse: _SingleShadow(
        color: base.diffuse.color,
        blur: lerpDouble(base.diffuse.blur, base.diffuse.blur * 0.4, pressT)!,
        offsetY: lerpDouble(
          base.diffuse.offsetY,
          base.diffuse.offsetY * 0.2,
          pressT,
        )!,
      ),
      crisp: _SingleShadow(
        color: base.crisp.color,
        blur: lerpDouble(base.crisp.blur, base.crisp.blur * 0.5, pressT)!,
        offsetY: lerpDouble(
          base.crisp.offsetY,
          base.crisp.offsetY * 0.3,
          pressT,
        )!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final theme = Theme.of(context);

    // Box Box-inspired: gradient fill instead of flat fill, unless the caller
    // overrode the background. The gradient is near-surface (depth, not colour)
    // and gives the card a physical top edge and a receding bottom edge.
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

    // Use gradient fill when no explicit background was given — the card gets
    // a physical top-to-bottom depth instead of a flat swatch.
    final Gradient? autoGradient;
    if (widget.backgroundColor == null &&
        widget.backgroundGradient == null &&
        widget.accentColor == null) {
      autoGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [appColors.cardGradientFrom, appColors.cardGradientTo],
      );
    } else {
      autoGradient = null;
    }

    final bool isDark = context.isDark;

    // Card — gradient-filled rounded rect with optional accent glow
    Widget innerContent = Container(
      decoration: BoxDecoration(
        color: (widget.backgroundGradient == null && autoGradient == null)
            ? cardColor
            : null,
        gradient: widget.backgroundGradient ?? autoGradient,
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
          // Press sheen — sweeps across the card with the press-down,
          // driven by the same press controller (zero extra frames).
          if (widget.onTap != null && !context.isReducedMotion)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    if (_controller.value == 0) return const SizedBox.shrink();
                    // A press sheen has to *change* the card to be felt.
                    // White-on-white was invisible in light mode, so the sheen
                    // is now ink on a light card and light on a dark one — a
                    // value shift either way, not a hue shift.
                    final sheen = isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.055);
                    return FractionalTranslation(
                      translation: Offset((_controller.value * 1.8) - 0.9, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.transparent,
                              sheen,
                              Colors.transparent,
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
          onTapDown: reducedMotion ? null : (_) => _controller.forward(),
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
              ? HairlineBorderPainter.of(context, widget.borderRadius)
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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ambient accent glow behind the card
          if (widget.accentGlow && widget.accentColor != null)
            Positioned(
              left: -20,
              right: -20,
              top: -10,
              bottom: -10,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      widget.borderRadius + 20,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accentColor!.withValues(
                          alpha: isDark ? 0.16 : 0.08,
                        ),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: shadow.toList(),
            ),
            child: CustomPaint(
              foregroundPainter: widget.hasBorder
                  ? HairlineBorderPainter.of(context, widget.borderRadius)
                  : null,
              child: child,
            ),
          ),
        ],
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

/// A single shadow layer.
class _SingleShadow {
  final Color color;
  final double blur;
  final double offsetY;

  const _SingleShadow({
    required this.color,
    required this.blur,
    required this.offsetY,
  });
}

/// Box Box-inspired dual-layer shadow: diffuse halo + crisp near edge.
class _ShadowParams {
  final _SingleShadow? diffuse;
  final _SingleShadow? crisp;

  const _ShadowParams({this.diffuse, this.crisp});

  static const none = _ShadowParams();

  List<BoxShadow> toList() {
    final out = <BoxShadow>[];
    if (diffuse != null && (diffuse!.blur > 0 || diffuse!.offsetY > 0)) {
      out.add(BoxShadow(
        color: diffuse!.color,
        blurRadius: diffuse!.blur,
        offset: Offset(0, diffuse!.offsetY),
      ));
    }
    if (crisp != null && (crisp!.blur > 0 || crisp!.offsetY > 0)) {
      out.add(BoxShadow(
        color: crisp!.color,
        blurRadius: crisp!.blur,
        offset: Offset(0, crisp!.offsetY),
      ));
    }
    return out;
  }
}
