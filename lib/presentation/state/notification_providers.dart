import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class DismissedNotificationsNotifier extends Notifier<Set<String>> {
  static const _prefKey = 'dismissed_notification_ids';

  @override
  Set<String> build() {
    _loadFromPrefs();
    return {};
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefKey) ?? [];
      state = list.toSet();
    } catch (_) {}
  }

  Future<void> dismiss(String id) async {
    if (state.contains(id)) return;
    state = {...state, id};
    _saveToPrefs();
  }

  Future<void> dismissAll(Iterable<String> ids) async {
    state = {...state, ...ids};
    _saveToPrefs();
  }

  Future<void> undismiss(String id) async {
    if (!state.contains(id)) return;
    final updated = Set<String>.from(state)..remove(id);
    state = updated;
    _saveToPrefs();
  }

  Future<void> clearAll() async {
    state = {};
    _saveToPrefs();
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefKey, state.toList());
    } catch (_) {}
  }
}

final dismissedNotificationsProvider =
    NotifierProvider<DismissedNotificationsNotifier, Set<String>>(
      DismissedNotificationsNotifier.new,
    );

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
  final dismissed = ref.watch(dismissedNotificationsProvider);
  final reviewQueue = (ref.watch(reviewQueueStreamProvider).value ?? [])
      .where((item) => !dismissed.contains('sms_${item.transaction.id}'))
      .toList();
  final dueBills = (ref.watch(dueRecurringTransactionsProvider).value ?? [])
      .where((b) => !dismissed.contains('bill_${b.id}'))
      .toList();
  final budgets = (ref.watch(budgetProgressProvider).value ?? [])
      .where((b) => !dismissed.contains('budget_${b.budget.id}'))
      .toList();
  final activeLoans = (ref.watch(activeLoansStreamProvider).value ?? [])
      .where((l) => !dismissed.contains('loan_${l.id}'))
      .toList();
  final savingsGoals = (ref.watch(savingsGoalsStreamProvider).value ?? [])
      .where((g) => !dismissed.contains('savings_${g.id}'))
      .toList();

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
