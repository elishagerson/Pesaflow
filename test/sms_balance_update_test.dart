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
import 'package:pesaflow/domain/categorization/auto_categorizer.dart';
import 'package:pesaflow/domain/sms/sms_processor.dart';
import 'package:pesaflow/domain/sms/deduplicator.dart';
import 'package:pesaflow/services/notification_service.dart';

class _MockNotificationService extends NotificationService {
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
  late Deduplicator deduplicator;
  late AutoCategorizer categorizer;
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
    smsProcessor = SmsProcessor(
      accountRepo: accountRepo,
      categoryRepo: categoryRepo,
      transactionRepo: transactionRepo,
      loanRepo: loanRepo,
      settingsRepo: settingsRepo,
      deduplicator: deduplicator,
      categorizer: categorizer,
      notificationService: _MockNotificationService(),
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('Account balance pill updates when expense SMS is processed', () {
    /// Helper: seed exactly one account for [provider] with [initialBalance]
    Future<String> seedAccount({
      required String provider,
      required int initialBalance,
      String name = 'Test Account',
      String type = 'mobile_money',
      String? phoneNumber,
    }) async {
      final id = const Uuid().v4();
      await accountDao.insertAccount(Account(
        id: id,
        name: name,
        type: type,
        balance: initialBalance,
        provider: provider,
        phoneNumber: phoneNumber,
        icon: 'wallet',
        sortOrder: 1,
        isArchived: false,
        createdAt: DateTime.now(),
      ));
      return id;
    }

    /// Verify a single account has [expectedBalance]
    Future<void> verifyBalance(String accountId, int expectedBalance) async {
      final account = await accountDao.getAccountById(accountId);
      expect(account, isNotNull, reason: 'Account should exist');
      expect(account!.balance, expectedBalance,
          reason: 'Balance should match SMS carrier ground truth');
    }

    test('M-Pesa expense (Swahili sent) — Salio overwrites balance', () async {
      const initialBalance = 50000000;
      final accountId = await seedAccount(
        provider: 'M-Pesa_TZ',
        initialBalance: initialBalance,
      );

      final sms =
          'Umetuma Tsh 30,000.00 kwa Jane Doe tarehe 15/5/2026 saa 10:00. '
          'Rej: P65XYZ123. Salio: Tsh 220,000.00';
      final success = await smsProcessor.processSms('M-PESA', sms, DateTime(2026, 5, 15, 10, 0));
      expect(success, isTrue);

      // Salio in SMS is 220,000.00 → 22,000,000 cents → ground truth overwrites
      await verifyBalance(accountId, 22000000);
    });

    test('M-Pesa expense (English sent) — "New M-PESA balance" overwrites', () async {
      const initialBalance = 30000000;
      final accountId = await seedAccount(
        provider: 'M-Pesa_TZ',
        initialBalance: initialBalance,
      );

      const sms =
          'AB12CD34 Confirmed.You have sent Tsh30,000 to JANE DOE on 27/1/14 at '
          '1:19 PM New M-PESA balance is Tsh184,676';
      final success = await smsProcessor.processSms('M-PESA', sms, DateTime(2014, 1, 27, 13, 19));
      expect(success, isTrue);

      await verifyBalance(accountId, 18467600);
    });

    test('Airtel expense (Swahili sent) — Salio overwrites balance', () async {
      const initialBalance = 50000000;
      final accountId = await seedAccount(
        provider: 'AirtelMoney_TZ',
        initialBalance: initialBalance,
      );

      const sms =
          'Umetuma Tsh 20,000.00 kwa 0765432198. Rej: AT654321. Salio: Tsh 280,000.00';
      final success = await smsProcessor.processSms('AIRTEL', sms, DateTime(2026, 5, 15, 14, 30));
      expect(success, isTrue);

      await verifyBalance(accountId, 28000000);
    });

    test('Airtel expense (English sent) — Balance overwrites', () async {
      const initialBalance = 50000000;
      final accountId = await seedAccount(
        provider: 'AirtelMoney_TZ',
        initialBalance: initialBalance,
      );

      const sms =
          'You have sent TZS 20,000.00 to 0765432198. TxnID: AT654321. Balance: TZS 280,000.00';
      final success = await smsProcessor.processSms('AIRTEL', sms, DateTime(2026, 5, 15, 14, 30));
      expect(success, isTrue);

      await verifyBalance(accountId, 28000000);
    });

    test('Mixx/Tigo expense (Swahili sent) — Salio overwrites balance', () async {
      const initialBalance = 50000000;
      final accountId = await seedAccount(
        provider: 'TigoPesa_TZ',
        initialBalance: initialBalance,
      );

      const sms =
          'Umetuma TZS 15,000.00 kwa 0765432198. Kumbukumbu: MX210987. Salio: TZS 135,000.00';
      final success = await smsProcessor.processSms('MIXX', sms, DateTime(2026, 5, 15, 14, 30));
      expect(success, isTrue);

      await verifyBalance(accountId, 13500000);
    });

    test('Mixx/Tigo expense (Nivushe Plus via Malipo) — Salio jipya ni overwrites', () async {
      const initialBalance = 50000000;
      final accountId = await seedAccount(
        provider: 'TigoPesa_TZ',
        initialBalance: initialBalance,
        phoneNumber: '0712345678',
      );

      final sms =
          'Malipo yamekamilika kwenda Nivushe Plus, Kiasi Tsh645,728. '
          'Salio jipya ni Tsh 47,272. Ada Tsh 0. VAT TSh 0. '
          'Kumbukumbu no.26394529507543. 21/05/26 16:25.';
      final success = await smsProcessor.processSms('MIXX', sms, DateTime(2026, 5, 21, 16, 25));
      expect(success, isTrue);

      await verifyBalance(accountId, 4727200);
    });

    test('Mixx/Tigo expense (Bustisha loan repayment, no wallet balance)', () async {
      const initialBalance = 50000000;
      final accountId = await seedAccount(
        provider: 'TigoPesa_TZ',
        initialBalance: initialBalance,
        phoneNumber: '0765432198',
      );

      final sms =
          'You have successfully paid your Bustisha Balance by TSh 117,904.55. '
          'Your outstanding balance: TSh 8,330.60. New balance: TSh 0. '
          'TxnID: 26794215512428. Loan ID: 202606081844181845670752806590. 10/06/26 10:38.';
      final success = await smsProcessor.processSms('MIXX', sms, DateTime(2026, 6, 10, 10, 38));
      expect(success, isTrue);

      // No wallet balance in SMS — balanceAfter is null.
      // The DAO delta adjustment subtracts the amount (11790455) from initial (50000000).
      // The fallback at line 357-373 re-reads the account and checks the delta.
      // Note: the DAO adjustment was already applied, so re-reading gives the delta-applied balance.
      await verifyBalance(accountId, 50000000 - 11790455);
    });

    test('Halopesa expense (Swahili sent) — Salio overwrites balance', () async {
      const initialBalance = 50000000;
      final accountId = await seedAccount(
        provider: 'Halopesa_TZ',
        initialBalance: initialBalance,
      );

      const sms =
          'Umetuma TZS 5,000.00 kwa 0627654321. Rej: HP54321. Salio: TZS 45,000.00';
      final success = await smsProcessor.processSms('HALOPESA', sms, DateTime(2026, 5, 15, 14, 30));
      expect(success, isTrue);

      await verifyBalance(accountId, 4500000);
    });

    test('Selcom expense (English sent) — "Updated balance" overwrites', () async {
      const initialBalance = 50000000;
      final accountId = await seedAccount(
        provider: 'SelcomPesa_TZ',
        initialBalance: initialBalance,
      );

      const sms =
          '0517EQN0Z Accepted. You have sent TZS 477,000.00 to PARTS AND COMPONENTS MBEYA - 19938686 '
          'on 2026-05-17 17:58:34. Charge is FREE. Transaction 13 of 150-Hello Mwezi. '
          'Updated balance is TZS 319.85. Help 0800 714 888 / 0800 784 888';
      final success = await smsProcessor.processSms('SELCOM', sms, DateTime(2026, 5, 17, 17, 58));
      expect(success, isTrue);

      await verifyBalance(accountId, 31985);
    });

    test('NMB Bank expense (debit) — Salio overwrites balance', () async {
      const initialBalance = 500000000;
      final accountId = await seedAccount(
        provider: 'NMB_Bank',
        initialBalance: initialBalance,
        type: 'bank',
      );

      final sms =
          'Tumekutoa TZS 150,000.00 kwa POS/MERCHANT/0123456789 tarehe 15/05/2026. '
          'Salio: TZS 1,250,000.00';
      final success = await smsProcessor.processSms('NMB', sms, DateTime(2026, 5, 15, 14, 30));
      expect(success, isTrue);

      // Salio in SMS is 1,250,000.00 → 125,000,000 cents
      await verifyBalance(accountId, 125000000);
    });

    test('CRDB Bank expense (withdrawal) — "Available" overwrites balance', () async {
      const initialBalance = 500000000;
      final accountId = await seedAccount(
        provider: 'CRDB_Bank',
        initialBalance: initialBalance,
        type: 'bank',
      );

      const sms =
          'CRDB: Withdrawal TZS 200,000.00 at ATM/Arusha. Available: TZS 800,000.00. Ref: CRDB123';
      final success = await smsProcessor.processSms('CRDB', sms, DateTime(2026, 5, 15, 14, 30));
      expect(success, isTrue);

      // Available in SMS is 800,000.00 → 80,000,000 cents
      await verifyBalance(accountId, 80000000);
    });

    test('NBC Bank expense (debit) — "Bal" overwrites balance', () async {
      const initialBalance = 500000000;
      final accountId = await seedAccount(
        provider: 'NBC_Bank',
        initialBalance: initialBalance,
        type: 'bank',
      );

      const sms =
          'NBC: TZS 50,000.00 debited from acct ****1234. Desc: AIRTIME. Bal: TZS 450,000.00';
      final success = await smsProcessor.processSms('NBC', sms, DateTime(2026, 5, 15, 14, 30));
      expect(success, isTrue);

      // Bal in SMS is 450,000.00 → 45,000,000 cents
      await verifyBalance(accountId, 45000000);
    });
  });
}
