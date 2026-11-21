import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/account_dao.dart';
import 'package:pesaflow/data/database/daos/category_dao.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/database/daos/settings_dao.dart';
import 'package:pesaflow/data/database/daos/loan_dao.dart';
import 'package:pesaflow/data/database/daos/analytics_dao.dart';
import 'package:pesaflow/data/database/daos/recurring_transaction_dao.dart';
import 'package:pesaflow/data/database/daos/budget_dao.dart';
import 'package:pesaflow/data/repositories/account_repository.dart';
import 'package:pesaflow/data/repositories/category_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/data/repositories/loan_repository.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';
import 'package:pesaflow/data/repositories/analytics_repository.dart';
import 'package:pesaflow/data/repositories/recurring_transaction_repository.dart';
import 'package:pesaflow/domain/categorization/auto_categorizer.dart';
import 'package:pesaflow/domain/sms/deduplicator.dart';
import 'package:pesaflow/domain/sms/parsers/mpesa_tz_parser.dart';
import 'package:pesaflow/domain/sms/parsers/mixx_parser.dart';
import 'package:pesaflow/domain/sms/parsers/airtel_tz_parser.dart';
import 'package:pesaflow/domain/sms/sms_processor.dart';
import 'package:pesaflow/services/budget_alert_service.dart';
import 'package:pesaflow/services/notification_service.dart';

