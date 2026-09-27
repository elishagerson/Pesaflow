import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

/// The app's hairline: a 1px stroke that is strongest where the light comes from
/// and fades across the surface.
///
/// This was a `Colors.white` gradient on `GlassCard`, which made
/// `hasBorder: true` a complete no-op in light mode — a white 1px line on a
/// white card — and hardcoded a colour that could not follow the palette. It
/// lives here, on the tokens, so every card edge in the app reads the same in
/// both modes.
class HairlineBorderPainter extends CustomPainter {
  final double radius;
  final Color hairline;
  final Color hairlineStrong;

  /// How far across the card the visible portion of the stroke travels.
  final double fadeEnd;

  const HairlineBorderPainter({
    required this.radius,
    required this.hairline,
    required this.hairlineStrong,
    this.fadeEnd = 0.6,
  });

  /// Reads the tokens from [context], so call sites never repeat them.
  factory HairlineBorderPainter.of(BuildContext context, double radius) {
    final appColors = context.appColors;
    return HairlineBorderPainter(
      radius: radius,
      hairline: appColors.hairline,
      hairlineStrong: appColors.hairlineStrong,
    );
  }

  /// The two stroke colours, strongest first. Exposed so the pair can be
  /// asserted directly instead of by pixel-scraping a render.
  List<Color> get colors => [hairlineStrong, hairline.withValues(alpha: 0)];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
          stops: [0.0, fadeEnd],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant HairlineBorderPainter old) =>
      old.radius != radius ||
      old.hairline != hairline ||
      old.hairlineStrong != hairlineStrong ||
      old.fadeEnd != fadeEnd;
}
