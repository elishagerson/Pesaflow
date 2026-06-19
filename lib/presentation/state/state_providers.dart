import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../data/database/daos/transaction_dao.dart';
import '../../data/database/daos/budget_dao.dart';
import '../../data/database/daos/analytics_dao.dart';
import '../../data/database/database_providers.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/tracker_repository.dart';
import '../../data/repositories/savings_goal_repository.dart';
import '../../data/repositories/loan_repository.dart';
import '../../data/repositories/recurring_transaction_repository.dart';
import '../../data/repositories/subscription_repository.dart';
import '../../domain/analytics/insight_generator.dart';

class ActiveTrackerIdNotifier extends Notifier<String> {
  late final SettingsRepository _settingsRepo;

  @override
  String build() {
    _settingsRepo = ref.watch(settingsRepositoryProvider);
    _init();
    return 'default_personal';
  }

  Future<void> _init() async {
    final saved = await _settingsRepo.getSetting('active_tracker_id');
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  Future<void> setTrackerId(String id) async {
    state = id;
    await _settingsRepo.setSetting('active_tracker_id', id);
  }
}

final activeTrackerIdProvider = NotifierProvider<ActiveTrackerIdNotifier, String>(() {
  return ActiveTrackerIdNotifier();
});

final allTrackersStreamProvider = StreamProvider<List<Tracker>>((ref) {
  final repo = ref.watch(trackerRepositoryProvider);
  return repo.watchAllTrackers();
});

final activeTrackerProvider = FutureProvider<Tracker?>((ref) async {
  final id = ref.watch(activeTrackerIdProvider);
  final repo = ref.watch(trackerRepositoryProvider);
  return repo.getTrackerById(id);
});

final accountsStreamProvider = StreamProvider<List<Account>>((ref) {
  final repo = ref.watch(accountRepositoryProvider);
  return repo.watchAllAccounts();
});

final categoriesFutureProvider = FutureProvider<List<Category>>((ref) {
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.getAllCategories();
});

final recentTransactionsStreamProvider = StreamProvider<List<TransactionWithCategoryAndAccount>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  final trackerId = ref.watch(activeTrackerIdProvider);
  return repo.watchRecentTransactions(5, trackerId: trackerId);
});

final netWorthProvider = Provider<int>((ref) {
  final accountsAsync = ref.watch(accountsStreamProvider);
  return accountsAsync.when(
    data: (accounts) => accounts.fold<int>(0, (sum, acc) => sum + acc.balance),
    loading: () => 0,
    error: (_, _) => 0,
  );
});

// Transaction List Filter Providers
class TransactionTypeFilterNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  @override
  set state(String value) => super.state = value;
}
final transactionTypeFilterProvider = NotifierProvider<TransactionTypeFilterNotifier, String>(() {
  return TransactionTypeFilterNotifier();
});

class TransactionAccountFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  @override
  set state(String? value) => super.state = value;
}
final transactionAccountFilterProvider = NotifierProvider<TransactionAccountFilterNotifier, String?>(() {
  return TransactionAccountFilterNotifier();
});

class TransactionCategoryFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  @override
  set state(String? value) => super.state = value;
}
final transactionCategoryFilterProvider = NotifierProvider<TransactionCategoryFilterNotifier, String?>(() {
  return TransactionCategoryFilterNotifier();
});

class TransactionSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  @override
  set state(String value) => super.state = value;
}
final transactionSearchQueryProvider = NotifierProvider<TransactionSearchQueryNotifier, String>(() {
  return TransactionSearchQueryNotifier();
});

class TransactionAmountMinNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  @override
  set state(int? value) => super.state = value;
}
final transactionAmountMinProvider = NotifierProvider<TransactionAmountMinNotifier, int?>(() {
  return TransactionAmountMinNotifier();
});

class TransactionAmountMaxNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  @override
  set state(int? value) => super.state = value;
}
final transactionAmountMaxProvider = NotifierProvider<TransactionAmountMaxNotifier, int?>(() {
  return TransactionAmountMaxNotifier();
});

class TransactionDateFromNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  @override
  set state(DateTime? value) => super.state = value;
}
final transactionDateFromProvider = NotifierProvider<TransactionDateFromNotifier, DateTime?>(() {
  return TransactionDateFromNotifier();
});

class TransactionDateToNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  @override
  set state(DateTime? value) => super.state = value;
}
final transactionDateToProvider = NotifierProvider<TransactionDateToNotifier, DateTime?>(() {
  return TransactionDateToNotifier();
});

final filteredTransactionsStreamProvider = StreamProvider<List<TransactionWithCategoryAndAccount>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  final type = ref.watch(transactionTypeFilterProvider);
  final accountId = ref.watch(transactionAccountFilterProvider);
  final categoryId = ref.watch(transactionCategoryFilterProvider);
  final search = ref.watch(transactionSearchQueryProvider);
  final amountMin = ref.watch(transactionAmountMinProvider);
  final amountMax = ref.watch(transactionAmountMaxProvider);
  final dateFrom = ref.watch(transactionDateFromProvider);
  final dateTo = ref.watch(transactionDateToProvider);
  final trackerId = ref.watch(activeTrackerIdProvider);

  return repo.watchFilteredTransactions(
    accountId: accountId,
    categoryId: categoryId,
    type: type,
    searchQuery: search,
    amountMin: amountMin,
    amountMax: amountMax,
    startDate: dateFrom,
    endDate: dateTo,
    trackerId: trackerId,
  );
});

final reviewQueueStreamProvider = StreamProvider<List<TransactionWithCategoryAndAccount>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchReviewQueueTransactions();
});

// ═══════════════════════════════════════════════════════
// Budget Providers
// ═══════════════════════════════════════════════════════

final activeBudgetsStreamProvider = StreamProvider<List<Budget>>((ref) {
  final repo = ref.watch(budgetRepositoryProvider);
  return repo.watchAllActiveBudgets();
});

final _transactionChangesProvider = StreamProvider<int>((ref) {
  final dao = ref.watch(budgetDaoProvider);
  return dao.watchTransactionChanges();
});

final budgetProgressProvider = FutureProvider<List<BudgetWithProgress>>((ref) {
  ref.watch(_transactionChangesProvider);
  ref.watch(activeBudgetsStreamProvider);
  final repo = ref.watch(budgetRepositoryProvider);
  return repo.getActiveBudgetsWithProgress();
});

// ═══════════════════════════════════════════════════════
// Analytics Providers
// ═══════════════════════════════════════════════════════

final monthlyTotalsProvider = FutureProvider<Map<String, int>>((ref) {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getMonthTotals(DateTime.now());
});

final topCategoriesProvider = FutureProvider<List<CategorySpending>>((ref) {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getTopCategoriesForMonth(DateTime.now(), limit: 5);
});

final monthlySnapshotsProvider = FutureProvider<List<MonthlySnapshot>>((ref) {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getMonthlySnapshots(12);
});

final insightsProvider = FutureProvider<List<Insight>>((ref) {
  final generator = ref.watch(insightGeneratorProvider);
  return generator.generateInsights();
});

// ═══════════════════════════════════════════════════════
// Savings Goals Providers
// ═══════════════════════════════════════════════════════

final savingsGoalsStreamProvider = StreamProvider<List<SavingsGoal>>((ref) {
  final repo = ref.watch(savingsGoalRepositoryProvider);
  final trackerId = ref.watch(activeTrackerIdProvider);
  return repo.watchAllSavingsGoals(trackerId);
});

final savingsGoalContributionsStreamProvider = StreamProvider.family<List<SavingsGoalContribution>, String>((ref, goalId) {
  final repo = ref.watch(savingsGoalRepositoryProvider);
  return repo.watchContributions(goalId);
});

final savingsGoalsTotalSavedProvider = Provider<int>((ref) {
  final goalsAsync = ref.watch(savingsGoalsStreamProvider);
  return goalsAsync.when(
    data: (goals) => goals.fold<int>(0, (sum, goal) => sum + goal.currentAmount),
    loading: () => 0,
    error: (_, _) => 0,
  );
});

final daysSinceLastSaveProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(savingsGoalRepositoryProvider);
  final trackerId = ref.watch(activeTrackerIdProvider);
  final goals = await repo.getAllSavingsGoals(trackerId);
  DateTime? lastDate;
  for (final goal in goals) {
    final contributions = await repo.getContributions(goal.id);
    for (final c in contributions) {
      if (c.amount > 0) {
        if (lastDate == null || c.createdAt.isAfter(lastDate)) {
          lastDate = c.createdAt;
        }
      }
    }
  }
  if (lastDate == null) return -1;
  return DateTime.now().difference(lastDate).inDays;
});

final currencyShowDecimalsProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watchSetting('currency_show_decimals').map((val) => val == 'true');
});

final appLockEnabledProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watchSetting('app_lock_enabled').map((val) => val == 'true');
});

final smsAutoDeduplicationProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watchSetting('sms_auto_deduplication').map((val) => val == 'true');
});

// ═══════════════════════════════════════════════════════
// Loan Providers
// ═══════════════════════════════════════════════════════

final loansStreamProvider = StreamProvider<List<Loan>>((ref) {
  final repo = ref.watch(loanRepositoryProvider);
  final trackerId = ref.watch(activeTrackerIdProvider);
  return repo.watchAllLoans(trackerId: trackerId);
});

final activeLoansStreamProvider = StreamProvider<List<Loan>>((ref) {
  final repo = ref.watch(loanRepositoryProvider);
  final trackerId = ref.watch(activeTrackerIdProvider);
  return repo.watchActiveLoans(trackerId: trackerId);
});

final paidLoansStreamProvider = StreamProvider<List<Loan>>((ref) {
  final repo = ref.watch(loanRepositoryProvider);
  final trackerId = ref.watch(activeTrackerIdProvider);
  return repo.watchPaidLoans(trackerId: trackerId);
});

final paidLoansCountProvider = FutureProvider<int>((ref) {
  final paidAsync = ref.watch(paidLoansStreamProvider);
  return paidAsync.when(data: (l) => l.length, loading: () => 0, error: (_, _) => 0);
});

final totalPaidLoanAmountProvider = FutureProvider<int>((ref) {
  final repo = ref.watch(loanRepositoryProvider);
  final trackerId = ref.watch(activeTrackerIdProvider);
  return repo.getTotalPaid(trackerId: trackerId);
});

final recentLoanActivityProvider = FutureProvider<int>((ref) {
  final repo = ref.watch(loanRepositoryProvider);
  final trackerId = ref.watch(activeTrackerIdProvider);
  return repo.getActiveLoanCountPastMonths(3, trackerId: trackerId);
});

final loanTransactionsStreamProvider = StreamProvider.family<List<Transaction>, String>((ref, loanId) {
  final repo = ref.watch(loanRepositoryProvider);
  return repo.watchLoanTransactions(loanId);
});

final totalOutstandingLoanProvider = FutureProvider<int>((ref) {
  final repo = ref.watch(loanRepositoryProvider);
  final trackerId = ref.watch(activeTrackerIdProvider);
  return repo.getTotalOutstanding(trackerId: trackerId);
});

// ═══════════════════════════════════════════════════════
// Recurring Transaction Providers
// ═══════════════════════════════════════════════════════

final recurringTransactionsStreamProvider = StreamProvider<List<RecurringTransaction>>((ref) {
  final repo = ref.watch(recurringTransactionRepositoryProvider);
  final trackerId = ref.watch(activeTrackerIdProvider);
  return repo.watchAll(trackerId: trackerId);
});

final dueRecurringTransactionsProvider = FutureProvider<List<RecurringTransaction>>((ref) {
  final repo = ref.watch(recurringTransactionRepositoryProvider);
  return repo.getDueTransactions(DateTime.now());
});

// ── Subscription Providers ───────────────────────────────────────────
final subscriptionsStreamProvider = StreamProvider<List<Subscription>>((ref) {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.watchAll();
});

final dueSubscriptionsProvider = FutureProvider<List<Subscription>>((ref) {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.getDue(DateTime.now());
});

final activeSubscriptionsProvider = FutureProvider<List<Subscription>>((ref) {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.getActive();
});

