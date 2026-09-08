import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

/// A page route that supports iOS-style interactive back-swipe gesture.
///
/// The current page slides right to reveal a dark scrim over the previous route.
/// Drag from the left edge (within 30px) to initiate. Release triggers either
/// a spring-dismiss (past 35% width or fling > 800px/s) or spring-back.
///
/// Usage:
/// ```dart
/// Navigator.of(context).push(SwipeBackRoute(page: MyScreen()));
/// // or
/// pushSwipeBack(context, MyScreen());
/// ```
class SwipeBackRoute<T> extends PageRouteBuilder<T> {
  SwipeBackRoute({required Widget page})
      : super(
          opaque: false,
          barrierDismissible: false,
          pageBuilder: (_, _, _) => page,
          transitionsBuilder: (_, animation, _, child) {
            return _SwipeBackTransition(
              animation: animation,
              child: child,
            );
          },
        );
}

/// Pushes [page] with an interactive iOS-style back-swipe gesture.
Future<T?> pushSwipeBack<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push(SwipeBackRoute<T>(page: page));
}

/// Returns a [CustomTransitionPage] with the interactive back-swipe gesture,
/// suitable for use in go_router's `pageBuilder`.
Page<dynamic> swipeBackPage(Widget page) {
  return CustomTransitionPage(
    key: ValueKey(page.runtimeType),
    opaque: false,
    child: page,
    transitionsBuilder: (_, animation, _, child) {
      return _SwipeBackTransition(animation: animation, child: child);
    },
  );
}

/// Stateful wrapper that handles the drag gesture and spring physics.
class _SwipeBackTransition extends StatefulWidget {
  final Animation<double> animation;
  final Widget child;

  const _SwipeBackTransition({
    required this.animation,
    required this.child,
  });

  @override
  State<_SwipeBackTransition> createState() => _SwipeBackTransitionState();
}

class _SwipeBackTransitionState extends State<_SwipeBackTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  /// 0 = fully covering previous route, 1 = fully dismissed.
  double _dragProgress = 0.0;
  bool _isDragging = false;

  static const double _edgeWidth = 30.0;
  static const double _dismissFraction = 0.35;
  static const double _dismissVelocity = 800.0;
  static const double _maxScrimAlpha = 0.3;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      value: 0,
      upperBound: 1,
    );

    // Drive from 0→1 as the route pushes forward; we read the raw value
    // during the transitionsBuilder but the real interactivity comes from
    // _dragProgress which drives the layout directly.
    widget.animation.addListener(_onAnimationTick);
  }

  void _onAnimationTick() {
    // When the forward push animation completes, snap progress to 0 (fully shown).
    if (widget.animation.isCompleted && !_isDragging && _dragProgress != 0.0) {
      // Only snap if this was the initial push settling, not a dismiss.
    }
  }

  @override
  void dispose() {
    widget.animation.removeListener(_onAnimationTick);
    _animController.dispose();
    super.dispose();
  }

  // ── Gesture Detection ──────────────────────────────────────────────────

  void _onDragStart(DragStartDetails details) {
    final dx = details.localPosition.dx;
    if (dx > _edgeWidth) return; // not from left edge
    _isDragging = true;
    _dragProgress = 0.0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final screenWidth = MediaQuery.sizeOf(context).width;
    if (screenWidth <= 0) return;

    setState(() {
      _dragProgress =
          (_dragProgress + details.delta.dx / screenWidth).clamp(0.0, 1.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    final velocity = details.velocity.pixelsPerSecond.dx;
    final shouldDismiss =
        _dragProgress > _dismissFraction || velocity > _dismissVelocity;

    if (shouldDismiss) {
      _animateDismiss(velocity: velocity);
    } else {
      _animateSpringBack();
    }
  }

  // ── Spring Animations ─────────────────────────────────────────────────

  void _animateDismiss({double velocity = 0}) {
    if (context.isReducedMotion) {
      Navigator.of(context).pop();
      return;
    }

    final startProgress = _dragProgress;
    // Map fling velocity to a starting speed — negative = leftward = dismiss.
    final startVelocity = velocity < 0 ? -velocity / 1000 : 1.0;

    final simulation = SpringSimulation(
      MotionTokens.springSnappy,
      startProgress,
      1.0,
      -startVelocity, // negative = toward 1.0 (dismiss direction)
    );

    _animController
      ..value = startProgress
      ..animateWith(simulation).then((_) {
        if (mounted) Navigator.of(context).pop();
      });
  }

  void _animateSpringBack() {
    if (context.isReducedMotion) {
      setState(() => _dragProgress = 0.0);
      return;
    }

    final startProgress = _dragProgress;

    final simulation = SpringSimulation(
      MotionTokens.springSnappy,
      startProgress,
      0.0,
      0.0,
    );

    _animController
      ..value = startProgress
      ..animateWith(simulation).then((_) {
        if (mounted) setState(() => _dragProgress = 0.0);
      });
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.animation, _animController]),
      builder: (_, _) {
        // Use the maximum of the push animation and the drag — whichever is
        // further along dominates. During drag _dragProgress > 0; during push
        // forward widget.animation drives from 0→1.
        final pushValue = widget.animation.value;
        final progress = math.max(pushValue, _dragProgress);

        final screenWidth = MediaQuery.sizeOf(context).width;
        final slideOffset = -screenWidth * (1.0 - progress);

        return GestureDetector(
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: Stack(
            children: [
              // Dark scrim behind the sliding content
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(
                        alpha: (1.0 - progress) * _maxScrimAlpha,
                      ),
                    ),
                  ),
                ),
              ),
              // The actual page content, sliding in from left
              Transform.translate(
                offset: Offset(slideOffset, 0),
                child: SizedBox(
                  width: screenWidth,
                  height: MediaQuery.sizeOf(context).height,
                  child: widget.child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
