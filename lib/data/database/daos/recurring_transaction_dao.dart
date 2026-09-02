import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/recurring_transactions_table.dart';

part 'recurring_transaction_dao.g.dart';

@DriftAccessor(tables: [RecurringTransactions])
class RecurringTransactionDao extends DatabaseAccessor<AppDatabase>
    with _$RecurringTransactionDaoMixin {
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
    return (select(
      recurringTransactions,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
  }

  /// Returns active recurring transactions whose nextDate is on or before [date].
  Future<List<RecurringTransaction>> getDueTransactions(DateTime date) {
    final query = select(recurringTransactions)
      ..where(
        (r) =>
            r.status.equals('active') &
            r.nextDate.isSmallerOrEqual(Constant(date)),
      )
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
    await update(
      recurringTransactions,
    ).replace(tx.copyWith(nextDate: nextOccurrence, updatedAt: DateTime.now()));
  }

  /// Returns all active recurring transactions with non-empty merchantKeywords.
  Future<List<RecurringTransaction>> getActiveWithKeywords() {
    return (select(recurringTransactions)..where(
          (r) =>
              r.status.equals('active') &
              r.merchantKeywords.isNotNull() &
              r.merchantKeywords.equals('').not(),
        ))
        .get();
  }

  /// Records an automated SMS-logged payment for the recurring transaction, increments stats, and advances nextDate.
  /// Returns false if the payment was rejected (end date passed or duplicate).
  Future<bool> recordPayment(String id, int amount, DateTime paidAt) async {
    final tx = await getById(id);
    if (tx == null) return false;

    if (tx.endDate != null && tx.nextDate.isAfter(tx.endDate!)) {
      return false;
    }

    if (tx.lastPaidAt != null) {
      final diff = paidAt.difference(tx.lastPaidAt!).inMinutes.abs();
      if (diff < 30 && tx.totalPaid > 0) {
        return false;
      }
    }

    final nextDue = tx.endDate != null
        ? _advanceDateWithEnd(tx.nextDate, tx.frequency, tx.intervalValue, tx.endDate!)
        : _advanceDate(tx.nextDate, tx.frequency, tx.intervalValue);

    final newStatus = nextDue == null ? 'cancelled' : tx.status;

    await update(recurringTransactions).replace(
      tx.copyWith(
        lastPaidAt: Value(paidAt),
        totalPaid: tx.totalPaid + amount,
        paymentCount: tx.paymentCount + 1,
        nextDate: nextDue ?? tx.nextDate,
        status: newStatus,
        updatedAt: DateTime.now(),
      ),
    );
    return true;
  }

  Future<void> toggleStatus(String id) async {
    final tx = await getById(id);
    if (tx == null) return;
    final newStatus = tx.status == 'active' ? 'paused' : 'active';
    await update(recurringTransactions).replace(
      tx.copyWith(status: newStatus, updatedAt: DateTime.now()),
    );
  }

  DateTime _advanceDate(DateTime from, String frequency, int interval) {
    switch (frequency) {
      case 'weekly':
        return DateTime(from.year, from.month, from.day + 7 * interval);
      case 'biweekly':
        return DateTime(from.year, from.month, from.day + 14 * interval);
      case 'monthly':
        return _addMonths(from, interval);
      case 'quarterly':
        return _addMonths(from, 3 * interval);
      case 'yearly':
        final targetYear = from.year + interval;
        final lastDay = DateTime(targetYear, from.month + 1, 0).day;
        final clampedDay = from.day.clamp(1, lastDay);
        return DateTime(targetYear, from.month, clampedDay);
      default:
        return _addMonths(from, interval);
    }
  }

  DateTime? _advanceDateWithEnd(
    DateTime from,
    String frequency,
    int interval,
    DateTime endDate,
  ) {
    final next = _advanceDate(from, frequency, interval);
    return next.isAfter(endDate) ? null : next;
  }

  static DateTime _addMonths(DateTime from, int months) {
    final targetMonth = from.month + months;
    final targetYear = from.year + ((targetMonth - 1) ~/ 12);
    final monthInYear = ((targetMonth - 1) % 12) + 1;
    final lastDay = DateTime(targetYear, monthInYear + 1, 0).day;
    final clampedDay = from.day.clamp(1, lastDay);
    return DateTime(targetYear, monthInYear, clampedDay);
  }
}
