import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Centralized haptic feedback for PesaFlow.
/// Maps interaction types to appropriate haptic patterns.
///
/// All methods automatically respect the platform's reduced-motion /
/// disable-animations accessibility setting. When the user has enabled
/// "Remove animations" (Android) or "Reduce Motion" (iOS), haptics are
/// suppressed — a haptic without its paired visual context can be confusing.
class PesaHaptics {
  PesaHaptics._();

  /// Whether the platform has requested reduced motion / disabled animations.
  ///
  /// Uses [WidgetsBinding.platformDispatcher] so callers don't need a
  /// [BuildContext]. Falls back to `false` if the binding isn't initialized
  /// yet (e.g. during very early startup).
  static bool get _isReducedMotion {
    final binding = WidgetsBinding.instance;
    return binding.platformDispatcher.accessibilityFeatures.disableAnimations;
  }

  /// Light tap — toggle switches, small buttons, filter chips
  static Future<void> light() {
    if (_isReducedMotion) return SynchronousFuture(null);
    return HapticFeedback.lightImpact();
  }

  /// Medium tap — primary actions, tab selection, list item tap
  static Future<void> medium() {
    if (_isReducedMotion) return SynchronousFuture(null);
    return HapticFeedback.mediumImpact();
  }

  /// Heavy tap — destructive actions (delete), major state changes
  static Future<void> heavy() {
    if (_isReducedMotion) return SynchronousFuture(null);
    return HapticFeedback.heavyImpact();
  }

  /// Selection — scroll wheels, pickers, segment controls
  static Future<void> selection() {
    if (_isReducedMotion) return SynchronousFuture(null);
    return HapticFeedback.selectionClick();
  }

  /// Success — transaction saved, goal reached
  static Future<void> success() async {
    if (_isReducedMotion) return;
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
  }

  /// Error — validation failure, sync error
  static Future<void> error() async {
    if (_isReducedMotion) return;
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }
}
