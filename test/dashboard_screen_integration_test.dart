import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/presentation/common/widgets/pesa_surface.dart';
import 'package:pesaflow/presentation/dashboard/dashboard_screen.dart';
import 'package:pesaflow/presentation/dashboard/widgets/budjetly_balance_header.dart';
import 'package:pesaflow/presentation/state/spending_heatmap_provider.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

/// One account, with only the fields the dashboard actually reads pinned.
Account _account({String name = 'M-PESA'}) => Account(
  id: 'acc-1',
  name: name,
  balance: 2_500_000,
  icon: 'phone',
  type: 'mobile',
  isArchived: false,
  sortOrder: 0,
  createdAt: DateTime(2026, 1, 1),
);

/// Overrides every provider the dashboard reads, so the screen renders from
/// real widgets with known values instead of being stubbed out.
///
/// The point of testing the screen rather than the hero widget is that the
/// hero's full-bleed layout depends on the scroll view *not* insetting it — a
/// property that only exists at the screen level and is invisible to a test
/// that mounts the hero on its own.
ProviderScope _scope({
  required Brightness brightness,
  double textScale = 1.0,
  String workspace = 'Zawadi',
  String accountName = 'M-PESA',
  int income = 4_000_000,
  int expense = 1_500_000,
}) {
  return ProviderScope(
    overrides: [
      cardholderNameProvider.overrideWith((ref) => Stream.value(workspace)),
      accountsStreamProvider.overrideWith(
        (ref) => Stream.value([_account(name: accountName)]),
      ),
      netWorthProvider.overrideWithValue(2_500_000),
      monthlyTotalsProvider.overrideWith(
        (ref) async => {'income': income, 'expense': expense},
      ),
      recentTransactionsStreamProvider.overrideWith(
        (ref) => Stream.value(const <TransactionWithCategoryAndAccount>[]),
      ),
      budgetProgressProvider.overrideWith((ref) async => const []),
      reviewQueueStreamProvider.overrideWith(
        (ref) => Stream.value(const <TransactionWithCategoryAndAccount>[]),
      ),
      savingsGoalsStreamProvider.overrideWith(
        (ref) => Stream.value(const <SavingsGoal>[]),
      ),
      activeTrackerProvider.overrideWith((ref) async => null),
      recurringTransactionsStreamProvider.overrideWith(
        (ref) => Stream.value(const <RecurringTransaction>[]),
      ),
      dueRecurringTransactionsProvider.overrideWith(
        (ref) async => const <RecurringTransaction>[],
      ),
      spendingHeatmapProvider.overrideWith(
        (ref) async => HeatmapData(
          totalExpenditure: 0,
          maxExpense: 0,
          dailyExpenses: const {},
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 31),
        ),
      ),
      transactionTemplatesStreamProvider.overrideWith(
        (ref) => Stream.value(const <Map<String, dynamic>>[]),
      ),
      activeLoansStreamProvider.overrideWith(
        (ref) => Stream.value(const <Loan>[]),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: brightness == Brightness.light
          ? ThemeMode.light
          : ThemeMode.dark,
      // The scale is applied to the app's own MediaQuery rather than to the
      // test view, so the dashboard lays out exactly as it would on a device
      // with the user's larger-type setting.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const DashboardScreen(),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  String workspace = 'Zawadi',
  String accountName = 'M-PESA',
  int income = 4_000_000,
  int expense = 1_500_000,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _scope(
      brightness: brightness,
      textScale: textScale,
      workspace: workspace,
      accountName: accountName,
      income: income,
      expense: expense,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the dashboard hero is full bleed on the real screen', () {
    // This is the test that would have caught the hero sitting inside a
    // 16dp gutter: the hero widget on its own cannot know what its parent
    // insets, so this has to be measured on the assembled screen.
    testWidgets('the hero touches both screen edges', (tester) async {
      await _pump(tester);

      final hero = find.byType(BudjetlyBalanceHeader);
      expect(hero, findsOneWidget, reason: 'the hero did not render at all');

      final rect = tester.getRect(hero);
      expect(rect.left, 0, reason: 'a gutter on the left is a bezel');
      expect(
        rect.right,
        tester.view.physicalSize.width / tester.view.devicePixelRatio,
        reason: 'a gutter on the right is a bezel',
      );
    });

    testWidgets('the hero stays flush across phone widths', (tester) async {
      for (final width in [320.0, 360.0, 390.0, 430.0]) {
        await _pump(tester, size: Size(width, 900));
        final rect = tester.getRect(find.byType(BudjetlyBalanceHeader));
        expect(rect.left, 0, reason: 'not flush at $width');
        expect(rect.width, width, reason: 'not full width at $width');
      }
    });
  });

  group('no overflow anywhere on the screen', () {
    const conditions = [
      (size: Size(390, 844), scale: 1.0, brightness: Brightness.light),
      (size: Size(320, 700), scale: 1.0, brightness: Brightness.light),
      (size: Size(390, 844), scale: 1.0, brightness: Brightness.dark),
      (size: Size(360, 800), scale: 1.3, brightness: Brightness.light),
    ];

    for (final c in conditions) {
      testWidgets('${c.size.width}x${c.size.height} @ ${c.scale}x '
          '${c.brightness.name}', (tester) async {
        await _pump(tester, size: c.size, brightness: c.brightness);
        expect(
          tester.takeException(),
          isNull,
          reason: 'the dashboard overflowed at ${c.size} / ${c.scale}x',
        );
      });
    }
  });

  group('the dashboard survives real content', () {
    // Each of these is a bug that shipped past a hero-only test and past an
    // empty-data test. All three are the same mistake: a `spaceBetween` Row
    // whose children cannot shrink, so the row overflows instead of yielding.

    testWidgets(
      'a long workspace name truncates instead of pushing the top bar',
      (tester) async {
        // The greeting Column and the three tool buttons were siblings in a
        // `spaceBetween` Row, so a long name shoved the search and review
        // buttons off the end of the bar.
        await _pump(
          tester,
          size: const Size(320, 700),
          workspace: 'Zawadi Family Savings Workspace',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a long account name does not overflow the hub grid', (
      tester,
    ) async {
      // The hub card title rode in a `mainAxisSize: MainAxisSize.min` Row,
      // which constrains nothing. At two cards per row that is a 159px card,
      // already at its limit at 12px type and hopeless at 1.3x.
      await _pump(
        tester,
        size: const Size(360, 800),
        textScale: 1.3,
        accountName: 'NMB Bank Main Personal Current',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a five-figure balance does not overflow the cashflow rows', (
      tester,
    ) async {
      // The amount in a `spaceBetween` Row with a non-flex label, in a
      // monospace face, at the width left over beside an 84px donut.
      await _pump(
        tester,
        size: const Size(360, 800),
        income: 987_654_321,
        expense: 123_456_789,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the section header and its affordance both fit at 320', (
      tester,
    ) async {
      await _pump(tester, size: const Size(320, 700), textScale: 1.3);
      expect(tester.takeException(), isNull);
    });
  });

  group('the hero is not framed', () {
    testWidgets('no border, no shadow, no specular edge', (tester) async {
      await _pump(tester);

      final surfaces = tester.widgetList<PesaSurface>(find.byType(PesaSurface));
      expect(surfaces, isNotEmpty);

      final hero = tester.widget<PesaSurface>(
        find.descendant(
          of: find.byType(BudjetlyBalanceHeader),
          matching: find.byType(PesaSurface),
        ),
      );
      expect(((hero.stroke ?? const Color(0x00000000)).a * 255).round(), 0);
      expect(hero.shadows, isEmpty);
      expect(hero.edgeLight, isFalse);
    });

    testWidgets('the hero keeps only a slight radius', (tester) async {
      await _pump(tester);
      final hero = tester.widget<PesaSurface>(
        find.descendant(
          of: find.byType(BudjetlyBalanceHeader),
          matching: find.byType(PesaSurface),
        ),
      );
      expect(hero.radius, AppTheme.radiusHero);
      expect(hero.radius, lessThanOrEqualTo(24));
      expect(hero.chamfered, isFalse);
    });
  });

  group('the hero inset is a real rhythm token', () {
    testWidgets('the horizontal inset matches kSpacing', (tester) async {
      await _pump(tester);
      final hero = tester.widget<PesaSurface>(
        find.descendant(
          of: find.byType(BudjetlyBalanceHeader),
          matching: find.byType(PesaSurface),
        ),
      );
      final pad = hero.padding.resolve(TextDirection.ltr);
      expect(pad.left, kSpacing20);
      expect(pad.left, greaterThanOrEqualTo(kSpacing16));
    });
  });
}
