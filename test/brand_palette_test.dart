import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';

/// Relative luminance per WCAG 2.1.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG 2.1 contrast ratio, 1.0 to 21.0.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('brand accent', () {
    test('light-mode accent is exactly the specified slate', () {
      expect(
        AppTheme.brandPrimaryLight,
        const Color(0xFF3C4550),
        reason: 'The accent is a specified brand value, not a free choice.',
      );
    });

    test('the accent survives as a container in dark mode', () {
      // Dark mode lifts the accent for contrast, which would otherwise erase
      // it from the palette entirely. Promoting the original into the
      // container role is what keeps the brand present on OLED black.
      expect(AppTheme.brandContainerDark, const Color(0xFF3C4550));
    });

    test('white on the light accent clears AA for body text', () {
      expect(
        _contrast(AppTheme.brandOnPrimaryLight, AppTheme.brandPrimaryLight),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('ink on the lifted dark accent clears AA for body text', () {
      expect(
        _contrast(AppTheme.brandOnPrimaryDark, AppTheme.brandPrimaryDark),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('the accent clears AA as text on the dark canvas', () {
      expect(
        _contrast(AppTheme.brandPrimaryDark, AppTheme.bgDark),
        greaterThanOrEqualTo(4.5),
        reason:
            'The accent is used for eyebrow labels and active states on the '
            'dark canvas, so it has to be readable as text, not just as a fill.',
      );
    });

    test('both gradient stops stay in the accent hue', () {
      // A saturated gradient would reintroduce exactly the "loud colour" the
      // neutral accent exists to avoid. Same hue = reads as light on a surface.
      Color.lerp(
        AppTheme.brandGradientFromLight,
        AppTheme.brandGradientToLight,
        0.5,
      );
      final lightFrom = HSLColor.fromColor(AppTheme.brandGradientFromLight);
      final lightTo = HSLColor.fromColor(AppTheme.brandGradientToLight);
      final darkFrom = HSLColor.fromColor(AppTheme.brandGradientFromDark);
      final darkTo = HSLColor.fromColor(AppTheme.brandGradientToDark);

      expect(
        (lightFrom.hue - lightTo.hue).abs(),
        lessThan(20),
        reason: 'Light gradient must not shift hue.',
      );
      expect(
        (darkFrom.hue - darkTo.hue).abs(),
        lessThan(20),
        reason: 'Dark gradient must not shift hue.',
      );
      expect(lightFrom.saturation, lessThan(0.25));
      expect(darkFrom.saturation, lessThan(0.25));
    });

    test('the glow is the accent, not a brighter hue', () {
      expect(AppTheme.brandGlowLight, AppTheme.brandPrimaryLight);
      expect(AppTheme.brandGlowDark, AppTheme.brandGlowDark);
    });
  });

  group('surface ladder', () {
    test('dark surfaces ascend monotonically', () {
      // A ladder that inverts is invisible until something is drawn on it.
      const ladder = [
        AppTheme.bgDark,
        AppTheme.surfaceDark,
        AppTheme.surfaceHighDark,
        AppTheme.surfaceRaisedDark,
        AppTheme.surfaceOverlayDark,
      ];
      for (var i = 1; i < ladder.length; i++) {
        expect(
          _luminance(ladder[i]),
          greaterThan(_luminance(ladder[i - 1])),
          reason: 'ladder[$i] must be lighter than ladder[${i - 1}]',
        );
      }
    });

    test('the dark canvas is pure black for OLED', () {
      expect(AppTheme.bgDark, Colors.black);
    });

    test('every dark surface is cool, not warm', () {
      // Blue channel >= red channel is what "cool" means numerically, and it
      // is the property that keeps the dark mode from reading as a different
      // product than the light mode.
      for (final c in const [
        AppTheme.surfaceDark,
        AppTheme.surfaceHighDark,
        AppTheme.surfaceRaisedDark,
        AppTheme.surfaceOverlayDark,
      ]) {
        expect(c.b, greaterThanOrEqualTo(c.r), reason: '$c is not cool');
      }
    });
  });

  group('finance semantics stay separable from the accent', () {
    test('no semantic colour collides with the light accent', () {
      final accent = AppTheme.brandPrimaryLight;
      for (final semantic in const [
        AppTheme.incomeColor,
        AppTheme.expenseColor,
        AppTheme.transferColor,
      ]) {
        expect(
          _contrast(accent, semantic),
          greaterThan(1.4),
          reason: '$semantic is too close to the accent to tell apart',
        );
      }
    });

    test('income and expense are distinguishable from each other', () {
      expect(
        _contrast(AppTheme.incomeColor, AppTheme.expenseColor),
        greaterThan(1.4),
      );
    });
  });

  group('goal identity palette', () {
    Color parse(String hex) =>
        Color(int.parse('FF${hex.substring(1)}', radix: 16));

    (double, double, double) labOf(Color c) {
      double channel(double v) => v <= 0.03928
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      final r = channel(c.r);
      final g = channel(c.g);
      final b = channel(c.b);
      final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
      final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
      double f(double t) =>
          t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
      final fx = f(x);
      final fy = f(y);
      final fz = f(z);
      return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz));
    }

    double deltaE(Color a, Color b) {
      final la = labOf(a);
      final lb = labOf(b);
      return math.sqrt(
        math.pow(la.$1 - lb.$1, 2) +
            math.pow(la.$2 - lb.$2, 2) +
            math.pow(la.$3 - lb.$3, 2),
      );
    }

    test('the palette holds eight swatches', () {
      expect(AppTheme.goalPalette, hasLength(8));
      expect(AppTheme.goalPalette.toSet(), hasLength(8));
    });

    test('every goal colour is a muted mid-tone, not a neon', () {
      for (final hex in AppTheme.goalPalette) {
        final c = parse(hex);
        expect(
          _luminance(c),
          inInclusiveRange(0.16, 0.26),
          reason: '$hex sits outside the muted luminance band',
        );
        expect(
          HSLColor.fromColor(c).saturation,
          lessThan(0.40),
          reason: '$hex is too saturated to read as muted',
        );
      }
    });

    test(
      'every goal colour stays readable on both the light and dark card',
      () {
        for (final hex in AppTheme.goalPalette) {
          final c = parse(hex);
          expect(
            _contrast(c, AppTheme.surfaceLight),
            greaterThanOrEqualTo(3.5),
            reason: '$hex fails on the light card',
          );
          expect(
            _contrast(c, AppTheme.surfaceHighDark),
            greaterThanOrEqualTo(3.5),
            reason: '$hex fails on the dark card',
          );
        }
      },
    );

    test('no two swatches are too close to tell apart', () {
      final colours = AppTheme.goalPalette.map(parse).toList();
      for (var i = 0; i < colours.length; i++) {
        for (var j = i + 1; j < colours.length; j++) {
          expect(
            deltaE(colours[i], colours[j]),
            greaterThanOrEqualTo(10),
            reason:
                '${AppTheme.goalPalette[i]} and ${AppTheme.goalPalette[j]} are '
                'indistinguishable as adjacent swatches',
          );
        }
      }
    });
  });
}
