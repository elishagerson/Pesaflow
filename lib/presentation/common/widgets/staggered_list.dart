import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

/// A list view with spring-physics staggered item entrance.
///
/// Each item fades + slides in with a 30ms stagger delay (capped at 300ms).
/// Items animate only on first appearance — rebuilds are instant.
class StaggeredList extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double staggerDelay;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final ScrollController? controller;

  const StaggeredList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.staggerDelay = MotionTokens.staggerDelayMs,
    this.padding,
    this.physics,
    this.shrinkWrap = true,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      physics:
          physics ??
          (shrinkWrap
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics()),
      shrinkWrap: shrinkWrap,
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return _StaggeredItem(
          index: index,
          staggerDelay: staggerDelay,
          child: itemBuilder(context, index),
        );
      },
    );
  }
}

class _StaggeredItem extends StatefulWidget {
  final int index;
  final double staggerDelay;
  final Widget child;

  const _StaggeredItem({
    required this.index,
    required this.staggerDelay,
    required this.child,
  });

  @override
  State<_StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<_StaggeredItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  Timer? _timer;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _fade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_controller);
    _slide = Tween<Offset>(
      begin: Offset(0, MotionTokens.staggerSlideOffset),
      end: Offset.zero,
    ).animate(_controller);

    _startAnimation();
  }

  void _startAnimation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_hasAnimated) {
        _controller.value = 1.0;
        return;
      }
      if (context.isReducedMotion) {
        _controller.value = 1.0;
        _hasAnimated = true;
        return;
      }
      // Cap total stagger delay at 300ms
      final delay = (widget.index * widget.staggerDelay)
          .round()
          .clamp(0, MotionTokens.staggerMaxDelay.inMilliseconds);
      _timer = Timer(Duration(milliseconds: delay), () {
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
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
