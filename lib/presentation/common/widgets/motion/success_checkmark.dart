import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

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
    final reducedMotion = context.isReducedMotion;
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) => _SuccessOverlay(
        message: message,
        color: color,
        displayDuration: reducedMotion
            ? const Duration(milliseconds: 400)
            : displayDuration,
        reducedMotion: reducedMotion,
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
          painter: _CheckmarkPainter(progress: _progress.value, color: color),
        );
      },
    );
  }
}

class _SuccessOverlay extends StatefulWidget {
  final String? message;
  final Color? color;
  final Duration displayDuration;
  final bool reducedMotion;

  const _SuccessOverlay({
    this.message,
    this.color,
    required this.displayDuration,
    this.reducedMotion = false,
  });

  @override
  State<_SuccessOverlay> createState() => _SuccessOverlayState();
}

class _SuccessOverlayState extends State<_SuccessOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _overlayController;

  static const _silentGreen = Color(0xFF7A9A7E);

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
    final userColor = widget.color;
    final circleColor = userColor ?? _silentGreen;
    final isDarkBg = circleColor.computeLuminance() < 0.4;
    final checkColor = isDarkBg ? Colors.white : Colors.black87;
    final ringColor = circleColor.withValues(alpha: 0.35);

    return AnimatedBuilder(
      animation: _overlayController,
      builder: (context, child) {
        final t = _overlayController.value;

        final bgFade = (t / 0.2).clamp(0.0, 1.0);

        final circleRaw = ((t - 0.15) / 0.35).clamp(0.0, 1.0);
        final circleScale = widget.reducedMotion
            ? circleRaw
            : _springBounce(circleRaw);

        final ringRaw = ((t - 0.12) / 0.45).clamp(0.0, 1.0);
        final ringProgress = Curves.easeOutCubic.transform(ringRaw);

        final checkRaw = ((t - 0.30) / 0.30).clamp(0.0, 1.0);
        final checkProgress = Curves.easeInOutCubic.transform(checkRaw);

        final textFade = ((t - 0.50) / 0.15).clamp(0.0, 1.0);

        final endFade = t > 0.85
            ? (1.0 - (t - 0.85) / 0.15).clamp(0.0, 1.0)
            : 1.0;

        return Opacity(
          opacity: bgFade * endFade,
          child: Container(
            color: Colors.black.withValues(alpha: 0.40 * bgFade),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: circleScale,
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: CustomPaint(
                        size: const Size(100, 100),
                        painter: _CirclePainter(
                          ringProgress: ringProgress,
                          ringColor: ringColor,
                        ),
                        child: Container(
                          width: 96,
                          height: 96,
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: circleColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: circleColor.withValues(alpha: 0.3),
                                blurRadius: 30,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            size: const Size(96, 96),
                            painter: _CheckmarkPainter(
                              progress: checkProgress,
                              color: checkColor,
                              strokeWidth: 5.0,
                            ),
                          ),
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
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
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
        math.pow(math.e, -t * 6) * (math.cos(t * 12) + 0.12 * math.sin(t * 12));
  }
}

class _CirclePainter extends CustomPainter {
  final double ringProgress;
  final Color ringColor;

  _CirclePainter({required this.ringProgress, required this.ringColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (ringProgress <= 0) return;

    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 1.5;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = ringColor;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * ringProgress,
      false,
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CirclePainter old) =>
      old.ringProgress != ringProgress || old.ringColor != ringColor;
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

    final start = Offset(center.dx - w * 0.22, center.dy + w * 0.04);
    final mid = Offset(center.dx - w * 0.02, center.dy + w * 0.22);
    final end = Offset(center.dx + w * 0.28, center.dy - w * 0.16);

    if (progress > 0) {
      if (progress < 0.4) {
        final segT = (progress / 0.4).clamp(0.0, 1.0);
        final sw = strokeWidth * (0.3 + 0.7 * Curves.easeOut.transform(segT));
        final point = Offset.lerp(start, mid, segT)!;
        canvas.drawLine(start, point, checkPaint..strokeWidth = sw);
      } else {
        final segT = ((progress - 0.4) / 0.6).clamp(0.0, 1.0);
        canvas.drawLine(start, mid, checkPaint..strokeWidth = strokeWidth);
        final point = Offset.lerp(mid, end, segT)!;
        canvas.drawLine(mid, point, checkPaint..strokeWidth = strokeWidth);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter old) =>
      old.progress != progress || old.color != color;
}