class _MockNotificationService extends NotificationService {
  String? lastTitle;
  String? lastBody;

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    bool needsReview = false,
  }) async {
    lastTitle = title;
    lastBody = body;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Reversals Parser Unit Tests', () {
    test('MpesaTzParser parses Swahili reversal SMS', () {
      final parser = MpesaTzParser();
      const body =
          'Muamala 5H8392HD wa Tsh 10,000.00 umerudishwa. Salio lako jipya la M-Pesa ni Tsh 45,000.00.';
      final parsed = parser.parse(body, DateTime.now());

      expect(parsed, isNotNull);
      expect(parsed!.type, 'reversal');
      expect(parsed.amount, 1000000); // 10,000 TZS in cents
      expect(parsed.reversedReference, '5H8392HD');
      expect(parsed.balanceAfter, 4500000); // 45,000 TZS in cents
    });

    test('MpesaTzParser parses English reversal SMS', () {
      final parser = MpesaTzParser();
      const body =
          'Transaction 5H8392HD of Tsh 15,500.00 has been reversed. New M-PESA balance is Tsh 60,000.00.';
      final parsed = parser.parse(body, DateTime.now());

      expect(parsed, isNotNull);
      expect(parsed!.type, 'reversal');
      expect(parsed.amount, 1550000);
      expect(parsed.reversedReference, '5H8392HD');
      expect(parsed.balanceAfter, 6000000);
    });

    test('MixxParser parses Swahili reversal SMS', () {
      final parser = MixxParser();
      const body =
          'Muamala namba 12345678 wa Tsh 20,000.00 umerudishwa. Salio jipya ni Tsh 75,000.00.';
      final parsed = parser.parse(body, DateTime.now());

      expect(parsed, isNotNull);
      expect(parsed!.type, 'reversal');
      expect(parsed.amount, 2000000);
      expect(parsed.reversedReference, '12345678');
      expect(parsed.balanceAfter, 7500000);
    });

    test('AirtelTzParser parses Swahili reversal SMS', () {
      final parser = AirtelTzParser();
      const body =
          'Muamala wenye kumbukumbu AT998877 wa Tsh 8,000.00 umerudishwa. Salio: Tsh 35,000.00.';
      final parsed = parser.parse(body, DateTime.now());

      expect(parsed, isNotNull);
      expect(parsed!.type, 'reversal');
      expect(parsed.amount, 800000);
      expect(parsed.reversedReference, 'AT998877');
      expect(parsed.balanceAfter, 3500000);
    });
  });

  group('SmsProcessor Reversal Integration Tests', () {
    late AppDatabase db;
    late AccountDao accountDao;
    late CategoryDao categoryDao;
    late TransactionDao transactionDao;
    late SettingsDao settingsDao;
    late LoanDao loanDao;
    late AccountRepository accountRepo;
    late CategoryRepository categoryRepo;
    late TransactionRepository transactionRepo;
    late LoanRepository loanRepo;
    late SettingsRepository settingsRepo;
    late RecurringTransactionRepository recurringTransactionRepo;
    late _MockNotificationService mockNotificationService;
    late SmsProcessor processor;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      accountDao = AccountDao(db);
      categoryDao = CategoryDao(db);
      transactionDao = TransactionDao(db);
      settingsDao = SettingsDao(db);
      loanDao = LoanDao(db);
      final analyticsDao = AnalyticsDao(db);
      final budgetDao = BudgetDao(db);
      final recurringDao = RecurringTransactionDao(db);

      accountRepo = AccountRepository(accountDao);
      categoryRepo = CategoryRepository(categoryDao);
      final analyticsRepo = AnalyticsRepository(analyticsDao);
      mockNotificationService = _MockNotificationService();
      final budgetAlertService = BudgetAlertService(
        budgetDao: budgetDao,
        notificationService: mockNotificationService,
      );
      transactionRepo = TransactionRepository(
        transactionDao,
        budgetAlertService,
        analyticsRepo,
      );
      loanRepo = LoanRepository(
        loanDao,
        transactionDao,
        db,
        analyticsRepo,
        budgetAlertService,
      );
      settingsRepo = SettingsRepository(settingsDao);
      recurringTransactionRepo = RecurringTransactionRepository(
        recurringDao,
        transactionDao,
        db,
      );

      final deduplicator = Deduplicator(transactionRepo);
      final categorizer = AutoCategorizer(categoryRepo, transactionDao);

      processor = SmsProcessor(
        accountRepo: accountRepo,
        categoryRepo: categoryRepo,
        transactionRepo: transactionRepo,
        loanRepo: loanRepo,
        settingsRepo: settingsRepo,
        recurringTransactionRepo: recurringTransactionRepo,
        deduplicator: deduplicator,
        categorizer: categorizer,
        notificationService: mockNotificationService,
        debounceEnabled: false,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'Reversal creates offsetting income transaction and updates account balance',
      () async {
        const uuid = Uuid();
        // 1. Seed Account
        final accountId = uuid.v4();
        await accountDao.insertAccount(
          Account(
            id: accountId,
            name: 'M-Pesa Wallet',
            type: 'mobile_money',
            provider: 'M-Pesa_TZ',
            balance: 5000000, // 50,000 TZS
            icon: 'phone',
            sortOrder: 1,
            isArchived: false,
            createdAt: DateTime.now(),
          ),
        );

        // 2. Seed Category
        final categoryId = uuid.v4();
        await categoryDao.insertCategory(
          Category(
            id: categoryId,
            name: 'Shopping',
            icon: 'shopping-bag',
            color: '#00BCD4',
            type: 'expense',
            sortOrder: 1,
            isSystem: true,
            createdAt: DateTime.now(),
          ),
        );

        // 3. Create an original expense transaction that will later be reversed
        const originalRef = '5H8392HD';
        await transactionRepo.createTransaction(
          Transaction(
            id: uuid.v4(),
            accountId: accountId,
            categoryId: categoryId,
            amount: 1000000, // 10,000 TZS
            type: 'expense',
            description: 'Supermarket shopping',
            provider: 'M-Pesa_TZ',
            reference: originalRef,
            rawSms: 'Sent Tsh 10,000 to Supermarket',
            source: 'sms_auto',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // 4. Process incoming reversal SMS
        const reversalSms =
            'Muamala 5H8392HD wa Tsh 10,000.00 umerudishwa. Salio lako jipya la M-Pesa ni Tsh 50,000.00.';
        final success = await processor.processSms(
          'M-PESA',
          reversalSms,
          DateTime.now(),
        );

        expect(success, isTrue);

        // 5. Verify the reversal transaction was created
        final txs = await db.select(db.transactions).get();
        expect(txs.length, 2);

        final reversalTx = txs.firstWhere((t) => t.reference != originalRef);
        expect(reversalTx.type, 'income'); // Credited back
        expect(reversalTx.amount, 1000000);
        expect(
          reversalTx.description,
          contains('Reversal: Supermarket shopping'),
        );
        expect(reversalTx.balanceAfter, 5000000);

        // 6. Verify account balance was updated to carrier reported balance
        final account = await accountRepo.getAccountById(accountId);
        expect(account?.balance, 5000000);

        // 7. Verify notification was sent
        expect(mockNotificationService.lastTitle, 'Transaction Reversed');
        expect(mockNotificationService.lastBody, contains('5H8392HD'));
      },
    );
  });
}
