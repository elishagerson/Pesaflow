import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/spacing.dart';

/// Shows a brief, confident success animation with a self-drawing checkmark.
///
/// Use after saving a transaction, completing a payment, etc.
/// Not confetti — a professional moment of confirmation.
///
/// ```dart
/// SuccessMoment.show(context, message: 'Transaction saved');
/// ```
class SuccessMoment {
  /// Shows the success moment as a full-screen overlay.
  static void show(
    BuildContext context, {
    String? message,
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _SuccessMomentOverlay(
        message: message,
        duration: duration,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlayState.insert(overlayEntry);
  }
}

// ─── Overlay ────────────────────────────────────────────────────────────────

class _SuccessMomentOverlay extends StatefulWidget {
  final String? message;
  final Duration duration;
  final VoidCallback onDismiss;

  const _SuccessMomentOverlay({
    this.message,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_SuccessMomentOverlay> createState() => _SuccessMomentOverlayState();
}

class _SuccessMomentOverlayState extends State<_SuccessMomentOverlay>
    with TickerProviderStateMixin {
  late AnimationController _checkController;
  late AnimationController _ringController;
  late AnimationController _messageController;
  late AnimationController _dismissController;

  Timer? _dismissTimer;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _messageController = AnimationController(
      vsync: this,
      duration: MotionTokens.durationNormal,
    );

    _dismissController = AnimationController(
      vsync: this,
      duration: MotionTokens.durationExit,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final reduced = context.isReducedMotion;

    if (reduced) {
      _checkController.value = 1.0;
      _ringController.value = 1.0;
      _messageController.value = 1.0;
    } else {
      _checkController.forward().then((_) {
        if (mounted) _ringController.forward();
      });

      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _messageController.forward();
      });
    }

    _dismissTimer = Timer(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _dismissTimer?.cancel();

    if (context.isReducedMotion) {
      widget.onDismiss();
      return;
    }

    _dismissController.forward().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _checkController.dispose();
    _ringController.dispose();
    _messageController.dispose();
    _dismissController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final successColor = context.appColors.incomeColor;
    final reduced = context.isReducedMotion;

    return AnimatedBuilder(
      animation: _dismissController,
      builder: (context, child) {
        final fadeOut = 1.0 - _dismissController.value;
        return Opacity(
          opacity: fadeOut.clamp(0.0, 1.0),
          child: IgnorePointer(
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.4 : 0.25,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _ringController,
                              builder: (context, child) {
                                final ringScale = reduced
                                    ? 1.0
                                    : 0.8 + (_ringController.value * 0.4);
                                final ringOpacity = reduced
                                    ? 0.3
                                    : (1.0 - _ringController.value) * 0.3;
                                return Transform.scale(
                                  scale: ringScale,
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: successColor.withValues(
                                          alpha: ringOpacity,
                                        ),
                                        width: 2.0,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            AnimatedBuilder(
                              animation: _checkController,
                              builder: (context, child) {
                                final scale = reduced
                                    ? 1.0
                                    : 0.5 + (_checkController.value * 0.5);
                                return Transform.scale(
                                  scale: scale,
                                  child: child,
                                );
                              },
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: successColor.withValues(alpha: 0.12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: successColor.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 20,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _checkController,
                              builder: (context, child) {
                                return CustomPaint(
                                  size: const Size(32, 32),
                                  painter: _CheckmarkPainter(
                                    progress: reduced
                                        ? 1.0
                                        : _checkController.value,
                                    color: successColor,
                                    strokeWidth: 3.0,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      if (widget.message != null) ...[
                        const SizedBox(height: kSpacing16),
                        AnimatedBuilder(
                          animation: _messageController,
                          builder: (context, child) {
                            return Opacity(
                              opacity: reduced ? 1.0 : _messageController.value,
                              child: Transform.translate(
                                offset: Offset(
                                  0,
                                  reduced
                                      ? 0
                                      : (1.0 - _messageController.value) * 8,
                                ),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            widget.message!,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Checkmark Painter ──────────────────────────────────────────────────────

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CheckmarkPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final start = Offset(size.width * 0.18, size.height * 0.52);
    final mid = Offset(size.width * 0.38, size.height * 0.72);
    final end = Offset(size.width * 0.82, size.height * 0.30);

    path.moveTo(start.dx, start.dy);
    path.lineTo(mid.dx, mid.dy);
    path.lineTo(end.dx, end.dy);

    final metrics = path.computeMetrics().first;
    final totalLength = metrics.length;
    final visibleLength = totalLength * progress.clamp(0.0, 1.0);
    final extractedPath = metrics.extractPath(0, visibleLength);

    canvas.drawPath(extractedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
