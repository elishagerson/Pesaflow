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
  /// Corner radius of the rectangle `paint` strokes. Unused by [strokePath],
  /// which takes the shape to follow instead.
  final double radius;
  final Color hairline;
  final Color hairlineStrong;

  /// How far across the card the visible portion of the stroke travels.
  final double fadeEnd;

  /// Whether the stroke fades to nothing across [fadeEnd].
  ///
  /// `GlassCard` fades, which suits a flat card on an arbitrary background. A
  /// surface with a deliberate silhouette cannot: the fade runs out partway
  /// across, so the far corners of a cut plate ended up with a border at ~25%
  /// opacity — the one edge the shape was built to show, and the one nobody
  /// could see. Those surfaces pass `fade: false` for a uniformly defined edge.
  final bool fade;

  const HairlineBorderPainter({
    this.radius = 0,
    required this.hairline,
    required this.hairlineStrong,
    this.fadeEnd = 0.6,
    this.fade = true,
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
  List<Color> get colors => fade
      ? [hairlineStrong, hairline.withValues(alpha: 0)]
      : [hairlineStrong, hairline];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    strokePath(
      canvas,
      Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius))),
      rect,
    );
  }

  /// Strokes an arbitrary shape with the same gradient, for surfaces whose
  /// outline is not a rectangle.
  ///
  /// `PesaSurface` resolves cut outlines (`PosterBorder`, `ChicaneBorder`) to a
  /// custom path. Stroking an `RRect` over it traced a plain rectangle: the
  /// diagonals were left with no border at all and the square corners bled
  /// past the cut into empty space, so the chamfer the rest of the surface
  /// agreed on was the one thing you could not see.
  void strokePath(Canvas canvas, Path path, Rect rect) {
    canvas.drawPath(
      path,
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
      old.fadeEnd != fadeEnd ||
      old.fade != fade;
}
