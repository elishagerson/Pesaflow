import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/account_dao.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/database/daos/category_dao.dart';

void main() {
  test('account delete repro', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final accountDao = AccountDao(db);
    final transactionDao = TransactionDao(db);
    final categoryDao = CategoryDao(db);
    final categories = await categoryDao.getAllCategories();
    final cat = categories.first;
    final acc = Account(id: 'acc1', name: 'Test', type: 'cash', balance: 10000, provider: 'test', icon: 'wallet', sortOrder: 0, isArchived: false, createdAt: DateTime.now());
    await accountDao.insertAccount(acc);
    print('inserted acc');
    final tx = Transaction(id: 'tx1', accountId: 'acc1', categoryId: cat.id, trackerId: 'default_personal', amount: 1000, type: 'expense', description: 'test', source: 'manual', createdAt: DateTime.now(), updatedAt: DateTime.now());
    await transactionDao.writeTransactionWithBalanceAdjustment(tx);
    var accAfter = await accountDao.getAccountById('acc1');
    print('after tx balance ${accAfter?.balance} expected 9000');
    expect(accAfter?.balance, 9000);
    await accountDao.deleteAccount('acc1');
    print('delete succeeded');
    var accDeleted = await accountDao.getAccountById('acc1');
    print('acc after delete: $accDeleted expected null');
    expect(accDeleted, isNull);
    var txs = await transactionDao.getFilteredTransactions(accountId: 'acc1');
    print('txs after delete count ${txs.length} expected 0');
    expect(txs.length, 0);
    await db.close();
  });
}
