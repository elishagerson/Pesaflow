import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/presentation/recurring/utils/affordability_calculator.dart';

RecurringTransaction _makeFlow({
  required String id,
  required String type,
  required int amount,
  required DateTime nextDate,
}) {
  final now = DateTime(2026, 11, 21);
  return RecurringTransaction(
    id: id,
    accountId: 'acc-1',
    categoryId: null,
    amount: amount,
    type: type,
    description: id,
    frequency: 'monthly',
    intervalValue: 1,
    nextDate: nextDate,
    endDate: null,
    status: 'active',
    trackerId: 'default',
    merchantKeywords: null,
    lastPaidAt: null,
    totalPaid: 0,
    paymentCount: 0,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final today = DateTime(2026, 11, 21);

  test('returns affordableToday when spare cash today covers item', () {
    final result = evaluateAffordability(
      priceCents: 12900,
      currentBalanceCents: 144000,
      allRecurring: [
        _makeFlow(
          id: 'bill-1',
          type: 'expense',
          amount: 62000,
          nextDate: DateTime(2026, 11, 25),
        ),
        _makeFlow(
          id: 'pay-1',
          type: 'income',
          amount: 145000,
          nextDate: DateTime(2026, 11, 27),
        ),
      ],
      now: today,
    );

    expect(result.status, AffordabilityStatus.affordableToday);
    expect(result.milestones.first.spareCents, 82000);
    expect(result.milestones.first.isHighlighted, isTrue);
  });

  test('returns bestAfterPayday when today is short but payday covers it', () {
    final result = evaluateAffordability(
      priceCents: 12900,
      currentBalanceCents: 65000,
      allRecurring: [
        _makeFlow(
          id: 'bill-1',
          type: 'expense',
          amount: 62000,
          nextDate: DateTime(2026, 11, 25),
        ),
        _makeFlow(
          id: 'pay-1',
          type: 'income',
          amount: 145000,
          nextDate: DateTime(2026, 11, 27),
        ),
      ],
      now: today,
    );

    expect(result.status, AffordabilityStatus.bestAfterPayday);
    expect(result.recommendedDate, DateTime(2026, 11, 27));
    expect(result.milestones[1].isHighlighted, isTrue);
  });

  test('returns needsAdjustment with concrete suggestions when shortfall is bridgeable', () {
    final result = evaluateAffordability(
      priceCents: 200000,
      currentBalanceCents: 50000,
      allRecurring: [
        _makeFlow(
          id: 'bill-1',
          type: 'expense',
          amount: 20000,
          nextDate: DateTime(2026, 11, 24),
        ),
        _makeFlow(
          id: 'pay-1',
          type: 'income',
          amount: 60000,
          nextDate: DateTime(2026, 11, 27),
        ),
      ],
      remainingBudgetHeadroomCents: 25000,
      now: today,
    );

    expect(result.status, AffordabilityStatus.needsAdjustment);
    expect(result.suggestions.length, greaterThanOrEqualTo(2));
  });

  test('returns notSupported when balance is 0 and no payday is configured', () {
    final result = evaluateAffordability(
      priceCents: 50000,
      currentBalanceCents: 0,
      allRecurring: const [],
      now: today,
    );

    expect(result.status, AffordabilityStatus.notSupported);
    expect(result.suggestions, isNotEmpty);
  });
}
