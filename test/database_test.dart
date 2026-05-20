import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/account_dao.dart';
import 'package:pesaflow/data/database/daos/category_dao.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';

void main() {
  late AppDatabase database;
  late AccountDao accountDao;
  late CategoryDao categoryDao;
  late TransactionDao transactionDao;

  setUp(() {
    // Open in-memory SQLite connection for testing
    database = AppDatabase(NativeDatabase.memory());
    accountDao = AccountDao(database);
    categoryDao = CategoryDao(database);
    transactionDao = TransactionDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('Drift Local Database & DAOs Verification', () {
    test('Default system categories are seeded on creation', () async {
      final list = await categoryDao.getAllCategories();
      
      // We expect at least 10 seeded default categories
      expect(list.length, greaterThanOrEqualTo(10));
      
      final salaryCat = list.firstWhere((cat) => cat.name == 'Salary');
      expect(salaryCat.type, 'income');
      expect(salaryCat.isSystem, true);

      final foodCat = list.firstWhere((cat) => cat.name == 'Food & Groceries');
      expect(foodCat.type, 'expense');
      expect(foodCat.isSystem, true);
    });

    test('Account additions and balance adjustments work together', () async {
      final uuid = const Uuid();
      final accountId = uuid.v4();

      final mockAccount = Account(
        id: accountId,
        name: 'Tigo Pesa',
        type: 'mobile_money',
        balance: 5000000, // Tsh 50,000 in cents
        provider: 'TigoPesa_TZ',
        phoneNumber: '0712345678',
        icon: 'phone-android',
        sortOrder: 0,
        isArchived: false,
        createdAt: DateTime.now(),
      );

      // 1. Insert Account
      await accountDao.insertAccount(mockAccount);
      final list = await accountDao.getAllAccounts();
      expect(list.length, 1);
      expect(list.first.balance, 5000000);

      // Find seeded category for testing
      final categoriesList = await categoryDao.getAllCategories();
      final salaryCat = categoriesList.firstWhere((cat) => cat.name == 'Salary');
      final foodCat = categoriesList.firstWhere((cat) => cat.name == 'Food & Groceries');

      // 2. Insert Income Transaction -> should increase balance
      final incomeTx = Transaction(
        id: uuid.v4(),
        accountId: accountId,
        categoryId: salaryCat.id,
        amount: 2000000, // Tsh 20,000 in cents
        type: 'income',
        description: 'Mock Bonus',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await transactionDao.writeTransactionWithBalanceAdjustment(incomeTx);
      
      // Account balance should now be 50,000 + 20,000 = 70,000
      var updatedAccount = await accountDao.getAccountById(accountId);
      expect(updatedAccount?.balance, 7000000);

      // 3. Insert Expense Transaction -> should decrease balance
      final expenseTx = Transaction(
        id: uuid.v4(),
        accountId: accountId,
        categoryId: foodCat.id,
        amount: 1500000, // Tsh 15,000 in cents
        type: 'expense',
        description: 'Supermarket shopping',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await transactionDao.writeTransactionWithBalanceAdjustment(expenseTx);

      // Account balance should now be 70,000 - 15,000 = 55,000
      updatedAccount = await accountDao.getAccountById(accountId);
      expect(updatedAccount?.balance, 5500000);

      // 4. Delete Expense Transaction -> should restore subtracted balance
      await transactionDao.deleteTransactionWithBalanceAdjustment(expenseTx.id);

      // Account balance should now be restored back to 70,000
      updatedAccount = await accountDao.getAccountById(accountId);
      expect(updatedAccount?.balance, 7000000);
    });
  });
}
