import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/services/auto_budget_service.dart';

void main() {
  group('distributeAmount', () {
    test('distributes evenly when percentages are equal', () {
      final result = distributeAmount(100, [0.5, 0.5]);
      expect(result, [50, 50]);
    });

    test('handles single allocation', () {
      final result = distributeAmount(1000, [1.0]);
      expect(result, [1000]);
    });

    test('no rounding loss — sum equals total', () {
      final result = distributeAmount(333333, [0.38, 0.25, 0.20, 0.10, 0.07]);
      expect(result.reduce((a, b) => a + b), 333333);
    });

    test('remainder goes to largest percentage first', () {
      final result = distributeAmount(100, [0.34, 0.33, 0.33]);
      expect(result.reduce((a, b) => a + b), 100);
      expect(result[0], 34);
      expect(result[1], 33);
      expect(result[2], 33);
    });

    test('handles zero total', () {
      final result = distributeAmount(0, [0.5, 0.3, 0.2]);
      expect(result, [0, 0, 0]);
    });

    test('handles empty percentages', () {
      final result = distributeAmount(1000, []);
      expect(result, isEmpty);
    });

    test('rounds down for tiny allocations', () {
      final result = distributeAmount(100, [0.99, 0.005, 0.005]);
      expect(result.reduce((a, b) => a + b), 100);
      expect(result[0], 99);
      expect(result[1], 1);
      expect(result[2], 0);
    });

    test('distributes 50/30/20 across 12 sub-allocations without loss', () {
      final needs = [0.38, 0.25, 0.20, 0.10, 0.07];
      final wants = [0.167, 0.30, 0.20, 0.333];
      final savings = [0.50, 0.25, 0.25];

      final income = 1000000;
      final needsAmount = (income * 0.50).round();
      final wantsAmount = (income * 0.30).round();
      final savingsAmount = (income * 0.20).round();

      final needsResult = distributeAmount(needsAmount, needs);
      final wantsResult = distributeAmount(wantsAmount, wants);
      final savingsResult = distributeAmount(savingsAmount, savings);

      expect(needsResult.reduce((a, b) => a + b), needsAmount);
      expect(wantsResult.reduce((a, b) => a + b), wantsAmount);
      expect(savingsResult.reduce((a, b) => a + b), savingsAmount);
      expect(
        needsAmount + wantsAmount + savingsAmount,
        income,
      );
    });
  });

  group('SubAllocation', () {
    test('serializes and deserializes correctly', () {
      const sub = SubAllocation(
        name: 'Rent',
        percentage: 0.38,
        categoryId: 'cat-123',
      );
      final json = sub.toJson();
      final restored = SubAllocation.fromJson(json);

      expect(restored.name, 'Rent');
      expect(restored.percentage, 0.38);
      expect(restored.categoryId, 'cat-123');
    });

    test('handles null categoryId', () {
      const sub = SubAllocation(name: 'Food', percentage: 0.25);
      final json = sub.toJson();
      expect(json.containsKey('categoryId'), isFalse);

      final restored = SubAllocation.fromJson(json);
      expect(restored.categoryId, isNull);
    });

    test('copyWith preserves original when no args', () {
      const sub = SubAllocation(name: 'Rent', percentage: 0.38, categoryId: 'a');
      final copy = sub.copyWith();
      expect(copy.name, 'Rent');
      expect(copy.percentage, 0.38);
      expect(copy.categoryId, 'a');
    });

    test('copyWith overrides categoryId', () {
      const sub = SubAllocation(name: 'Rent', percentage: 0.38, categoryId: 'a');
      final copy = sub.copyWith(categoryId: 'b');
      expect(copy.categoryId, 'b');
    });
  });

  group('BudgetGroupConfig', () {
    test('isValid when sub-allocations sum to 1.0', () {
      const group = BudgetGroupConfig(
        name: 'Needs',
        percentage: 0.50,
        subAllocations: [
          SubAllocation(name: 'A', percentage: 0.6),
          SubAllocation(name: 'B', percentage: 0.4),
        ],
      );
      expect(group.isValid, isTrue);
    });

    test('is invalid when sub-allocations don\'t sum to 1.0', () {
      const group = BudgetGroupConfig(
        name: 'Needs',
        percentage: 0.50,
        subAllocations: [
          SubAllocation(name: 'A', percentage: 0.3),
          SubAllocation(name: 'B', percentage: 0.3),
        ],
      );
      expect(group.isValid, isFalse);
    });

    test('is invalid with empty sub-allocations', () {
      const group = BudgetGroupConfig(
        name: 'Needs',
        percentage: 0.50,
        subAllocations: [],
      );
      expect(group.isValid, isFalse);
    });

    test('totalSubPercentage sums correctly', () {
      const group = BudgetGroupConfig(
        name: 'Needs',
        percentage: 0.50,
        subAllocations: [
          SubAllocation(name: 'A', percentage: 0.38),
          SubAllocation(name: 'B', percentage: 0.25),
          SubAllocation(name: 'C', percentage: 0.20),
          SubAllocation(name: 'D', percentage: 0.10),
          SubAllocation(name: 'E', percentage: 0.07),
        ],
      );
      expect(group.totalSubPercentage, closeTo(1.0, 0.001));
    });

    test('serializes and deserializes', () {
      const group = BudgetGroupConfig(
        name: 'Needs',
        percentage: 0.50,
        subAllocations: [
          SubAllocation(name: 'Rent', percentage: 0.6, categoryId: 'x'),
          SubAllocation(name: 'Food', percentage: 0.4),
        ],
      );
      final json = group.toJson();
      final restored = BudgetGroupConfig.fromJson(json);

      expect(restored.name, 'Needs');
      expect(restored.percentage, 0.50);
      expect(restored.subAllocations.length, 2);
      expect(restored.subAllocations[0].categoryId, 'x');
      expect(restored.subAllocations[1].categoryId, isNull);
    });
  });

  group('AutoBudgetConfig', () {
    test('defaults are valid', () {
      final config = AutoBudgetConfig.defaults();
      expect(config.isValid, isTrue);
    });

    test('totalGroupPercentage sums to 1.0', () {
      final config = AutoBudgetConfig.defaults();
      expect(config.totalGroupPercentage, closeTo(1.0, 0.001));
    });

    test('isValid returns false when groups empty', () {
      const config = AutoBudgetConfig(
        enabled: true,
        incomeCategoryIds: [],
        groups: [],
      );
      expect(config.isValid, isFalse);
    });

    test('isValid returns false when group percentages wrong', () {
      const config = AutoBudgetConfig(
        enabled: true,
        incomeCategoryIds: [],
        groups: [
          BudgetGroupConfig(
            name: 'A',
            percentage: 0.30,
            subAllocations: [SubAllocation(name: 'X', percentage: 1.0)],
          ),
        ],
      );
      expect(config.isValid, isFalse);
    });

    test('validationErrors returns meaningful messages', () {
      const config = AutoBudgetConfig(
        enabled: true,
        incomeCategoryIds: [],
        groups: [
          BudgetGroupConfig(
            name: 'Needs',
            percentage: 0.50,
            subAllocations: [
              SubAllocation(name: 'A', percentage: 0.30),
              SubAllocation(name: 'B', percentage: 0.30),
            ],
          ),
          BudgetGroupConfig(
            name: 'Wants',
            percentage: 0.30,
            subAllocations: [],
          ),
        ],
      );
      final errors = config.validationErrors;
      expect(errors.length, 4);
      expect(errors[0], contains('80.0%'));
      expect(errors[1], contains('50.0%'));
      expect(errors[2], contains('60.0%'));
      expect(errors[3], contains('has no sub-allocations'));
    });

    test('serializes and deserializes defaults', () {
      final config = AutoBudgetConfig.defaults();
      final json = config.toJson();
      final restored = AutoBudgetConfig.fromJson(json);

      expect(restored.enabled, config.enabled);
      expect(restored.groups.length, config.groups.length);
      expect(restored.period, 'monthly');

      for (var i = 0; i < config.groups.length; i++) {
        expect(restored.groups[i].name, config.groups[i].name);
        expect(restored.groups[i].percentage, config.groups[i].percentage);
        expect(
          restored.groups[i].subAllocations.length,
          config.groups[i].subAllocations.length,
        );
      }
    });

    test('fromJson handles missing fields gracefully', () {
      final config = AutoBudgetConfig.fromJson({});
      expect(config.enabled, isFalse);
      expect(config.incomeCategoryIds, isEmpty);
      expect(config.groups, isEmpty);
      expect(config.period, 'monthly');
    });

    test('fromJson handles malformed JSON without throwing', () {
      expect(
        () => AutoBudgetConfig.fromJson({'enabled': 'not_a_bool'}),
        returnsNormally,
      );
    });
  });

  group('Default config category mapping', () {
    test('defaults cover all standard expense categories', () {
      final config = AutoBudgetConfig.defaults();
      final allSubNames = <String>{};
      for (final group in config.groups) {
        for (final sub in group.subAllocations) {
          allSubNames.add(sub.name);
        }
      }

      expect(allSubNames, contains('Rent'));
      expect(allSubNames, contains('Food & Groceries'));
      expect(allSubNames, contains('Transport'));
      expect(allSubNames, contains('Utilities'));
      expect(allSubNames, contains('Health'));
      expect(allSubNames, contains('Airtime & Data'));
      expect(allSubNames, contains('Shopping'));
      expect(allSubNames, contains('Entertainment'));
      expect(allSubNames, contains('Savings'));
      expect(allSubNames, contains('Loans'));
    });

    test('default sub-percentages per group sum to 1.0', () {
      final config = AutoBudgetConfig.defaults();
      for (final group in config.groups) {
        final sum = group.subAllocations.fold<double>(
          0,
          (s, sub) => s + sub.percentage,
        );
        expect(
          sum,
          closeTo(1.0, 0.001),
          reason: '${group.name} sub-percentages should sum to 1.0',
        );
      }
    });

    test('group percentages sum to 1.0', () {
      final config = AutoBudgetConfig.defaults();
      final sum = config.groups.fold<double>(
        0,
        (s, g) => s + g.percentage,
      );
      expect(sum, closeTo(1.0, 0.001));
    });
  });
}
