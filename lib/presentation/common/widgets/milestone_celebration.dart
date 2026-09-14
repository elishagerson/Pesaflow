import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/utils/spacing.dart';

/// Shows a brief, satisfying celebration when a savings goal reaches 100%.
///
/// Not confetti — a confident checkmark with a subtle ring expansion.
/// Inspired by PocketCal's emotional transformation moments:
/// the relief of organisation becomes the joy of financial achievement.
///
/// ```dart
/// MilestoneCelebration.show(context, goalName: 'Holiday Fund', amount: 500000);
/// ```
class MilestoneCelebration extends StatefulWidget {
  final String goalName;
  final double amount;
  final VoidCallback? onDismiss;

  const MilestoneCelebration({
    super.key,
    required this.goalName,
    required this.amount,
    this.onDismiss,
  });

  /// Show the celebration as a full-screen overlay.
  static Future<void> show(
    BuildContext context, {
    required String goalName,
    required double amount,
  }) async {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => MilestoneCelebration(
        goalName: goalName,
        amount: amount,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlayState.insert(overlayEntry);
  }

  @override
  State<MilestoneCelebration> createState() => _MilestoneCelebrationState();
}

class _MilestoneCelebrationState extends State<MilestoneCelebration>
    with TickerProviderStateMixin {
  late AnimationController _circleController;
  late AnimationController _checkController;
  late AnimationController _ringController;
  late AnimationController _textController;
  late AnimationController _dismissController;

  Timer? _dismissTimer;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    _circleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _checkController = AnimationController(
      vsync: this,
      duration: MotionTokens.durationSlow,
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _textController = AnimationController(
      vsync: this,
      duration: MotionTokens.durationSlow,
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

    PesaHaptics.success();
    // TODO(future): play a soft chime sound here when audio is implemented

    if (context.isReducedMotion) {
      _circleController.value = 1.0;
      _checkController.value = 1.0;
      _ringController.value = 1.0;
      _textController.value = 1.0;
    } else {
      // Circle scales in with a bouncy spring
      _circleController
          .animateWith(
            SpringSimulation(MotionTokens.springBouncy, 0.0, 1.0, 0.0),
          )
          .then((_) {
            if (!mounted) return;
            // Checkmark draws itself after circle lands
            _checkController.forward();
          });

      // Ring expansion starts slightly after circle
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          _ringController.forward();
        }
      });

      // Text fades in after checkmark completes
      Future.delayed(MotionTokens.durationNormal, () {
        if (mounted) _textController.forward();
      });
    }

    _dismissTimer = Timer(const Duration(seconds: 3), _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _dismissTimer?.cancel();

    if (context.isReducedMotion) {
      widget.onDismiss?.call();
      return;
    }

    _dismissController.forward().then((_) {
      widget.onDismiss?.call();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _circleController.dispose();
    _checkController.dispose();
    _ringController.dispose();
    _textController.dispose();
    _dismissController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final successColor = context.appColors.successColor;
    final reduced = context.isReducedMotion;

    return AnimatedBuilder(
      animation: _dismissController,
      builder: (context, child) {
        final fadeOut = 1.0 - _dismissController.value;
        return Opacity(
          opacity: fadeOut.clamp(0.0, 1.0),
          child: GestureDetector(
            onTap: _dismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.6 : 0.45,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Circle + Checkmark + Ring ──
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer ring expansion
                          AnimatedBuilder(
                            animation: _ringController,
                            builder: (context, child) {
                              final ringScale = reduced
                                  ? 1.2
                                  : 0.6 + (_ringController.value * 0.6);
                              final ringOpacity = reduced
                                  ? 0.15
                                  : (1.0 - _ringController.value) * 0.25;
                              return Transform.scale(
                                scale: ringScale,
                                child: Container(
                                  width: 120,
                                  height: 120,
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

                          // Filled circle — scales in with bouncy spring
                          AnimatedBuilder(
                            animation: _circleController,
                            builder: (context, child) {
                              final scale = reduced
                                  ? 1.0
                                  : _circleController.value;
                              return Transform.scale(
                                scale: scale,
                                child: child,
                              );
                            },
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: successColor.withValues(alpha: 0.12),
                                boxShadow: [
                                  BoxShadow(
                                    color: successColor.withValues(alpha: 0.2),
                                    blurRadius: 32,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Self-drawing checkmark
                          AnimatedBuilder(
                            animation: _checkController,
                            builder: (context, child) {
                              return CustomPaint(
                                size: const Size(48, 48),
                                painter: _CheckmarkPainter(
                                  progress: reduced
                                      ? 1.0
                                      : _checkController.value,
                                  color: successColor,
                                  strokeWidth: 4.0,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: kSpacing24),

                    // ── Text content ──
                    AnimatedBuilder(
                      animation: _textController,
                      builder: (context, child) {
                        final t = reduced ? 1.0 : _textController.value;
                        return Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, (1.0 - t) * 12),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Goal reached!',
                            style: context.ts(
                              24,
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: kSpacing8),
                          Text(
                            widget.goalName,
                            style: context.ts(
                              16,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: kSpacing12),
                          Text(
                            'TSh ${_formatAmount(widget.amount)}',
                            style: context.ts(
                              28,
                              color: successColor,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: kSpacing8),
                          Text('🎉', style: context.ts(24)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Formats a number with thousand separators (e.g. 500000 → 500,000).
  static String _formatAmount(double amount) {
    final parts = amount.round().toString().split('').reversed.toList();
    final buffer = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write(',');
      buffer.write(parts[i]);
    }
    return buffer.toString().split('').reversed.join();
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
    this.strokeWidth = 4.0,
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
