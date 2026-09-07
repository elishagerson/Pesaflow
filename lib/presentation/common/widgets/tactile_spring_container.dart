import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/motion/haptic_pattern.dart';

/// A press-interactive container with physics-based spring scale + opacity dim.
///
/// Provides PocketCal-level tactile feel:
/// - Press-down: quick ease to [scaleFactor] + subtle opacity dim
/// - Release: spring-back to 1.0 (haptic fires on release, confirming action)
/// - Reduced motion: instant state changes, no spring physics
class TactileSpringContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;

  /// Optional haptic type to fire on tap-up (not tap-down).
  /// PocketCal pattern: haptic confirms the action, not the intent.
  final HapticType? haptic;

  const TactileSpringContainer({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = MotionTokens.scalePress,
    this.haptic,
  });

  @override
  State<TactileSpringContainer> createState() =>
      _TactileSpringContainerState();
}

class _TactileSpringContainerState extends State<TactileSpringContainer>
    with SingleTickerProviderStateMixin {
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
    if (context.isReducedMotion) {
      _controller.value = 1.0;
      return;
    }
    _controller.animateTo(
      1.0,
      duration: MotionTokens.durationFast,
      curve: Curves.easeOutCubic,
    );
  }

  void _springBack() {
    if (widget.onTap == null) return;
    if (context.isReducedMotion) {
      _controller.value = 0.0;
      return;
    }
    final simulation = SpringSimulation(
      MotionTokens.springSnappy,
      _controller.value,
      0.0,
      0.0,
    );
    _controller.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _pressDown(),
      onTapUp: (_) {
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
