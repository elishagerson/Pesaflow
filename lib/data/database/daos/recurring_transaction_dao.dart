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
}
