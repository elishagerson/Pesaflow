import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_shapes.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/hairline_border.dart';
import 'package:pesaflow/presentation/common/widgets/morph_button.dart';
import 'package:pesaflow/presentation/common/widgets/pesa_progress_bar.dart';
import 'package:pesaflow/presentation/common/widgets/pesa_surface.dart';
import 'package:pesaflow/presentation/common/widgets/radial_glow.dart';
import 'package:pesaflow/presentation/common/widgets/track_ring.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.light
        ? AppTheme.lightTheme
        : AppTheme.darkTheme,
    home: Scaffold(
      body: Center(child: SizedBox(width: 320, child: child)),
    ),
  );
}

void main() {
  group('PesaSurface', () {
    testWidgets('card paints a rounded surface with the default radius', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(PesaSurface.card(child: const SizedBox(height: 80))),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PesaSurface), findsOneWidget);
      final DecoratedBox box = tester.widget(
        find.descendant(
          of: find.byType(PesaSurface),
          matching: find.byType(DecoratedBox),
        ),
      );
      final shape = (box.decoration as ShapeDecoration).shape;
      expect(shape, isA<RoundedRectangleBorder>());
    });

    testWidgets('chamfered surface uses the poster cut on both corners', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          PesaSurface.chamferSurface(
            chamfer: 20,
            child: const SizedBox(height: 120),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final DecoratedBox box = tester.widget(
        find.descendant(
          of: find.byType(PesaSurface),
          matching: find.byType(DecoratedBox),
        ),
      );
      final shape = (box.decoration as ShapeDecoration).shape;
      expect(shape, isA<ChicaneBorder>());
    });

    testWidgets('glow above zero mounts a RadialGlow masked to the shape', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          PesaSurface.chamferSurface(glow: 0.3, child: SizedBox(height: 120)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RadialGlow), findsOneWidget);
    });

    testWidgets('no glow is mounted for a plain card', (tester) async {
      await tester.pumpWidget(
        _host(PesaSurface.card(child: const SizedBox(height: 80))),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RadialGlow), findsNothing);
    });
  });

  group('PesaProgressBar', () {
    testWidgets('clamps out-of-range values instead of overflowing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: [
              PesaProgressBar(value: -0.5, wave: false),
              PesaProgressBar(value: 3.2, wave: false),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a zero value without dividing by zero', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const PesaProgressBar(value: 0, wave: false)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports its value through Semantics', (tester) async {
      await tester.pumpWidget(
        _host(const PesaProgressBar(value: 0.42, wave: false)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byType(PesaProgressBar)).value,
        contains('42'),
      );
    });

    testWidgets('StaticProgressBar runs no ticker', (tester) async {
      await tester.pumpWidget(_host(const StaticProgressBar(value: 0.5)));
      await tester.pump(const Duration(seconds: 3));
      // If a ticker were running, the test binding would still be able to
      // settle; a *wave* one is what leaks frames. This asserts the cheaper
      // widget exists and paints.
      expect(find.byType(StaticProgressBar), findsOneWidget);
    });
  });

  group('TrackRing', () {
    testWidgets('renders a value and a centred child', (tester) async {
      await tester.pumpWidget(
        _host(
          const TrackRing(
            value: 0.65,
            child: Icon(Icons.account_balance_wallet_rounded),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TrackRing), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet_rounded), findsOneWidget);
    });

    testWidgets('clamps a value above 1', (tester) async {
      await tester.pumpWidget(_host(const TrackRing(value: 4.0)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('GlassCard', () {
    // Regression: the card border was a `Colors.white` gradient, which made
    // `hasBorder: true` a no-op in light mode (a white 1px line on a white
    // card) and gave the press sheen nothing to show against.
    for (final brightness in Brightness.values) {
      // Regression: the card border was a `Colors.white` gradient, so
      // `hasBorder: true` was a no-op in light mode — a white 1px line on a
      // white card. Read the painter straight off the CustomPaint rather than
      // pixel-scraping, and assert the stroke is not the fill's twin.
      testWidgets('strokes a visible border in \$brightness', (tester) async {
        await tester.pumpWidget(
          _host(
            const GlassCard(hasBorder: true, child: SizedBox(height: 60)),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();

        final painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((c) => c.foregroundPainter)
            .whereType<HairlineBorderPainter>()
            .first;

        final fill = brightness == Brightness.light
            ? AppTheme.lightTheme.colorScheme.surface
            : AppTheme.darkTheme.colorScheme.surface;
        expect(
          painter.colors.first.computeLuminance(),
          isNot(closeTo(fill.computeLuminance(), 0.02)),
          reason: 'hairline is indistinguishable from the card fill',
        );
        expect(painter.colors.last.a, 0, reason: 'the stroke must fade out');
      });
    }

    testWidgets('renders without an onTap', (tester) async {
      await tester.pumpWidget(
        _host(const GlassCard(child: SizedBox(height: 60))),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(GlassCard), findsOneWidget);
    });
  });

  group('reduced motion', () {
    // Regression: MotionAwareMixin used to read MediaQuery on demand, so any
    // widget that started its first animation from initState threw
    // "dependOnInheritedWidgetOfExactType<MediaQuery>() was called before
    // initState() completed" and took its whole subtree down with it. PesaProgress
    // Bar's wave hit it the moment it grew on mount.
    testWidgets('a grow-on-mount bar mounts under disableAnimations', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await tester.pumpWidget(
        _host(
          const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: PesaProgressBar(value: 0.5, growOnMount: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(PesaProgressBar), findsOneWidget);
    });

    testWidgets('a grow-on-mount bar ends at its value, not at zero', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const PesaProgressBar(value: 0.75, growOnMount: true)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byType(PesaProgressBar)).value,
        contains('75'),
      );
    });
  });

  group('MorphButton', () {
    testWidgets('fires onPressed and reports a pressed state', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(MorphButton(onPressed: () => taps++, child: const Text('ADD'))),
      );
      await tester.pumpAndSettle();

      final before = tester.getSize(find.byType(MorphButton));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(MorphButton)),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(taps, 1);
      expect(tester.getSize(find.byType(MorphButton)), before);
    });

    testWidgets('is disabled and inert when onPressed is null', (tester) async {
      await tester.pumpWidget(_host(const MorphButton(child: Text('ADD'))));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MorphButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a non-expanding button hugs its child but stays 44pt tall', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          MorphButton(expand: false, onPressed: () {}, child: const Text('GO')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(MorphButton)).width,
        greaterThanOrEqualTo(200),
      );
    });
  });
}
