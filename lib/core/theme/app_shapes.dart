import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Corner treatments available in the shape library.
///
/// The app's rule, borrowed from the racing-poster idiom: **rounded everywhere,
/// but never uniform.** A screen of identical rounded rectangles reads as
/// generic; a screen with one or two deliberate angles reads as designed. Use
/// [rounded] as the default and reach for [chamfer] on at most one surface per
/// screen — the hero, a primary action, or a badge.
enum AppCorner {
  /// Continuous curve, using the same iOS superellipse as `SquircleBorder`.
  rounded,

  /// A 45° poster cut. The corner is replaced by a straight diagonal.
  chamfer,

  /// Hard 90° corner. Reserve for the very smallest elements, e.g. a 2px
  /// track notch.
  square,
}

/// Builds a rounded-rectangle path with a per-corner treatment.
///
/// This is the single geometry entry point for the app's shape language. Every
/// non-trivial surface (cards, hero, pills, morphing buttons, banners) is a
/// call to this, so changing the corner math changes the whole app at once.
Path appShapePath({
  required Rect rect,
  double radius = 16,
  AppCorner topLeft = AppCorner.rounded,
  AppCorner topRight = AppCorner.rounded,
  AppCorner bottomRight = AppCorner.rounded,
  AppCorner bottomLeft = AppCorner.rounded,
  double chamfer = 0,
}) {
  final path = Path();
  if (rect.isEmpty) return path;

  final maxR = math.min(rect.width, rect.height) / 2;
  final r = math.min(radius, maxR);
  final c = math.min(chamfer, math.min(rect.width, rect.height) / 2);

  // A corner contributes either a curve of extent `r`, a diagonal of extent
  // `c`, or nothing at all. Whichever it is, it spans the same two edge
  // waypoints, so the path is always closed and never self-intersecting.
  double extent(AppCorner kind) => switch (kind) {
    AppCorner.rounded => r,
    AppCorner.chamfer => c,
    AppCorner.square => 0,
  };

  final tl = extent(topLeft);
  final tr = extent(topRight);
  final br = extent(bottomRight);
  final bl = extent(bottomLeft);

  final l = rect.left;
  final t = rect.top;
  final rr = rect.right;
  final b = rect.bottom;

  void lineTo(double x, double y) => path.lineTo(x, y);

  // Superellipse control offset, matching SquircleBorder so `rounded` here and
  // `SquircleBorder` at the same radius are visually identical.
  void curveTo(
    double fromX,
    double fromY,
    double toX,
    double toY,
    double cx,
    double cy,
  ) {
    final off = r * 0.44;
    // Two control points pulled toward the corner produce the continuous
    // iOS curve rather than a circular arc.
    final c1 = _lerpPoint(fromX, fromY, cx, cy, off / math.max(r, 0.0001));
    final c2 = _lerpPoint(toX, toY, cx, cy, off / math.max(r, 0.0001));
    path.cubicTo(c1.$1, c1.$2, c2.$1, c2.$2, toX, toY);
  }

  void corner(
    AppCorner kind,
    double cornerX,
    double cornerY,
    double entryX,
    double entryY,
    double exitX,
    double exitY,
  ) {
    switch (kind) {
      case AppCorner.square:
        break;
      case AppCorner.chamfer:
        lineTo(
          entryX + (cornerX - entryX) * _chamferRatio(c, r),
          entryY + (cornerY - entryY) * _chamferRatio(c, r),
        );
        lineTo(
          exitX + (cornerX - exitX) * _chamferRatio(c, r),
          exitY + (cornerY - exitY) * _chamferRatio(c, r),
        );
      case AppCorner.rounded:
        curveTo(entryX, entryY, exitX, exitY, cornerX, cornerY);
    }
  }

  path.moveTo(l + tl, t);
  lineTo(rr - tr, t);
  corner(topRight, rr, t, rr - tr, t, rr, t + tr);
  lineTo(rr, b - br);
  corner(bottomRight, rr, b, rr, b - br, rr - br, b);
  lineTo(l + bl, b);
  corner(bottomLeft, l, b, l + bl, b, l, b - bl);
  lineTo(l, t + tl);
  corner(topLeft, l, t, l, t + tl, l + tl, t);
  path.close();
  return path;
}

double _chamferRatio(double chamfer, double radius) {
  if (radius <= 0) return 1;
  // When the chamfer and the corner radius want the same edge length, take
  // the midpoint so a morph between the two states has no visible jump.
  return 0.5;
}

/// Arc-length-parameterised blend of two paths.
///
/// Both inputs are expected to be built clockwise from the same anchor, which
/// is true of every [appShapePath] result — that keeps the correspondence
/// stable and the morph free of visible flipping. 48 samples is more than
/// enough to render a morph indistinguishable from the source curves.
Path _lerpPaths(Path a, Path b, double t, {int samples = 48}) {
  final ma = a.computeMetrics().toList();
  final mb = b.computeMetrics().toList();
  if (ma.isEmpty || mb.isEmpty) return t < 0.5 ? a : b;
  final la = ma.first;
  final lb = mb.first;
  if (la.length == 0 || lb.length == 0) return t < 0.5 ? a : b;

  final out = Path();
  for (var i = 0; i <= samples; i++) {
    final f = i / samples;
    final ta = ma.first.getTangentForOffset(la.length * f);
    final tb = mb.first.getTangentForOffset(lb.length * f);
    if (ta == null || tb == null) continue;
    final x = ta.position.dx + (tb.position.dx - ta.position.dx) * t;
    final y = ta.position.dy + (tb.position.dy - ta.position.dy) * t;
    if (i == 0) {
      out.moveTo(x, y);
    } else {
      out.lineTo(x, y);
    }
  }
  out.close();
  return out;
}

