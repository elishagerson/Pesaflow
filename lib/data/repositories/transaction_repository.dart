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
    String? trackerId,
  }) {
    return _transactionDao.watchFilteredTransactions(
      accountId: accountId,
      categoryId: categoryId,
      type: type,
      searchQuery: searchQuery,
      startDate: startDate,
      endDate: endDate,
      trackerId: trackerId,
    );
  }

  Stream<List<TransactionWithCategoryAndAccount>> watchRecentTransactions(int limit, {String? trackerId}) {
    return _transactionDao.watchRecentTransactions(limit, trackerId: trackerId);
  }

  Future<void> createTransaction(Transaction transaction) {
    return _transactionDao.writeTransactionWithBalanceAdjustment(transaction);
  }

  Future<void> deleteTransaction(String transactionId) {
    return _transactionDao.deleteTransactionWithBalanceAdjustment(transactionId);
  }

  Future<bool> transactionExistsByReference(String reference) {
    return _transactionDao.existsByReference(reference);
  }

  Future<List<Transaction>> getTransactionsByFuzzyWindow({
    required String provider,
    required String type,
    required int amount,
    required DateTime start,
    required DateTime end,
  }) {
    return _transactionDao.getFuzzyMatches(
      provider: provider,
      type: type,
      amount: amount,
      start: start,
      end: end,
    );
  }

  Stream<List<TransactionWithCategoryAndAccount>> watchReviewQueueTransactions() {
    return _transactionDao.watchReviewQueueTransactions();
  }

  Future<void> approveReviewedTransaction(String transactionId, {String? newCategoryId}) {
    return _transactionDao.approveReviewedTransaction(transactionId, newCategoryId: newCategoryId);
  }

  Future<Transaction?> findFuzzyTransferMatch({
    required String accountId,
    required String destinationAccountId,
    required int amount,
    required DateTime start,
    required DateTime end,
  }) {
    return _transactionDao.findFuzzyTransferMatch(
      accountId: accountId,
      destinationAccountId: destinationAccountId,
      amount: amount,
      start: start,
      end: end,
    );
  }
}
