import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/account_dao.dart';
import 'package:pesaflow/data/database/daos/category_dao.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/database/daos/settings_dao.dart';
import 'package:pesaflow/data/repositories/account_repository.dart';
import 'package:pesaflow/data/repositories/category_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';
import 'package:pesaflow/domain/categorization/auto_categorizer.dart';
import 'package:pesaflow/domain/sms/sms_processor.dart';
import 'package:pesaflow/domain/sms/deduplicator.dart';
import 'package:pesaflow/services/budget_alert_service.dart';
import 'package:pesaflow/services/notification_service.dart';

class MockNotificationService extends NotificationService {
  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    bool needsReview = false,
  }) async {}
}

class MockBudgetAlertService extends BudgetAlertService {
  MockBudgetAlertService() : super(budgetDao: null!, notificationService: null!);

  @override
  Future<void> checkBudgetsAfterTransaction(String categoryId) async {}

  @override
  Future<void> checkAllBudgets() async {}
}

void main() {
  late AppDatabase database;
  late AccountDao accountDao;
  late CategoryDao categoryDao;
  late TransactionDao transactionDao;
  late SettingsDao settingsDao;

  late AccountRepository accountRepo;
  late CategoryRepository categoryRepo;
  late TransactionRepository transactionRepo;
  late SettingsRepository settingsRepo;
  late Deduplicator deduplicator;
  late AutoCategorizer categorizer;
  late MockNotificationService notificationService;
  late SmsProcessor smsProcessor;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    accountDao = AccountDao(database);
    categoryDao = CategoryDao(database);
    transactionDao = TransactionDao(database);
    settingsDao = SettingsDao(database);

    accountRepo = AccountRepository(accountDao);
    categoryRepo = CategoryRepository(categoryDao);
    transactionRepo = TransactionRepository(transactionDao, MockBudgetAlertService());
    settingsRepo = SettingsRepository(settingsDao);
    deduplicator = Deduplicator(transactionRepo);
    categorizer = AutoCategorizer(categoryRepo, transactionDao);
    notificationService = MockNotificationService();

    smsProcessor = SmsProcessor(
      accountRepo: accountRepo,
      categoryRepo: categoryRepo,
      transactionRepo: transactionRepo,
      settingsRepo: settingsRepo,
      deduplicator: deduplicator,
      categorizer: categorizer,
      notificationService: notificationService,
    );

  });

  tearDown(() async {
    await database.close();
  });

  group('Adaptive Dynamic Auto-Categorization Tests', () {
    test('Learns from past matching transactions and assigns custom categories with high confidence', () async {
      final categories = await categoryDao.getAllCategories();
      final rentCategory = categories.firstWhere((c) => c.name == 'Rent');
      final supermarketCategory = categories.firstWhere((c) => c.name == 'Food & Groceries');

      // Create target test account
      final accountId = const Uuid().v4();
      await accountDao.insertAccount(Account(
        id: accountId,
        name: 'M-Pesa',
        type: 'mobile_money',
        balance: 1000000,
        provider: 'M-Pesa_TZ',
        icon: 'phone',
        sortOrder: 1,
        isArchived: false,
        createdAt: DateTime.now(),
      ));

      // Standard keyword match checks (Supermarket -> Food & Groceries)
      final standardRes = await categorizer.categorize(
        type: 'expense',
        description: 'Supermarket POS payment',
        senderOrRecipient: 'Supermarket POS payment',
      );
      expect(standardRes.category.id, supermarketCategory.id);
      expect(standardRes.confidence, 0.95);

      // Now insert a historical transaction mapping 'Supermarket' to 'Rent' (simulating user manually recategorizing it)
      final historicalTx = Transaction(
        id: const Uuid().v4(),
        accountId: accountId,
        categoryId: rentCategory.id,
        amount: 250000,
        type: 'expense',
        description: 'Supermarket POS payment',
        sender: null,
        recipient: 'Supermarket POS payment',
        source: 'manual',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      await transactionDao.writeTransactionWithBalanceAdjustment(historicalTx);

      // Dynamically categorizing again with same desc should yield 'Rent' category and 0.99 confidence
      final dynamicRes = await categorizer.categorize(
        type: 'expense',
        description: 'Supermarket POS payment',
        senderOrRecipient: 'Supermarket POS payment',
      );
      expect(dynamicRes.category.id, rentCategory.id);
      expect(dynamicRes.confidence, 0.99);
    });
  });

  group('Automated Transfer & Deduplication Tests', () {
    test('Intercepts account deposit as a Transfer transaction and deduplicates the corresponding telco SMS', () async {
      // 1. Seed two active accounts: M-Pesa & CRDB Bank
      final mpesaId = const Uuid().v4();
      final crdbId = const Uuid().v4();

      await accountDao.insertAccount(Account(
        id: mpesaId,
        name: 'M-Pesa',
        type: 'mobile_money',
        balance: 50000000, // Tsh 500k in cents
        provider: 'M-Pesa_TZ',
        icon: 'phone',
        sortOrder: 1,
        isArchived: false,
        createdAt: DateTime.now(),
      ));

      await accountDao.insertAccount(Account(
        id: crdbId,
        name: 'CRDB Bank',
        type: 'bank',
        balance: 100000000, // Tsh 1M in cents
        provider: 'CRDB_Bank',
        icon: 'bank',
        sortOrder: 2,
        isArchived: false,
        createdAt: DateTime.now(),
      ));

      // 2. Simulate deposit SMS alert at CRDB Bank (credited from MPESA)
      // "CRDB: Deposit TZS 100,000.00 from MPESA. Available: TZS 1,100,000.00. Ref: CRDB456"
      final bankSms = "CRDB: Deposit TZS 100,000.00 from MPESA. Available: TZS 1,100,000.00. Ref: CRDB456";
      final transferTime = DateTime.now();

      final firstSuccess = await smsProcessor.processSms('CRDB', bankSms, transferTime);
      expect(firstSuccess, true);

      // Verify a Transfer transaction was created in database
      final allTx = await database.select(database.transactions).get();
      expect(allTx.length, 1);
      final tx = allTx.first;

      expect(tx.type, 'transfer');
      expect(tx.amount, 10000000); // Tsh 100,000 * 100 cents
      expect(tx.accountId, mpesaId); // Source is M-Pesa
      expect(tx.destinationAccountId, crdbId); // Destination is CRDB Bank
      expect(tx.description, 'Transfer from M-Pesa to CRDB Bank');

      // Verify that M-Pesa balance was reduced (500k - 100k = 400k)
      // and CRDB Bank balance was reconciled to exact stated ending available (Tsh 1,100,000 = 110,000,000 cents)
      final updatedMpesa = await accountDao.getAccountById(mpesaId);
      final updatedCrdb = await accountDao.getAccountById(crdbId);
      expect(updatedMpesa?.balance, 40000000);
      expect(updatedCrdb?.balance, 110000000);

      // 3. Simulate processing corresponding M-Pesa SMS alert that arrives seconds later:
      // "Umetuma Tsh 100,000.00 kwa CRDB Bank tarehe 15/5/2026 saa 14:30. Rej: P65AB. Salio: Tsh 400,000.00"
      final mpesaSms = "Umetuma Tsh 100,000.00 kwa CRDB Bank tarehe 15/5/2026 saa 14:30. Rej: P65AB. Salio: Tsh 400,000.00";
      
      final secondSuccess = await smsProcessor.processSms('M-PESA', mpesaSms, transferTime.add(const Duration(seconds: 10)));
      expect(secondSuccess, true);

      // Verify that NO new transaction was inserted (deduplicated successfully!)
      final finalTxList = await database.select(database.transactions).get();
      expect(finalTxList.length, 1); // Still exactly one transfer transaction!

      // Verify M-Pesa balance remains reconciled correctly
      final finalMpesa = await accountDao.getAccountById(mpesaId);
      expect(finalMpesa?.balance, 40000000);
    });
  });
}
