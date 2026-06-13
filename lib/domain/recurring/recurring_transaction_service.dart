import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/database/app_database.dart';
import '../../data/database/daos/recurring_transaction_dao.dart';
import '../../data/database/daos/transaction_dao.dart';
import '../../data/database/database_providers.dart';

final recurringTransactionServiceProvider = Provider<RecurringTransactionService>((ref) {
  return RecurringTransactionService(
    recurringDao: ref.watch(recurringTransactionDaoProvider),
    transactionDao: ref.watch(transactionDaoProvider),
  );
});

class RecurringTransactionService {
  final RecurringTransactionDao _recurringDao;
  final TransactionDao _transactionDao;

  RecurringTransactionService({
    required this._recurringDao,
    required this._transactionDao,
  });

  /// Calculates the next occurrence date for a recurring transaction
  /// based on its frequency and interval value.
  DateTime calculateNextDate(RecurringTransaction recurring) {
    final current = recurring.nextDate;
    final interval = recurring.intervalValue;

    switch (recurring.frequency) {
      case 'weekly':
        return current.add(Duration(days: 7 * interval));
      case 'biweekly':
        return current.add(Duration(days: 14 * interval));
      case 'monthly':
        return DateTime(current.year, current.month + interval, current.day);
      case 'quarterly':
        return DateTime(current.year, current.month + 3 * interval, current.day);
      case 'yearly':
        return DateTime(current.year + interval, current.month, current.day);
      default:
        return current.add(Duration(days: 7 * interval));
    }
  }

  /// Processes all due recurring transactions:
  /// 1. Finds all active recurring txs where nextDate <= now
  /// 2. Creates real Transaction records
  /// 3. Updates nextDate for each recurring tx
  Future<int> processDueTransactions() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = await _recurringDao.getDueTransactions(today);

    int processedCount = 0;

    for (final recurring in due) {
      try {
        final transaction = Transaction(
          id: const Uuid().v4(),
          accountId: recurring.accountId,
          categoryId: recurring.categoryId ?? '',
          trackerId: recurring.trackerId,
          amount: recurring.amount,
          type: recurring.type,
          description: '${recurring.description ?? 'Recurring'} (auto)',
          source: 'auto',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _transactionDao.writeTransactionWithBalanceAdjustment(transaction);

        if (recurring.endDate != null && recurring.endDate!.isBefore(today)) {
          await _recurringDao.deleteRecurringTransaction(recurring.id);
        } else {
          final next = calculateNextDate(recurring);
          await _recurringDao.markAsProcessed(recurring.id, next);
        }

        processedCount++;
      } catch (e) {
        developer.log('Failed to process recurring tx ${recurring.id}: $e',
            name: 'RecurringTransactionService');
      }
    }

    return processedCount;
  }
}