(double, double) _lerpPoint(
  double x1,
  double y1,
  double x2,
  double y2,
  double t,
) {
  return (x1 + (x2 - x1) * t, y1 + (y2 - y1) * t);
}

/// A `ShapeBorder` whose outline is a morph between two paths.
///
/// This is the engine behind the app's signature press interaction: a surface
/// does not merely scale, it *changes shape* — a full-width pill contracts into
/// a squircle under the finger and springs back on release. `t` is driven
/// straight from a `SpringSimulation`, so the morph inherits the same physics
/// as the scale and never feels like a separate animation.
class MorphShapeBorder extends ShapeBorder {
  final Path pathA;
  final Path pathB;

  /// 0 → [pathA], 1 → [pathB].
  final double t;

  final Color? color;
  final BorderSide side;

  const MorphShapeBorder({
    required this.pathA,
    required this.pathB,
    this.t = 0,
    this.color,
    this.side = BorderSide.none,
  });

  /// A rounded-rect ⇄ chamfered-rect morph. The cheapest way to get the
  /// poster-diagonal press without hand-building two paths.
  factory MorphShapeBorder.chamfer({
    required Rect rect,
    required double radius,
    required double chamfer,
    required double t,
    BorderSide side = BorderSide.none,
    Color? color,
  }) {
    return MorphShapeBorder(
      pathA: appShapePath(rect: rect, radius: radius),
      pathB: appShapePath(
        rect: rect,
        radius: radius,
        topLeft: AppCorner.chamfer,
        bottomRight: AppCorner.chamfer,
        chamfer: chamfer,
      ),
      t: t,
      side: side,
      color: color,
    );
  }

  Path _lerped(Rect rect) {
    if (t <= 0) return pathA;
    if (t >= 1) return pathB;
    return _lerpPaths(pathA, pathB, t);
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _lerped(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _lerped(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final path = _lerped(rect);
    if (side.style != BorderStyle.none) {
      canvas.drawPath(path, side.toPaint());
    }
    if (color != null) {
      canvas.drawPath(path, Paint()..color = color!);
    }
  }

  @override
  ShapeBorder scale(double factor) => MorphShapeBorder(
    pathA: pathA,
    pathB: pathB,
    t: t,
    color: color,
    side: side.scale(factor),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MorphShapeBorder &&
          other.pathA == pathA &&
          other.pathB == pathB &&
          other.t == t &&
          other.color == color &&
          other.side == side;

  @override
  int get hashCode => Object.hash(pathA, pathB, t, color, side);
}

/// The app's poster cut: top-left and bottom-right corners are 45° chamfers,
/// the other two stay fully rounded.
///
/// Use on a hero or a primary action. Two of these on one screen and the
/// motif stops reading.
class ChicaneBorder extends ShapeBorder {
  final double borderRadius;
  final double chamfer;
  final BorderSide side;

  const ChicaneBorder({
    this.borderRadius = 16,
    this.chamfer = 14,
    this.side = BorderSide.none,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      pathFor(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => pathFor(rect);

  Path pathFor(Rect rect) => appShapePath(
    rect: rect,
    radius: borderRadius,
    topLeft: AppCorner.chamfer,
    bottomRight: AppCorner.chamfer,
    chamfer: chamfer,
  );

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style != BorderStyle.none) {
      canvas.drawPath(pathFor(rect), side.toPaint());
    }
  }

  @override
  ShapeBorder scale(double t) => ChicaneBorder(
    borderRadius: borderRadius * t,
    chamfer: chamfer * t,
    side: side.scale(t),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChicaneBorder &&
          other.borderRadius == borderRadius &&
          other.chamfer == chamfer &&
          other.side == side;

  @override
  int get hashCode => Object.hash(borderRadius, chamfer, side);
}

/// The boldest cut in the library: two 45° chamfers on opposite corners and
/// hard 90° corners on the other two — a racing number plate, not a rounded
/// rectangle with two nicks taken out of it.
///
/// [ChicaneBorder] keeps curves on its uncut corners, so a large card still
/// reads as a softened rectangle. This one does not: the silhouette is entirely
/// straight edges, which is what gives it the authority to carry a number big
/// enough to dominate a screen. Reserve it for the single hero surface of a
/// screen — using it on a list row would flatten the hierarchy it exists to
/// create.
class PosterBorder extends ShapeBorder {
  /// Extent of the two 45° cuts.
  final double chamfer;

  final BorderSide side;

  const PosterBorder({this.chamfer = 22, this.side = BorderSide.none});

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      pathFor(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => pathFor(rect);

  Path pathFor(Rect rect) => appShapePath(
    rect: rect,
    topLeft: AppCorner.chamfer,
    topRight: AppCorner.square,
    bottomRight: AppCorner.chamfer,
    bottomLeft: AppCorner.square,
    chamfer: chamfer,
  );

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style != BorderStyle.none) {
      canvas.drawPath(pathFor(rect), side.toPaint());
    }
  }

  @override
  ShapeBorder scale(double t) =>
      PosterBorder(chamfer: chamfer * t, side: side.scale(t));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PosterBorder && other.chamfer == chamfer && other.side == side;

  @override
  int get hashCode => Object.hash(chamfer, side);
}
