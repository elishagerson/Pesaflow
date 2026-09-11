import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/domain/analytics/insight_generator.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/transactions/transaction_list_screen.dart';

void main() {
  final now = DateTime.now();

  final testAccount = Account(
    id: 'acc1',
    name: 'M-Pesa',
    type: 'mobile_money',
    balance: 5000000,
    icon: 'wallet',
    isArchived: false,
    sortOrder: 1,
    createdAt: now,
  );

  final testCategory = Category(
    id: 'cat1',
    name: 'Dining & Food',
    color: '#FF5722',
    icon: 'restaurant',
    type: 'expense',
    isSystem: true,
    sortOrder: 1,
    createdAt: now,
  );

  final testTransaction = Transaction(
    id: 'txn1',
    accountId: 'acc1',
    categoryId: 'cat1',
    amount: 1500000, // TSh 15,000
    type: 'expense',
    description: 'Dinner with friends',
    source: 'manual',
    createdAt: now,
    updatedAt: now,
  );

  final testItem = TransactionWithCategoryAndAccount(
    transaction: testTransaction,
    category: testCategory,
    account: testAccount,
  );

  List<dynamic> baseOverrides({
    List<TransactionWithCategoryAndAccount> transactions = const [],
  }) {
    return [
      filteredTransactionsStreamProvider.overrideWith(
        (ref) => Stream.value(transactions),
      ),
      recentTransactionsStreamProvider.overrideWith(
        (ref) => Stream.value(transactions),
      ),
      accountsStreamProvider.overrideWith(
        (ref) => Stream.value([testAccount]),
      ),
      categoriesFutureProvider.overrideWith(
        (ref) => Future.value([testCategory]),
      ),
      currencyShowDecimalsProvider.overrideWith(
        (ref) => Stream.value(false),
      ),
      insightsProvider.overrideWith((ref) => Future.value([])),
      monthlyTotalsProvider.overrideWith((ref) => Future.value({})),
    ];
  }

  Widget createTestWidget({
    List<dynamic> overrides = const [],
  }) {
    return ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const TransactionListScreen(),
      ),
    );
  }

  group('TransactionListScreen Refinement', () {
    testWidgets('renders title, type filters, and action buttons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          overrides: baseOverrides(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Transactions'), findsWidgets);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);
      expect(find.byIcon(PesaFlowIcons.search), findsOneWidget);
    });

    testWidgets('toggles search input field smoothly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          overrides: baseOverrides(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(TextField), findsNothing);

      // Tap search icon in header
      await tester.tap(find.byIcon(PesaFlowIcons.search));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.text('Search transactions, accounts, notes...'),
        findsOneWidget,
      );
    });

    testWidgets('renders active secondary filter chips and allows dismissal', (
      WidgetTester tester,
    ) async {
      final container = ProviderContainer(
        overrides: baseOverrides().cast(),
      );

      // Set active filters
      container.read(transactionAccountFilterProvider.notifier).state = 'acc1';
      container.read(transactionCategoryFilterProvider.notifier).state = 'cat1';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const TransactionListScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Verify filter chips appear
      expect(find.text('M-Pesa'), findsOneWidget);
      expect(find.text('Dining & Food'), findsOneWidget);
      expect(find.text('Reset Filters'), findsOneWidget);

      // Tap clear on the M-Pesa chip
      final clearIcons = find.byIcon(PesaFlowIcons.clear);
      expect(clearIcons, findsNWidgets(2));
      await tester.tap(clearIcons.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Account filter should be cleared
      expect(container.read(transactionAccountFilterProvider), isNull);
    });

    testWidgets(
      'renders grouped daily header with daily net badge and transaction card',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            overrides: [
              ...baseOverrides(transactions: [testItem]),
              insightsProvider.overrideWith(
                (ref) => Future.value([
                  const Insight(
                    type: InsightType.netCashflow,
                    severity: InsightSeverity.warning,
                    title: 'High Dining Expenses',
                    message: 'Dining exceeded usual budget by 15%.',
                    icon: 'trending_down',
                  ),
                ]),
              ),
              monthlyTotalsProvider.overrideWith(
                (ref) => Future.value({
                  'income': 5000000,
                  'expense': 1500000,
                }),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Header date for today's transaction
        expect(find.text('Today'), findsOneWidget);

        // Transaction description
        expect(find.text('Dinner with friends'), findsOneWidget);
        expect(find.text('M-Pesa'), findsOneWidget);

        // Executive insight card at the end of the list
        expect(find.text('EXECUTIVE INSIGHT'), findsOneWidget);
        expect(find.text('High Dining Expenses'), findsOneWidget);
      },
    );
  });
}
