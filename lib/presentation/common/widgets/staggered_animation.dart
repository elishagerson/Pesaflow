import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

class StaggeredFadeSlide extends StatefulWidget {
  final int index;
  final Widget child;
  final double offset;

  const StaggeredFadeSlide({
    super.key,
    required this.index,
    required this.child,
    this.offset = 10,
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
    _fade = Tween<double>(begin: 0, end: 1).animate(_controller);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offset / 60),
      end: Offset.zero,
    ).animate(_controller);

    _startAnimation();
  }

  void _startAnimation() {
    // Skip animation if reduced motion is preferred
    // (checked in first build via addPostFrameCallback)
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
      _delayTimer = Timer(Duration(milliseconds: widget.index * 30), () {
        if (!mounted) return;
        const spring = SpringDescription(
          mass: 1.0,
          stiffness: 250.0,
          damping: 18.0,
        );
        _controller
            .animateWith(SpringSimulation(spring, 0.0, 1.0, 0.0))
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
