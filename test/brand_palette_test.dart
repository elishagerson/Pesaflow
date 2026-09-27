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
}
