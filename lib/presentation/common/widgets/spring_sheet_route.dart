import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// A bottom sheet route with physics-based spring animation.
///
/// Replaces the default linear slide with a spring-driven scale + slide
/// for a premium feel. Call [showSpringSheet] instead of `showModalBottomSheet`.
Future<T?> showSpringSheet<T>(
  BuildContext context, {
  required Widget builder(BuildContext),
  Color? backgroundColor,
  double? initialChildSize,
  bool useSafeArea = true,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    useSafeArea: useSafeArea,
    isScrollControlled: isScrollControlled,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionAnimationController: null,
    builder: (ctx) => _SpringSheetWrapper(
      builder: builder(ctx),
      backgroundColor: backgroundColor,
    ),
  );
}

class _SpringSheetWrapper extends StatefulWidget {
  final Widget builder;
  final Color? backgroundColor;

  const _SpringSheetWrapper({
    required this.builder,
    this.backgroundColor,
  });

  @override
  State<_SpringSheetWrapper> createState() => _SpringSheetWrapperState();
}

class _SpringSheetWrapperState extends State<_SpringSheetWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    final spring = SpringSimulation(
      SpringDescription(mass: 0.8, stiffness: 300, damping: 18),
      0,
      1,
      0,
    );
    _animation = _controller.drive(Tween<double>(begin: 0, end: 1));

    _controller.animateWith(spring);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = widget.backgroundColor ?? theme.colorScheme.surface;

    return AnimatedBuilder(
      animation: _animation,
      builder: (_, child) {
        final t = _animation.value;
        final scale = 1.0 - (0.08 * (1 - t));
        final translateY = (1 - t) * 60;
        final opacity = 0.5 + (0.5 * t);

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: widget.builder,
        ),
      ),
    );
  }
}
