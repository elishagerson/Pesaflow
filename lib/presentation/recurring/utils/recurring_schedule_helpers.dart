import 'package:pesaflow/core/utils/frequency_helpers.dart';
import 'package:pesaflow/data/database/app_database.dart';

/// Projected payday occurrence with its source recurring income.
class PaydayOccurrence {
  final DateTime date;
  final RecurringTransaction source;

  const PaydayOccurrence({required this.date, required this.source});
}

/// Classification of recurring expense bills relative to today and the next payday.
class ClassifiedBills {
  /// Active bills whose nextDate is today or overdue.
  final List<RecurringTransaction> dueNow;

  /// Active bills due after today and on/before the next payday
  /// (or within the next 7 days when no payday is configured).
  final List<RecurringTransaction> dueBeforePayday;

  /// Active bills due after the next payday (or after 7 days when no payday).
  final List<RecurringTransaction> upcomingLater;

  /// Bills that were paid at least once in the current calendar month.
  final List<RecurringTransaction> paidThisMonth;

  /// Paused or cancelled expense flows.
  final List<RecurringTransaction> inactive;

  /// Whether classification is anchored to an active recurring payday.
  final bool hasPaydayAnchor;

  const ClassifiedBills({
    required this.dueNow,
    required this.dueBeforePayday,
    required this.upcomingLater,
    required this.paidThisMonth,
    required this.inactive,
    required this.hasPaydayAnchor,
  });

  /// All active bills due now or before payday (the "to pay" total).
  List<RecurringTransaction> get toPayBeforePayday => [
        ...dueNow,
        ...dueBeforePayday,
      ];

  int get toPayTotalCents =>
      toPayBeforePayday.fold<int>(0, (sum, r) => sum + r.amount);

  int get paidThisMonthTotalCents => paidThisMonth.fold<int>(
        0,
        (sum, r) => sum + (r.totalPaid > 0 && r.paymentCount == 1 ? r.totalPaid : r.amount),
      );
}

/// A single step on the projected balance-after-bills chart.
class BalanceStepPoint {
  final DateTime date;
  final int balanceAfterCents;
  final int dropCents;
  final String? label;

  const BalanceStepPoint({
    required this.date,
    required this.balanceAfterCents,
    required this.dropCents,
    this.label,
  });
}

/// Normalizes a [DateTime] to midnight in local time.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Advances [from] by one cycle using the same calendar rules as the DAO.
DateTime advanceRecurringDate(DateTime from, String frequency, int interval) {
  final step = interval < 1 ? 1 : interval;
  switch (frequency) {
    case 'weekly':
      return DateTime(from.year, from.month, from.day + 7 * step);
    case 'biweekly':
      return DateTime(from.year, from.month, from.day + 14 * step);
    case 'monthly':
      return _addMonths(from, step);
    case 'quarterly':
      return _addMonths(from, 3 * step);
    case 'yearly':
      final targetYear = from.year + step;
      final lastDay = DateTime(targetYear, from.month + 1, 0).day;
      final clampedDay = from.day.clamp(1, lastDay);
      return DateTime(targetYear, from.month, clampedDay);
    default:
      return _addMonths(from, step);
  }
}

DateTime _addMonths(DateTime from, int months) {
  final targetMonth = from.month + months;
  final targetYear = from.year + ((targetMonth - 1) ~/ 12);
  final monthInYear = ((targetMonth - 1) % 12) + 1;
  final lastDay = DateTime(targetYear, monthInYear + 1, 0).day;
  final clampedDay = from.day.clamp(1, lastDay);
  return DateTime(targetYear, monthInYear, clampedDay);
}

/// Returns the earliest upcoming (or today's) payday from active income flows.
DateTime? nextPaydayFor(
  List<RecurringTransaction> allRecurring, {
  DateTime? now,
}) {
  final today = dateOnly(now ?? DateTime.now());
  final activeIncomes = allRecurring.where(
    (r) => r.type == 'income' && r.status == 'active',
  );
  DateTime? earliest;
  for (final income in activeIncomes) {
    var candidate = dateOnly(income.nextDate);
    // If an income's stored nextDate is in the past, roll it forward to today or later.
    int guard = 0;
    while (candidate.isBefore(today) && guard < 120) {
      candidate = dateOnly(
        advanceRecurringDate(candidate, income.frequency, income.intervalValue),
      );
      guard++;
    }
    if (income.endDate != null && candidate.isAfter(dateOnly(income.endDate!))) {
      continue;
    }
    if (earliest == null || candidate.isBefore(earliest)) {
      earliest = candidate;
    }
  }
  return earliest;
}

/// Projects the next [count] chronological payday occurrences across all active incomes.
List<PaydayOccurrence> projectUpcomingPaydays(
  List<RecurringTransaction> allRecurring, {
  int count = 3,
  DateTime? now,
}) {
  final today = dateOnly(now ?? DateTime.now());
  final activeIncomes = allRecurring.where(
    (r) => r.type == 'income' && r.status == 'active',
  );

  final allOccurrences = <PaydayOccurrence>[];
  for (final income in activeIncomes) {
    var current = dateOnly(income.nextDate);
    int guard = 0;
    while (current.isBefore(today) && guard < 120) {
      current = dateOnly(
        advanceRecurringDate(current, income.frequency, income.intervalValue),
      );
      guard++;
    }

    for (int i = 0; i < count; i++) {
      if (income.endDate != null &&
          current.isAfter(dateOnly(income.endDate!))) {
        break;
      }
      allOccurrences.add(PaydayOccurrence(date: current, source: income));
      current = dateOnly(
        advanceRecurringDate(current, income.frequency, income.intervalValue),
      );
    }
  }

  allOccurrences.sort((a, b) => a.date.compareTo(b.date));
  return allOccurrences.take(count).toList();
}

