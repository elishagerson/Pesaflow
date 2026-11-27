import 'package:intl/intl.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/presentation/recurring/utils/recurring_schedule_helpers.dart';

enum AffordabilityStatus {
  affordableToday,
  bestAfterPayday,
  needsAdjustment,
  notSupported,
}

class SpareMilestone {
  final String label;
  final DateTime date;
  final int spareCents;
  final bool isHighlighted;

  const SpareMilestone({
    required this.label,
    required this.date,
    required this.spareCents,
    this.isHighlighted = false,
  });
}

class AffordabilityResult {
  final AffordabilityStatus status;
  final String headline;
  final String subtitle;
  final List<SpareMilestone> milestones;
  final List<String> suggestions;
  final DateTime? recommendedDate;

  const AffordabilityResult({
    required this.status,
    required this.headline,
    required this.subtitle,
    required this.milestones,
    required this.suggestions,
    this.recommendedDate,
  });
}

/// Evaluates whether an item of [priceCents] is affordable today, after an
/// upcoming payday, with budget adjustments, or not supported by current data.
AffordabilityResult evaluateAffordability({
  required int priceCents,
  required int currentBalanceCents,
  required List<RecurringTransaction> allRecurring,
  int estimatedDailySpendCents = 0,
  int remainingBudgetHeadroomCents = 0,
  DateTime? now,
}) {
  final today = dateOnly(now ?? DateTime.now());
  final nextPayday = nextPaydayFor(allRecurring, now: today);
  final paydays = projectUpcomingPaydays(allRecurring, count: 2, now: today);
  final classified = classifyUpcomingBills(
    allRecurring,
    nextPayday: nextPayday,
    now: today,
  );

  final activeExpenses = allRecurring
      .where((r) => r.type == 'expense' && r.status == 'active')
      .toList();

  final todaySpare = currentBalanceCents - classified.toPayTotalCents;
  final dateFmt = DateFormat('EEE d');
  final fullDateFmt = DateFormat('EEE d MMM');

  final milestones = <SpareMilestone>[
    SpareMilestone(
      label: 'Today',
      date: today,
      spareCents: todaySpare,
      isHighlighted: todaySpare >= priceCents,
    ),
  ];

  // Project spare cash at the next 2 paydays (or +14d / +30d if no payday set).
  if (paydays.isNotEmpty) {
    var runningSpare = todaySpare;
    var cursorDate = today;

    for (int i = 0; i < paydays.length; i++) {
      final p = paydays[i];
      final daysBetween = p.date.difference(cursorDate).inDays.clamp(0, 365);

      // Bills falling strictly after cursorDate and on/before p.date
      // (Today's bills before payday[0] are already deducted in todaySpare).
      int extraBills = 0;
      if (i > 0) {
        for (final bill in activeExpenses) {
          final due = dateOnly(bill.nextDate);
          if (due.isAfter(cursorDate) && !due.isAfter(p.date)) {
            extraBills += bill.amount;
          }
        }
      }

      final burn = estimatedDailySpendCents * daysBetween;
      runningSpare = runningSpare + p.source.amount - extraBills - burn;

      milestones.add(
        SpareMilestone(
          label: i == 0 ? dateFmt.format(p.date) : fullDateFmt.format(p.date),
          date: p.date,
          spareCents: runningSpare,
          isHighlighted:
              i == 0 && todaySpare < priceCents && runningSpare >= priceCents,
        ),
      );
      cursorDate = p.date;
    }

    // Ensure 3 bars for visual balance if only 1 payday occurrence was returned.
    if (milestones.length == 2) {
      final last = milestones.last;
      final extraDate = last.date.add(const Duration(days: 14));
      milestones.add(
        SpareMilestone(
          label: fullDateFmt.format(extraDate),
          date: extraDate,
          spareCents: last.spareCents,
        ),
      );
    }
  } else {
    // No recurring income configured: show +14d and +30d estimates.
    final d14 = today.add(const Duration(days: 14));
    final d30 = today.add(const Duration(days: 30));
    final bills14 = _billsInRange(
      activeExpenses,
      today.add(const Duration(days: 7)),
      d14,
    );
    final bills30 = _billsInRange(activeExpenses, d14, d30);
    final spare14 = todaySpare - bills14 - (estimatedDailySpendCents * 14);
    final spare30 = spare14 - bills30 - (estimatedDailySpendCents * 16);

    milestones.add(
      SpareMilestone(
        label: dateFmt.format(d14),
        date: d14,
        spareCents: spare14,
      ),
    );
    milestones.add(
      SpareMilestone(
        label: fullDateFmt.format(d30),
        date: d30,
        spareCents: spare30,
      ),
    );
  }

  final suggestions = <String>[];

  // Case 1: Affordable right now.
  if (todaySpare >= priceCents) {
    final afterPurchase = todaySpare - priceCents;
    if (remainingBudgetHeadroomCents > 0 &&
        priceCents > remainingBudgetHeadroomCents) {
      suggestions.add(
        'Cash covers this purchase, though it exceeds your remaining active budget (${CurrencyFormatter.formatCompact(remainingBudgetHeadroomCents)}).',
      );
    } else if (remainingBudgetHeadroomCents > 0) {
      suggestions.add(
        'Fits within your remaining budget headroom (${CurrencyFormatter.formatCompact(remainingBudgetHeadroomCents)}).',
      );
    }
    return AffordabilityResult(
      status: AffordabilityStatus.affordableToday,
      headline: 'You can afford it today',
      subtitle:
          'You will still have ${CurrencyFormatter.formatCompact(afterPurchase)} spare after upcoming bills.',
      milestones: milestones,
      suggestions: suggestions,
      recommendedDate: today,
    );
  }

  // Case 2: Affordable after the 1st or 2nd payday.
  if (paydays.isNotEmpty) {
    for (int i = 1; i < milestones.length; i++) {
      if (milestones[i].spareCents >= priceCents) {
        final target = milestones[i];
        final dayName = DateFormat('EEEE').format(target.date);
        final afterPurchase = target.spareCents - priceCents;
        suggestions.add(
          'Wait until ${fullDateFmt.format(target.date)} — you will have ${CurrencyFormatter.formatCompact(afterPurchase)} left after buying.',
        );
        if (todaySpare < 0) {
          suggestions.add(
            'Right now, upcoming bills exceed your balance by ${CurrencyFormatter.formatCompact(todaySpare.abs())}.',
          );
        }
        return AffordabilityResult(
          status: AffordabilityStatus.bestAfterPayday,
          headline: i == 1
              ? 'Best after payday'
              : 'Best after ${dateFmt.format(target.date)}',
          subtitle:
              'After $dayName you will have ${CurrencyFormatter.formatCompact(target.spareCents)} spare.',
          milestones: milestones,
          suggestions: suggestions,
          recommendedDate: target.date,
        );
      }
    }
  }

  // Case 3: Needs adjustment (shortfall is bridgeable or no payday yet but positive balance).
  final bestFuture = milestones
      .skip(1)
      .fold<SpareMilestone>(
        milestones.first,
        (a, b) => b.spareCents > a.spareCents ? b : a,
      );

  if (paydays.isEmpty && currentBalanceCents <= 0) {
    return AffordabilityResult(
      status: AffordabilityStatus.notSupported,
      headline: 'Not enough data yet',
      subtitle:
          'Your current balance is ${CurrencyFormatter.formatCompact(currentBalanceCents)} and no recurring payday is set.',
      milestones: milestones,
      suggestions: [
        'Add your salary or income in the Payday tab so PesaFlow can project future spare cash.',
        'Or add this item as a Savings Goal to set aside ${CurrencyFormatter.formatCompact((priceCents / 4).ceil())}/week.',
      ],
    );
  }

  if (bestFuture.spareCents <= 0 && todaySpare <= 0) {
    return AffordabilityResult(
      status: AffordabilityStatus.notSupported,
      headline: 'Not supported right now',
      subtitle: 'Current balance and upcoming income are fully committed to bills and daily spending.',
      milestones: milestones,
      suggestions: [
        'Upcoming bills leave ${CurrencyFormatter.formatCompact(todaySpare)} spare today.',
        'Pause a non-essential subscription or create a Savings Goal for ${CurrencyFormatter.formatCompact(priceCents)}.',
      ],
    );
  }

  // Bridgeable shortfall -> concrete adjustment plan.
  final shortfall = (priceCents - bestFuture.spareCents).clamp(1, priceCents);
  final daysWindow = bestFuture.date.difference(today).inDays.clamp(7, 60);
  final dailyTrim = (shortfall / daysWindow).ceil();
  final weeklySave = (priceCents / 4).ceil();

  suggestions.add(
    'Trim daily discretionary spending by ${CurrencyFormatter.formatCompact(dailyTrim)}/day to close the ${CurrencyFormatter.formatCompact(shortfall)} gap by ${fullDateFmt.format(bestFuture.date)}.',
  );
  suggestions.add(
    'Or save ${CurrencyFormatter.formatCompact(weeklySave)}/week for 4 weeks in a dedicated Savings Goal.',
  );
  if (remainingBudgetHeadroomCents > 0) {
    suggestions.add(
      'You currently have ${CurrencyFormatter.formatCompact(remainingBudgetHeadroomCents)} left in active budgets that could be reallocated.',
    );
  }

  return AffordabilityResult(
    status: AffordabilityStatus.needsAdjustment,
    headline: 'Adjust to afford it',
    subtitle:
        'You are ${CurrencyFormatter.formatCompact(shortfall)} short of ${CurrencyFormatter.formatCompact(priceCents)} by ${dateFmt.format(bestFuture.date)}.',
    milestones: milestones,
    suggestions: suggestions,
    recommendedDate: bestFuture.date,
  );
}

int _billsInRange(
  List<RecurringTransaction> activeExpenses,
  DateTime exclusiveStart,
  DateTime inclusiveEnd,
) {
  int total = 0;
  for (final bill in activeExpenses) {
    final due = dateOnly(bill.nextDate);
    if (due.isAfter(exclusiveStart) && !due.isAfter(inclusiveEnd)) {
      total += bill.amount;
    }
  }
  return total;
}
