import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/presentation/common/widgets/motion/haptic_pattern.dart';
import 'package:pesaflow/presentation/common/widgets/motion/motion_aware.dart';

/// A spring-physics button with configurable spring parameters.
///
/// For most cases, prefer [TactileSpringContainer] which uses the standard
/// spring preset. Use [SpringButton] when you need custom spring tuning
/// (e.g., a bouncier celebration button or a stiffer nav element).
class SpringButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final SpringDescription spring;
  final Duration pressDuration;

  /// Haptic fires on tap-up (confirms the action, not the intent).
  final HapticType? haptic;

  const SpringButton({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = MotionTokens.scalePress,
    this.spring = MotionTokens.springSnappy,
    this.pressDuration = MotionTokens.durationFast,
    this.haptic,
  });

  @override
  State<SpringButton> createState() => _SpringButtonState();
}

class _SpringButtonState extends State<SpringButton>
    with SingleTickerProviderStateMixin, MotionAwareMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(_controller);
    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: MotionTokens.opacityPress,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pressDown() {
    if (widget.onTap == null) return;
    tweenAnimate(_controller, 1.0, duration: widget.pressDuration);
  }

  void _springBack() {
    if (widget.onTap == null) return;
    springAnimate(_controller, widget.spring, _controller.value, 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _pressDown(),
      onTapUp: (_) {
        // Haptic on release — confirms the action, not the intent
        if (widget.haptic != null) triggerHaptic(widget.haptic!);
        _springBack();
        widget.onTap?.call();
      },
      onTapCancel: () => _springBack(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: ScaleTransition(scale: _scaleAnimation, child: child),
          );
        },
        child: widget.child,
      ),
    );
  }
}
