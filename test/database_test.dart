import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/account_dao.dart';
import 'package:pesaflow/data/database/daos/category_dao.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/database/daos/tracker_dao.dart';

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
    test('Default tracker "Personal" is seeded on creation', () async {
      final list = await database.select(database.trackers).get();
      expect(list.length, 1);
      expect(list.first.id, 'default_personal');
      expect(list.first.name, 'Personal');
      expect(list.first.icon, 'person');
    });

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
        source: 'manual',
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
        source: 'manual',
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

    test('approveReviewedTransaction updates source and links with active tracker ID if null', () async {
      final uuid = const Uuid();
      final accountId = uuid.v4();

      final mockAccount = Account(
        id: accountId,
        name: 'M-Pesa',
        type: 'mobile_money',
        balance: 100000,
        provider: 'M-Pesa_TZ',
        icon: 'phone-android',
        sortOrder: 1,
        isArchived: false,
        createdAt: DateTime.now(),
      );

      await accountDao.insertAccount(mockAccount);

      final categoriesList = await categoryDao.getAllCategories();
      final foodCat = categoriesList.firstWhere((cat) => cat.name == 'Food & Groceries');

      // Create transaction with source 'sms_reviewed' and null trackerId
      final transaction = Transaction(
        id: uuid.v4(),
        accountId: accountId,
        categoryId: foodCat.id,
        amount: 10000,
        type: 'expense',
        description: 'Supermarket',
        source: 'sms_reviewed',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await transactionDao.writeTransactionWithBalanceAdjustment(transaction);

      // Verify created state
      var retrieved = await (database.select(database.transactions)
            ..where((t) => t.id.equals(transaction.id)))
          .getSingle();
      expect(retrieved.source, 'sms_reviewed');
      expect(retrieved.trackerId, isNull);

      // Approve transaction
      await transactionDao.approveReviewedTransaction(transaction.id);

      // Verify approved state: source should be sms_auto and trackerId should be default_personal
      retrieved = await (database.select(database.transactions)
            ..where((t) => t.id.equals(transaction.id)))
          .getSingle();
      expect(retrieved.source, 'sms_auto');
      expect(retrieved.trackerId, 'default_personal');
    });

    test('tracker deletion cascade deletes transactions, savings goals and contribution adjustments', () async {
      final uuid = const Uuid();
      final accountId = uuid.v4();
      final trackerId = uuid.v4();

      // 1. Create a workspace (tracker)
      final mockTracker = Tracker(
        id: trackerId,
        name: 'Trip Fund',
        icon: 'flight',
        color: '#F43F5E',
        isArchived: false,
        createdAt: DateTime.now(),
      );
      await database.into(database.trackers).insert(mockTracker);

      // 2. Create an account with balance 100,000 cents (100,000 Tsh)
      final mockAccount = Account(
        id: accountId,
        name: 'M-Pesa Test',
        type: 'mobile_money',
        balance: 10000000,
        provider: 'M-Pesa_TZ',
        icon: 'phone-android',
        sortOrder: 0,
        isArchived: false,
        createdAt: DateTime.now(),
      );
      await accountDao.insertAccount(mockAccount);

      // Find category
      final categoriesList = await categoryDao.getAllCategories();
      final foodCat = categoriesList.firstWhere((cat) => cat.name == 'Food & Groceries');

      // 3. Write a transaction (15,000 Tsh expense) in the new workspace
      final tx = Transaction(
        id: uuid.v4(),
        accountId: accountId,
        categoryId: foodCat.id,
        trackerId: trackerId,
        amount: 1500000,
        type: 'expense',
        description: 'Dinner',
        source: 'manual',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await transactionDao.writeTransactionWithBalanceAdjustment(tx);

      // Verify account balance is adjusted to 100,000 - 15,000 = 85,000
      var account = await accountDao.getAccountById(accountId);
      expect(account?.balance, 8500000);

      // 4. Add a savings goal in the new workspace
      final goalId = uuid.v4();
      final mockGoal = SavingsGoal(
        id: goalId,
        name: 'New Car',
        targetAmount: 5000000,
        currentAmount: 0,
        targetDate: DateTime.now().add(const Duration(days: 30)),
        color: '#4CAF50',
        icon: 'piggy-bank',
        trackerId: trackerId,
        isCompleted: false,
        createdAt: DateTime.now(),
      );
      await database.into(database.savingsGoals).insert(mockGoal);

      // 5. Add a savings goal contribution
      final contribution = SavingsGoalContribution(
        id: uuid.v4(),
        savingsGoalId: goalId,
        amount: 500000,
        createdAt: DateTime.now(),
      );
      await database.into(database.savingsGoalContributions).insert(contribution);

      // Verify they exist in DB
      final goalsBefore = await (database.select(database.savingsGoals)..where((t) => t.trackerId.equals(trackerId))).get();
      expect(goalsBefore.length, 1);
      final txsBefore = await (database.select(database.transactions)..where((t) => t.trackerId.equals(trackerId))).get();
      expect(txsBefore.length, 1);

      // 6. Delete tracker with cascade
      final trackerDao = TrackerDao(database);
      await trackerDao.deleteTrackerWithCascade(trackerId);

      // 7. Verify all entities associated with tracker are deleted
      final trackersAfter = await (database.select(database.trackers)..where((t) => t.id.equals(trackerId))).get();
      expect(trackersAfter.isEmpty, true);

      final txsAfter = await (database.select(database.transactions)..where((t) => t.trackerId.equals(trackerId))).get();
      expect(txsAfter.isEmpty, true);

      final goalsAfter = await (database.select(database.savingsGoals)..where((t) => t.trackerId.equals(trackerId))).get();
      expect(goalsAfter.isEmpty, true);

      final contributionsAfter = await (database.select(database.savingsGoalContributions)..where((t) => t.savingsGoalId.equals(goalId))).get();
      expect(contributionsAfter.isEmpty, true);

      // 8. Verify account balance is reversed to 100,000 Tsh
      account = await accountDao.getAccountById(accountId);
      expect(account?.balance, 10000000);
    });
  });
}

