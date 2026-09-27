import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_shapes.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/pesa_surface.dart';

/// The rendered pixels of [key], as raw RGBA rows.
class _Pixels {
  _Pixels(this.bytes, this.width, this.height);

  final Uint8List bytes;
  final int width;
  final int height;

  int alpha(int x, int y) => bytes[(y * width + x) * 4 + 3];
}

Future<_Pixels> _capture(WidgetTester tester, GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return _Pixels(data!.buffer.asUint8List(), image.width, image.height);
}

void main() {
  // A cut surface whose fill, clip and border must all agree on one silhouette.
  // Before `strokePath` the border was an RRect with radius 0, so it traced a
  // plain rectangle: the diagonals were unstroked and the square corners bled
  // past the cut. Nothing in a widget test caught it because the paint calls
  // were all valid — only the pixels were wrong.
  testWidgets('the border follows the cut instead of the bounding rectangle', (
    tester,
  ) async {
    const size = Size(200, 120);
    const c = 24.0;
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          // Opaque backdrop, so "nothing painted" is unambiguous.
          backgroundColor: const Color(0xFF00FF00),
          body: Center(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: RepaintBoundary(
                key: key,
                child: PesaSurface.posterSurface(
                  chamfer: c,
                  fill: const Color(0xFF000000),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final px = await _capture(tester, key);
    final midX = (size.width / 2).round();

    // The cut runs from (c, 0) to (0, c). Its midpoint is at c/2 on both axes
    // — on the boundary itself, so it must carry the stroke.
    final onCut = (c / 2).round();
    expect(
      px.alpha(onCut, onCut),
      greaterThan(200),
      reason: 'the diagonal is unstroked — the border is still a rectangle',
    );

    // Just outside the cut, in the corner the shape removes, nothing may be
    // painted: no fill and no protruding stroke.
    expect(
      px.alpha(2, 2),
      lessThan(40),
      reason: 'a square corner is bleeding past the cut',
    );

    // And the interior is still filled.
    expect(px.alpha(midX, 60), greaterThan(200), reason: 'fill is missing');
  });

  testWidgets('a square right corner keeps its border', (tester) async {
    const size = Size(200, 120);
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF00FF00),
          body: Center(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: RepaintBoundary(
                key: key,
                child: PesaSurface.posterSurface(
                  fill: const Color(0xFF000000),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final px = await _capture(tester, key);
    // Top-right is deliberately square, so its vertex is a real corner.
    expect(px.alpha(198, 1), greaterThan(120), reason: 'corner lost');
  });

  test('the painter and the clip resolve the same outline', () {
    const rect = Rect.fromLTWH(0, 0, 200, 120);
    // The clip, the glow mask and the stroke all read `_outline`; if any of
    // them resolved a different border the surface would tear along the edge.
    final clip = const PosterBorder(chamfer: 24).getOuterPath(rect);
    final stroke = const PosterBorder(chamfer: 24).getOuterPath(rect);
    expect(
      clip.getBounds(),
      stroke.getBounds(),
      reason: 'clip and stroke disagree on the silhouette',
    );
  });
}
