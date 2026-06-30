import 'package:flutter/material.dart';

class SuccessCheckmark extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;
  final VoidCallback? onComplete;

  const SuccessCheckmark({
    super.key,
    this.size = 80,
    this.color = const Color(0xFF10B981),
    this.duration = const Duration(milliseconds: 800),
    this.onComplete,
  });

  @override
  State<SuccessCheckmark> createState() => _SuccessCheckmarkState();
}

class _SuccessCheckmarkState extends State<SuccessCheckmark>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _drawProgress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _drawProgress = CurvedAnimation(
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _drawProgress,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _CheckmarkPainter(
            progress: _drawProgress.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CheckmarkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.1
      ..strokeCap = StrokeCap.round;

    final center = size.center(Offset.zero);
    final radius = size.width * 0.4;
    final startAngle = -1.5 * 3.14159;

    // Draw circle arc
    if (progress > 0) {
      final circleProgress = (progress * 1.2).clamp(0.0, 1.0);
      final sweepAngle = circleProgress * 2 * 3.14159;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }

    // Draw checkmark
    if (progress > 0.6) {
      final checkProgress = ((progress - 0.6) / 0.4).clamp(0.0, 1.0);
      paint.strokeWidth = size.width * 0.08;

      final checkStart = Offset(
        center.dx - radius * 0.35,
        center.dy,
      );
      final checkMid = Offset(
        center.dx - radius * 0.08,
        center.dy + radius * 0.4,
      );
      final checkEnd = Offset(
        center.dx + radius * 0.5,
        center.dy - radius * 0.3,
      );

      final path = Path();
      if (checkProgress < 0.5) {
        final t = (checkProgress / 0.5).clamp(0.0, 1.0);
        path.moveTo(checkStart.dx, checkStart.dy);
        path.lineTo(
          checkStart.dx + (checkMid.dx - checkStart.dx) * t,
          checkStart.dy + (checkMid.dy - checkStart.dy) * t,
        );
      } else {
        final t = ((checkProgress - 0.5) / 0.5).clamp(0.0, 1.0);
        path.moveTo(checkStart.dx, checkStart.dy);
        path.lineTo(checkMid.dx, checkMid.dy);
        path.lineTo(
          checkMid.dx + (checkEnd.dx - checkMid.dx) * t,
          checkMid.dy + (checkEnd.dy - checkMid.dy) * t,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
