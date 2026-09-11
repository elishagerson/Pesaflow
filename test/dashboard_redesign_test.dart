import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/presentation/dashboard/widgets/budjetly_balance_header.dart';
import 'package:pesaflow/presentation/dashboard/widgets/dashboard_widgets.dart';

void main() {
  Widget createTestWidget({required Widget child}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('BudjetlyBalanceHeader', () {
    testWidgets('renders balance, label, and monthly cash flow metrics', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const BudjetlyBalanceHeader(
            balance: 250000000, // TSh 2,500,000.00
            label: 'Total Net Worth',
            income: 300000000,
            expense: 50000000,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TOTAL NET WORTH'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Spent'), findsOneWidget);
    });

    testWidgets('toggles privacy visibility when eye button is tapped', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const BudjetlyBalanceHeader(
            balance: 150000000,
            label: 'CRDB Bank',
            income: 200000000,
            expense: 50000000,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('••••••'), findsNothing);

      // Tap the eye toggle button
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Obfuscated dots should now appear
      expect(find.text('••••••'), findsOneWidget);
      expect(find.text('••••'), findsNWidgets(2)); // for Income and Spent
    });

    testWidgets('reflects negative balance reality with minus sign and deficit status', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const BudjetlyBalanceHeader(
            balance: -4500000, // - TSh 45,000.00
            label: 'Credit Card',
            income: 10000000,
            expense: 14500000,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CREDIT CARD'), findsOneWidget);
      expect(find.text('DEFICIT'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);
    });
  });

  group('FinancialHubGrid', () {
    testWidgets('renders 4 hub cards with correct metrics and badges', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const FinancialHubGrid(
            budgets: ['budget1'],
            overallPct: 0.65,
            savingsGoals: ['goal1', 'goal2'],
            activeRecurringCount: 3,
            dueCount: 1,
            pendingReviewCount: 0,
            trackerColor: Colors.blue,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FINANCIAL OVERVIEW'), findsOneWidget);
      expect(find.text('Budgets'), findsOneWidget);
      expect(find.text('Savings'), findsOneWidget);
      expect(find.text('Recurring'), findsOneWidget);
      expect(find.text('Loans & Debt'), findsOneWidget);

      expect(find.text('65% spent'), findsOneWidget);
      expect(find.text('2 goals'), findsOneWidget);
      expect(find.text('1 due today'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // Badge for due count
    });
  });
}
