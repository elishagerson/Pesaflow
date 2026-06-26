import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/daos/transaction_dao.dart';
import '../database/database_providers.dart';
import '../../services/budget_alert_service.dart';
import 'analytics_repository.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final dao = ref.watch(transactionDaoProvider);
  final budgetAlertService = ref.watch(budgetAlertServiceProvider);
  final analyticsRepo = ref.watch(analyticsRepositoryProvider);
  return TransactionRepository(dao, budgetAlertService, analyticsRepo);
});

final transactionRepositoryNoAlertsProvider = Provider<TransactionRepository>((ref) {
  final dao = ref.watch(transactionDaoProvider);
  final analyticsRepo = ref.watch(analyticsRepositoryProvider);
  return TransactionRepository(dao, null, analyticsRepo);
});

class TransactionRepository {
  final TransactionDao _transactionDao;
  final BudgetAlertService? _budgetAlertService;
  final AnalyticsRepository _analyticsRepo;

  TransactionRepository(this._transactionDao, this._budgetAlertService, this._analyticsRepo);

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
    _refreshAnalytics(transaction.createdAt);
  }

  /// Creates a transaction record without adjusting any account balance.
  /// Used for offline/record-only payments.
  Future<void> createTransactionNoBalanceAdjustment(Transaction transaction) async {
    await _transactionDao.insertTransactionWithoutBalanceAdjustment(transaction);
    _budgetAlertService?.checkBudgetsAfterTransaction(transaction.categoryId);
    _refreshAnalytics(transaction.createdAt);
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

  Future<TransactionWithCategoryAndAccount?> getTransactionById(String id) {
    return _transactionDao.getTransactionWithDetailsById(id);
  }

  Future<void> approveReviewedTransaction(String transactionId, {String? newCategoryId}) async {
    await _transactionDao.approveReviewedTransaction(transactionId, newCategoryId: newCategoryId);
    final tx = await _transactionDao.getTransactionById(transactionId);
    if (tx != null) {
      _refreshAnalytics(tx.createdAt);
    }
  }

  void _refreshAnalytics(DateTime date) {
    _analyticsRepo.refreshAllSnapshots(date).catchError((e) {
      developer.log('Analytics snapshot refresh failed (non-fatal): $e', name: 'TransactionRepo');
    });
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
