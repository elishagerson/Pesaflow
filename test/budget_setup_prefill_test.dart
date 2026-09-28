import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/presentation/budgets/budget_setup_screen.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/services/home_widgets_renderer.dart';

void main() {
  Widget createScreen({
    int savedIncomeCents = 0,
    int lastMonthIncomeCents = 0,
  }) {
    return ProviderScope(
      overrides: [
        monthlyIncomeProvider.overrideWith((ref) async => savedIncomeCents),
        lastMonthIncomeProvider.overrideWith(
          (ref) async => lastMonthIncomeCents,
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const BudgetSetupScreen(),
      ),
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    int savedIncomeCents = 0,
    int lastMonthIncomeCents = 0,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      createScreen(
        savedIncomeCents: savedIncomeCents,
        lastMonthIncomeCents: lastMonthIncomeCents,
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder incomeField() => find.byType(TextFormField);

  group('Budget setup income prefill', () {
    testWidgets('prefills the saved monthly income setting', (
      WidgetTester tester,
    ) async {
      // 4,500,000 cents = TSh 45,000, matching what `_save()` stores.
      await pumpScreen(tester, savedIncomeCents: 4500000);

      expect(
        tester.widget<TextFormField>(incomeField()).controller?.text,
        '45,000',
      );
    });

    testWidgets('leaves the field empty when no income is saved', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, savedIncomeCents: 0);

      expect(tester.widget<TextFormField>(incomeField()).controller?.text, '');
    });

    testWidgets('does not overwrite what the user has already typed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createScreen(savedIncomeCents: 4500000));
      await tester.pumpAndSettle();

      await tester.enterText(incomeField(), '99,000');
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextFormField>(incomeField()).controller?.text,
        '99,000',
      );
    });
  });

  group('Budget setup last-month income suggestion', () {
    testWidgets('shows the suggestion when last month earned something', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, lastMonthIncomeCents: 3000000);

      expect(find.text('Last month you earned'), findsOneWidget);
      expect(find.text('Tsh 30,000'), findsOneWidget);
    });

    testWidgets('tapping the suggestion fills the income field', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, lastMonthIncomeCents: 3000000);

      await tester.tap(find.text('Last month you earned'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextFormField>(incomeField()).controller?.text,
        '30,000',
      );
      // Already applied — no need to keep offering it.
      expect(find.text('Last month you earned'), findsNothing);
    });

    testWidgets('is hidden when there is no recorded income', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, lastMonthIncomeCents: 0);

      expect(find.text('Last month you earned'), findsNothing);
    });

    testWidgets('is hidden when it matches the prefilled value', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        savedIncomeCents: 4500000,
        lastMonthIncomeCents: 4500000,
      );

      expect(find.text('Last month you earned'), findsNothing);
    });
  });

  group('Safe-to-spend home widget with no budget', () {
    Widget wrap(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: Center(child: child)),
    );

    testWidgets('never shows a red full bar when no limit is set', (
      WidgetTester tester,
    ) async {
      // The dashboard passes 100% spent with a zero limit when income and
      // budgets are both unrecorded. That must read as "not set".
      await tester.pumpWidget(
        wrap(
          WidgetSafeToSpend(
            remainingCents: -150000,
            limitCents: 0,
            percentage: 1.0,
            theme: AppTheme.lightTheme,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No budget set'), findsOneWidget);
      expect(find.text('Limit: Tsh 0'), findsNothing);

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.0);
    });

    testWidgets('keeps the real limit and spend percentage when one exists', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          WidgetSafeToSpend(
            remainingCents: 350000,
            limitCents: 500000,
            percentage: 0.3,
            theme: AppTheme.lightTheme,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Limit: Tsh'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0.3,
      );
    });
  });
}
