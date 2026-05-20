import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/daos/transaction_dao.dart';
import '../database/database_providers.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final dao = ref.watch(transactionDaoProvider);
  return TransactionRepository(dao);
});

class TransactionRepository {
  final TransactionDao _transactionDao;

  TransactionRepository(this._transactionDao);

  Stream<List<TransactionWithCategoryAndAccount>> watchFilteredTransactions({
    String? accountId,
    String? categoryId,
    String? type,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _transactionDao.watchFilteredTransactions(
      accountId: accountId,
      categoryId: categoryId,
      type: type,
      searchQuery: searchQuery,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Stream<List<TransactionWithCategoryAndAccount>> watchRecentTransactions(int limit) {
    return _transactionDao.watchRecentTransactions(limit);
  }

  Future<void> createTransaction(Transaction transaction) {
    return _transactionDao.writeTransactionWithBalanceAdjustment(transaction);
  }

  Future<void> deleteTransaction(String transactionId) {
    return _transactionDao.deleteTransactionWithBalanceAdjustment(transactionId);
  }
}
