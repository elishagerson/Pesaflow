import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_shapes.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/pesa_surface.dart';

List<Offset> _sample(Path path, {double step = 0.25}) {
  final out = <Offset>[];
  for (final m in path.computeMetrics()) {
    for (var d = 0.0; d < m.length; d += step) {
      final t = m.getTangentForOffset(d);
      if (t != null) out.add(t.position);
    }
  }
  return out;
}

double _perimeter(Path path) =>
    path.computeMetrics().fold<double>(0, (s, m) => s + m.length);

/// Is there a sampled point within [tolerance] of [p]?
bool _hits(List<Offset> pts, Offset p, [double tolerance = 0.3]) => pts.any(
  (q) => (q.dx - p.dx).abs() < tolerance && (q.dy - p.dy).abs() < tolerance,
);

void main() {
  group('appShapePath chamfer geometry', () {
    // Regression. `AppCorner.chamfer` used to emit two points pulled halfway
    // toward the corner, while the surrounding `lineTo` calls already sat at
    // the full chamfer extent. The diagonal therefore landed at half the
    // requested size and left a doubled edge segment where the path overlapped
    // itself — a malformed notch, not a cut. At `radius: 0` both points landed
    // exactly on the corner and the chamfer did nothing at all.
    //
    // Both failures were invisible to a widget test and obvious on screen, so
    // the cut is pinned by perimeter here instead.

    test('the cut removes the corner it claims to cut', () {
      final pts = _sample(
        appShapePath(
          rect: const Rect.fromLTWH(0, 0, 300, 200),
          topLeft: AppCorner.chamfer,
          chamfer: 28,
        ),
      );
      // The 45° diagonal replaces the corner, so the vertex is off the path.
      expect(_hits(pts, Offset.zero), isFalse);
    });

    test('the cut spans the full chamfer extent on both edges', () {
      const c = 28.0;
      final pts = _sample(
        appShapePath(
          rect: const Rect.fromLTWH(0, 0, 300, 200),
          topLeft: AppCorner.chamfer,
          chamfer: c,
        ),
        step: 0.1,
      );
      // The two waypoints the cut joins, one full chamfer in from each edge.
      expect(_hits(pts, const Offset(c, 0)), isTrue, reason: 'top waypoint');
      expect(_hits(pts, const Offset(0, c)), isTrue, reason: 'left waypoint');
      // And nothing of the removed triangle survives.
      final inside = pts.where(
        (p) => p.dx < c && p.dy < c && p.dx + p.dy < c - 0.2,
      );
      expect(inside, isEmpty, reason: 'the cut triangle is still filled');
    });

    test('perimeter matches the analytic length of a cut rectangle', () {
      const w = 300.0, h = 200.0, c = 28.0;
      final path = appShapePath(
        rect: const Rect.fromLTWH(0, 0, w, h),
        topLeft: AppCorner.chamfer,
        topRight: AppCorner.square,
        bottomRight: AppCorner.chamfer,
        bottomLeft: AppCorner.square,
        chamfer: c,
      );
      // Each cut trims `c` off both edges it touches and adds a c·√2 diagonal.
      final expected =
          (w - c) + (h - c) + (w - c) + (h - c) + 2 * (c * math.sqrt2);
      expect(_perimeter(path), closeTo(expected, 0.01));
    });

    test('the cut is independent of the corner radius', () {
      // Other corners are square, so they ignore `radius` entirely and any
      // difference in length can only come from the cut itself.
      final lengths = [0.0, 4.0, 16.0, 40.0, 99.0]
          .map(
            (r) => _perimeter(
              appShapePath(
                rect: const Rect.fromLTWH(0, 0, 300, 200),
                radius: r,
                topLeft: AppCorner.chamfer,
                topRight: AppCorner.square,
                bottomRight: AppCorner.chamfer,
                bottomLeft: AppCorner.square,
                chamfer: 28,
              ),
            ),
          )
          .toSet();
      expect(lengths, hasLength(1), reason: 'the cut moved with the radius');
    });

    test('a square corner is a hard 90°', () {
      final pts = _sample(
        appShapePath(
          rect: const Rect.fromLTWH(0, 0, 300, 200),
          topRight: AppCorner.square,
        ),
      );
      expect(_hits(pts, const Offset(300, 0)), isTrue);
    });

    test('a rounded corner curves and never reaches its vertex', () {
      const r = 24.0;
      final pts = _sample(
        appShapePath(rect: const Rect.fromLTWH(0, 0, 300, 200), radius: r),
        step: 0.1,
      );
      expect(_hits(pts, Offset.zero), isFalse, reason: 'vertex on the curve');
      // The quarter has to be symmetric about the 45° diagonal, which is the
      // property a broken control point would destroy.
      final onDiagonal = pts.where(
        (p) =>
            p.dx > 0.5 &&
            p.dy > 0.5 &&
            p.dx < r &&
            p.dy < r &&
            (p.dx - p.dy).abs() < 0.4,
      );
      expect(onDiagonal, isNotEmpty, reason: 'corner is not symmetric');
    });

    test('a cut is a straight 45° line, not a curve', () {
      const c = 30.0;
      final pts = _sample(
        appShapePath(
          rect: const Rect.fromLTWH(0, 0, 300, 200),
          topLeft: AppCorner.chamfer,
          chamfer: c,
        ),
        step: 0.05,
      );
      // Every point on the cut satisfies x + y == c exactly.
      final onCut = pts.where((p) => p.dx <= c && p.dy <= c).toList();
      expect(onCut.length, greaterThan(100));
      for (final p in onCut) {
        expect(p.dx + p.dy, closeTo(c, 0.05), reason: 'cut is not straight');
      }
    });
  });

  group('PosterBorder', () {
    // The hero silhouette: a left-pointing chevron. Both left corners are cut
    // and both right corners are square, so the diagonal reads as one continuous
    // gesture down each side. Cutting opposite corners instead left a bare 90°
    // spike at the other end of the same vertical edge, which reads as an
    // accident rather than a decision.
    test('cuts both left corners and squares both right corners', () {
      final pts = _sample(
        const PosterBorder(
          chamfer: 24,
        ).pathFor(const Rect.fromLTWH(0, 0, 300, 200)),
      );
      expect(
        _hits(pts, Offset.zero),
        isFalse,
        reason: 'top-left should be cut',
      );
      expect(_hits(pts, const Offset(0, 200)), isFalse, reason: 'bottom-left');
      expect(
        _hits(pts, const Offset(300, 0)),
        isTrue,
        reason: 'top-right square',
      );
      expect(
        _hits(pts, const Offset(300, 200)),
        isTrue,
        reason: 'bottom-right',
      );
    });

    test('perimeter matches a left-chevron plate', () {
      const w = 300.0, h = 200.0, c = 24.0;
      final path = const PosterBorder(
        chamfer: c,
      ).pathFor(const Rect.fromLTWH(0, 0, w, h));
      // Top and bottom lose `c` each; the left edge loses `2c` because both of
      // its ends are diagonals; the right edge is untouched.
      final expected =
          (w - c) + h + (w - c) + (h - 2 * c) + 2 * (c * math.sqrt2);
      expect(_perimeter(path), closeTo(expected, 0.01));
    });

    test('the left edge is shorter than the right by exactly two cuts', () {
      const w = 300.0, h = 200.0, c = 24.0;
      final pts = _sample(
        const PosterBorder(chamfer: c).pathFor(const Rect.fromLTWH(0, 0, w, h)),
        step: 0.05,
      );
      // The remaining vertical run of the left edge. The sample list wraps
      // around the path, so dy is not monotonic — take the extremes.
      final leftEdge = pts.where((p) => p.dx < 0.15).toList();
      expect(leftEdge, isNotEmpty);
      final top = leftEdge.map((p) => p.dy).reduce(math.min);
      final bottom = leftEdge.map((p) => p.dy).reduce(math.max);
      expect(bottom - top, closeTo(h - 2 * c, 0.6));
    });

    test('scales without collapsing', () {
      final scaled = const PosterBorder(chamfer: 20).scale(0.5) as PosterBorder;
      expect(scaled.chamfer, 10);
    });
  });

  group('ChicaneBorder', () {
    test('cuts opposite corners and leaves the other two rounded', () {
      final pts = _sample(
        const ChicaneBorder(
          borderRadius: 16,
          chamfer: 24,
        ).pathFor(const Rect.fromLTWH(0, 0, 300, 200)),
      );
      expect(_hits(pts, Offset.zero), isFalse, reason: 'top-left cut');
      expect(
        _hits(pts, const Offset(300, 200)),
        isFalse,
        reason: 'bottom-right',
      );
      // The rounded corners still never reach their vertex.
      expect(_hits(pts, const Offset(300, 0)), isFalse);
      expect(_hits(pts, const Offset(0, 200)), isFalse);
    });
  });

  group('heroPaddingFor', () {
    // A uniform inset is not enough: the cut removes the triangle outside the
    // diagonal, so a flat inset can still leave content's corner under the cut.
    test('insets the cut sides by the chamfer plus the rhythm gap', () {
      final pad = heroPaddingFor(chamfer: 24);
      expect(pad.left, 24 + kSpacing20);
      expect(pad.top, 24 + kSpacing20);
      // The square sides keep the normal gap.
      expect(pad.right, kSpacing20);
      expect(pad.bottom, kSpacing20);
    });

    test('content clears the diagonal on both cut corners', () {
      const c = 24.0;
      final pad = heroPaddingFor(chamfer: c);
      // The cut on the left edge is the segment from (c, 0) to (0, c).
      // Content's top-left corner must sit outside that triangle.
      expect(
        pad.left + pad.top,
        greaterThan(c),
        reason: 'content corner would sit under the cut',
      );
    });
  });

  group('MorphShapeBorder', () {
    test('a full pill ⇄ chamfer morph stays a simple path at every t', () {
      const rect = Rect.fromLTWH(0, 0, 300, 120);
      for (var i = 0; i <= 10; i++) {
        final t = i / 10;
        final border = MorphShapeBorder.chamfer(
          rect: rect,
          radius: 60,
          chamfer: 24,
          t: t,
        );
        final path = border.getOuterPath(rect);
        expect(
          _perimeter(path),
          greaterThan(0),
          reason: 'degenerate path at t=$t',
        );
        // Never escapes the rectangle it was built for.
        final bounds = path.getBounds();
        expect(bounds.width, lessThanOrEqualTo(rect.width + 0.5));
        expect(bounds.height, lessThanOrEqualTo(rect.height + 0.5));
        expect(bounds.left, greaterThanOrEqualTo(rect.left - 0.5));
        expect(bounds.top, greaterThanOrEqualTo(rect.top - 0.5));
      }
    });
  });
}
