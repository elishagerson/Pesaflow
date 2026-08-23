import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// Subtle animated glass sheen layered beneath [child].
///
/// Instead of running a perpetual `AnimationController.repeat()` (which forces
/// a full repaint of the painter on every frame, 24/7), the overlay is driven
/// by a [Stopwatch] and only repaints when its [speedFactor] or color changes
/// (i.e. while the user is scrolling). A low-frequency ticker runs only while
/// [speedFactor] differs from `1.0`, so the layer is completely inert at rest.
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

class _LiquidGlassOverlayState extends State<LiquidGlassOverlay> {
  final Stopwatch _clock = Stopwatch();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _clock.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(LiquidGlassOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speedFactor == widget.speedFactor) return;
    _syncTicker();
  }

  /// Drift the glass only while the user is actively scrolling.
  void _syncTicker() {
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final shouldRun = !reducedMotion && widget.speedFactor != 1.0;
    if (shouldRun) {
      _ticker ??= Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (!mounted) return;
        setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = widget.accentColor ?? theme.colorScheme.onSurface;
    final primaryColor = theme.colorScheme.primary;
    final tertiaryColor = theme.colorScheme.tertiary;

    // Respect reduced motion: render children without the animated overlay
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return widget.child;
    }

    return RepaintBoundary(
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _LiquidGlassPainter(
                  elapsedMs: _clock.elapsedMilliseconds,
                  speedFactor: widget.speedFactor,
                  baseColor: baseColor,
                  primaryColor: primaryColor,
                  tertiaryColor: tertiaryColor,
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
  final int elapsedMs;
  final double speedFactor;
  final Color baseColor;
  final Color primaryColor;
  final Color tertiaryColor;

  _LiquidGlassPainter({
    required this.elapsedMs,
    required this.speedFactor,
    required this.baseColor,
    required this.primaryColor,
    required this.tertiaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0.0 || size.height <= 0.0) {
      return;
    }

    // Original rate of change: 0.1 per second (0.0001 per millisecond).
    // Scrolling scales the apparent drift via speedFactor.
    final time = elapsedMs * 0.00005 * speedFactor; // Slowed down slightly for aurora feel

    // Aurora blob 1 (Primary)
    final px1 = 0.5 + 0.5 * sin(time * 2 * pi * 0.15);
    final py1 = 0.5 + 0.5 * cos(time * 2 * pi * 0.11 + 1.0);

    final poolPaint1 = Paint()
      ..shader = RadialGradient(
        center: Alignment(px1 * 2 - 1, py1 * 2 - 1),
        radius: 1.2,
        colors: [
          primaryColor.withValues(alpha: 0.12),
          primaryColor.withValues(alpha: 0.04),
          primaryColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), poolPaint1);

    // Aurora blob 2 (Tertiary)
    final px2 = 0.5 + 0.6 * sin(time * 2 * pi * 0.09 + 2.0);
    final py2 = 0.5 + 0.4 * cos(time * 2 * pi * 0.13 + 3.0);

    final poolPaint2 = Paint()
      ..shader = RadialGradient(
        center: Alignment(px2 * 2 - 1, py2 * 2 - 1),
        radius: 1.0,
        colors: [
          tertiaryColor.withValues(alpha: 0.12),
          tertiaryColor.withValues(alpha: 0.04),
          tertiaryColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), poolPaint2);

    // Aurora blob 3 (Base/OnSurface)
    final px3 = 0.5 + 0.4 * cos(time * 2 * pi * 0.12 + 4.5);
    final py3 = 0.5 + 0.5 * sin(time * 2 * pi * 0.14 + 1.5);

    final poolPaint3 = Paint()
      ..shader = RadialGradient(
        center: Alignment(px3 * 2 - 1, py3 * 2 - 1),
        radius: 0.9,
        colors: [
          baseColor.withValues(alpha: 0.08),
          baseColor.withValues(alpha: 0.02),
          baseColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), poolPaint3);

    // Diagonal sheen (very faint moving reflection)
    final sheenT = (time * 2 * pi * 2) % (2 * pi); // Sheen moves slightly faster
    final dx = size.width * (0.5 + 0.6 * sin(sheenT - pi / 2));

    final sheenPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.white.withValues(alpha: 0.025),
              Colors.transparent,
              Colors.transparent,
            ],
            stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
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
      oldDelegate.elapsedMs != elapsedMs ||
      oldDelegate.baseColor != baseColor ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.tertiaryColor != tertiaryColor;
}
