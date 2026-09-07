import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

/// A widget that staggers its entrance with a spring-driven fade + slide.
///
/// Subtle by default: 6px slide offset, 30ms stagger delay, max 300ms total.
/// Animates only once — rebuilds after the initial entrance are instant.
class StaggeredFadeSlide extends StatefulWidget {
  final int index;
  final Widget child;
  final double offset;
  final Axis axis;

  const StaggeredFadeSlide({
    super.key,
    required this.index,
    required this.child,
    this.offset = 6,
    this.axis = Axis.vertical,
  });

  @override
  State<StaggeredFadeSlide> createState() => _StaggeredFadeSlideState();
}

class _StaggeredFadeSlideState extends State<StaggeredFadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  Timer? _delayTimer;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);

    final slideBegin = widget.axis == Axis.vertical
        ? Offset(0, widget.offset / 60)
        : Offset(widget.offset / 60, 0);

    _fade = Tween<double>(begin: 0, end: 1).animate(_controller);
    _slide = Tween<Offset>(
      begin: slideBegin,
      end: Offset.zero,
    ).animate(_controller);

    _startAnimation();
  }

  void _startAnimation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.isReducedMotion) {
        _controller.value = 1.0;
        _hasAnimated = true;
        return;
      }
      if (_hasAnimated) {
        _controller.value = 1.0;
        return;
      }
      // Cap total stagger delay at 300ms
      final delay = (widget.index * MotionTokens.staggerDelayMs)
          .round()
          .clamp(0, MotionTokens.staggerMaxDelay.inMilliseconds);
      _delayTimer = Timer(Duration(milliseconds: delay), () {
        if (!mounted) return;
        _controller
            .animateWith(SpringSimulation(
              MotionTokens.springStiff,
              0.0,
              1.0,
              0.0,
            ))
            .then((_) => _hasAnimated = true);
      });
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      ),
    );
  }
}
