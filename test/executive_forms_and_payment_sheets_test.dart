import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/budget_repository.dart';
import 'package:pesaflow/data/repositories/savings_goal_repository.dart';
import 'package:pesaflow/presentation/budgets/budget_form_screen.dart';
import 'package:pesaflow/presentation/loans/widgets/payment_sheet.dart';
import 'package:pesaflow/presentation/savings_goals/savings_goal_form_screen.dart';
import 'package:pesaflow/presentation/savings_goals/widgets/quick_deposit_sheet.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class MockActiveTrackerIdNotifier extends ActiveTrackerIdNotifier {
  @override
  String build() => 'test-tracker-id';
}

class FakeBudgetRepository extends Fake implements BudgetRepository {}

class FakeSavingsGoalRepository extends Fake implements SavingsGoalRepository {
  @override
  Future<SavingsGoal?> getSavingsGoalById(String id) async => null;
}

void main() {
  final testLoan = Loan(
    id: 'loan-1',
    amount: 100000000, // 1,000,000 Tsh
    remaining: 60000000, // 600,000 Tsh remaining
    status: 'active',
    provider: 'NMB Bank',
    description: 'Emergency Loan',
    sender: 'NMB',
    reference: 'NMB-REF-01',
    disbursedAt: DateTime(2026, 1, 1),
    dueAt: DateTime(2026, 12, 31),
    trackerId: 'test-tracker-id',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final testGoal = SavingsGoal(
    id: 'goal-1',
    name: 'Emergency Buffer',
    targetAmount: 20000000, // 200,000 Tsh
    currentAmount: 10000000, // 100,000 Tsh (50%)
    targetDate: DateTime(2026, 12, 31),
    color: '#30D158',
    icon: 'savings',
    trackerId: 'test-tracker-id',
    isCompleted: false,
    createdAt: DateTime(2026, 1, 1),
  );

  final testCategories = [
    Category(
      id: 'cat-groceries',
      name: 'Groceries',
      icon: 'basket',
      color: '#30D158',
      type: 'expense',
      isSystem: true,
      sortOrder: 0,
      createdAt: DateTime.now(),
    ),
    Category(
      id: 'cat-emergencies',
      name: 'Emergencies',
      icon: 'alert-circle',
      color: '#FF453A',
      type: 'expense',
      isSystem: true,
      sortOrder: 1,
      createdAt: DateTime.now(),
    ),
  ];

  group('LoanPayoffSimulatorCard', () {
    testWidgets('renders initial status and remaining balance when payment is 0', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: LoanPayoffSimulatorCard(
              loan: testLoan,
              paymentCents: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('REPAYMENT STATUS'), findsOneWidget);
      expect(find.text('Paid: 40%'), findsOneWidget);
      expect(find.text('Remaining'), findsOneWidget);
      expect(find.text('FULL PAYOFF'), findsNothing);
      expect(find.textContaining('JUMP'), findsNothing);
    });

    testWidgets('displays projected remaining balance and % jump when payment > 0', (
      WidgetTester tester,
    ) async {
      // Paying 300,000 Tsh (30,000,000 cents) -> 30% jump
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: LoanPayoffSimulatorCard(
              loan: testLoan,
              paymentCents: 30000000,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('+30% JUMP'), findsOneWidget);
      expect(find.text('New Remaining'), findsOneWidget);
      expect(find.text('FULL PAYOFF'), findsNothing);
    });

    testWidgets('displays FULL PAYOFF badge when payment settles total remaining', (
      WidgetTester tester,
    ) async {
      // Paying full 600,000 Tsh (60,000,000 cents)
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: LoanPayoffSimulatorCard(
              loan: testLoan,
              paymentCents: 60000000,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FULL PAYOFF'), findsOneWidget);
      expect(find.text('Remaining: TSh 0'), findsOneWidget);
    });
  });

  group('QuickDepositSheet Executive Features', () {
    testWidgets('renders live milestone progress simulator and quick increment chips', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeTrackerIdProvider.overrideWith(
              () => MockActiveTrackerIdNotifier(),
            ),
            accountsStreamProvider.overrideWith((ref) => Stream.value([])),
            currencyShowDecimalsProvider.overrideWith(
              (ref) => Stream.value(false),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => Consumer(
                  builder: (context, ref, _) => ElevatedButton(
                    onPressed: () =>
                        showQuickDepositSheet(context, ref, testGoal),
                    child: const Text('Open Deposit'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Deposit'));
      await tester.pumpAndSettle();

      expect(find.text('Deposit into Emergency Buffer'), findsOneWidget);
      expect(find.text('MILESTONE PROGRESS'), findsOneWidget);
      expect(find.text('Current: 50%'), findsOneWidget);
      expect(find.text('Confirm Deposit'), findsOneWidget);
      expect(find.text('+10,000'), findsOneWidget);
      expect(find.text('+50,000'), findsOneWidget);
      expect(find.text('Remainder'), findsOneWidget);

      // Tap quick increment chip +50,000
      await tester.tap(find.text('+50,000'));
      await tester.pumpAndSettle();

      expect(find.text('+25% JUMP'), findsOneWidget);
      expect(find.textContaining('Confirm Deposit (Tsh 50,000)'), findsOneWidget);
    });
  });

  group('BudgetFormScreen Executive Features', () {
    testWidgets('renders budget allocation hero and interactive quick increment pills', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            budgetRepositoryProvider.overrideWithValue(FakeBudgetRepository()),
            activeTrackerIdProvider.overrideWith(
              () => MockActiveTrackerIdNotifier(),
            ),
            categoriesFutureProvider.overrideWith(
              (ref) async => testCategories,
            ),
            currencyShowDecimalsProvider.overrideWith(
              (ref) => Stream.value(false),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const BudgetFormScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Allocation: '), findsOneWidget);
      expect(find.text('+100K'), findsOneWidget);
      expect(find.text('+500K'), findsOneWidget);
      expect(find.text('+1M'), findsOneWidget);

      // Tap +100K
      await tester.tap(find.text('+100K'));
      await tester.pumpAndSettle();

      // Check allocation reflects 100,000
      expect(find.textContaining('100,000'), findsWidgets);
      expect(find.text('Daily spending allowance: '), findsOneWidget);

      // Tap Clear
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(find.text('TSh 0'), findsWidgets);
    });
  });

  group('SavingsGoalFormScreen Executive Features', () {
    testWidgets('renders Tanzanian milestone presets and applies template on tap', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savingsGoalRepositoryProvider.overrideWithValue(
              FakeSavingsGoalRepository(),
            ),
            activeTrackerIdProvider.overrideWith(
              () => MockActiveTrackerIdNotifier(),
            ),
            currencyShowDecimalsProvider.overrideWith(
              (ref) => Stream.value(false),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SavingsGoalFormScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Emergency Fund'), findsOneWidget);
      expect(find.text('Land & Construction'), findsOneWidget);

      // Tap Land & Construction template
      await tester.tap(find.text('Land & Construction'));
      await tester.pumpAndSettle();

      expect(find.text('10000000'), findsOneWidget);
      expect(find.text('+250K'), findsOneWidget);
      expect(find.text('+2M'), findsOneWidget);
    });
  });
}
