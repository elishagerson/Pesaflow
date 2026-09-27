import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

/// Mixin for widgets that need reduced-motion-aware animations.
///
/// Provides helper methods to safely animate with spring physics
/// or instant jumps depending on the user's accessibility settings.
///
/// Usage:
/// ```dart
/// class _MyWidgetState extends State<MyWidget>
///     with SingleTickerProviderStateMixin, MotionAwareMixin {
///   void _animateIn() {
///     springAnimate(_controller, MotionTokens.springSnappy, 0.0, 1.0);
///   }
/// }
/// ```
mixin MotionAwareMixin<T extends StatefulWidget> on State<T> {
  bool? _reducedMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = context.isReducedMotion;
  }

  /// Whether the user prefers reduced motion.
  ///
  /// Cached in [didChangeDependencies] rather than read on demand, because
  /// `MediaQuery.maybeOf` still asserts when called from `initState` — a
  /// widget that kicks off its first animation there would throw
  /// *"dependOnInheritedWidgetOfExactType was called before
  /// initState() completed"* and take its whole subtree with it.
  ///
  /// Before the first dependency resolution this reports `true` (animate),
  /// which is the right default: a widget that starts work from a post-frame
  /// callback is already past [didChangeDependencies] and gets the real value.
  bool get shouldAnimate => !(_reducedMotion ?? true);

  /// Animates [controller] with spring physics if motion is allowed,
  /// otherwise jumps instantly to [target].
  void springAnimate(
    AnimationController controller,
    SpringDescription spring,
    double from,
    double target,
  ) {
    if (!shouldAnimate) {
      controller.value = target;
      return;
    }
    final simulation = SpringSimulation(spring, from, target, 0.0);
    controller.animateWith(simulation);
  }

  /// Animates [controller] to [target] with the given [duration] and [curve]
  /// if motion is allowed, otherwise jumps instantly.
  void tweenAnimate(
    AnimationController controller,
    double target, {
    Duration duration = MotionTokens.durationNormal,
    Curve curve = Curves.easeOutCubic,
  }) {
    if (!shouldAnimate) {
      controller.value = target;
      return;
    }
    controller.animateTo(target, duration: duration, curve: curve);
  }

  /// Returns [duration] if motion is allowed, [Duration.zero] otherwise.
  Duration motionDuration(Duration duration) {
    return shouldAnimate ? duration : Duration.zero;
  }
}
