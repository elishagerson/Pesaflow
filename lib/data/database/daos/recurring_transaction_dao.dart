import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/recurring_transactions_table.dart';

part 'recurring_transaction_dao.g.dart';

@DriftAccessor(tables: [RecurringTransactions])
class RecurringTransactionDao extends DatabaseAccessor<AppDatabase> with _$RecurringTransactionDaoMixin {
  RecurringTransactionDao(super.db);

  Stream<List<RecurringTransaction>> watchAll({String? trackerId}) {
    final query = select(recurringTransactions)
      ..orderBy([(r) => OrderingTerm.asc(r.nextDate)]);
    if (trackerId != null) {
      query.where((r) => r.trackerId.equals(trackerId));
    }
    return query.watch();
  }

  Future<List<RecurringTransaction>> getAll({String? trackerId}) {
    final query = select(recurringTransactions)
      ..orderBy([(r) => OrderingTerm.asc(r.nextDate)]);
    if (trackerId != null) {
      query.where((r) => r.trackerId.equals(trackerId));
    }
    return query.get();
  }

  Future<RecurringTransaction?> getById(String id) {
    return (select(recurringTransactions)..where((r) => r.id.equals(id))).getSingleOrNull();
  }

  /// Returns active recurring transactions whose nextDate is on or before [date].
  Future<List<RecurringTransaction>> getDueTransactions(DateTime date) {
    final query = select(recurringTransactions)
      ..where((r) =>
        r.status.equals('active') &
        r.nextDate.isSmallerOrEqual(Constant(date)))
      ..orderBy([(r) => OrderingTerm.asc(r.nextDate)]);
    return query.get();
  }

  Future<int> insertRecurringTransaction(RecurringTransaction transaction) =>
      into(recurringTransactions).insert(transaction);

  Future<bool> updateRecurringTransaction(RecurringTransaction transaction) =>
      update(recurringTransactions).replace(transaction);

  Future<void> deleteRecurringTransaction(String id) async {
    await (delete(recurringTransactions)..where((r) => r.id.equals(id))).go();
  }

  /// Updates [nextDate] and [updatedAt] after processing a recurring transaction.
  Future<void> markAsProcessed(String id, DateTime nextOccurrence) async {
    final tx = await getById(id);
    if (tx == null) return;
    await update(recurringTransactions).replace(tx.copyWith(
      nextDate: nextOccurrence,
      updatedAt: DateTime.now(),
    ));
  }

  /// Returns all active recurring transactions with non-empty merchantKeywords.
  Future<List<RecurringTransaction>> getActiveWithKeywords() {
    return (select(recurringTransactions)
          ..where((r) =>
              r.status.equals('active') &
              r.merchantKeywords.isNotNull() &
              r.merchantKeywords.isNotEqualTo('')))
        .get();
  }

  /// Records an automated SMS-logged payment for the recurring transaction, increments stats, and advances nextDate.
  Future<void> recordPayment(String id, int amount, DateTime paidAt) async {
    final tx = await getById(id);
    if (tx == null) return;

    final nextDue = _advanceDate(tx.nextDate, tx.frequency, tx.intervalValue);
    await update(recurringTransactions).replace(tx.copyWith(
      lastPaidAt: Value(paidAt),
      totalPaid: tx.totalPaid + amount,
      paymentCount: tx.paymentCount + 1,
      nextDate: nextDue,
      updatedAt: DateTime.now(),
    ));
  }

  DateTime _advanceDate(DateTime from, String frequency, int interval) {
    switch (frequency) {
      case 'weekly':
        return DateTime(from.year, from.month, from.day + 7 * interval);
      case 'biweekly':
        return DateTime(from.year, from.month, from.day + 14 * interval);
      case 'monthly':
        return DateTime(from.year, from.month + interval, from.day);
      case 'quarterly':
        return DateTime(from.year, from.month + 3 * interval, from.day);
      case 'yearly':
        return DateTime(from.year + interval, from.month, from.day);
      default:
        return DateTime(from.year, from.month + interval, from.day);
    }
  }
}
