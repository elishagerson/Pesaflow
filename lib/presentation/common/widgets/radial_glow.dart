import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

/// An ambient brand glow, painted behind a surface.
///
/// This is the app's "energy" primitive. It is never interactive and never
/// carries information — it exists so that the one loud brand accent has
/// somewhere to *live* on a pure-black canvas, where a flat fill would
/// otherwise look like a sticker rather than a light source.
///
/// Three rules keep it from becoming decoration-for-decoration's-sake:
///  * One glow per screen region. Two glowing cards side by side cancel out.
///  * It sits behind a surface, never on top of text.
///  * It is static. No breathing loop, no drift — a glow that moves draws the
///    eye to a region the user did not ask about.
class RadialGlow extends StatelessWidget {
  final double size;
  final double intensity;

  /// When set, the glow is masked to this shape instead of a circle. Useful for
  /// following a chamfered hero.
  final ShapeBorder? shape;

  const RadialGlow({
    super.key,
    this.size = 220,
    this.intensity = 0.35,
    this.shape,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.appColors.brandGlow;
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RadialGlowPainter(
            color: brand,
            intensity: intensity,
            shape: shape,
          ),
        ),
      ),
    );
  }
}

class _RadialGlowPainter extends CustomPainter {
  final Color color;
  final double intensity;
  final ShapeBorder? shape;

  const _RadialGlowPainter({
    required this.color,
    required this.intensity,
    required this.shape,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    // Two stops only: a tight bright core and a long soft falloff. A
    // three-stop gradient reads as a visible disc rather than as light.
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: intensity),
          color.withValues(alpha: intensity * 0.35),
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    if (shape == null) {
      canvas.drawCircle(center, radius, paint);
    } else {
      canvas.save();
      canvas.clipPath(shape!.getOuterPath(rect));
      canvas.drawRect(rect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _RadialGlowPainter old) =>
      old.color != color || old.intensity != intensity || old.shape != shape;
}
