import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

Widget _host({required double scale, required Widget child}) {
  return MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Theme(data: AppTheme.lightTheme, child: child),
    ),
  );
}

void main() {
  group('text scaling', () {
    testWidgets('context.ts resolves the declared size, not a pre-scaled one', (
      tester,
    ) async {
      late double resolved;
      await tester.pumpWidget(
        _host(
          scale: 2.0,
          child: Builder(
            builder: (context) {
              resolved = context.ts(15).fontSize!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, 15);
    });

    testWidgets('the system text scale reaches the glyphs exactly once', (
      tester,
    ) async {
      Future<double> lineHeightAt(double scale) async {
        await tester.pumpWidget(
          _host(
            scale: scale,
            child: Center(
              child: Builder(
                builder: (context) => Text('0000', style: context.ts(15)),
              ),
            ),
          ),
        );
        return tester.getSize(find.text('0000')).height;
      }

      final base = await lineHeightAt(1.0);
      final doubled = await lineHeightAt(2.0);

      // Line boxes round to whole pixels, so allow a little slack. Double
      // scaling would put this ratio near 3.4, far outside the band.
      expect(doubled / base, closeTo(2.0, 0.1));
    });
  });
}
