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

  Future<bool> updateAccount(Account account) => update(accounts).replace(account);

  Future<void> deleteAccount(String id) async {
    await db.transaction(() async {
      await (db.delete(db.transactions)..where((t) => t.accountId.equals(id))).go();
      await (db.delete(db.transactions)..where((t) => t.destinationAccountId.equals(id))).go();
      await (delete(accounts)..where((t) => t.id.equals(id))).go();
    });
  }
}
