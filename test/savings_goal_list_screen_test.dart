import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/presentation/savings_goals/savings_goal_list_screen.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class MockActiveTrackerIdNotifier extends ActiveTrackerIdNotifier {
  @override
  String build() => 'test-tracker-id';
}

void main() {
  Widget createTestWidget({
    required List<SavingsGoal> goals,
    int? totalSaved,
  }) {
    final computedTotal =
        totalSaved ??
        goals.fold<int>(0, (sum, g) => sum + g.currentAmount);

    return ProviderScope(
      overrides: [
        activeTrackerIdProvider.overrideWith(
          () => MockActiveTrackerIdNotifier(),
        ),
        savingsGoalsStreamProvider.overrideWith(
          (ref) => Stream.value(goals),
        ),
        savingsGoalsTotalSavedProvider.overrideWithValue(computedTotal),
        accountsStreamProvider.overrideWith((ref) => Stream.value([])),
        currencyShowDecimalsProvider.overrideWith((ref) => Stream.value(false)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const SavingsGoalListScreen(),
      ),
    );
  }

  group('SavingsGoalListScreen Executive Redesign', () {
    testWidgets('renders empty state when no goals exist', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(goals: []));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('No Savings Goals Yet'), findsOneWidget);
      expect(find.text('Set Your First Goal'), findsOneWidget);
    });

    testWidgets(
      'renders executive savings vault, active goals, strategy card, and suggestions',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final now = DateTime.now();
        final goals = [
          SavingsGoal(
            id: 'goal-1',
            name: 'Life Getter',
            targetAmount: 300000000, // 3,000,000 TZS
            currentAmount: 19100000, // 191,000 TZS
            targetDate: now.add(const Duration(days: 110)),
            color: '#2563EB',
            icon: 'piggy-bank',
            isCompleted: false,
            trackerId: 'test-tracker-id',
            createdAt: now,
          ),
          SavingsGoal(
            id: 'goal-2',
            name: 'Life Starter',
            targetAmount: 500000000, // 5,000,000 TZS
            currentAmount: 5200000, // 52,000 TZS
            targetDate: now.add(const Duration(days: 155)),
            color: '#0D9488',
            icon: 'piggy-bank',
            isCompleted: false,
            trackerId: 'test-tracker-id',
            createdAt: now,
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(goals: goals, totalSaved: 24300000),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));

        // 1. Summary Vault Card
        expect(find.text('SAVINGS VAULT'), findsOneWidget);
        expect(find.text('3% FUNDED'), findsWidgets);
        expect(find.text('TOTAL SAVED'), findsOneWidget);
        expect(find.text('COMBINED TARGET'), findsOneWidget);

        // 2. Section Header & Active Goals
        expect(find.text('ACTIVE GOALS'), findsOneWidget);
        expect(find.text('Life Getter'), findsWidgets);
        expect(find.text('Life Starter'), findsOneWidget);

        // 3. Goal Card Details
        expect(find.text('CURRENTLY SAVED'), findsWidgets);
        expect(find.text('TARGET'), findsWidgets);
        expect(find.text('6% FUNDED'), findsOneWidget);
        expect(find.text('1% FUNDED'), findsOneWidget);
        expect(find.text('Deposit'), findsWidgets);
        expect(find.text('Edit'), findsWidgets);
        expect(find.text('View Details'), findsWidgets);

        // 4. Strategy Insight Card
        expect(find.text('SAVINGS STRATEGY'), findsOneWidget);
        expect(find.text('PORTFOLIO PACE'), findsOneWidget);
        expect(find.text('MONTHLY COMMITMENT'), findsOneWidget);
        expect(find.text('NEXT MILESTONE DUE'), findsOneWidget);

        // 5. Explore Milestones (Starter Suggestions)
        expect(find.text('EXPLORE MILESTONES'), findsOneWidget);
        expect(find.text('Emergency Fund'), findsOneWidget);
        expect(find.text('Vacation Trip'), findsOneWidget);
        expect(find.text('New Vehicle'), findsOneWidget);
        expect(find.text('Tech Upgrade'), findsOneWidget);
      },
    );

    testWidgets('renders completed section when goals are achieved', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final now = DateTime.now();
      final goals = [
        SavingsGoal(
          id: 'goal-completed',
          name: 'MacBook Pro',
          targetAmount: 200000000,
          currentAmount: 200000000,
          targetDate: now.subtract(const Duration(days: 10)),
          color: '#10B981',
          icon: 'laptop',
          isCompleted: true,
          trackerId: 'test-tracker-id',
          createdAt: now,
        ),
      ];

      await tester.pumpWidget(
        createTestWidget(goals: goals, totalSaved: 200000000),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('COMPLETED MILESTONES'), findsOneWidget);
      expect(find.text('COMPLETED'), findsWidgets);
      expect(find.text('MacBook Pro'), findsOneWidget);
      expect(find.text('Goal achieved!'), findsOneWidget);
    });

    testWidgets('tapping quick deposit opens deposit bottom sheet', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final now = DateTime.now();
      final goals = [
        SavingsGoal(
          id: 'goal-1',
          name: 'Life Getter',
          targetAmount: 300000000,
          currentAmount: 19100000,
          targetDate: now.add(const Duration(days: 110)),
          color: '#2563EB',
          icon: 'piggy-bank',
          isCompleted: false,
          trackerId: 'test-tracker-id',
          createdAt: now,
        ),
      ];

      await tester.pumpWidget(createTestWidget(goals: goals));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // Tap "Deposit"
      await tester.tap(find.text('Deposit').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify sheet opened
      expect(find.text('Deposit into Life Getter'), findsOneWidget);
      expect(find.text('DEPOSIT AMOUNT'), findsOneWidget);
      expect(find.text('Confirm Deposit'), findsOneWidget);
      expect(find.text('+10,000'), findsOneWidget);
      expect(find.text('+50,000'), findsOneWidget);

      // Dismiss sheet
      Navigator.of(tester.element(find.text('Confirm Deposit'))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    });
  });
}
