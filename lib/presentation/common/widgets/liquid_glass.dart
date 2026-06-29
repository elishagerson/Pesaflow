import 'dart:math';
import 'package:flutter/material.dart';

class LiquidGlassOverlay extends StatefulWidget {
  final Widget child;
  final Color? accentColor;

  const LiquidGlassOverlay({super.key, required this.child, this.accentColor});

  @override
  State<LiquidGlassOverlay> createState() => _LiquidGlassOverlayState();
}

class _LiquidGlassOverlayState extends State<LiquidGlassOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) => Stack(
          children: [
            child!,
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _LiquidGlassPainter(
                    time: _controller.value,
                    isDark: isDark,
                    accentColor: widget.accentColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiquidGlassPainter extends CustomPainter {
  final double time;
  final bool isDark;
  final Color? accentColor;

  _LiquidGlassPainter({
    required this.time,
    required this.isDark,
    this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final baseColor = accentColor ?? (isDark ? Colors.white : Colors.black);

    // -- Highlight 1: drifting radial pool --
    final hx =
        size.width * (0.2 + 0.6 * (0.5 + 0.5 * sin(time * 2 * pi * 0.15)));
    final hy =
        size.height *
        (0.1 + 0.8 * (0.5 + 0.5 * sin(time * 2 * pi * 0.11 + 1.8)));

    final poolPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (hx / size.width) * 2 - 1,
          (hy / size.height) * 2 - 1,
        ),
        radius: 0.7,
        colors: [
          baseColor.withValues(alpha: 0.035),
          baseColor.withValues(alpha: 0.015),
          baseColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), poolPaint);

    // -- Highlight 2: smaller secondary drift (opposite phase) --
    final hx2 =
        size.width *
        (0.1 + 0.8 * (0.5 + 0.5 * sin(time * 2 * pi * 0.09 + 3.2)));
    final hy2 =
        size.height *
        (0.3 + 0.6 * (0.5 + 0.5 * cos(time * 2 * pi * 0.13 + 0.7)));

    final poolPaint2 = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (hx2 / size.width) * 2 - 1,
          (hy2 / size.height) * 2 - 1,
        ),
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
      oldDelegate.time != time;
}
