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
///  * [PesaSurface.bleed] — borderless and shadowless, for a surface that
///    should read as part of the screen rather than an object on it.
class PesaSurface extends StatelessWidget {
  final Widget child;
  final Color? fill;
  final Color? stroke;

  /// Optional subtle gradient over [fill]. `ShapeDecoration` has no gradient
  /// slot, so it is applied as a second layer clipped to this same path — the
  /// gradient can never escape the outline the way an unclipped `BoxDecoration`
  /// would. Keep it to two or three near-surface stops; this is depth, not
  /// colour.
  final Gradient? background;

  /// Corner radius at rest. Ignored for chamfered surfaces, which derive theirs.
  final double radius;

  /// Extent of the 45° cut on the chamfered variant.
  final double chamfer;

  final bool chamfered;

  /// Brand glow behind the fill, masked to this surface's own shape. `0`
  /// disables it. Keep it under `0.5` — above that it stops reading as light
  /// and starts reading as a coloured card.
  final double glow;

  final List<BoxShadow> shadows;
  final EdgeInsetsGeometry padding;

  /// Draws a 1px specular line just inside the top edge and the top chamfer.
  ///
  /// A hairline alone defines the *outside* of a surface; this defines its
  /// thickness. It is most of the difference between a flat rectangle with a
  /// border and an object with an edge.
  final bool edgeLight;

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
    this.background,
    this.radius = AppTheme.radiusCard,
    this.chamfer = 18,
    this.chamfered = false,
    this.glow = 0,
    this.shadows = const [],
    this.padding = EdgeInsets.zero,
    this.edgeLight = false,
    this.clipContent = true,
    this.onTap,
    this.semanticLabel,
  });

  /// A borderless, shadowless surface that spans its parent edge to edge.
  ///
  /// A hairline plus an elevation shadow is what makes a card read as an object
  /// *placed on* the screen. For something meant to read as part of the screen
  /// itself — a hero the user is inside rather than looking at — both have to
  /// go, and the fill has to carry the shape on its own. A subtle gradient and
  /// slightly rounded corners are what define it instead.
  ///
  /// Pair with a parent that does not add horizontal padding, so "bleed" is
  /// actually true; a bleed inside a gutter is just a card with extra steps.
  factory PesaSurface.bleed({
    Key? key,
    required Widget child,
    Color? fill,
    Gradient? background,
    double radius = AppTheme.radiusHero,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    bool clipContent = true,
    VoidCallback? onTap,
    String? semanticLabel,
  }) {
    return PesaSurface(
      key: key,
      // No stroke and no shadow: those are the bezel.
      stroke: const Color(0x00000000),
      shadows: const [],
      glow: 0,
      edgeLight: false,
      fill: fill,
      background: background,
      radius: radius,
      padding: padding,
      clipContent: clipContent,
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: child,
    );
  }

  /// A card with two opposite corners cut at 45°. **One per screen region** —
  /// the motif stops reading the moment it is everywhere, and the brief is
  /// moving away from framed surfaces, so prefer [PesaSurface.bleed].
  factory PesaSurface.chamferSurface({
    Key? key,
    required Widget child,
    Color? fill,
    Color? stroke,
    Gradient? background,
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
      background: background,
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

  /// A standard card: rounded, hairline, soft elevation, no glow.
  factory PesaSurface.card({
    Key? key,
    required Widget child,
    Color? fill,
    Color? stroke,
    Gradient? background,
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
      background: background,
      radius: radius,
      shadows: shadows,
      padding: padding,
      clipContent: clipContent,
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: child,
    );
  }

  /// The one outline every layer agrees on: the fill, the clip, the glow mask
  /// and the painter all call this. Anything that re-derives the shape
  /// separately is how a shadow ends up rounding a corner the fill cut.
  ShapeBorder get _outline => chamfered
      ? ChicaneBorder(borderRadius: AppTheme.radiusCard, chamfer: chamfer)
      : RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final theme = Theme.of(context);
    // Specular line: a light edge on a dark surface, an ink edge on a light one.
    // Hardcoding white here would be invisible in light mode, the same bug the
    // GlassCard hairline had.
    final edgeColor = theme.colorScheme.onSurface.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.13 : 0.10,
    );
    final body = DecoratedBox(
      decoration: ShapeDecoration(
        shape: _outline,
        color: fill ?? appColors.cardBackground,
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (background != null)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: background),
                ),
              ),
            ),
          if (glow > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: RadialGlow(size: 260, intensity: glow, shape: _outline),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );

    final content = CustomPaint(
      painter: _PesaSurfacePainter(
        outline: _outline,
        edgeLight: edgeLight,
        edgeLightColor: edgeColor,
        stroke: stroke ?? appColors.hairline,
        shadows: shadows,
      ),
      child: clipContent
          ? ClipPath(clipper: _ShapeOutlineClipper(_outline), child: body)
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

/// Clips to whatever outline the surface resolved, so there is no second
/// implementation of the shape to drift out of sync.
class _ShapeOutlineClipper extends CustomClipper<Path> {
  final ShapeBorder outline;

  const _ShapeOutlineClipper(this.outline);

  @override
  Path getClip(Size size) => outline.getOuterPath(Offset.zero & size);

  @override
  bool shouldReclip(covariant _ShapeOutlineClipper old) =>
      old.outline != outline;
}

class _PesaSurfacePainter extends CustomPainter {
  final ShapeBorder outline;
  final Color stroke;
  final List<BoxShadow> shadows;
  final bool edgeLight;
  final Color edgeLightColor;

  const _PesaSurfacePainter({
    required this.outline,
    required this.stroke,
    required this.shadows,
    required this.edgeLight,
    required this.edgeLightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = outline.getOuterPath(rect);

    // Painted first so the fill (this CustomPaint's child) covers the shadow's
    // solid core and only the soft halo survives.
    for (final s in shadows) {
      canvas.save();
      canvas.translate(s.offset.dx, s.offset.dy);
      canvas.drawShadow(path, s.color, s.blurRadius / 2, true);
      canvas.restore();
    }

    if (stroke.a > 0) {
      // Same gradient hairline as GlassCard, so a card and a hero have the same
      // edge behaviour rather than two subtly different ones — but stroked
      // along this surface's own outline, not a rectangle, so the border
      // follows the cut instead of stopping at it.
      canvas.save();
      canvas.translate(0.5, 0.5);
      final inset = Rect.fromLTWH(0, 0, size.width - 1, size.height - 1);
      HairlineBorderPainter(
        hairline: stroke,
        hairlineStrong: stroke,
        // Uniform, not faded: this surface's edge is a deliberate silhouette,
        // so it has to stay defined all the way round — including the cuts.
        fade: false,
      ).strokePath(canvas, outline.getOuterPath(inset), inset);
      canvas.restore();
    }

    if (edgeLight) _paintEdgeLight(canvas, size, path);
  }

  /// A specular line inset from the top edge, clipped to the surface's own
  /// outline so it follows the chamfer instead of running straight across it.
  void _paintEdgeLight(Canvas canvas, Size size, Path path) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipPath(path);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.topRight,
        colors: [edgeLightColor, edgeLightColor.withValues(alpha: 0)],
      ).createShader(Offset.zero & size);
    // Inset by half a pixel so the line lands inside the outline rather than
    // straddling it.
    canvas.drawLine(
      const Offset(0.5, 0.7),
      Offset(size.width - 0.5, 0.7),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PesaSurfacePainter old) =>
      old.outline != outline ||
      old.stroke != stroke ||
      old.edgeLight != edgeLight ||
      old.edgeLightColor != edgeLightColor ||
      !identical(old.shadows, shadows);
}

/// Vertical rhythm helper for hero padding, so every cut surface in the app
/// insets its content by the same amount regardless of its cut size.
const EdgeInsets kHeroPadding = EdgeInsets.all(kSpacing20);

/// Padding for a surface whose content must stay clear of a 45° cut.
///
/// A uniform inset is not enough. The cut removes the triangle outside the
/// diagonal, so content that respects only a flat inset still ends up with its
/// top-left corner sitting a few pixels under the cut — which reads as the
/// content being clipped rather than the shape being deliberate. Insetting the
/// cut sides by the chamfer itself, plus the normal rhythm gap, guarantees
/// clearance instead of luck.
EdgeInsets heroPaddingFor({required double chamfer, double gap = kSpacing20}) {
  final inset = chamfer + gap;
  return EdgeInsets.fromLTRB(inset, inset, gap, gap);
}
