import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/services/budget_alert_service.dart';

final transactionServiceProvider = Provider<TransactionService>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  final budgetAlertService = ref.watch(budgetAlertServiceProvider);
  return TransactionService(repo, budgetAlertService);
});

final transactionServiceNoAlertsProvider = Provider<TransactionService>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return TransactionService(repo, null);
});

class TransactionService {
  final TransactionRepository _repo;
  final BudgetAlertService? _budgetAlertService;

  TransactionService(this._repo, this._budgetAlertService);

  Stream<List<dynamic>> watchFilteredTransactions({
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
    return _repo.watchFilteredTransactions(
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

  Stream<List<dynamic>> watchRecentTransactions(
    int limit, {
    String? trackerId,
  }) {
    return _repo.watchRecentTransactions(limit, trackerId: trackerId);
  }

  Future<void> createTransaction(dynamic transaction) async {
    await _repo.createTransaction(transaction);
    _budgetAlertService?.checkBudgetsAfterTransaction(transaction.categoryId);
  }

  Future<void> createTransactionNoBalanceAdjustment(dynamic transaction) async {
    await _repo.createTransactionNoBalanceAdjustment(transaction);
    _budgetAlertService?.checkBudgetsAfterTransaction(transaction.categoryId);
  }

  Future<void> deleteTransaction(String transactionId) {
    return _repo.deleteTransaction(transactionId);
  }

  Future<bool> transactionExistsByReference(String reference) {
    return _repo.transactionExistsByReference(reference);
  }

  Future<List<dynamic>> getTransactionsByFuzzyWindow({
    required String provider,
    required String type,
    required int amount,
    required DateTime start,
    required DateTime end,
  }) {
    return _repo.getTransactionsByFuzzyWindow(
      provider: provider,
      type: type,
      amount: amount,
      start: start,
      end: end,
    );
  }

  Stream<List<dynamic>> watchReviewQueueTransactions() {
    return _repo.watchReviewQueueTransactions();
  }

  Future<dynamic> getTransactionById(String id) {
    return _repo.getTransactionById(id);
  }

  Future<void> approveReviewedTransaction(
    String transactionId, {
    String? newCategoryId,
  }) async {
    await _repo.approveReviewedTransaction(
      transactionId,
      newCategoryId: newCategoryId,
    );
  }

  Future<dynamic> findFuzzyTransferMatch({
    required String accountId,
    required String destinationAccountId,
    required int amount,
    required DateTime start,
    required DateTime end,
  }) {
    return _repo.findFuzzyTransferMatch(
      accountId: accountId,
      destinationAccountId: destinationAccountId,
      amount: amount,
      start: start,
      end: end,
    );
  }
}
