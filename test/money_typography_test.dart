import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/theme/app_typography_theme.dart';

void main() {
  group('money figures', () {
    test('getMonospaceStyle asks the face for tabular figures', () {
      final style = AppTheme.getMonospaceStyle(
        const TextStyle(fontFamily: 'Inter', fontSize: 14),
      );

      expect(
        style.fontFeatures,
        contains(const FontFeature.tabularFigures()),
        reason:
            'The mono role is documented as tabular figures, but the primary '
            'family (Inter) resolves every digit, so a fallback font alone '
            'never makes the figures tabular.',
      );
    });

    test('the app typography monospace role asks for tabular figures', () {
      final typography = AppTypographyTheme.base(AppTheme.lightTheme.textTheme);

      expect(
        typography.monospace.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });
  });
}
