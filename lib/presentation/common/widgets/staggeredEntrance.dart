import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

/// Wraps a list of children with staggered entrance animations.
/// Each child slides up + fades in with a spring-physics delay.
///
/// Usage:
/// ```dart
/// StaggeredEntrance(
///   children: items.map((item) => ListTile(...)).toList(),
/// )
/// ```
class StaggeredEntrance extends StatefulWidget {
  final List<Widget> children;
  final Duration staggerDelay;
  final double slideOffset;

  const StaggeredEntrance({
    super.key,
    required this.children,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.slideOffset = 24.0,
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<double>> _slideAnimations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.children.length,
      (i) => AnimationController(
        vsync: this,
        duration: MotionTokens.durationSlow,
      ),
    );

    _fadeAnimations = _controllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut))
        .toList();

    _slideAnimations = _controllers
        .map(
          (c) => Tween<double>(
            begin: widget.slideOffset,
            end: 0,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic)),
        )
        .toList();

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    for (int i = 0; i < _controllers.length; i++) {
      await Future.delayed(widget.staggerDelay);
      if (mounted && !_controllers[i].isAnimating) {
        _controllers[i].forward();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.isReducedMotion) {
      return Column(children: widget.children);
    }

    return Column(
      children: List.generate(widget.children.length, (i) {
        return AnimatedBuilder(
          animation: _controllers[i],
          builder: (_, child) {
            return Opacity(
              opacity: _fadeAnimations[i].value,
              child: Transform.translate(
                offset: Offset(0, _slideAnimations[i].value),
                child: child,
              ),
            );
          },
          child: widget.children[i],
        );
      }),
    );
  }
}
