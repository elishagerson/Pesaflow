import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/presentation/dashboard/widgets/dashboard_balance_header.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  testWidgets('an animating hero digit keeps the settled digit width', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const DashboardBalanceHeader(
          balance: 200000,
          label: 'Total',
          income: 0,
          expense: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final settledWidth = tester.getSize(find.text('2')).width;
    expect(settledWidth, greaterThan(0));

    await tester.pumpWidget(
      _host(
        const DashboardBalanceHeader(
          balance: 300000,
          label: 'Total',
          income: 0,
          expense: 0,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Animating digits are the only text that asks for tabular figures.
    final animatingGlyphs = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          RegExp(r'^\d$').hasMatch(widget.data ?? '') &&
          (widget.style?.fontFeatures?.contains(
                const FontFeature.tabularFigures(),
              ) ??
              false),
    );
    expect(animatingGlyphs, findsWidgets);

    for (var i = 0; i < animatingGlyphs.evaluate().length; i++) {
      expect(
        tester.getSize(animatingGlyphs.at(i)).width,
        moreOrLessEquals(settledWidth, epsilon: 0.5),
        reason:
            'An animating digit must occupy the same width as a settled digit, '
            'or the number snaps wider the frame the run completes.',
      );
    }

    // The odometer staggers its digit timers; let them all fire before teardown.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  });
}
