import 'dart:math';
import 'package:flutter/material.dart';

class LiquidGlassOverlay extends StatefulWidget {
  final Widget child;
  final Color? accentColor;
  final double speedFactor;

  const LiquidGlassOverlay({
    super.key,
    required this.child,
    this.accentColor,
    this.speedFactor = 1.0,
  });

  @override
  State<LiquidGlassOverlay> createState() => _LiquidGlassOverlayState();
}

class _LiquidGlassOverlayState extends State<LiquidGlassOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3600),
    )..repeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause the continuous repaint loop when the app is backgrounded
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      if (!_controller.isAnimating) _controller.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = widget.accentColor ?? theme.colorScheme.onSurface;

    // Respect reduced motion: render children without the animated overlay
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reducedMotion) return widget.child;

    return RepaintBoundary(
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _LiquidGlassPainter(
                  animation: _controller,
                  speedFactor: widget.speedFactor,
                  baseColor: baseColor,
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _LiquidGlassPainter extends CustomPainter {
  final Animation<double> animation;
  final double speedFactor;
  final Color baseColor;

  _LiquidGlassPainter({
    required this.animation,
    required this.speedFactor,
    required this.baseColor,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0.0 || size.height <= 0.0) {
      return;
    }

    // Original rate of change: 0.1 per second.
    // Animation value goes 0.0 -> 1.0 over 3600 seconds.
    // So time = value * 3600 * 0.1 = value * 360.
    final time = animation.value * 360.0 * speedFactor;

    // -- Highlight 1: drifting radial pool --
    final px1 = 0.2 + 0.6 * (0.5 + 0.5 * sin(time * 2 * pi * 0.15));
    final py1 = 0.1 + 0.8 * (0.5 + 0.5 * sin(time * 2 * pi * 0.11 + 1.8));

    final poolPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(px1 * 2 - 1, py1 * 2 - 1),
        radius: 0.7,
        colors: [
          baseColor.withValues(alpha: 0.035),
          baseColor.withValues(alpha: 0.015),
          baseColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), poolPaint);

    // -- Highlight 2: smaller secondary drift (opposite phase) --
    final px2 = 0.1 + 0.8 * (0.5 + 0.5 * sin(time * 2 * pi * 0.09 + 3.2));
    final py2 = 0.3 + 0.6 * (0.5 + 0.5 * cos(time * 2 * pi * 0.13 + 0.7));

    final poolPaint2 = Paint()
      ..shader = RadialGradient(
        center: Alignment(px2 * 2 - 1, py2 * 2 - 1),
        radius: 0.5,
        colors: [
          baseColor.withValues(alpha: 0.025),
          baseColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), poolPaint2);

    // -- Diagonal sheen (very faint moving reflection) --
    final sheenT = (time * 2 * pi) % (2 * pi);
    final dx = size.width * (0.5 + 0.6 * sin(sheenT - pi / 2));

    final sheenPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.transparent,
              Colors.transparent,
              baseColor.withValues(alpha: 0.015),
              Colors.transparent,
              Colors.transparent,
            ],
            stops: [0.0, 0.35, 0.5, 0.65, 1.0],
            transform: GradientRotation(0.3),
          ).createShader(
            Rect.fromLTWH(
              dx - size.width * 0.4,
              0,
              size.width * 0.8,
              size.height,
            ),
          );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), sheenPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassPainter oldDelegate) =>
      oldDelegate.animation.value != animation.value ||
      oldDelegate.speedFactor != speedFactor ||
      oldDelegate.baseColor != baseColor;
}
