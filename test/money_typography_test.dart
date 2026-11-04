import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

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

    testWidgets('tabular context styles keep digit widths equal', (
      tester,
    ) async {
      // The flutter_test fallback font gives every glyph one width, so the
      // shipped Inter face has to be loaded for digit advances to differ.
      await (FontLoader(
        'Inter',
      )..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))).load();

      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );

      double widthOf(String text, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
        )..layout();
        return painter.width;
      }

      final proportional = ctx.ts(14);
      expect(
        widthOf('1,111', proportional),
        isNot(moreOrLessEquals(widthOf('9,999', proportional), epsilon: 0.01)),
        reason: 'Inter digits are proportional, so this is what needs fixing.',
      );

      final tabular = ctx.ts(14, tabular: true);
      expect(
        widthOf('1,111', tabular),
        moreOrLessEquals(widthOf('9,999', tabular), epsilon: 0.01),
        reason: 'A money figure must not change width as its digits change.',
      );
    });
  });
}
