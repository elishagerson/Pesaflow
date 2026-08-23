import 'dart:ui';
import 'package:flutter/material.dart';

/// visionOS / iOS 17-style frosted glass overlay.
///
/// Composition (top to bottom):
/// 1. `BackdropFilter` blur + saturation boost — the core "material" look
/// 2. Translucent tint wash (white in dark mode, ink in light mode)
/// 3. Top-edge specular highlight — simulates light catching the glass rim
/// 4. Hairline inner border — defines the sheet/card silhouette
/// 5. [child] content
///
/// Performance contract (per AGENTS.md): reserved for overlays/sheets only —
/// never wrap scrollable card lists. The entrance fade runs once (~350ms);
/// afterwards the widget is fully inert. Reduced-motion users skip the fade.
class LiquidGlassOverlay extends StatefulWidget {
  final Widget child;
  final Color? tintColor;
  final double intensity;
  final double blurSigma;
  final bool showTopHighlight;
  final bool showInnerBorder;

  const LiquidGlassOverlay({
    super.key,
    required this.child,
    this.tintColor,
    this.intensity = 1.0,
    this.blurSigma = 24,
    this.showTopHighlight = true,
    this.showInnerBorder = true,
  });

  @override
  State<LiquidGlassOverlay> createState() => _LiquidGlassOverlayState();
}

class _LiquidGlassOverlayState extends State<LiquidGlassOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  bool _entranceStarted = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceStarted) return;
    _entranceStarted = true;

    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reducedMotion) {
      _entrance.value = 1.0;
    } else {
      // Post-frame so the first frame paints content-only (no flash).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _entrance.forward();
      });
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // visionOS "regular" material: lighten on dark surfaces, darken on light.
    final baseTint = widget.tintColor ??
        (isDark
            ? const Color(0xFFFFFFFF).withValues(alpha: 0.10)
            : const Color(0xFFFBFBFD).withValues(alpha: 0.72));

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _entrance,
        builder: (context, child) {
          final e = Curves.easeOutCubic.transform(_entrance.value);
          final k = e * widget.intensity;
          if (k <= 0.01) return child!;

          return Stack(
            children: [
              // ── 1+2. Frosted blur + saturation + tint wash ──
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: widget.blurSigma * k,
                        sigmaY: widget.blurSigma * k,
                        tileMode: TileMode.mirror,
                      ),
                      child: Container(
                        color: baseTint.withValues(
                          alpha: baseTint.a * k,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── 3. Specular top highlight ──
              if (widget.showTopHighlight && k > 0.25)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 1.5,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.35 * k),
                            Colors.white.withValues(alpha: 0),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

              // ── 4. Hairline inner border ──
              if (widget.showInnerBorder && k > 0.25)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _HairlineBorderPainter(k: k, isDark: isDark),
                    ),
                  ),
                ),

              // ── 5. Content ──
              Opacity(opacity: e.clamp(0.0, 1.0), child: child!),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Hairline stroke that reads as the physical edge of a glass pane.
class _HairlineBorderPainter extends CustomPainter {
  final double k;
  final bool isDark;

  _HairlineBorderPainter({required this.k, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      const Radius.circular(27),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: (isDark ? 0.22 : 0.55) * k),
            Colors.white.withValues(alpha: 0.04 * k),
            Colors.white.withValues(alpha: (isDark ? 0.10 : 0.28) * k),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_HairlineBorderPainter oldDelegate) =>
      oldDelegate.k != k || oldDelegate.isDark != isDark;
}

/// Ready-made visionOS sheet container: clip radius + glass + padding.
class VisionOSSheet extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const VisionOSSheet({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: LiquidGlassOverlay(
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}
