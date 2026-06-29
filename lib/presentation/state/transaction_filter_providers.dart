import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'active_tracker_provider.dart';

class TransactionTypeFilterNotifier extends Notifier<String> {
  @override
  String build() => 'All';
}

final transactionTypeFilterProvider =
    NotifierProvider<TransactionTypeFilterNotifier, String>(() {
      return TransactionTypeFilterNotifier();
    });

class TransactionAccountFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
}

final transactionAccountFilterProvider =
    NotifierProvider<TransactionAccountFilterNotifier, String?>(() {
      return TransactionAccountFilterNotifier();
    });

class TransactionCategoryFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
}

final transactionCategoryFilterProvider =
    NotifierProvider<TransactionCategoryFilterNotifier, String?>(() {
      return TransactionCategoryFilterNotifier();
    });

class TransactionSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
}

final transactionSearchQueryProvider =
    NotifierProvider<TransactionSearchQueryNotifier, String>(() {
      return TransactionSearchQueryNotifier();
    });

class TransactionAmountMinNotifier extends Notifier<int?> {
  @override
  int? build() => null;
}

final transactionAmountMinProvider =
    NotifierProvider<TransactionAmountMinNotifier, int?>(() {
      return TransactionAmountMinNotifier();
    });

class TransactionAmountMaxNotifier extends Notifier<int?> {
  @override
  int? build() => null;
}

final transactionAmountMaxProvider =
    NotifierProvider<TransactionAmountMaxNotifier, int?>(() {
      return TransactionAmountMaxNotifier();
    });

class TransactionDateFromNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;
}

final transactionDateFromProvider =
    NotifierProvider<TransactionDateFromNotifier, DateTime?>(() {
      return TransactionDateFromNotifier();
    });

class TransactionDateToNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;
}

final transactionDateToProvider =
    NotifierProvider<TransactionDateToNotifier, DateTime?>(() {
      return TransactionDateToNotifier();
    });

final filteredTransactionsStreamProvider =
    StreamProvider<List<TransactionWithCategoryAndAccount>>((ref) {
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
