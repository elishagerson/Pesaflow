import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/daos/transaction_dao.dart';
import '../database/database_providers.dart';
import '../../services/budget_alert_service.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final dao = ref.watch(transactionDaoProvider);
  final budgetAlertService = ref.watch(budgetAlertServiceProvider);
  return TransactionRepository(dao, budgetAlertService);
});

final transactionRepositoryNoAlertsProvider = Provider<TransactionRepository>((ref) {
  final dao = ref.watch(transactionDaoProvider);
  return TransactionRepository(dao, null);
});

class TransactionRepository {
  final TransactionDao _transactionDao;
  final BudgetAlertService? _budgetAlertService;

  TransactionRepository(this._transactionDao, this._budgetAlertService);

  Stream<List<TransactionWithCategoryAndAccount>> watchFilteredTransactions({
    String? accountId,
    String? categoryId,
    String? type,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    String? trackerId,
    int? amountMin,
    int? amountMax,
  }) {
    return _transactionDao.watchFilteredTransactions(
      accountId: accountId,
      categoryId: categoryId,
      type: type,
      searchQuery: searchQuery,
      startDate: startDate,
      endDate: endDate,
      trackerId: trackerId,
      amountMin: amountMin,
      amountMax: amountMax,
    );
  }

  Stream<List<TransactionWithCategoryAndAccount>> watchRecentTransactions(int limit, {String? trackerId}) {
    return _transactionDao.watchRecentTransactions(limit, trackerId: trackerId);
  }

  Future<void> createTransaction(Transaction transaction) async {
    await _transactionDao.writeTransactionWithBalanceAdjustment(transaction);
    _budgetAlertService?.checkBudgetsAfterTransaction(transaction.categoryId);
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
