import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:pesaflow/presentation/common/widgets/motion/haptic_pattern.dart';

class SpringButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final double springMass;
  final double springStiffness;
  final double springDamping;
  final Duration pressDuration;
  final HapticType? haptic;

  const SpringButton({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.96,
    this.springMass = 0.8,
    this.springStiffness = 350.0,
    this.springDamping = 14.0,
    this.pressDuration = const Duration(milliseconds: 100),
    this.haptic,
  });

  @override
  State<SpringButton> createState() => _SpringButtonState();
}

class _SpringButtonState extends State<SpringButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pressDown() {
    if (widget.onTap == null) return;
    _controller.animateTo(
      1.0,
      duration: widget.pressDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _springBack() {
    if (widget.onTap == null) return;
    if (widget.haptic != null) triggerHaptic(widget.haptic!);
    const spring = SpringDescription(
      mass: 0.8,
      stiffness: 350.0,
      damping: 14.0,
    );
    final simulation = SpringSimulation(spring, _controller.value, 0.0, 0.0);
    _controller.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _pressDown(),
      onTapUp: (_) {
        _springBack();
        widget.onTap?.call();
      },
      onTapCancel: () => _springBack(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}
