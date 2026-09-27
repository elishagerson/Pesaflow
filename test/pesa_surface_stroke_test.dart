import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/presentation/common/widgets/pesa_surface.dart';

/// The rendered pixels of [key], as raw RGBA rows.
class _Pixels {
  _Pixels(this.bytes, this.width, this.height);

  final Uint8List bytes;
  final int width;
  final int height;

  int alpha(int x, int y) => bytes[(y * width + x) * 4 + 3];
}

/// Renders a cut surface with everything that could tint an edge turned off, so
/// the only thing that can make a pixel non-transparent is the fill or stroke.
///
/// [PesaSurface] normally paints a translucent hairline and a radial glow; both
/// would make a pixel assertion pass or fail for reasons unrelated to the
/// silhouette, which is the opposite of what these tests are for.
Future<_Pixels> _renderPoster(
  WidgetTester tester, {
  required GlobalKey key,
  required Size size,
  double chamfer = 24,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        backgroundColor: const Color(0xFF00CC00),
        body: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: RepaintBoundary(
              key: key,
              child: PesaSurface.chamferSurface(
                chamfer: chamfer,
                fill: const Color(0xFF000000),
                stroke: const Color(0xFF000000),
                glow: 0,
                shadows: const [],
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // A fixed pump, not pumpAndSettle: the surface animates continuously, so
  // settling would never complete.
  await tester.pump(const Duration(milliseconds: 32));

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final px = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return _Pixels(data!.buffer.asUint8List(), image.width, image.height);
  });
  return px!;
}

/// The 1px stroke straddles the silhouette, so the pixel exactly on a cut is
/// partially covered rather than fully painted or fully bare. A missing stroke
/// and a stroke of zero width both read as bare, so the two are distinguished
/// only by the neighbouring interior.
Matcher _onBoundary(String reason) => predicate<int>((a) => a > 0, reason);

void main() {
  // A cut surface's fill, clip and border must all agree on one silhouette.
  // Before `strokePath` the border was an RRect with radius 0, so it traced a
  // plain rectangle: the diagonals were left unstroked and the square corners
  // bled past the cut into empty space. No widget test caught it because every
  // paint call was valid — only the pixels were wrong.
  testWidgets('the border follows the cut, not the bounding rectangle', (
    tester,
  ) async {
    const size = Size(200, 120);
    const c = 24.0;
    final px = await _renderPoster(
      tester,
      key: GlobalKey(),
      size: size,
      chamfer: c,
    );

    // The top cut is the line x + y == c, so (c/2, c/2) is on it. The stroke
    // has to be there: with a rectangular border this pixel is bare.
    expect(
      px.alpha((c / 2).round(), (c / 2).round()),
      _onBoundary(
        'the diagonal is unstroked — the border is still a rectangle',
      ),
    );

    // Well inside the corner the shape removes, nothing may be painted: no fill
    // and no stroke protruding past the cut.
    expect(px.alpha(2, 2), 0, reason: 'a corner is bleeding past the cut');
    expect(px.alpha(4, 6), 0, reason: 'a corner is bleeding past the cut');

    // The two pixels that pin the border to the silhouette. A rectangular
    // border runs along y = 0 and x = 0, so it paints both of these; the
    // silhouette has removed them. This is the assertion that distinguishes a
    // border which follows the cut from one that ignores it.
    expect(
      px.alpha(12, 0),
      0,
      reason: 'a rectangular border is bleeding across the top cut',
    );
    expect(
      px.alpha(0, 12),
      0,
      reason: 'a rectangular border is bleeding across the left cut',
    );

    // And the interior is still filled, so a bare boundary is a stroke and not
    // simply an empty surface.
    expect(px.alpha(100, 60), 255, reason: 'the fill is missing');
  });

  testWidgets('the lower cut is stroked as clearly as the upper one', (
    tester,
  ) async {
    const size = Size(200, 120);
    const c = 24.0;
    final px = await _renderPoster(
      tester,
      key: GlobalKey(),
      size: size,
      chamfer: c,
    );

    // Lower cut midpoint: (c/2, height - c/2).
    final x = (c / 2).round();
    final y = (size.height - c / 2).round();
    expect(px.alpha(x, y), _onBoundary('the lower cut is unstroked'));
    expect(px.alpha(2, size.height.round() - 3), 0, reason: 'corner bleeds');
  });

  testWidgets('both cuts are stroked, not just the first one', (tester) async {
    const size = Size(200, 120);
    const c = 24.0;
    final px = await _renderPoster(
      tester,
      key: GlobalKey(),
      size: size,
      chamfer: c,
    );

    // This surface cuts opposite corners, so the lower cut is the mirror of the
    // upper one: from (w - c, h) to (w, h - c). Its midpoint sits on
    // x + y == w + h - c; the painter insets the outline by half a pixel, so
    // sample the pixel *centre* against that line rather than guessing.
    final line = size.width + size.height - c;
    var x = 0;
    for (var i = 0; i <= 100; i++) {
      final probe = (line - i - 0.5).floor();
      if (px.alpha(probe, i) > 0) {
        x = probe;
        break;
      }
    }
    expect(
      px.alpha(x, line.round() - x - 1),
      _onBoundary('the lower cut is unstroked'),
    );
    expect(
      px.alpha(size.width.round() - 2, size.height.round() - 3),
      0,
      reason: 'a corner is bleeding past the lower cut',
    );
  });

  testWidgets('the uncut corners stay curved, not hard', (tester) async {
    const size = Size(200, 120);
    final px = await _renderPoster(tester, key: GlobalKey(), size: size);

    // The two corners that are *not* cut keep the shared card radius, so their
    // vertex is legitimately empty — a surface that squared them off would be
    // a different shape, and the test would not notice.
    expect(px.alpha(198, 1), 0, reason: 'the rounded corner is squared off');
    expect(px.alpha(198, 118), 0, reason: 'the rounded corner is squared off');
    // ...but the curve still encloses the corner, so the interior is filled.
    expect(
      px.alpha(190, 8),
      255,
      reason: 'the rounded corner cut into the surface',
    );
  });

  testWidgets('a larger chamfer moves the stroke with it', (tester) async {
    const size = Size(200, 120);
    final px = await _renderPoster(
      tester,
      key: GlobalKey(),
      size: size,
      chamfer: 40,
    );
    // (12, 12) was the midpoint of the chamfer-24 cut, so it is now well
    // inside the removed corner.
    expect(px.alpha(12, 12), 0, reason: 'the cut did not grow');
    // The new midpoint is on the new cut.
    expect(px.alpha(20, 20), _onBoundary('the cut is unstroked'));
  });
}
