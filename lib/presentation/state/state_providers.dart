import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../data/database/daos/transaction_dao.dart';
import '../../data/database/daos/budget_dao.dart';
import '../../data/database/daos/analytics_dao.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/tracker_repository.dart';
import '../../data/repositories/savings_goal_repository.dart';
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
    error: (_, __) => 0,
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

final filteredTransactionsStreamProvider = StreamProvider<List<TransactionWithCategoryAndAccount>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  final type = ref.watch(transactionTypeFilterProvider);
  final accountId = ref.watch(transactionAccountFilterProvider);
  final categoryId = ref.watch(transactionCategoryFilterProvider);
  final search = ref.watch(transactionSearchQueryProvider);
  final trackerId = ref.watch(activeTrackerIdProvider);

  return repo.watchFilteredTransactions(
    accountId: accountId,
    categoryId: categoryId,
    type: type,
    searchQuery: search,
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

final budgetProgressProvider = FutureProvider<List<BudgetWithProgress>>((ref) {
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
    error: (_, __) => 0,
  );
});
