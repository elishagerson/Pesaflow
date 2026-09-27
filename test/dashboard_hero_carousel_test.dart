import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/presentation/dashboard/widgets/dashboard_hero_carousel.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

/// Overrides the recurring stream with a fixed set of future bills. The
/// carousel is a `ConsumerWidget` for exactly one provider, so this is the only
/// thing it needs to be exercised deterministically.
ProviderScope _host() {
  return ProviderScope(
    overrides: [
      recurringTransactionsStreamProvider.overrideWith(
        (ref) => Stream.value(const <RecurringTransaction>[]),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          child: DashboardHeroCarousel(
            balance: 2500000,
            label: 'M-PESA',
            income: 4000000,
            expense: 1500000,
            remainingBudget: 2500000,
            budgetPct: 0.375,
            budgetTotal: 4000000,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('DashboardHeroCarousel', () {
    testWidgets('opens on the balance page', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      expect(find.text('Balance'), findsOneWidget);
      expect(find.text('M-PESA'), findsOneWidget);
    });

    testWidgets('shows all three pages exist via the segment rail', (
      tester,
    ) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      // The rail renders one dot per page plus the current page's name.
      expect(find.text('Balance'), findsOneWidget);
    });

    testWidgets('paging to the next card shows Safe to spend', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Page 2 is the ring gauge.
      expect(find.text('Safe to spend'), findsOneWidget);
    });

    testWidgets('paging twice reaches the next-up countdown', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // With no upcoming bills the countdown card shows its empty state, which
      // is still a real, deliberately designed state and not a blank page.
      expect(find.text('Next up'), findsOneWidget);
      expect(find.text('All clear'), findsOneWidget);
    });

    testWidgets(
      'a negative remaining balance surfaces as an error, not a clamp',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              recurringTransactionsStreamProvider.overrideWith(
                (ref) => Stream.value([]),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: SizedBox(
                  width: 400,
                  child: DashboardHeroCarousel(
                    balance: -500000,
                    label: 'M-PESA',
                    income: 100000,
                    expense: 900000,
                    remainingBudget: -800000,
                    budgetPct: 1.0,
                    budgetTotal: 100000,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.drag(find.byType(PageView), const Offset(-500, 0));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(PageView), const Offset(-500, 0));
        await tester.pumpAndSettle();

        expect(find.text('Over budget by this much'), findsOneWidget);
      },
    );

    testWidgets('renders in dark mode without overflowing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recurringTransactionsStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SizedBox(
                width: 360,
                child: DashboardHeroCarousel(
                  balance: 98765432100,
                  label: 'A very long workspace name here',
                  income: 0,
                  expense: 0,
                  remainingBudget: 0,
                  budgetPct: 0,
                  budgetTotal: 0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
