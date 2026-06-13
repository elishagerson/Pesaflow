import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/budget_dao.dart';
import 'package:pesaflow/domain/budget/budget_engine.dart';

void main() {
  group('BudgetEngine', () {
    group('computeStatus', () {
      test('calculates correct percentage for partial spend', () {
        final status = BudgetEngine.computeStatus(
          allocated: 30000000, // Tsh 300,000
          spent: 15000000,     // Tsh 150,000
          periodStart: DateTime.now().subtract(const Duration(days: 15)),
          periodEnd: DateTime.now().add(const Duration(days: 15)),
        );

        expect(status.percentage, closeTo(0.5, 0.01));
        expect(status.remaining, equals(15000000));
        expect(status.isOverBudget, isFalse);
      });

      test('detects over-budget when spent exceeds allocated', () {
        final status = BudgetEngine.computeStatus(
          allocated: 10000000, // Tsh 100,000
          spent: 12000000,     // Tsh 120,000
          periodStart: DateTime.now().subtract(const Duration(days: 20)),
          periodEnd: DateTime.now().add(const Duration(days: 10)),
        );

        expect(status.percentage, greaterThan(1.0));
        expect(status.remaining, lessThan(0));
        expect(status.isOverBudget, isTrue);
        expect(status.paceLabel, equals('Over budget'));
      });

      test('returns 0% for zero spending', () {
        final status = BudgetEngine.computeStatus(
          allocated: 50000000,
          spent: 0,
          periodStart: DateTime.now().subtract(const Duration(days: 1)),
          periodEnd: DateTime.now().add(const Duration(days: 29)),
        );

        expect(status.percentage, equals(0.0));
        expect(status.remaining, equals(50000000));
        expect(status.isOverBudget, isFalse);
      });

      test('computes days left correctly', () {
        final futureEnd = DateTime.now().add(const Duration(days: 10));
        final status = BudgetEngine.computeStatus(
          allocated: 10000000,
          spent: 5000000,
          periodStart: DateTime.now().subtract(const Duration(days: 20)),
          periodEnd: futureEnd,
        );

        expect(status.daysLeft, greaterThanOrEqualTo(9));
        expect(status.daysLeft, lessThanOrEqualTo(11));
      });

      test('handles zero allocation gracefully', () {
        final status = BudgetEngine.computeStatus(
          allocated: 0,
          spent: 5000000,
          periodStart: DateTime.now().subtract(const Duration(days: 5)),
          periodEnd: DateTime.now().add(const Duration(days: 25)),
        );

        // With zero allocation, percentage should be 0 (not infinity)
        expect(status.percentage, equals(0.0));
      });
    });

    group('computeRollover', () {
      test('rollover type "all" carries full remaining', () {
        final rollover = BudgetEngine.computeRollover(
          allocated: 30000000,
          spent: 20000000,
          rolloverType: 'all',
        );
        expect(rollover, equals(10000000)); // Tsh 100,000 remaining
      });

      test('rollover type "all" carries deficit (negative)', () {
        final rollover = BudgetEngine.computeRollover(
          allocated: 30000000,
          spent: 35000000,
          rolloverType: 'all',
        );
        expect(rollover, equals(-5000000)); // Tsh 50,000 deficit
      });

      test('rollover type "capped" limits positive carry-forward', () {
        final rollover = BudgetEngine.computeRollover(
          allocated: 30000000,
          spent: 20000000,
          rolloverType: 'capped',
          rolloverCap: 5000000, // Cap: Tsh 50,000
        );
        expect(rollover, equals(5000000)); // Capped at Tsh 50,000
      });

      test('rollover type "capped" still carries deficit', () {
        final rollover = BudgetEngine.computeRollover(
          allocated: 30000000,
          spent: 35000000,
          rolloverType: 'capped',
          rolloverCap: 5000000,
        );
        expect(rollover, equals(-5000000)); // Deficit carries even with cap
      });

      test('rollover type "none" returns 0', () {
        final rollover = BudgetEngine.computeRollover(
          allocated: 30000000,
          spent: 20000000,
          rolloverType: 'none',
        );
        expect(rollover, equals(0));
      });
    });

    group('checkThresholds', () {
      test('detects halfway at 50%', () {
        final alerts = BudgetEngine.checkThresholds(
          percentage: 0.55,
          notificationThreshold: 0.8,
        );
        expect(alerts, contains(BudgetAlert.halfway));
      });

      test('detects warning at threshold', () {
        final alerts = BudgetEngine.checkThresholds(
          percentage: 0.85,
          notificationThreshold: 0.8,
        );
        expect(alerts, contains(BudgetAlert.warning));
      });

      test('detects exceeded over 100%', () {
        final alerts = BudgetEngine.checkThresholds(
          percentage: 1.15,
          notificationThreshold: 0.8,
        );
        expect(alerts, contains(BudgetAlert.exceeded));
      });

      test('returns empty below 50%', () {
        final alerts = BudgetEngine.checkThresholds(
          percentage: 0.3,
          notificationThreshold: 0.8,
        );
        expect(alerts, isEmpty);
      });
    });

    group('checkBudgetThresholds', () {
      Category _cat(String id) => Category(
        id: id, name: 'Food', icon: 'cart', color: '#FF9800',
        type: 'expense', isSystem: true, sortOrder: 1, createdAt: DateTime.now(),
      );

      Budget _budget(String id, {int amount = 30000000, double threshold = 0.8}) => Budget(
        id: id, name: 'Food', categoryId: 'cat1',
        period: 'monthly', amount: amount,
        rollover: false, rolloverType: 'none',
        startDate: DateTime.now().subtract(const Duration(days: 15)),
        endDate: DateTime.now().add(const Duration(days: 15)),
        notificationThreshold: threshold,
        isActive: true, createdAt: DateTime.now(),
      );

      BudgetPeriod _period(String budgetId, int allocated, {int spent = 0}) => BudgetPeriod(
        id: 'p_$budgetId', budgetId: budgetId,
        periodStart: DateTime.now().subtract(const Duration(days: 15)),
        periodEnd: DateTime.now().add(const Duration(days: 15)),
        allocated: allocated, spent: spent,
        isClosed: false, createdAt: DateTime.now(),
      );

      test('no alerts when budgets are on track', () {
        final result = BudgetEngine.checkBudgetThresholds([
          BudgetWithProgress(
            budget: _budget('b1'),
            spentInPeriod: 5000000,
            category: _cat('cat1'),
            currentPeriod: _period('b1', 30000000),
          ),
        ]);

        expect(result.crossedThreshold, isEmpty);
        expect(result.exceeded, isEmpty);
        expect(result.projectedToExceed, isEmpty);
      });

      test('detects crossed threshold when percentage >= notificationThreshold', () {
        final result = BudgetEngine.checkBudgetThresholds([
          BudgetWithProgress(
            budget: _budget('b1'),
            spentInPeriod: 28000000,
            category: _cat('cat1'),
            currentPeriod: _period('b1', 30000000),
          ),
        ]);

        expect(result.crossedThreshold, contains('b1'));
        expect(result.exceeded, isEmpty);
      });

      test('detects exceeded when spent > allocated', () {
        final result = BudgetEngine.checkBudgetThresholds([
          BudgetWithProgress(
            budget: _budget('b2'),
            spentInPeriod: 35000000,
            category: _cat('cat1'),
            currentPeriod: _period('b2', 30000000),
          ),
        ]);

        expect(result.exceeded, contains('b2'));
      });

      test('handles empty budget list', () {
        final result = BudgetEngine.checkBudgetThresholds([]);
        expect(result.crossedThreshold, isEmpty);
        expect(result.exceeded, isEmpty);
        expect(result.projectedToExceed, isEmpty);
      });

      test('skips budgets without current period', () {
        final result = BudgetEngine.checkBudgetThresholds([
          BudgetWithProgress(
            budget: _budget('b3'),
            spentInPeriod: 0,
            category: _cat('cat1'),
            currentPeriod: null,
          ),
        ]);

        expect(result.crossedThreshold, isEmpty);
        expect(result.exceeded, isEmpty);
        expect(result.projectedToExceed, isEmpty);
      });
    });
  });
}
