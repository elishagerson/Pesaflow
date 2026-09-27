import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/app_shapes.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/hairline_border.dart';
import 'package:pesaflow/presentation/common/widgets/radial_glow.dart';

/// The app's surface primitive: a shape-aware container that owns fill, the
/// 1px hairline, the elevation shadow and the ambient brand glow in one place.
///
/// It exists because those four things are always needed *together* and always
/// have to agree on the same outline. Doing them in a `BoxDecoration` forces
/// the shadow to be a rounded rectangle while the fill is something else, so
/// the app had been quietly giving up on chamfered heroes. One painter fixes
/// that: shadow, glow, fill and stroke all trace the identical path.
///
/// Use:
///  * [PesaSurface.card] — the default. Rounded, hairline, soft elevation.
///  * [PesaSurface.chamfered] — the poster cut. **One per screen region**; the
///    motif stops reading the moment it is everywhere.
class PesaSurface extends StatelessWidget {
  final Widget child;
  final Color? fill;
  final Color? stroke;

  /// Corner radius at rest. Ignored for chamfered surfaces, which derive theirs.
  final double radius;

  /// Extent of the 45° poster cut on the chamfered variant.
  final double chamfer;

  final bool chamfered;

  /// Brand glow behind the fill, masked to this surface's own shape. `0`
  /// disables it. Keep it under `0.5` — above that it stops reading as light
  /// and starts reading as a coloured card.
  final double glow;

  final List<BoxShadow> shadows;
  final EdgeInsetsGeometry padding;

  /// Whether content (and the glow) is clipped to the surface outline. Only
  /// turn this off for content that must bleed past the shape deliberately.
  final bool clipContent;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const PesaSurface({
    super.key,
    required this.child,
    this.fill,
    this.stroke,
    this.radius = AppTheme.radiusCard,
    this.chamfer = 18,
    this.chamfered = false,
    this.glow = 0,
    this.shadows = const [],
    this.padding = EdgeInsets.zero,
    this.clipContent = true,
    this.onTap,
    this.semanticLabel,
  });

  /// A standard card: rounded, hairline, soft elevation, no glow.
  factory PesaSurface.card({
    Key? key,
    required Widget child,
    Color? fill,
    Color? stroke,
    double radius = AppTheme.radiusCard,
    List<BoxShadow> shadows = const [],
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    bool clipContent = true,
    VoidCallback? onTap,
    String? semanticLabel,
  }) {
    return PesaSurface(
      key: key,
      fill: fill,
      stroke: stroke,
      radius: radius,
      shadows: shadows,
      padding: padding,
      clipContent: clipContent,
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: child,
    );
  }

  /// The poster cut, with the brand glow behind it.
  factory PesaSurface.chamferSurface({
    Key? key,
    required Widget child,
    Color? fill,
    Color? stroke,
    double chamfer = 18,
    double glow = 0.28,
    List<BoxShadow> shadows = const [],
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    bool clipContent = true,
    VoidCallback? onTap,
    String? semanticLabel,
  }) {
    return PesaSurface(
      key: key,
      fill: fill,
      stroke: stroke,
      chamfer: chamfer,
      chamfered: true,
      glow: glow,
      shadows: shadows,
      padding: padding,
      clipContent: clipContent,
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final body = DecoratedBox(
      decoration: ShapeDecoration(
        shape: chamfered
            ? ChicaneBorder(borderRadius: AppTheme.radiusCard, chamfer: chamfer)
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
        color: fill ?? appColors.cardBackground,
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (glow > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: RadialGlow(
                  size: 260,
                  intensity: glow,
                  shape: chamfered
                      ? ChicaneBorder(
                          borderRadius: AppTheme.radiusCard,
                          chamfer: chamfer,
                        )
                      : RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radius),
                        ),
                ),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );

    final content = CustomPaint(
      painter: _PesaSurfacePainter(
        chamfered: chamfered,
        radius: radius,
        chamfer: chamfer,
        stroke: stroke ?? appColors.hairline,
        shadows: shadows,
      ),
      child: clipContent
          ? ClipPath(
              clipper: _SurfaceClipper(
                chamfered: chamfered,
                radius: radius,
                chamfer: chamfer,
              ),
              child: body,
            )
          : body,
    );

    if (semanticLabel == null && onTap == null) return content;
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: content,
    );
  }
}

class _SurfaceClipper extends CustomClipper<Path> {
  final bool chamfered;
  final double radius;
  final double chamfer;

  const _SurfaceClipper({
    required this.chamfered,
    required this.radius,
    required this.chamfer,
  });

  @override
  Path getClip(Size size) => _pathFor(size);

  @override
  bool shouldReclip(covariant _SurfaceClipper old) =>
      old.chamfered != chamfered ||
      old.radius != radius ||
      old.chamfer != chamfer;

  Path _pathFor(Size size) => chamfered
      ? appShapePath(
          rect: Offset.zero & size,
          radius: radius,
          topLeft: AppCorner.chamfer,
          bottomRight: AppCorner.chamfer,
          chamfer: chamfer,
        )
      : appShapePath(rect: Offset.zero & size, radius: radius);
}

class _PesaSurfacePainter extends CustomPainter {
  final bool chamfered;
  final double radius;
  final double chamfer;
  final Color stroke;
  final List<BoxShadow> shadows;

  const _PesaSurfacePainter({
    required this.chamfered,
    required this.radius,
    required this.chamfer,
    required this.stroke,
    required this.shadows,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = chamfered
        ? appShapePath(
            rect: Offset.zero & size,
            radius: radius,
            topLeft: AppCorner.chamfer,
            bottomRight: AppCorner.chamfer,
            chamfer: chamfer,
          )
        : appShapePath(rect: Offset.zero & size, radius: radius);

    // Painted first so the fill (this CustomPaint's child) covers the shadow's
    // solid core and only the soft halo survives.
    for (final s in shadows) {
      canvas.save();
      canvas.translate(s.offset.dx, s.offset.dy);
      canvas.drawShadow(path, s.color, s.blurRadius / 2, true);
      canvas.restore();
    }

    if (stroke.a > 0) {
      // Same gradient hairline as GlassCard, so a card and a chamfered hero
      // have the same edge behaviour rather than two subtly different ones.
      canvas.save();
      canvas.translate(0.5, 0.5);
      HairlineBorderPainter(
        radius: 0,
        hairline: stroke,
        hairlineStrong: stroke,
      ).paint(canvas, Size(size.width - 1, size.height - 1));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PesaSurfacePainter old) =>
      old.chamfered != chamfered ||
      old.radius != radius ||
      old.chamfer != chamfer ||
      old.stroke != stroke ||
      !identical(old.shadows, shadows);
}

/// Vertical rhythm helper for hero padding, so every chamfered surface in the
/// app insets its content by the same amount regardless of its cut size.
const EdgeInsets kHeroPadding = EdgeInsets.all(kSpacing20);
