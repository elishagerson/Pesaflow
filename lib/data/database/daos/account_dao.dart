import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/accounts_table.dart';

part 'account_dao.g.dart';

@DriftAccessor(tables: [Accounts])
class AccountDao extends DatabaseAccessor<AppDatabase> with _$AccountDaoMixin {
  AccountDao(super.db);

  Stream<List<Account>> watchAllAccounts() {
    return (select(accounts)
          ..where((t) => t.isArchived.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .watch();
  }

  Future<List<Account>> getAllAccounts() {
    return (select(accounts)
          ..where((t) => t.isArchived.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
  }

  Future<Account?> getAccountById(String id) {
    return (select(accounts)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertAccount(Account account) => into(accounts).insert(account);

  Future<bool> updateAccount(Account account) =>
      update(accounts).replace(account);

  Future<void> deleteAccount(String id) async {
    await db.transaction(() async {
      // Fetch all transactions linked to this account (as source or destination)
      final sourceTxs = await (db.select(
        db.transactions,
      )..where((t) => t.accountId.equals(id))).get();
      final destTxs = await (db.select(
        db.transactions,
      )..where((t) => t.destinationAccountId.equals(id))).get();
      final allTxIds = <String>{...sourceTxs.map((t) => t.id), ...destTxs.map((t) => t.id)};

      // Reverse balance adjustments for each transaction
      for (final tx in [...sourceTxs, ...destTxs]) {
        final txAccId = tx.accountId;
        if (txAccId == null) continue;
        final account = await (db.select(
          db.accounts,
        )..where((t) => t.id.equals(txAccId))).getSingleOrNull();
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
          await (db.update(
            db.accounts,
          )..where((t) => t.id.equals(account.id))).write(
            AccountsCompanion(balance: Value(account.balance + balanceDelta)),
          );
        }

        // For transfers, also reverse the destination credit
        if (tx.type.toLowerCase() == 'transfer' &&
            tx.destinationAccountId != null) {
          final destAccount =
              await (db.select(db.accounts)
                    ..where((t) => t.id.equals(tx.destinationAccountId!)))
                  .getSingleOrNull();
          if (destAccount != null) {
            await (db.update(
              db.accounts,
            )..where((t) => t.id.equals(destAccount.id))).write(
              AccountsCompanion(
                balance: Value(destAccount.balance - tx.amount),
              ),
            );
          }
        }
      }

      // Delete all linked transactions
      if (allTxIds.isNotEmpty) {
        await (db.delete(
          db.transactions,
        )..where((t) => t.id.isIn(allTxIds.toList()))).go();
      }

      // Delete the account
      await (delete(accounts)..where((t) => t.id.equals(id))).go();
    });
  }
}
