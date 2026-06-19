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
import 'package:pesaflow/data/repositories/loan_repository.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';
import 'package:pesaflow/data/database/daos/loan_dao.dart';
import 'package:pesaflow/data/database/daos/subscription_dao.dart';
import 'package:pesaflow/data/repositories/subscription_repository.dart';
import 'package:pesaflow/domain/categorization/auto_categorizer.dart';
import 'package:pesaflow/domain/sms/sms_processor.dart';
import 'package:pesaflow/domain/sms/deduplicator.dart';
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

void main() {
  late AppDatabase database;
  late AccountDao accountDao;
  late CategoryDao categoryDao;
  late TransactionDao transactionDao;
  late SettingsDao settingsDao;

  late AccountRepository accountRepo;
  late CategoryRepository categoryRepo;
  late TransactionRepository transactionRepo;
  late LoanRepository loanRepo;
  late SettingsRepository settingsRepo;
  late SubscriptionRepository subscriptionRepo;
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
    transactionRepo = TransactionRepository(transactionDao, null);
    loanRepo = LoanRepository(LoanDao(database));
    settingsRepo = SettingsRepository(settingsDao);
    deduplicator = Deduplicator(transactionRepo);
    categorizer = AutoCategorizer(categoryRepo, transactionDao);
    notificationService = MockNotificationService();
    subscriptionRepo = SubscriptionRepository(SubscriptionDao(database));

    smsProcessor = SmsProcessor(
      accountRepo: accountRepo,
      categoryRepo: categoryRepo,
      transactionRepo: transactionRepo,
      loanRepo: loanRepo,
      settingsRepo: settingsRepo,
      subscriptionRepo: subscriptionRepo,
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
      // Single consistent match yields 0.85; two or more would yield 0.99
      expect(dynamicRes.confidence, 0.85);
    });
  });

  group('Automated Transfer & Deduplication Tests', () {
    test('Intercepts P2P transfer as a Transfer transaction and deduplicates counterparty SMS', () async {
      // 1. Seed two accounts on different providers with distinct phone numbers
      final senderId = const Uuid().v4();
      final receiverId = const Uuid().v4();
      const senderPhone = '0712345678';
      const receiverPhone = '0765432109';

      await accountDao.insertAccount(Account(
        id: senderId,
        name: 'Alice',
        type: 'mobile_money',
        balance: 50000000, // Tsh 500k in cents
        provider: 'M-Pesa_TZ',
        phoneNumber: senderPhone,
        icon: 'phone',
        sortOrder: 1,
        isArchived: false,
        createdAt: DateTime.now(),
      ));

      await accountDao.insertAccount(Account(
        id: receiverId,
        name: 'Bob',
        type: 'mobile_money',
        balance: 20000000, // Tsh 200k in cents
        provider: 'TigoPesa_TZ',
        phoneNumber: receiverPhone,
        icon: 'phone',
        sortOrder: 2,
        isArchived: false,
        createdAt: DateTime.now(),
      ));

      final transferTime = DateTime.now();

      // 2. Simulate the SENDER's M-Pesa SMS (expense from Alice to Bob)
      final senderSms = 'Umetuma Tsh 100,000.00 kwa $receiverPhone tarehe 15/5/2026 saa 14:30. Rej: MPESA01. Salio: Tsh 400,000.00';

      final firstSuccess = await smsProcessor.processSms('M-Pesa_TZ', senderSms, transferTime);
      expect(firstSuccess, true);

      // Verify a Transfer transaction was created
      final allTx = await database.select(database.transactions).get();
      expect(allTx.length, 1);
      final tx = allTx.first;

      expect(tx.type, 'transfer');
      expect(tx.amount, 10000000); // Tsh 100,000 * 100 cents
      expect(tx.accountId, senderId); // Source is Alice
      expect(tx.destinationAccountId, receiverId); // Destination is Bob
      expect(tx.description, 'Transfer from Alice to Bob');

      // Verify balances: Alice debited (500k - 100k = 400k), Bob credited (200k + 100k = 300k)
      final updatedSender = await accountDao.getAccountById(senderId);
      final updatedReceiver = await accountDao.getAccountById(receiverId);
      expect(updatedSender?.balance, 40000000);
      expect(updatedReceiver?.balance, 30000000); // Bob credited in transfer

      // 3. Simulate RECEIVER's TigoPesa SMS arriving seconds later (income to Bob from Alice)
      // Different reference so the general deduplicator doesn't false-positive
      final receiverSms = 'Umepokea Tsh 100,000.00 kutoka kwa $senderPhone tarehe 15/5/2026 saa 14:30. Rej: TIGO02. Salio: Tsh 300,000.00';

      final secondSuccess = await smsProcessor.processSms('TigoPesa_TZ', receiverSms, transferTime.add(const Duration(seconds: 30)));
      expect(secondSuccess, true);

      // Verify exactly one Transaction remains (no duplicate)
      final finalTx = await database.select(database.transactions).get();
      expect(finalTx.length, 1);

      // Verify Bob's balance was reconciled from the SMS
      final reconciledReceiver = await accountDao.getAccountById(receiverId);
      expect(reconciledReceiver?.balance, 30000000);
    });
  });
}
