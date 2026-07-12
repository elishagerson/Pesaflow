import 'package:flutter/material.dart';

class SuccessCheckmark extends StatefulWidget {
  final double size;
  final Color? color;
  final Duration duration;
  final VoidCallback? onComplete;

  const SuccessCheckmark({
    super.key,
    this.size = 40,
    this.color = Colors.white,
    this.duration = const Duration(milliseconds: 500),
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
      curve: Curves.easeInOutCubic,
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
    final color = widget.color ?? Colors.white;

    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _CheckmarkPainter(
            progress: _progress.value,
            color: color,
          ),
        );
      },
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CheckmarkPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final width = size.width;

    // Simple minimal checkmark stroke
    final checkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final start = Offset(center.dx - width * 0.22, center.dy + width * 0.02);
    final mid = Offset(center.dx - width * 0.02, center.dy + width * 0.22);
    final end = Offset(center.dx + width * 0.26, center.dy - width * 0.18);

    if (progress > 0) {
      if (progress < 0.4) {
        final segT = (progress / 0.4).clamp(0.0, 1.0);
        final point = Offset.lerp(start, mid, segT)!;
        canvas.drawLine(start, point, checkPaint);
      } else {
        final segT = ((progress - 0.4) / 0.6).clamp(0.0, 1.0);
        canvas.drawLine(start, mid, checkPaint);
        final point = Offset.lerp(mid, end, segT)!;
        canvas.drawLine(mid, point, checkPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter old) =>
      old.progress != progress || old.color != color;
}