/// Builds a concise schedule subtitle like "every 13th and 27th" or "Every month on the 27th".
String paydayScheduleSubtitle(List<RecurringTransaction> activeIncomes) {
  if (activeIncomes.isEmpty) return 'No income schedule set';

  final allMonthly = activeIncomes.every(
    (r) => r.frequency == 'monthly' && r.intervalValue == 1,
  );
  if (allMonthly) {
    final days = activeIncomes.map((r) => r.nextDate.day).toSet().toList()
      ..sort();
    if (days.length == 1) {
      return 'every ${_ordinal(days.first)} of the month';
    }
    if (days.length == 2) {
      return 'every ${_ordinal(days[0])} and ${_ordinal(days[1])}';
    }
    final head = days.take(days.length - 1).map(_ordinal).join(', ');
    return 'every $head and ${_ordinal(days.last)}';
  }

  if (activeIncomes.length == 1) {
    final single = activeIncomes.first;
    return frequencyLabel(single.frequency, single.intervalValue).toLowerCase();
  }

  return '${activeIncomes.length} active income streams';
}

String _ordinal(int day) {
  if (day >= 11 && day <= 13) return '${day}th';
  return switch (day % 10) {
    1 => '${day}st',
    2 => '${day}nd',
    3 => '${day}rd',
    _ => '${day}th',
  };
}

/// Classifies expense recurring transactions into upcoming payment buckets.
ClassifiedBills classifyUpcomingBills(
  List<RecurringTransaction> allRecurring, {
  DateTime? nextPayday,
  DateTime? now,
}) {
  final today = dateOnly(now ?? DateTime.now());
  final windowEnd = nextPayday != null
      ? dateOnly(nextPayday)
      : today.add(const Duration(days: 7));

  final expenses = allRecurring.where((r) => r.type == 'expense').toList();

  final dueNow = <RecurringTransaction>[];
  final dueBeforePayday = <RecurringTransaction>[];
  final upcomingLater = <RecurringTransaction>[];
  final paidThisMonth = <RecurringTransaction>[];
  final inactive = <RecurringTransaction>[];

  for (final bill in expenses) {
    if (bill.lastPaidAt != null &&
        bill.lastPaidAt!.year == today.year &&
        bill.lastPaidAt!.month == today.month) {
      paidThisMonth.add(bill);
    }

    if (bill.status != 'active') {
      inactive.add(bill);
      continue;
    }

    final due = dateOnly(bill.nextDate);
    if (!due.isAfter(today)) {
      dueNow.add(bill);
    } else if (!due.isAfter(windowEnd)) {
      dueBeforePayday.add(bill);
    } else {
      upcomingLater.add(bill);
    }
  }

  dueNow.sort((a, b) => a.nextDate.compareTo(b.nextDate));
  dueBeforePayday.sort((a, b) => a.nextDate.compareTo(b.nextDate));
  upcomingLater.sort((a, b) => a.nextDate.compareTo(b.nextDate));
  paidThisMonth.sort(
    (a, b) => (b.lastPaidAt ?? b.nextDate).compareTo(a.lastPaidAt ?? a.nextDate),
  );

  return ClassifiedBills(
    dueNow: dueNow,
    dueBeforePayday: dueBeforePayday,
    upcomingLater: upcomingLater,
    paidThisMonth: paidThisMonth,
    inactive: inactive,
    hasPaydayAnchor: nextPayday != null,
  );
}

/// Builds step-down balance points from [start] to [end] as each bill falls due.
List<BalanceStepPoint> buildBalanceStepPoints({
  required int currentBalanceCents,
  required List<RecurringTransaction> bills,
  required DateTime start,
  required DateTime end,
}) {
  final startDay = dateOnly(start);
  final endDay = dateOnly(end).isBefore(startDay) ? startDay : dateOnly(end);

  // Group bills by clamped day within [startDay, endDay].
  final dropsByDay = <DateTime, int>{};
  final sortedBills = List<RecurringTransaction>.from(bills)
    ..sort((a, b) => a.nextDate.compareTo(b.nextDate));

  for (final bill in sortedBills) {
    var d = dateOnly(bill.nextDate);
    if (d.isBefore(startDay)) d = startDay;
    if (d.isAfter(endDay)) d = endDay;
    dropsByDay[d] = (dropsByDay[d] ?? 0) + bill.amount;
  }

  final points = <BalanceStepPoint>[];
  var runningBalance = currentBalanceCents;

  final initialDrop = dropsByDay[startDay] ?? 0;
  runningBalance -= initialDrop;
  points.add(
    BalanceStepPoint(
      date: startDay,
      balanceAfterCents: runningBalance,
      dropCents: initialDrop,
    ),
  );

  final sortedDays = dropsByDay.keys.where((d) => d.isAfter(startDay)).toList()
    ..sort();
  for (final day in sortedDays) {
    final drop = dropsByDay[day]!;
    runningBalance -= drop;
    points.add(
      BalanceStepPoint(
        date: day,
        balanceAfterCents: runningBalance,
        dropCents: drop,
      ),
    );
  }

  if (points.last.date.isBefore(endDay)) {
    points.add(
      BalanceStepPoint(
        date: endDay,
        balanceAfterCents: runningBalance,
        dropCents: 0,
      ),
    );
  }

  return points;
}

/// Human-friendly relative day label ("Today", "Tomorrow", "in 3 days", "2d overdue").
String relativeDayLabel(DateTime targetDate, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final target = dateOnly(targetDate);
  final diff = target.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff < 0) return '${diff.abs()}d overdue';
  return 'in $diff days';
}
