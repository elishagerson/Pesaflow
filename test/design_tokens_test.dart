import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/spacing.dart';

void main() {
  group('Design token invariants', () {
    test('radius tokens are exactly the documented scale', () {
      final radii = <double>{
        AppTheme.radiusTiny,
        AppTheme.radiusSmall,
        AppTheme.radiusCompact,
        AppTheme.radiusInput,
        AppTheme.radiusCard,
        AppTheme.radiusHero,
        AppTheme.radiusDialog,
        AppTheme.radiusButton,
        AppTheme.radiusPill,
      };
      expect(radii, equals(<double>{4, 8, 10, 12, 16, 20, 24, 28, 100}));
    });

    test('spacing tokens are the 2px-grid scale with no off-grid values', () {
      final spacings = <double>{
        kSpacing2,
        kSpacing4,
        kSpacing5,
        kSpacing6,
        kSpacing8,
        kSpacing10,
        kSpacing12,
        kSpacing14,
        kSpacing16,
        kSpacing18,
        kSpacing20,
        kSpacing24,
        kSpacing28,
        kSpacing32,
        kSpacing40,
        kSpacing48,
        kSpacing56,
        kSpacing80,
      };
      expect(
        spacings,
        equals(<double>{
          2,
          4,
          5,
          6,
          8,
          10,
          12,
          14,
          16,
          18,
          20,
          24,
          28,
          32,
          40,
          48,
          56,
          80,
        }),
      );
      // Every step is on the 2px grid (the 5px optical step is the sole
      // documented exception and is explicitly listed above).
      for (final value in spacings) {
        if (value == kSpacing5) continue;
        expect(value % 2, 0, reason: 'Off-grid spacing step: $value');
      }
    });
  });
}
