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
import '../../domain/analytics/insight_generator.dart';

final activeTrackerIdProvider = StateNotifierProvider<ActiveTrackerIdNotifier, String>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return ActiveTrackerIdNotifier(settingsRepo);
});

class ActiveTrackerIdNotifier extends StateNotifier<String> {
  final SettingsRepository _settingsRepo;

  ActiveTrackerIdNotifier(this._settingsRepo) : super('default_personal') {
    _init();
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
final transactionTypeFilterProvider = StateProvider<String>((ref) => 'All');
final transactionAccountFilterProvider = StateProvider<String?>((ref) => null);
final transactionCategoryFilterProvider = StateProvider<String?>((ref) => null);
final transactionSearchQueryProvider = StateProvider<String>((ref) => '');

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
