import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SuccessCheckmark extends StatefulWidget {
  final double size;
  final Color? color;
  final Duration duration;
  final VoidCallback? onComplete;

  const SuccessCheckmark({
    super.key,
    this.size = 40,
    this.color,
    this.duration = const Duration(milliseconds: 500),
    this.onComplete,
  });

  static Future<void> show(
    BuildContext context, {
    String? message,
    Color? color,
    Duration displayDuration = const Duration(milliseconds: 1500),
    bool hapticFeedback = true,
  }) async {
    if (hapticFeedback) HapticFeedback.mediumImpact();
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) => _SuccessOverlay(
        message: message,
        color: color,
        displayDuration: displayDuration,
      ),
    );
  }

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

class _SuccessOverlay extends StatefulWidget {
  final String? message;
  final Color? color;
  final Duration displayDuration;

  const _SuccessOverlay({
    this.message,
    this.color,
    required this.displayDuration,
  });

  @override
  State<_SuccessOverlay> createState() => _SuccessOverlayState();
}

class _SuccessOverlayState extends State<_SuccessOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _overlayController;

  @override
  void initState() {
    super.initState();

    _overlayController = AnimationController(
      vsync: this,
      duration: widget.displayDuration + const Duration(milliseconds: 300),
    );

    _overlayController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) Navigator.of(context).pop();
      }
    });

    _overlayController.forward();
  }

  @override
  void dispose() {
    _overlayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.color ?? theme.colorScheme.primary;
    final checkColor =
        color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    final totalSec = _overlayController.duration!.inMilliseconds / 1000.0;

    return AnimatedBuilder(
      animation: _overlayController,
      builder: (context, child) {
        final t = _overlayController.value * totalSec / totalSec;

        final bgFade = (t / 0.2).clamp(0.0, 1.0);

        final circleRaw = ((t - 0.15) / 0.35).clamp(0.0, 1.0);
        final circleScale = _springBounce(circleRaw);

        final checkT = ((t - 0.3) / 0.3).clamp(0.0, 1.0);

        final textFade = ((t - 0.5) / 0.15).clamp(0.0, 1.0);

        final endFade =
            t > 0.85 ? (1.0 - (t - 0.85) / 0.15).clamp(0.0, 1.0) : 1.0;

        return Opacity(
          opacity: bgFade * endFade,
          child: Container(
            color: Colors.black.withValues(alpha: 0.55 * bgFade),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: circleScale,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: CustomPaint(
                        size: const Size(96, 96),
                        painter: _CheckmarkPainter(
                          progress: checkT,
                          color: checkColor,
                          strokeWidth: 5.5,
                        ),
                      ),
                    ),
                  ),
                  if (widget.message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Opacity(
                        opacity: textFade * endFade,
                        child: Text(
                          widget.message!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static double _springBounce(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    return 1 -
        math.pow(math.e, -t * 6) *
            (math.cos(t * 12) + 0.12 * math.sin(t * 12));
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CheckmarkPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 3.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final w = size.width;

    final checkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final start = Offset(center.dx - w * 0.22, center.dy + w * 0.02);
    final mid = Offset(center.dx - w * 0.02, center.dy + w * 0.22);
    final end = Offset(center.dx + w * 0.26, center.dy - w * 0.18);

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
