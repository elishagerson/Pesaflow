import 'dart:math';
import 'package:flutter/material.dart';

class SuccessCheckmark extends StatefulWidget {
  final double size;
  final Color? color;
  final Duration duration;
  final VoidCallback? onComplete;

  const SuccessCheckmark({
    super.key,
    this.size = 80,
    this.color,
    this.duration = const Duration(milliseconds: 800),
    this.onComplete,
  });

  @override
  State<SuccessCheckmark> createState() => _SuccessCheckmarkState();
}

class _SuccessCheckmarkState extends State<SuccessCheckmark>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void play() => _controller.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.color ?? theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final t = _progress.value;
        final springScale = _springBounce(t);
        final checkT = ((t - 0.25) / 0.6).clamp(0.0, 1.0);
        final glowAlpha = (t * 0.3).clamp(0.0, 0.3);
        final ringT = ((t - 0.75) / 0.25).clamp(0.0, 1.0);

        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _CheckmarkPainter(
            scale: springScale,
            checkT: checkT,
            glowAlpha: glowAlpha,
            ringT: ringT,
            color: color,
          ),
        );
      },
    );
  }

  double _springBounce(double t) {
    if (t < 0.5) {
      return 1.0 + (0.25 * sin(t / 0.5 * pi * 0.5));
    }
    final decay = (t - 0.5) * 2;
    return 1.25 - (0.3 * decay * decay) + (0.05 * decay);
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double scale;
  final double checkT;
  final double glowAlpha;
  final double ringT;
  final Color color;

  _CheckmarkPainter({
    required this.scale,
    required this.checkT,
    required this.glowAlpha,
    required this.ringT,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 0.4 * scale;

    // Glow
    if (glowAlpha > 0) {
      final glowPaint = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16)
        ..color = color.withValues(alpha: glowAlpha);
      canvas.drawCircle(center, radius + 4, glowPaint);
    }

    // Filled circle
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.drawCircle(center, radius, fillPaint);

    // White checkmark
    if (checkT > 0) {
      final checkPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.07
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white;

      final start = Offset(center.dx - radius * 0.35, center.dy);
      final mid = Offset(center.dx - radius * 0.05, center.dy + radius * 0.35);
      final end = Offset(center.dx + radius * 0.45, center.dy - radius * 0.3);

      if (checkT < 0.5) {
        final segT = (checkT / 0.5).clamp(0.0, 1.0);
        final point = Offset.lerp(start, mid, segT)!;
        canvas.drawLine(start, point, checkPaint);
      } else {
        final segT = ((checkT - 0.5) / 0.5).clamp(0.0, 1.0);
        canvas.drawLine(start, mid, checkPaint);
        final point = Offset.lerp(mid, end, segT)!;
        canvas.drawLine(mid, point, checkPaint);
      }
    }

    // Ring reveal arc
    if (ringT > 0) {
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = Colors.white.withValues(alpha: ringT * 0.5);
      canvas.drawCircle(center, radius + 3, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter old) =>
      old.scale != scale ||
      old.checkT != checkT ||
      old.glowAlpha != glowAlpha ||
      old.ringT != ringT ||
      old.color != color;
}
