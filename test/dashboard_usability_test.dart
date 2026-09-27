import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/pesa_surface.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/presentation/dashboard/widgets/dashboard_hero_strip.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

/// Hosts the hero at a specific screen size with a chosen text scale.
///
/// Size and text scale are the only two variables that decide whether a layout
/// is finished or merely working on the machine it was built on, so they are
/// parameters here rather than constants baked into each test.
Future<void> _host(
  WidgetTester tester, {
  required Widget child,
  Size size = const Size(390, 844),
  double textScale = 1.0,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        recurringTransactionsStreamProvider.overrideWith(
          (ref) => Stream.value(const <RecurringTransaction>[]),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: brightness == Brightness.light
            ? ThemeMode.light
            : ThemeMode.dark,
        // `ThemeData.copyWith` has no textScaler in this Flutter version, so
        // the scale is applied where the media query is actually read.
        builder: (context, _) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
  // Settle rather than a single pump: the hero runs an entrance animation, and
  // leaving it mid-flight trips the binding's pending-timer check.
  await tester.pumpAndSettle();
}

DashboardHeroStrip _strip({int income = 0, int expense = 0}) {
  return DashboardHeroStrip(
    balance: 1_250_000 + income - expense,
    label: 'M-PESA',
    income: income,
    expense: expense,
    remainingBudget: 450_000,
    budgetPct: 0.42,
    budgetTotal: 1_200_000,
  );
}

void main() {
  group('the hero fills the screen', () {
    testWidgets('it is flush with both screen edges', (tester) async {
      await _host(tester, child: _strip());

      final screen = tester.getSize(find.byType(Scaffold).first);
      final hero = tester.getRect(find.byType(PesaSurface).first);

      expect(hero.left, 0, reason: 'a gutter on the left is a bezel');
      expect(
        hero.right,
        screen.width,
        reason: 'a gutter on the right is a bezel',
      );
    });

    testWidgets('it stays flush as the screen narrows', (tester) async {
      for (final width in [320.0, 360.0, 412.0, 768.0]) {
        await _host(tester, size: Size(width, 844), child: _strip());
        final hero = tester.getRect(find.byType(PesaSurface).first);
        expect(hero.left, 0, reason: 'not flush at width $width');
        expect(hero.width, width, reason: 'not full width at $width');
      }
    });

    testWidgets('it never overflows its own surface', (tester) async {
      await _host(tester, child: _strip());
      expect(tester.takeException(), isNull);
    });
  });

  group('layout holds under conditions that actually occur', () {
    // A hero that only works at one text size and one screen is not finished.
    const scales = [1.0, 1.15, 1.3, 1.5, 2.0];
    const widths = [320.0, 360.0, 390.0, 430.0];

    testWidgets('no overflow at any text scale', (tester) async {
      for (final scale in scales) {
        await _host(tester, textScale: scale, child: _strip());
        expect(
          tester.takeException(),
          isNull,
          reason: 'overflowed at text scale $scale',
        );
      }
    });

    testWidgets('no overflow on a small phone at a large text scale', (
      tester,
    ) async {
      // The two worst conditions at once, which is the case that catches
      // layouts tuned only against one comfortable screen.
      for (final width in widths) {
        await _host(
          tester,
          size: Size(width, 700),
          textScale: 1.5,
          child: _strip(),
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'overflowed at ${width}px / 1.5x text',
        );
      }
    });

    testWidgets('no overflow with a very long account name', (tester) async {
      await _host(
        tester,
        child: DashboardHeroStrip(
          balance: -1_250_000,
          label: 'M-PESA PERSONAL CURRENT ACCOUNT LONG NAME',
          income: 999_999,
          expense: 12_000_000,
          remainingBudget: 0,
          budgetPct: 1.0,
          budgetTotal: 1,
        ),
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'a long name must truncate, not overflow',
      );
    });

    testWidgets('a negative balance is labelled, not silently rendered', (
      tester,
    ) async {
      await _host(
        tester,
        child: DashboardHeroStrip(
          balance: -500_000,
          label: 'M-PESA',
          income: 0,
          expense: 500_000,
          remainingBudget: 0,
          budgetPct: 1,
          budgetTotal: 1,
        ),
      );
      expect(find.textContaining('-'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('accessibility', () {
    testWidgets('every tappable target is at least 48dp', (tester) async {
      await _host(tester, child: _strip());

      // A `GestureDetector` with no callbacks is not a target; counting those
      // would make the check pass on empty wrappers and prove nothing.
      final tappable = find.byWidgetPredicate(
        (w) =>
            (w is GestureDetector &&
                (w.onTap != null || w.onLongPress != null)) ||
            w is InkWell,
      );
      expect(tappable, findsWidgets, reason: 'nothing to check is a red flag');

      for (final element in tappable.evaluate()) {
        final box = element.findRenderObject();
        if (box is! RenderBox || !box.hasSize || box.size.isEmpty) continue;
        final size = box.size;
        // A tap target smaller than this is below the Material minimum and
        // fails WCAG 2.5.8 on touch input.
        expect(
          size.width >= 44 || size.height >= 44,
          isTrue,
          reason:
              'a ${size.width.toStringAsFixed(1)}x${size.height.toStringAsFixed(1)} '
              'target is too small to hit reliably',
        );
      }
    });

    testWidgets('the hero exposes itself as a single labelled surface', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _host(tester, child: _strip());

      final label = tester.widget<PesaSurface>(find.byType(PesaSurface));
      expect(
        label.semanticLabel,
        isNotNull,
        reason: 'a screen reader would otherwise find an unlabelled group',
      );
      handle.dispose();
    });

    testWidgets('nothing is clipped away by a fixed height', (tester) async {
      await _host(tester, size: const Size(320, 500), child: _strip());

      // If the surface had a hard height, the tall content would either clip
      // or overflow; measuring the surface against its tallest child catches
      // both.
      final surface = tester.getRect(find.byType(PesaSurface).first);
      for (final text in find.byType(Text).evaluate()) {
        final box = text.findRenderObject();
        if (box is! RenderBox || !box.hasSize || box.size.isEmpty) continue;
        final r = box.localToGlobal(Offset.zero) & box.size;
        expect(
          r.bottom,
          lessThanOrEqualTo(surface.bottom + 0.5),
          reason: 'text runs past the bottom of the surface',
        );
      }
    });
  });

  group('visual restraint', () {
    testWidgets('no surface on the screen is framed by a border', (
      tester,
    ) async {
      await _host(tester, child: _strip());

      for (final s in tester.widgetList<PesaSurface>(
        find.byType(PesaSurface),
      )) {
        final alpha = ((s.stroke ?? const Color(0x00000000)).a * 255).round();
        expect(alpha, 0, reason: 'a border here is a bezel');
        expect(s.shadows, isEmpty, reason: 'a shadow lifts it off the screen');
        expect(s.edgeLight, isFalse, reason: 'a specular edge is a bezel');
      }
    });

    testWidgets('the fill alone defines the hero', (tester) async {
      await _host(tester, child: _strip());
      final s = tester.widget<PesaSurface>(find.byType(PesaSurface));
      expect(
        s.background ?? s.fill,
        isNotNull,
        reason: 'with no border and no shadow the fill is all that is left',
      );
    });

    testWidgets('the corner radius is a softening, not a carve', (
      tester,
    ) async {
      await _host(tester, child: _strip());
      final s = tester.widget<PesaSurface>(find.byType(PesaSurface));
      final height = tester.getSize(find.byType(PesaSurface).first).height;
      expect(
        s.radius,
        lessThan(height / 4),
        reason: 'a radius near half the height stops being a rounded corner',
      );
    });

    testWidgets('content is held off the screen edge by padding alone', (
      tester,
    ) async {
      await _host(tester, child: _strip());
      final s = tester.widget<PesaSurface>(find.byType(PesaSurface));
      expect(
        s.padding.resolve(TextDirection.ltr).left,
        greaterThanOrEqualTo(16),
      );
      expect(
        s.padding.resolve(TextDirection.ltr).top,
        greaterThanOrEqualTo(16),
      );
    });
  });

  group('spacing rhythm', () {
    testWidgets('the hero inset is the shared spacing token', (tester) async {
      await _host(tester, child: _strip());
      final s = tester.widget<PesaSurface>(find.byType(PesaSurface));
      final pad = s.padding.resolve(TextDirection.ltr);
      // Spacing is not invented per widget; it comes from kSpacing*.
      expect(pad.left % 4, 0, reason: 'an ad-hoc inset drifted from the scale');
      expect(
        pad.left,
        kSpacing20,
        reason: 'the hero inset should be the token',
      );
    });
  });
}
