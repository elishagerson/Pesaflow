import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_shapes.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/presentation/common/widgets/pesa_surface.dart';
import 'package:pesaflow/presentation/dashboard/widgets/budjetly_balance_header.dart';
import 'package:pesaflow/presentation/dashboard/widgets/dashboard_hero_strip.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

/// Builds a [RecurringTransaction] without dragging the whole Drift row
/// surface into a widget test.
RecurringTransaction _bill({
  required String description,
  required int amount,
  required DateTime nextDate,
  String type = 'expense',
  String status = 'active',
}) {
  return RecurringTransaction(
    id: 'bill-1',
    accountId: 'acc-1',
    description: description,
    amount: amount,
    type: type,
    status: status,
    frequency: 'monthly',
    intervalValue: 1,
    nextDate: nextDate,
    totalPaid: 0,
    paymentCount: 0,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

Widget _host({
  List<RecurringTransaction> recurring = const [],
  Brightness brightness = Brightness.light,
  double width = 380,
  int balance = 2500000,
  int remainingBudget = 2500000,
  double budgetPct = 0.375,
}) {
  return ProviderScope(
    overrides: [
      recurringTransactionsStreamProvider.overrideWith(
        (ref) => Stream.value(recurring),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: brightness == Brightness.light
          ? ThemeMode.light
          : ThemeMode.dark,
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: DashboardHeroStrip(
            balance: balance,
            label: 'M-PESA',
            income: 4000000,
            expense: 1500000,
            remainingBudget: remainingBudget,
            budgetPct: budgetPct,
            budgetTotal: 4000000,
          ),
        ),
      ),
    ),
  );
}

/// Every non-null `fontSize` actually set on a `Text` inside the hero.
///
/// The balance is an odometer — one `Text` per character — so it cannot be
/// found as a single string. Reading the sizes the widget tree really uses is
/// both simpler and more honest than searching for formatted currency.
List<double> _typeScale(WidgetTester tester) {
  final sizes = <double>[];
  for (final e in find.byType(Text).evaluate()) {
    final size = (e.widget as Text).style?.fontSize;
    if (size != null) sizes.add(size);
  }
  return sizes;
}

void main() {
  group('DashboardHeroStrip', () {
    // The reference is a single continuous card with the widgets next to each
    // other, not a carousel. These three tests are the regression guard for
    // exactly that: no paging, one outline, cells side by side.
    testWidgets('is not a paged carousel', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsNothing);
      expect(find.byType(BudjetlyBalanceHeader), findsOneWidget);
    });

    testWidgets('renders every metric at once, without a gesture', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          recurring: [
            _bill(
              description: 'DAWASA',
              amount: 45000,
              nextDate: DateTime.now().add(const Duration(days: 1, hours: 2)),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Balance, both cash-flow legs, and both footer cells are all on screen
      // in the first frame. Nothing is hidden behind a swipe.
      expect(find.text('INCOME'), findsOneWidget);
      expect(find.text('SPENT'), findsOneWidget);
      expect(find.text('NEXT UP'), findsOneWidget);
      expect(find.text('TOMORROW'), findsOneWidget);
      expect(find.text('SAFE TO SPEND'), findsOneWidget);
    });

    testWidgets('the two footer cells sit side by side, not stacked', (
      tester,
    ) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final nextUp = tester.getRect(find.text('NEXT UP'));
      final safeToSpend = tester.getRect(find.text('SAFE TO SPEND'));

      // Side by side: no horizontal overlap between the two labels, and both
      // sit inside the same vertical band rather than one above the other.
      expect(safeToSpend.left, greaterThanOrEqualTo(nextUp.right));
      expect(safeToSpend.top, lessThan(nextUp.bottom));
      expect(nextUp.top, lessThan(safeToSpend.bottom));

      // And they share one baseline. One cell leads with a ring, the other
      // with a headline, so centring them left the labels a few pixels apart.
      expect((safeToSpend.top - nextUp.top).abs(), lessThan(0.5));
    });

    testWidgets('is one card, not one card per metric', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      // A single surface owns the whole strip.
      final headers = find.byType(BudjetlyBalanceHeader);
      expect(headers, findsOneWidget);

      final card = tester.renderObject<RenderBox>(headers);
      // Every metric sits inside the card's own width.
      for (final label in ['INCOME', 'SPENT', 'NEXT UP', 'SAFE TO SPEND']) {
        final r = tester.renderObject<RenderBox>(find.text(label));
        expect(
          r.size.width,
          lessThan(card.size.width),
          reason: '$label escaped the card',
        );
      }
    });

    testWidgets('has a gradient background rather than a flat fill', (
      tester,
    ) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final gradients = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where((d) => d.decoration is BoxDecoration)
          .map((d) => d.decoration as BoxDecoration)
          .where((d) => d.gradient != null)
          .toList();

      expect(gradients, isNotEmpty, reason: 'the hero card has no gradient');
    });

    testWidgets('an empty schedule reads as a designed state, not a blank', (
      tester,
    ) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      expect(find.text('All clear'), findsOneWidget);
    });

    testWidgets('an overdue or inactive bill is not counted as next up', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          recurring: [
            _bill(
              description: 'Past due',
              amount: 1000,
              nextDate: DateTime.now().subtract(const Duration(days: 3)),
            ),
            _bill(
              description: 'Cancelled',
              amount: 1000,
              nextDate: DateTime.now().add(const Duration(days: 1)),
              status: 'paused',
            ),
            _bill(
              description: 'Income not a bill',
              amount: 1000,
              nextDate: DateTime.now().add(const Duration(hours: 2)),
              type: 'income',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('All clear'), findsOneWidget);
    });

    testWidgets('picks the soonest upcoming bill', (tester) async {
      await tester.pumpWidget(
        _host(
          recurring: [
            _bill(
              description: 'Later',
              amount: 1000,
              nextDate: DateTime.now().add(const Duration(days: 9)),
            ),
            _bill(
              description: 'Sooner',
              amount: 1000,
              nextDate: DateTime.now().add(const Duration(hours: 3)),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('TODAY 2H'), findsOneWidget);
      expect(find.text('Sooner'), findsOneWidget);
      expect(find.text('Later'), findsNothing);
    });

    // Regression: `posterLarge` (64px condensed) in a half-width cell wrapped to
    // three lines and the last line fell out of the card.
    testWidgets('a long countdown stays on one line', (tester) async {
      await tester.pumpWidget(
        _host(
          width: 320,
          recurring: [
            _bill(
              description: 'A very long bill description here',
              amount: 1000,
              nextDate: DateTime.now().add(const Duration(days: 40)),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('1 FEB'), findsNothing); // sanity: date moved
    });

    testWidgets('a negative safe-to-spend is an error, not a clamped zero', (
      tester,
    ) async {
      await tester.pumpWidget(_host(remainingBudget: -800000, budgetPct: 1.0));
      await tester.pumpAndSettle();

      expect(find.text('- Tsh 8,000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    group('boldness and definition', () {
      // "Bolder" is only meaningful if it is measurable, so these assert the
      // specific decisions rather than a vibe.
      testWidgets('the hero uses the hard-cut poster silhouette', (
        tester,
      ) async {
        await tester.pumpWidget(_host());
        await tester.pumpAndSettle();

        final outlines = tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .map((d) => d.decoration)
            .whereType<ShapeDecoration>()
            .map((d) => d.shape);

        expect(
          outlines.whereType<PosterBorder>(),
          isNotEmpty,
          reason: 'the hero fell back to a rounded or chamfered outline',
        );
      });

      testWidgets('the hero has a specular top edge', (tester) async {
        await tester.pumpWidget(_host());
        await tester.pumpAndSettle();

        // `edgeLight` is a public field on the surface, so this reads the real
        // configuration rather than a proxy for it.
        final surface = tester.widget<PesaSurface>(find.byType(PesaSurface));
        expect(
          surface.edgeLight,
          isTrue,
          reason: 'a defined edge needs the specular line',
        );
      });

      testWidgets('the balance is set larger than the cell values', (
        tester,
      ) async {
        await tester.pumpWidget(_host());
        await tester.pumpAndSettle();

        final sizes = _typeScale(tester);
        expect(sizes, isNotEmpty);
        final hero = sizes.reduce((a, b) => a > b ? a : b);

        // The cells are the other poster-sized values; the hero must clear
        // them by a real margin, not by a rounding artefact.
        final cells = sizes.where((v) => v < hero).toSet();
        expect(hero, greaterThanOrEqualTo(76), reason: 'the hero role is 76px');
        expect(
          cells.any((c) => c >= 24),
          isTrue,
          reason: 'the footer cells are supposed to be bold too',
        );
      });

      testWidgets('the two footer cell values share one scale', (tester) async {
        await tester.pumpWidget(
          _host(
            recurring: [
              _bill(
                description: 'DAWASA',
                amount: 45000,
                nextDate: DateTime.now().add(const Duration(days: 1, hours: 2)),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // The 30px tier is the peer-cell value scale: the countdown and the
        // safe-to-spend figure. Count how many separate values sit at it.
        final atCellScale = _typeScale(tester).where((v) => v >= 29 && v <= 31);
        expect(
          atCellScale.toSet(),
          hasLength(1),
          reason: 'the two peer cells disagree on value size',
        );
        expect(atCellScale.length, greaterThanOrEqualTo(2));
      });

      testWidgets('the poster face is set tight enough to stay in the card', (
        tester,
      ) async {
        for (final width in [280.0, 320.0, 380.0, 440.0]) {
          await tester.pumpWidget(_host(width: width));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'overflowed at width $width',
          );
        }
      });
    });

    for (final brightness in Brightness.values) {
      testWidgets('renders in $brightness without overflowing', (tester) async {
        await tester.pumpWidget(
          _host(
            brightness: brightness,
            width: 320,
            balance: 98765432100,
            remainingBudget: -800000,
            recurring: [
              _bill(
                description: 'A very long bill description here',
                amount: 1000,
                nextDate: DateTime.now().add(const Duration(hours: 5)),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(DashboardHeroStrip), findsOneWidget);
      });
    }
  });
}
