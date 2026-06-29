import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/daos/recurring_transaction_dao.dart';
import '../database/database_providers.dart';

final recurringTransactionRepositoryProvider =
    Provider<RecurringTransactionRepository>((ref) {
      final dao = ref.watch(recurringTransactionDaoProvider);
      return RecurringTransactionRepository(dao);
    });

class RecurringTransactionRepository {
  final RecurringTransactionDao _recurringTransactionDao;

  RecurringTransactionRepository(this._recurringTransactionDao);

  Stream<List<RecurringTransaction>> watchAll({String? trackerId}) =>
      _recurringTransactionDao.watchAll(trackerId: trackerId);

  Future<List<RecurringTransaction>> getAll({String? trackerId}) =>
      _recurringTransactionDao.getAll(trackerId: trackerId);

  Future<RecurringTransaction?> getById(String id) =>
      _recurringTransactionDao.getById(id);

  Future<List<RecurringTransaction>> getDueTransactions(DateTime date) =>
      _recurringTransactionDao.getDueTransactions(date);

  Future<int> createRecurringTransaction(RecurringTransaction transaction) =>
      _recurringTransactionDao.insertRecurringTransaction(transaction);

  Future<bool> updateRecurringTransaction(RecurringTransaction transaction) =>
      _recurringTransactionDao.updateRecurringTransaction(transaction);

  Future<void> deleteRecurringTransaction(String id) =>
      _recurringTransactionDao.deleteRecurringTransaction(id);

  Future<void> markAsProcessed(String id, DateTime nextOccurrence) =>
      _recurringTransactionDao.markAsProcessed(id, nextOccurrence);

  Future<List<RecurringTransaction>> getActiveWithKeywords() =>
      _recurringTransactionDao.getActiveWithKeywords();

  Future<void> recordPayment(String id, int amount, DateTime paidAt) =>
      _recurringTransactionDao.recordPayment(id, amount, paidAt);
}
