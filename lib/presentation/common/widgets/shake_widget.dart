import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';

/// A widget that shakes horizontally when [shaking] is true.
/// Used for form validation errors — draws attention to the offending field.
///
/// The oscillation curve is parametrized from [MotionTokens.springStiff]
/// to match the app's spring feel while staying within ~400ms.
///
/// Usage:
/// ```dart
/// ShakeWidget(
///   shaking: _showError,
///   child: TextField(...),
/// )
/// ```
class ShakeWidget extends StatefulWidget {
  final bool shaking;
  final Widget child;
  final double offset;
  final int shakeCount;

  const ShakeWidget({
    super.key,
    required this.shaking,
    required this.child,
    this.offset = 8.0,
    this.shakeCount = 3,
  });

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shakeAnim;
  double _offsetX = 0.0;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 400),
        )..addListener(() {
          setState(() => _offsetX = _shakeAnim.value);
        });
    _shakeAnim = _buildShakeAnimation();
  }

  @override
  void didUpdateWidget(ShakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shaking && !oldWidget.shaking) {
      _startShake();
    } else if (!widget.shaking && oldWidget.shaking) {
      _reset();
    }
  }

  /// Build a decaying oscillation animation parametrized from
  /// [MotionTokens.springStiff]. Produces `shakeCount` peaks that
  /// decay exponentially over ~400ms.
  Animation<double> _buildShakeAnimation() {
    final spring = MotionTokens.springStiff;
    final omega = math.sqrt(spring.stiffness / spring.mass);
    final zeta =
        spring.damping / (2 * math.sqrt(spring.stiffness * spring.mass));

    return Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: _SpringOscillation(
          amplitude: widget.offset,
          decay: zeta * omega,
          frequency: omega,
        ),
      ),
    );
  }

  void _startShake() {
    final mq = MediaQuery.maybeOf(context);
    if (mq?.disableAnimations ?? false) return;

    _controller
      ..stop()
      ..reset()
      ..forward();
  }

  void _reset() {
    _controller.stop();
    if (mounted) setState(() => _offsetX = 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(_offsetX, 0),
      child: widget.child,
    );
  }
}

/// A [Curve] that produces decaying horizontal oscillation.
///
/// Models a damped harmonic oscillator:
///   x(t) = A * e^(-decay * t) * cos(2π * frequency * t)
///
/// where the decay rate and frequency are derived from the app's
/// spring constants via [MotionTokens.springStiff].
class _SpringOscillation extends Curve {
  final double amplitude;
  final double decay;
  final double frequency;

  const _SpringOscillation({
    required this.amplitude,
    required this.decay,
    required this.frequency,
  });

  @override
  double transformInternal(double t) {
    if (t <= 0.0 || t >= 1.0) return 0.0;
    return amplitude *
        math.exp(-decay * t) *
        math.cos(frequency * t * 2 * math.pi);
  }
}
