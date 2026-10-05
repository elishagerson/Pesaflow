import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/budget_dao.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/presentation/dashboard/widgets/notification_center_sheet.dart';
import 'package:pesaflow/presentation/state/notification_providers.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

void main() {
  Widget createTestWidget({
    List<dynamic> overrides = const [],
    required Widget child,
  }) {
    return ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: Scaffold(body: child),
      ),
    );
  }

  group('NotificationCenterSheet', () {
    testWidgets('shows empty state when no alerts exist', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            reviewQueueStreamProvider.overrideWith(
              (ref) => Stream.value(const <TransactionWithCategoryAndAccount>[]),
            ),
            dueRecurringTransactionsProvider.overrideWith(
              (ref) async => const <RecurringTransaction>[],
            ),
            budgetProgressProvider.overrideWith((ref) async => const []),
            activeLoansStreamProvider.overrideWith(
              (ref) => Stream.value(const <Loan>[]),
            ),
            savingsGoalsStreamProvider.overrideWith(
              (ref) => Stream.value(const <SavingsGoal>[]),
            ),
          ],
          child: const NotificationCenterSheet(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notification Center'), findsOneWidget);
      expect(find.text('All Caught Up!'), findsOneWidget);
      expect(
        find.text(
          'No pending carrier SMS, overdue bills, or budget warnings at this time.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays carrier SMS, bills, and budget warnings accurately', (
      tester,
    ) async {
      final now = DateTime.now();

      final mockCategory = Category(
        id: 'cat-1',
        name: 'Dining',
        color: '#FF5722',
        icon: 'restaurant',
        type: 'expense',
        isSystem: false,
        sortOrder: 1,
        createdAt: now,
      );

      final mockTransaction = TransactionWithCategoryAndAccount(
        transaction: Transaction(
          id: 'tx-1',
          accountId: 'acc-1',
          categoryId: 'cat-1',
          amount: 5000000, // 50,000 TSh
          type: 'expense',
          description: 'M-PESA to John Doe',
          source: 'sms_reviewed',
          createdAt: now,
          updatedAt: now,
        ),
        category: mockCategory,
        account: null,
      );

      final mockDueBill = RecurringTransaction(
        id: 'rec-1',
        accountId: 'acc-1',
        amount: 2500000, // 25,000 TSh
        type: 'expense',
        status: 'active',
        frequency: 'monthly',
        intervalValue: 1,
        nextDate: now,
        totalPaid: 0,
        paymentCount: 0,
        createdAt: now,
        updatedAt: now,
        description: 'LUKU Electricity Bill',
      );

      final mockBudget = BudgetWithProgress(
        budget: Budget(
          id: 'b-1',
          name: 'Dining & Entertainment',
          categoryId: 'cat-1',
          amount: 10000000,
          period: 'monthly',
          rollover: false,
          rolloverType: 'none',
          startDate: now,
          notificationThreshold: 0.8,
          isActive: true,
          createdAt: now,
        ),
        category: Category(
          id: 'c-1',
          name: 'Dining',
          color: '#FF5722',
          icon: 'restaurant',
          type: 'expense',
          isSystem: false,
          sortOrder: 1,
          createdAt: now,
        ),
        currentPeriod: BudgetPeriod(
          id: 'bp-1',
          budgetId: 'b-1',
          periodStart: now,
          periodEnd: now.add(const Duration(days: 30)),
          allocated: 10000000,
          spent: 12000000,
          isClosed: false,
          createdAt: now,
        ),
        spentInPeriod: 12000000, // Over budget by 20,000 TSh
      );

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            reviewQueueStreamProvider.overrideWith(
              (ref) => Stream.value([mockTransaction]),
            ),
            dueRecurringTransactionsProvider.overrideWith(
              (ref) async => [mockDueBill],
            ),
            budgetProgressProvider.overrideWith((ref) async => [mockBudget]),
            activeLoansStreamProvider.overrideWith(
              (ref) => Stream.value(const <Loan>[]),
            ),
            savingsGoalsStreamProvider.overrideWith(
              (ref) => Stream.value(const <SavingsGoal>[]),
            ),
          ],
          child: const NotificationCenterSheet(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notification Center'), findsOneWidget);
      expect(find.text('3'), findsWidgets); // badge in header and All pill

      // Carrier SMS card rendered
      expect(find.text('M-PESA to John Doe'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);

      // Bill due card rendered
      expect(find.text('LUKU Electricity Bill'), findsOneWidget);
      expect(find.text('Due Today'), findsOneWidget);
      expect(find.text('Pay Now'), findsOneWidget);

      // Budget alert card rendered
      await tester.scrollUntilVisible(
        find.text('Dining & Entertainment Alert'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Dining & Entertainment Alert'), findsOneWidget);
      expect(find.text('Adjust'), findsOneWidget);
    });

    testWidgets('displays savings milestone reminders and provides deposit action', (
      tester,
    ) async {
      final now = DateTime.now();
      final mockGoal = SavingsGoal(
        id: 'goal-1',
        name: 'Emergency Fund',
        targetAmount: 50000000, // 500,000 TSh
        currentAmount: 20000000, // 200,000 TSh
        targetDate: now.add(const Duration(days: 15)),
        color: '#4CAF50',
        icon: 'savings',
        isCompleted: false,
        createdAt: now,
      );

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            reviewQueueStreamProvider.overrideWith(
              (ref) => Stream.value(const <TransactionWithCategoryAndAccount>[]),
            ),
            dueRecurringTransactionsProvider.overrideWith(
              (ref) async => const <RecurringTransaction>[],
            ),
            budgetProgressProvider.overrideWith((ref) async => const []),
            activeLoansStreamProvider.overrideWith(
              (ref) => Stream.value(const <Loan>[]),
            ),
            savingsGoalsStreamProvider.overrideWith(
              (ref) => Stream.value([mockGoal]),
            ),
          ],
          child: const NotificationCenterSheet(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Emergency Fund'), findsOneWidget);
      expect(find.textContaining('DUE IN'), findsOneWidget);
      expect(find.text('Deposit'), findsOneWidget);
    });

    testWidgets('filtering tabs isolates corresponding category items', (
      tester,
    ) async {
      final now = DateTime.now();

      final mockDueBill = RecurringTransaction(
        id: 'rec-1',
        accountId: 'acc-1',
        amount: 2500000,
        type: 'expense',
        status: 'active',
        frequency: 'monthly',
        intervalValue: 1,
        nextDate: now,
        totalPaid: 0,
        paymentCount: 0,
        createdAt: now,
        updatedAt: now,
        description: 'DAWASA Water Bill',
      );

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            reviewQueueStreamProvider.overrideWith(
              (ref) => Stream.value(const <TransactionWithCategoryAndAccount>[]),
            ),
            dueRecurringTransactionsProvider.overrideWith(
              (ref) async => [mockDueBill],
            ),
            budgetProgressProvider.overrideWith((ref) async => const []),
            activeLoansStreamProvider.overrideWith(
              (ref) => Stream.value(const <Loan>[]),
            ),
            savingsGoalsStreamProvider.overrideWith(
              (ref) => Stream.value(const <SavingsGoal>[]),
            ),
          ],
          child: const NotificationCenterSheet(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DAWASA Water Bill'), findsOneWidget);

      // Switch filter to Carrier SMS (which has 0 items)
      await tester.tap(find.text('Carrier SMS'));
      await tester.pumpAndSettle();

      // Should now show empty state because no SMS items exist
      expect(find.text('All Caught Up!'), findsOneWidget);
      expect(find.text('DAWASA Water Bill'), findsNothing);

      // Switch filter to Bills Due
      await tester.tap(find.text('Bills Due'));
      await tester.pumpAndSettle();

      expect(find.text('DAWASA Water Bill'), findsOneWidget);
    });
  });

  group('notificationCountsProvider', () {
    test('computes total notifications accurately', () {
      final container = ProviderContainer(
        overrides: [
          reviewQueueStreamProvider.overrideWith(
            (ref) => Stream.value(const <TransactionWithCategoryAndAccount>[]),
          ),
          dueRecurringTransactionsProvider.overrideWith(
            (ref) async => const <RecurringTransaction>[],
          ),
          budgetProgressProvider.overrideWith((ref) async => const []),
          activeLoansStreamProvider.overrideWith(
            (ref) => Stream.value(const <Loan>[]),
          ),
          savingsGoalsStreamProvider.overrideWith(
            (ref) => Stream.value(const <SavingsGoal>[]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final counts = container.read(notificationCountsProvider);
      expect(counts.total, 0);
      expect(counts.pendingSmsCount, 0);
      expect(counts.dueBillsCount, 0);
      expect(counts.budgetAlertsCount, 0);
      expect(counts.savingsRemindersCount, 0);
      expect(counts.dueLoansCount, 0);
    });
  });
}
