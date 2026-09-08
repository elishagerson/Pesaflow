import 'package:flutter/physics.dart';

/// Centralized motion design tokens for PesaFlow.
///
/// Inspired by PocketCal's physics-based motion: every interaction should
/// feel physical, purposeful, and invisible — not decorative.
///
/// Usage:
/// ```dart
/// _controller.animateWith(
///   SpringSimulation(kSpringSnappy, 0.0, 1.0, 0.0),
/// );
/// ```
class MotionTokens {
  MotionTokens._();

  // ── Spring Descriptions ──────────────────────────────────────────────
  // Named springs for consistent physics across the app.

  /// Snappy spring for buttons, taps, and quick interactions.
  /// Fast settle, minimal overshoot — feels responsive and precise.
  static const SpringDescription springSnappy = SpringDescription(
    mass: 0.8,
    stiffness: 350.0,
    damping: 22.0,
  );

  /// Gentle spring for sheets, cards, and content entrances.
  /// Slower settle, soft overshoot — feels natural and organic.
  static const SpringDescription springGentle = SpringDescription(
    mass: 0.8,
    stiffness: 300.0,
    damping: 18.0,
  );

  /// Bouncy spring for celebrations and emphasis moments.
  /// Noticeable overshoot — use sparingly for delight.
  static const SpringDescription springBouncy = SpringDescription(
    mass: 0.6,
    stiffness: 200.0,
    damping: 12.0,
  );

  /// Stiff spring for quick settle with no visible overshoot.
  /// Used for list item stagger and subtle position corrections.
  static const SpringDescription springStiff = SpringDescription(
    mass: 1.0,
    stiffness: 400.0,
    damping: 28.0,
  );

  // ── Durations ────────────────────────────────────────────────────────
  // For tween-based animations where springs aren't appropriate.

  /// Ultra-fast feedback (press-down scale).
  static const Duration durationFast = Duration(milliseconds: 100);

  /// Standard transitions (crossfades, simple state changes).
  static const Duration durationNormal = Duration(milliseconds: 250);

  /// Deliberate transitions (expand/collapse, content reveal).
  static const Duration durationSlow = Duration(milliseconds: 400);

  /// Sheet and dialog entrance.
  static const Duration durationSheet = Duration(milliseconds: 600);

  /// Exit/dismiss animations — always faster than entrance.
  static const Duration durationExit = Duration(milliseconds: 200);

  // ── Scale Factors ────────────────────────────────────────────────────
  // Press-down scale targets for different surface types.

  /// Standard button/interactive element press scale.
  static const double scalePress = 0.96;

  /// Card press — subtler to preserve content readability.
  static const double scaleCardPress = 0.98;

  /// FAB press — deeper to feel "pushable".
  static const double scaleFabPress = 0.92;

  /// Opacity dim during press — subtle tactile depth cue.
  static const double opacityPress = 0.85;

  // ── Stagger Timing ──────────────────────────────────────────────────

  /// Delay between consecutive stagger items (milliseconds).
  static const double staggerDelayMs = 30.0;

  /// Maximum total stagger delay — after this, items appear together.
  static const Duration staggerMaxDelay = Duration(milliseconds: 300);

  /// Slide offset for stagger entrance (fraction of container height).
  static const double staggerSlideOffset = 0.08;

  // ── Thresholds ───────────────────────────────────────────────────────

  /// Minimum fling velocity to trigger sheet dismiss (px/s).
  static const double sheetDismissVelocity = 400.0;

  /// Sheet drag fraction of height to trigger dismiss (without fling).
  static const double sheetDismissFraction = 0.4;

  /// Upward fling velocity threshold — snaps sheet to full open (px/s).
  static const double sheetSnapUpVelocity = -400.0;

  /// Lower bound of the half-open (peek) snap zone as a fraction of sheet height.
  static const double sheetHalfOpenFractionLower = 0.15;

  /// Visible fraction of sheet height when snapped to peek mode.
  static const double sheetHalfOpenVisibleFraction = 0.4;
}
