import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/physics.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

/// A list view with spring-physics staggered item entrance.
///
/// Each item fades + slides in with a 30ms stagger delay (capped at 300ms).
/// The entrance belongs to the **first load only**: once the opening stagger
/// has settled, rows built by scrolling or by a filter change appear
/// instantly. Re-animating on every scroll is decorative motion on a
/// high-frequency surface and reads as jank, not polish.
class StaggeredList extends StatefulWidget {
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
  State<StaggeredList> createState() => _StaggeredListState();
}

class _StaggeredListState extends State<StaggeredList> {
  bool _firstLoad = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Keep the window just longer than the longest staggered entrance so the
    // opening animation is never cut short, then stop animating new rows.
    _timer = Timer(
      MotionTokens.staggerMaxDelay +
          MotionTokens.durationNormal +
          const Duration(milliseconds: 100),
      () {
        if (mounted) setState(() => _firstLoad = false);
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.controller,
      physics:
          widget.physics ??
          (widget.shrinkWrap
              ? const NeverScrollableScrollPhysics()
              : const ClampingScrollPhysics()),
      shrinkWrap: widget.shrinkWrap,
      padding: widget.padding,
      itemCount: widget.itemCount,
      itemBuilder: (context, index) {
        return _StaggeredItem(
          index: index,
          staggerDelay: widget.staggerDelay,
          animate: _firstLoad,
          child: widget.itemBuilder(context, index),
        );
      },
    );
  }
}

class _StaggeredItem extends StatefulWidget {
  final int index;
  final double staggerDelay;
  final bool animate;
  final Widget child;

  const _StaggeredItem({
    required this.index,
    required this.staggerDelay,
    required this.animate,
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
    _fade = Tween<double>(begin: 0, end: 1).animate(_controller);
    _slide = Tween<Offset>(
      begin: Offset(0, MotionTokens.staggerSlideOffset),
      end: Offset.zero,
    ).animate(_controller);

    _startAnimation();
  }

  void _startAnimation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.animate || _hasAnimated) {
        _controller.value = 1.0;
        _hasAnimated = true;
        return;
      }
      if (context.isReducedMotion) {
        _controller.value = 1.0;
        _hasAnimated = true;
        return;
      }
      // Cap total stagger delay at 300ms
      final delay = (widget.index * widget.staggerDelay).round().clamp(
        0,
        MotionTokens.staggerMaxDelay.inMilliseconds,
      );
      _timer = Timer(Duration(milliseconds: delay), () {
        if (!mounted) return;
        _controller
            .animateWith(
              SpringSimulation(MotionTokens.springStiff, 0.0, 1.0, 0.0),
            )
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
