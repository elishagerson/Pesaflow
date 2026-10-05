import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class NotificationCounts {
  final int pendingSmsCount;
  final int dueBillsCount;
  final int budgetAlertsCount;
  final int savingsRemindersCount;
  final int dueLoansCount;

  const NotificationCounts({
    this.pendingSmsCount = 0,
    this.dueBillsCount = 0,
    this.budgetAlertsCount = 0,
    this.savingsRemindersCount = 0,
    this.dueLoansCount = 0,
  });

  int get total =>
      pendingSmsCount +
      dueBillsCount +
      budgetAlertsCount +
      savingsRemindersCount +
      dueLoansCount;
}

final notificationCountsProvider = Provider<NotificationCounts>((ref) {
  final reviewQueue = ref.watch(reviewQueueStreamProvider).value ?? [];
  final dueBills = ref.watch(dueRecurringTransactionsProvider).value ?? [];
  final budgets = ref.watch(budgetProgressProvider).value ?? [];
  final activeLoans = ref.watch(activeLoansStreamProvider).value ?? [];
  final savingsGoals = ref.watch(savingsGoalsStreamProvider).value ?? [];

  final overBudget = budgets.where((b) {
    if (b.remaining < 0) return true;
    if (b.percentage >= 0.9) return true;
    return false;
  }).length;

  final now = DateTime.now();

  final dueLoans = activeLoans.where((l) {
    if (l.remaining <= 0 || l.dueAt == null) return false;
    final diff = l.dueAt!.difference(now).inDays;
    return diff <= 3;
  }).length;

  final activeIncompleteSavings = savingsGoals.where((g) {
    return !g.isCompleted && g.currentAmount < g.targetAmount;
  }).toList();

  final urgentSavings = activeIncompleteSavings.where((g) {
    final diff = g.targetDate.difference(now).inDays;
    return diff <= 30;
  }).length;

  // Count goals with approaching target dates or at least 1 periodic reminder if active goals exist
  final savingsCount = urgentSavings > 0
      ? urgentSavings
      : (activeIncompleteSavings.isNotEmpty ? 1 : 0);

  return NotificationCounts(
    pendingSmsCount: reviewQueue.length,
    dueBillsCount: dueBills.where((b) => b.type == 'expense').length,
    budgetAlertsCount: overBudget,
    savingsRemindersCount: savingsCount,
    dueLoansCount: dueLoans,
  );
});
