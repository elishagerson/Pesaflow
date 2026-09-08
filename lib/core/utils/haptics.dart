import 'package:flutter/services.dart';

/// Centralized haptic feedback for PesaFlow.
/// Maps interaction types to appropriate haptic patterns.
class PesaHaptics {
  PesaHaptics._();

  /// Light tap — toggle switches, small buttons, filter chips
  static Future<void> light() => HapticFeedback.lightImpact();

  /// Medium tap — primary actions, tab selection, list item tap
  static Future<void> medium() => HapticFeedback.mediumImpact();

  /// Heavy tap — destructive actions (delete), major state changes
  static Future<void> heavy() => HapticFeedback.heavyImpact();

  /// Selection — scroll wheels, pickers, segment controls
  static Future<void> selection() => HapticFeedback.selectionClick();

  /// Success — transaction saved, goal reached
  static Future<void> success() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
  }

  /// Error — validation failure, sync error
  static Future<void> error() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }
}
