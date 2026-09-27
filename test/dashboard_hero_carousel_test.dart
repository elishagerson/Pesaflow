import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/presentation/dashboard/widgets/budjetly_balance_header.dart';
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

    // Regression: the 'All clear' / countdown headlines used `posterLarge`
    // (64px condensed) inside a 232px card. A 64px face wraps to three lines
    // in a 300px card and the last line fell off the bottom of the screen.
    testWidgets('no page overflows its 232px card with a long balance', (
      tester,
    ) async {
      for (final page in [0, 1, 2]) {
        await tester.pumpWidget(_host());
        await tester.pumpAndSettle();
        for (var i = 0; i < page; i++) {
          await tester.drag(find.byType(PageView), const Offset(-500, 0));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: 'page $page overflowed');
      }
    });

    // Regression: the account label sat inside a `MainAxisSize.min` Row, which
    // hands its child an unbounded width, so a long workspace name pushed the
    // privacy toggle off the right edge of the card.
    testWidgets(
      'a long account name truncates instead of pushing the toggle off',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              recurringTransactionsStreamProvider.overrideWith(
                (ref) => Stream.value(const <RecurringTransaction>[]),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: SizedBox(
                  width: 320,
                  child: const BudjetlyBalanceHeader(
                    balance: 2500000,
                    label: 'A workspace name that is far too long for the card',
                    income: 4000000,
                    expense: 1500000,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final toggle = find.byType(InkWell);
        expect(toggle, findsWidgets);
        final header = tester.renderObject<RenderBox>(
          find.byType(BudjetlyBalanceHeader),
        );
        final toggleBox = tester.renderObject<RenderBox>(toggle.first);
        expect(
          toggleBox.size.width,
          lessThan(header.size.width),
          reason: 'the toggle must still be on the card',
        );
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
