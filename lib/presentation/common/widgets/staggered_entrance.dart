import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/presentation/common/widgets/motion/motion_aware.dart';

/// Wraps [children] in staggered entrance animations and returns the wrapped
/// list — spread it directly into a parent's `children:` so layout, width,
/// and cross-axis alignment stay exactly as the parent dictates.
///
/// Each child fades in + rises with a spring-physics stagger delay, animates
/// only on first appearance (rebuilds are instant), and repaints inside its
/// own [RepaintBoundary].
///
/// Usage:
/// ```dart
/// children: [
///   ...staggerEntrance([
///     header,
///     card,
///   ]),
/// ],
/// ```
List<Widget> staggerEntrance(
  List<Widget> children, {
  double staggerDelay = MotionTokens.staggerDelayMs,
  double slideOffset = 12.0,
}) {
  return List.generate(children.length, (i) {
    return _StaggeredEntranceItem(
      key: ValueKey(i),
      index: i,
      staggerDelay: staggerDelay,
      slideOffset: slideOffset,
      child: children[i],
    );
  });
}

class _StaggeredEntranceItem extends StatefulWidget {
  final int index;
  final double staggerDelay;
  final double slideOffset;
  final Widget child;

  const _StaggeredEntranceItem({
    super.key,
    required this.index,
    required this.staggerDelay,
    required this.slideOffset,
    required this.child,
  });

  @override
  State<_StaggeredEntranceItem> createState() =>
      _StaggeredEntranceItemState();
}

class _StaggeredEntranceItemState extends State<_StaggeredEntranceItem>
    with SingleTickerProviderStateMixin, MotionAwareMixin {
  late AnimationController _controller;
  Timer? _timer;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _startAnimation();
  }

  void _startAnimation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_hasAnimated) {
        _controller.value = 1.0;
        return;
      }
      if (!shouldAnimate) {
        _controller.value = 1.0;
        _hasAnimated = true;
        return;
      }
      // Cap total stagger delay at staggerMaxDelay — after that,
      // items appear together instead of trailing off.
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
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          return Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, widget.slideOffset * (1 - t)),
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
