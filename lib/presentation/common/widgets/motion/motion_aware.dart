import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';

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
  /// Whether the user prefers reduced motion.
  bool get shouldAnimate =>
      !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

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
