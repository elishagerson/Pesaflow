import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/recurring_transaction_dao.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/database/daos/account_dao.dart';
import 'package:pesaflow/data/database/daos/category_dao.dart';
import 'package:pesaflow/domain/recurring/recurring_transaction_service.dart';

void main() {
  late AppDatabase database;
  late RecurringTransactionDao recurringDao;
  late TransactionDao transactionDao;
  late AccountDao accountDao;
  late CategoryDao categoryDao;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    recurringDao = RecurringTransactionDao(database);
    transactionDao = TransactionDao(database);
    accountDao = AccountDao(database);
    categoryDao = CategoryDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('RecurringTransactionService', () {
    test('calculateNextDate advances weekly frequency by 7 days', () {
      final service = RecurringTransactionService(
        recurringDao: recurringDao,
        transactionDao: transactionDao,
      );

      final recurring = RecurringTransaction(
        id: const Uuid().v4(),
        accountId: 'test',
        amount: 5000000,
        type: 'expense',
        frequency: 'weekly',
        intervalValue: 1,
        nextDate: DateTime(2025, 1, 1),
        status: 'active',
        trackerId: 'default_personal',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      final next = service.calculateNextDate(recurring);
      expect(next, DateTime(2025, 1, 8));
    });

    test('calculateNextDate advances monthly frequency by 1 month', () {
      final service = RecurringTransactionService(
        recurringDao: recurringDao,
        transactionDao: transactionDao,
      );

      final recurring = RecurringTransaction(
        id: const Uuid().v4(),
        accountId: 'test',
        amount: 5000000,
        type: 'expense',
        frequency: 'monthly',
        intervalValue: 1,
        nextDate: DateTime(2025, 3, 15),
        status: 'active',
        trackerId: 'default_personal',
        createdAt: DateTime(2025, 3, 15),
        updatedAt: DateTime(2025, 3, 15),
      );

      final next = service.calculateNextDate(recurring);
      expect(next, DateTime(2025, 4, 15));
    });

    test('calculateNextDate advances quarterly by 3 months', () {
      final service = RecurringTransactionService(
        recurringDao: recurringDao,
        transactionDao: transactionDao,
      );

      final recurring = RecurringTransaction(
        id: const Uuid().v4(),
        accountId: 'test',
        amount: 5000000,
        type: 'expense',
        frequency: 'quarterly',
        intervalValue: 1,
        nextDate: DateTime(2025, 1, 1),
        status: 'active',
        trackerId: 'default_personal',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      final next = service.calculateNextDate(recurring);
      expect(next, DateTime(2025, 4, 1));
    });

    test('calculateNextDate advances yearly by 1 year', () {
      final service = RecurringTransactionService(
        recurringDao: recurringDao,
        transactionDao: transactionDao,
      );

      final recurring = RecurringTransaction(
        id: const Uuid().v4(),
        accountId: 'test',
        amount: 5000000,
        type: 'expense',
        frequency: 'yearly',
        intervalValue: 1,
        nextDate: DateTime(2025, 6, 15),
        status: 'active',
        trackerId: 'default_personal',
        createdAt: DateTime(2025, 6, 15),
        updatedAt: DateTime(2025, 6, 15),
      );

      final next = service.calculateNextDate(recurring);
      expect(next, DateTime(2026, 6, 15));
    });

    test('processDueTransactions creates real transactions for due recurring', () async {
      final accountId = const Uuid().v4();
      final categories = await categoryDao.getAllCategories();
      final foodCat = categories.firstWhere((c) => c.name == 'Food & Groceries');

      await accountDao.insertAccount(Account(
        id: accountId,
        name: 'Test Wallet',
        type: 'cash',
        balance: 10000000,
        icon: 'wallet',
        sortOrder: 0,
        isArchived: false,
        createdAt: DateTime.now(),
      ));

      final dueDate = DateTime.now().subtract(const Duration(days: 1));
      final futureDate = DateTime.now().add(const Duration(days: 30));

      await recurringDao.insertRecurringTransaction(RecurringTransaction(
        id: const Uuid().v4(),
        accountId: accountId,
        categoryId: foodCat.id,
        amount: 5000000,
        type: 'expense',
        description: 'Monthly groceries',
        frequency: 'monthly',
        intervalValue: 1,
        nextDate: dueDate,
        status: 'active',
        trackerId: 'default_personal',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await recurringDao.insertRecurringTransaction(RecurringTransaction(
        id: const Uuid().v4(),
        accountId: accountId,
        categoryId: foodCat.id,
        amount: 5000000,
        type: 'expense',
        description: 'Future bill',
        frequency: 'monthly',
        intervalValue: 1,
        nextDate: futureDate,
        status: 'active',
        trackerId: 'default_personal',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final service = RecurringTransactionService(
        recurringDao: recurringDao,
        transactionDao: transactionDao,
      );

      final processed = await service.processDueTransactions();
      expect(processed, 1);

      // Verify transaction was created
      final allTxns = await database.select(database.transactions).get();
      expect(allTxns.length, 1);
      expect(allTxns.first.description, 'Monthly groceries (auto)');
      expect(allTxns.first.amount, 5000000);

      // Verify nextDate was advanced
      final allRecurring = await recurringDao.getAll();
      final monthly = allRecurring.firstWhere((r) => r.description == 'Monthly groceries');
      expect(monthly.nextDate.isAfter(dueDate), true);
    });

    test('processDueTransactions does nothing when none are due', () async {
      final service = RecurringTransactionService(
        recurringDao: recurringDao,
        transactionDao: transactionDao,
      );

      final futureDate = DateTime.now().add(const Duration(days: 30));
      await recurringDao.insertRecurringTransaction(RecurringTransaction(
        id: const Uuid().v4(),
        accountId: 'test',
        amount: 5000000,
        type: 'expense',
        frequency: 'monthly',
        intervalValue: 1,
        nextDate: futureDate,
        status: 'active',
        trackerId: 'default_personal',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final processed = await service.processDueTransactions();
      expect(processed, 0);

      final allTxns = await database.select(database.transactions).get();
      expect(allTxns, isEmpty);
    });
  });
}
