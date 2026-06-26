import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/trackers_table.dart';

part 'tracker_dao.g.dart';

@DriftAccessor(tables: [Trackers])
class TrackerDao extends DatabaseAccessor<AppDatabase> with _$TrackerDaoMixin {
  TrackerDao(super.db);

  Stream<List<Tracker>> watchAllTrackers() {
    return (select(trackers)
          ..where((t) => t.isArchived.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<Tracker>> getAllTrackers() {
    return (select(trackers)
          ..where((t) => t.isArchived.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  Future<Tracker?> getTrackerById(String id) {
    return (select(trackers)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertTracker(Tracker tracker) => into(trackers).insert(tracker);

  Future<bool> updateTracker(Tracker tracker) => update(trackers).replace(tracker);

  Future<void> deleteTrackerWithCascade(String id) async {
    await db.transaction(() async {
      // 1. Fetch all transactions for this tracker
      final txs = await (db.select(db.transactions)..where((t) => t.trackerId.equals(id))).get();

      // 2. Reverse balance adjustments for each transaction
      for (final tx in txs) {
        final txAccId = tx.accountId;
        if (txAccId == null) continue;
        final account = await (db.select(db.accounts)..where((t) => t.id.equals(txAccId))).getSingleOrNull();
        if (account != null) {
          int balanceDelta = 0;
          final type = tx.type.toLowerCase();
          if (type == 'income' || type == 'loan') {
            balanceDelta = -tx.amount;
          } else if (type == 'expense' || type == 'airtime' || type == 'fee') {
            balanceDelta = tx.amount;
          } else if (type == 'transfer') {
            balanceDelta = tx.amount;
          }
          await (db.update(db.accounts)..where((t) => t.id.equals(account.id))).write(
            AccountsCompanion(
              balance: Value(account.balance + balanceDelta),
            ),
          );
        }

        if (tx.type.toLowerCase() == 'transfer' && tx.destinationAccountId != null) {
          final destAccount = await (db.select(db.accounts)..where((t) => t.id.equals(tx.destinationAccountId!))).getSingleOrNull();
          if (destAccount != null) {
            await (db.update(db.accounts)..where((t) => t.id.equals(destAccount.id))).write(
              AccountsCompanion(
                balance: Value(destAccount.balance - tx.amount),
              ),
            );
          }
        }
      }

      // 3. Delete transactions
      await (db.delete(db.transactions)..where((t) => t.trackerId.equals(id))).go();

      // 4. Delete savings goals and contributions
      final goals = await (db.select(db.savingsGoals)..where((t) => t.trackerId.equals(id))).get();
      final goalIds = goals.map((g) => g.id).toList();
      if (goalIds.isNotEmpty) {
        await (db.delete(db.savingsGoalContributions)..where((t) => t.savingsGoalId.isIn(goalIds))).go();
        await (db.delete(db.savingsGoals)..where((t) => t.trackerId.equals(id))).go();
      }

      // 5. Finally delete the tracker
      await (db.delete(db.trackers)..where((t) => t.id.equals(id))).go();
    });
  }
}

