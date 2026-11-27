import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/presentation/recurring/utils/recurring_schedule_helpers.dart';

RecurringTransaction _makeRecurring({
  required String id,
  required String type,
  required int amount,
  required DateTime nextDate,
  String frequency = 'monthly',
  int intervalValue = 1,
  String status = 'active',
  DateTime? lastPaidAt,
  int totalPaid = 0,
  int paymentCount = 0,
}) {
  final now = DateTime(2026, 11, 21);
  return RecurringTransaction(
    id: id,
    accountId: 'acc-1',
    categoryId: null,
    amount: amount,
    type: type,
    description: id,
    frequency: frequency,
    intervalValue: intervalValue,
    nextDate: nextDate,
    endDate: null,
    status: status,
    trackerId: 'default',
    merchantKeywords: null,
    lastPaidAt: lastPaidAt,
    totalPaid: totalPaid,
    paymentCount: paymentCount,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final today = DateTime(2026, 11, 21);

  group('nextPaydayFor & projectUpcomingPaydays', () {
    test('projects chronological paydays across multiple monthly incomes', () {
      final incomes = [
        _makeRecurring(
          id: 'sal-27',
          type: 'income',
          amount: 145000,
          nextDate: DateTime(2026, 11, 27),
        ),
        _makeRecurring(
          id: 'sal-13',
          type: 'income',
          amount: 145000,
          nextDate: DateTime(2026, 12, 13),
        ),
        _makeRecurring(
          id: 'paused-inc',
          type: 'income',
          amount: 50000,
          nextDate: DateTime(2026, 11, 22),
          status: 'paused',
        ),
      ];

      final next = nextPaydayFor(incomes, now: today);
      expect(next, DateTime(2026, 11, 27));

      final projected = projectUpcomingPaydays(incomes, count: 3, now: today);
      expect(projected.length, 3);
      expect(projected[0].date, DateTime(2026, 11, 27));
      expect(projected[1].date, DateTime(2026, 12, 13));
      expect(projected[2].date, DateTime(2026, 12, 27));
    });

    test('rolls forward past income nextDate to upcoming date', () {
      final incomes = [
        _makeRecurring(
          id: 'weekly-inc',
          type: 'income',
          amount: 50000,
          frequency: 'weekly',
          nextDate: DateTime(2026, 11, 10),
        ),
      ];

      final next = nextPaydayFor(incomes, now: today);
      expect(next, DateTime(2026, 11, 24));
    });

    test('paydayScheduleSubtitle formats 13th and 27th', () {
      final incomes = [
        _makeRecurring(
          id: 'sal-27',
          type: 'income',
          amount: 145000,
          nextDate: DateTime(2026, 11, 27),
        ),
        _makeRecurring(
          id: 'sal-13',
          type: 'income',
          amount: 145000,
          nextDate: DateTime(2026, 12, 13),
        ),
      ];

      expect(paydayScheduleSubtitle(incomes), 'every 13th and 27th');
    });
  });

  group('classifyUpcomingBills', () {
    test('classifies dueNow, dueBeforePayday, upcomingLater, paidThisMonth, inactive', () {
      final nextPayday = DateTime(2026, 11, 27);
      final items = [
        _makeRecurring(
          id: 'due-today',
          type: 'expense',
          amount: 2500,
          nextDate: DateTime(2026, 11, 21),
        ),
        _makeRecurring(
          id: 'before-payday',
          type: 'expense',
          amount: 7900,
          nextDate: DateTime(2026, 11, 23),
        ),
        _makeRecurring(
          id: 'after-payday',
          type: 'expense',
          amount: 50000,
          nextDate: DateTime(2026, 12, 1),
          lastPaidAt: DateTime(2026, 11, 1),
          totalPaid: 50000,
          paymentCount: 1,
        ),
        _makeRecurring(
          id: 'paused-bill',
          type: 'expense',
          amount: 1500,
          nextDate: DateTime(2026, 11, 22),
          status: 'paused',
        ),
      ];

      final classified = classifyUpcomingBills(
        items,
        nextPayday: nextPayday,
        now: today,
      );

      expect(classified.hasPaydayAnchor, isTrue);
      expect(classified.dueNow.map((e) => e.id), ['due-today']);
      expect(classified.dueBeforePayday.map((e) => e.id), ['before-payday']);
      expect(classified.upcomingLater.map((e) => e.id), ['after-payday']);
      expect(classified.paidThisMonth.map((e) => e.id), ['after-payday']);
      expect(classified.inactive.map((e) => e.id), ['paused-bill']);
      expect(classified.toPayTotalCents, 10400);
    });
  });

  group('buildBalanceStepPoints & relativeDayLabel', () {
    test('builds stepped balance points across bill dates', () {
      final bills = [
        _makeRecurring(
          id: 'b1',
          type: 'expense',
          amount: 7900,
          nextDate: DateTime(2026, 11, 23),
        ),
        _makeRecurring(
          id: 'b2',
          type: 'expense',
          amount: 3500,
          nextDate: DateTime(2026, 11, 25),
        ),
      ];

      final points = buildBalanceStepPoints(
        currentBalanceCents: 144000,
        bills: bills,
        start: DateTime(2026, 11, 21),
        end: DateTime(2026, 11, 27),
      );

      expect(points.first.balanceAfterCents, 144000);
      expect(points[1].date, DateTime(2026, 11, 23));
      expect(points[1].dropCents, 7900);
      expect(points[1].balanceAfterCents, 136100);
      expect(points[2].date, DateTime(2026, 11, 25));
      expect(points[2].dropCents, 3500);
      expect(points[2].balanceAfterCents, 132600);
      expect(points.last.date, DateTime(2026, 11, 27));
      expect(points.last.balanceAfterCents, 132600);
    });

    test('relativeDayLabel formats today, tomorrow, future, and overdue', () {
      expect(relativeDayLabel(DateTime(2026, 11, 21), now: today), 'Today');
      expect(relativeDayLabel(DateTime(2026, 11, 22), now: today), 'Tomorrow');
      expect(relativeDayLabel(DateTime(2026, 11, 27), now: today), 'in 6 days');
      expect(
        relativeDayLabel(DateTime(2026, 11, 19), now: today),
        '2d overdue',
      );
    });
  });
}
