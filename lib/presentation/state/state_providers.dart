import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/transaction_repository.dart';

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
  return repo.watchRecentTransactions(5);
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

  return repo.watchFilteredTransactions(
    accountId: accountId,
    categoryId: categoryId,
    type: type,
    searchQuery: search,
  );
});

final reviewQueueStreamProvider = StreamProvider<List<TransactionWithCategoryAndAccount>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchReviewQueueTransactions();
});
