
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

/// A page route that supports iOS-native forward push and interactive back-swipe.
///
/// Forward push slides the page in from the RIGHT (matching CupertinoPageRoute).
/// Back gesture: drag from the left edge (within 30px) to slide the page off
/// to the right, revealing a dark scrim. Release triggers either a spring-dismiss
/// (past 35% width or fling > 800px/s) or spring-back with iOS ease-out curve.
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
          return _SwipeBackTransition(animation: animation, child: child);
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

  const _SwipeBackTransition({required this.animation, required this.child});

  @override
  State<_SwipeBackTransition> createState() => _SwipeBackTransitionState();
}

class _SwipeBackTransitionState extends State<_SwipeBackTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  /// 0 = fully on-screen, 1 = fully dismissed off-screen to the right.
  double _dragProgress = 0.0;
  bool _isDragging = false;

  static const double _edgeWidth = 36.0;
  static const double _dismissFraction = 0.35;
  static const double _dismissVelocity = 700.0;
  static const double _maxScrimAlpha = 0.35;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController.unbounded(vsync: this, value: 0.0)
      ..addListener(() {
        if (!_isDragging && mounted) {
          setState(() {
            _dragProgress = _animController.value.clamp(0.0, 1.0);
          });
        }
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Gesture Detection ──────────────────────────────────────────────────

  void _onDragStart(DragStartDetails details) {
    final dx = details.localPosition.dx;
    if (dx > _edgeWidth) return; // only activate from left edge
    _isDragging = true;
    _dragProgress = 0.0;
    _animController.value = 0.0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final screenWidth = MediaQuery.sizeOf(context).width;
    if (screenWidth <= 0) return;

    setState(() {
      _dragProgress = (_dragProgress + details.delta.dx / screenWidth).clamp(
        0.0,
        1.0,
      );
      _animController.value = _dragProgress;
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

  // ── iOS-native Animations ─────────────────────────────────────────────

  void _animateDismiss({double velocity = 0}) {
    if (context.isReducedMotion) {
      Navigator.of(context).pop();
      return;
    }

    final startProgress = _dragProgress;
    final initialVelocity = velocity > 0 ? (velocity / 1000).clamp(0.5, 3.0) : 1.0;

    final simulation = SpringSimulation(
      MotionTokens.springSnappy,
      startProgress,
      1.0,
      initialVelocity,
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
      _animController.value = 0.0;
      return;
    }

    final simulation = SpringSimulation(
      MotionTokens.springSnappy,
      _dragProgress,
      0.0,
      0.0,
    );
    _animController.animateWith(simulation);
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.animation, _animController]),
      builder: (_, _) {
        final pushValue = widget.animation.value;
        // When stationary on screen: pushValue == 1.0, _dragProgress == 0.0 -> visibleFraction == 1.0.
        // During swipe-back drag or dismiss: visibleFraction tracks (1.0 - _dragProgress).
        // During normal Navigator.pop: pushValue reverses 1.0 -> 0.0 smoothly.
        final visibleFraction = (pushValue * (1.0 - _dragProgress)).clamp(0.0, 1.0);

        final screenWidth = MediaQuery.sizeOf(context).width;
        // iOS-native: 0 offset = fully visible, screenWidth = fully off-screen right
        final slideOffset = screenWidth * (1.0 - visibleFraction);

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: Stack(
            children: [
              // Dark scrim behind sliding content, deepest during drag
              if (visibleFraction < 1.0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(
                          alpha: visibleFraction * _maxScrimAlpha,
                        ),
                      ),
                    ),
                  ),
                ),
              // Cupertino-style shadow on the leading edge for tactile depth
              if (slideOffset > 0)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: slideOffset - 16,
                  width: 16,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.12 * visibleFraction),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // The actual page content sliding in/out
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
