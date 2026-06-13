import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/loan_dao.dart';
import 'package:pesaflow/data/database/daos/account_dao.dart';
import 'package:pesaflow/data/database/daos/category_dao.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';

void main() {
  late AppDatabase database;
  late LoanDao loanDao;
  late AccountDao accountDao;
  late CategoryDao categoryDao;
  late TransactionDao transactionDao;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    loanDao = LoanDao(database);
    accountDao = AccountDao(database);
    categoryDao = CategoryDao(database);
    transactionDao = TransactionDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('LoanDao', () {
    test('inserts and retrieves a loan', () async {
      final loan = Loan(
        id: const Uuid().v4(),
        amount: 50000000,
        remaining: 50000000,
        status: 'active',
        provider: 'NMB Bank',
        description: 'Personal loan',
        sender: 'NMB',
        reference: 'REF123',
        disbursedAt: DateTime.now(),
        dueAt: DateTime.now().add(const Duration(days: 30)),
        trackerId: 'default_personal',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await loanDao.insertLoan(loan);
      final retrieved = await loanDao.getLoanById(loan.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.amount, 50000000);
      expect(retrieved.provider, 'NMB Bank');
      expect(retrieved.status, 'active');
    });

    test('inserts and retrieves a loan with interest rate', () async {
      final loan = Loan(
        id: const Uuid().v4(),
        amount: 100000000,
        remaining: 100000000,
        status: 'active',
        provider: 'CRDB',
        interestRate: 18.5,
        installmentAmount: 10000000,
        totalInstallments: 12,
        paidInstallments: 2,
        disbursedAt: DateTime.now(),
        trackerId: 'default_personal',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await loanDao.insertLoan(loan);
      final retrieved = await loanDao.getLoanById(loan.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.interestRate, 18.5);
      expect(retrieved.installmentAmount, 10000000);
      expect(retrieved.totalInstallments, 12);
      expect(retrieved.paidInstallments, 2);
    });

    test('returns active loans only', () async {
      final activeId = const Uuid().v4();
      final paidId = const Uuid().v4();

      await loanDao.insertLoan(Loan(
        id: activeId,
        amount: 50000000,
        remaining: 30000000,
        status: 'active',
        disbursedAt: DateTime.now(),
        trackerId: 'default_personal',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await loanDao.insertLoan(Loan(
        id: paidId,
        amount: 50000000,
        remaining: 0,
        status: 'paid',
        paidAt: DateTime.now(),
        disbursedAt: DateTime.now(),
        trackerId: 'default_personal',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final activeLoans = await loanDao.getActiveLoans();
      expect(activeLoans.length, 1);
      expect(activeLoans.first.id, activeId);
    });

    test('markLoanAsPaid sets status to paid and remaining to 0', () async {
      final loanId = const Uuid().v4();

      await loanDao.insertLoan(Loan(
        id: loanId,
        amount: 50000000,
        remaining: 20000000,
        status: 'active',
        disbursedAt: DateTime.now(),
        trackerId: 'default_personal',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await loanDao.markLoanAsPaid(loanId);
      final loan = await loanDao.getLoanById(loanId);
      expect(loan!.status, 'paid');
      expect(loan.remaining, 0);
      expect(loan.paidAt, isNotNull);
    });

    test('applyPayment reduces remaining balance', () async {
      final loanId = const Uuid().v4();

      await loanDao.insertLoan(Loan(
        id: loanId,
        amount: 50000000,
        remaining: 50000000,
        status: 'active',
        disbursedAt: DateTime.now(),
        trackerId: 'default_personal',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await loanDao.applyPayment(loanId, 10000000);
      var loan = await loanDao.getLoanById(loanId);
      expect(loan!.remaining, 40000000);
      expect(loan.status, 'active');

      await loanDao.applyPayment(loanId, 40000000);
      loan = await loanDao.getLoanById(loanId);
      expect(loan!.remaining, 0);
      expect(loan.status, 'paid');
    });

    test('applyPayment clamps remaining to 0', () async {
      final loanId = const Uuid().v4();

      await loanDao.insertLoan(Loan(
        id: loanId,
        amount: 50000000,
        remaining: 50000000,
        status: 'active',
        disbursedAt: DateTime.now(),
        trackerId: 'default_personal',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await loanDao.applyPayment(loanId, 99999999);
      final loan = await loanDao.getLoanById(loanId);
      expect(loan!.remaining, 0);
      expect(loan.status, 'paid');
    });

    test('getTotalOutstanding sums active loan remaining balances', () async {
      await loanDao.insertLoan(Loan(
        id: const Uuid().v4(),
        amount: 50000000,
        remaining: 30000000,
        status: 'active',
        disbursedAt: DateTime.now(),
        trackerId: 'default_personal',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await loanDao.insertLoan(Loan(
        id: const Uuid().v4(),
        amount: 10000000,
        remaining: 5000000,
        status: 'active',
        disbursedAt: DateTime.now(),
        trackerId: 'default_personal',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await loanDao.insertLoan(Loan(
        id: const Uuid().v4(),
        amount: 20000000,
        remaining: 0,
        status: 'paid',
        paidAt: DateTime.now(),
        disbursedAt: DateTime.now(),
        trackerId: 'default_personal',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final total = await loanDao.getTotalOutstanding();
      expect(total, 35000000);
    });

    test('deletes loan and associated transactions', () async {
      final loanId = const Uuid().v4();
      final categories = await categoryDao.getAllCategories();
      final salaryCat = categories.firstWhere((c) => c.name == 'Salary');

      await accountDao.insertAccount(Account(
        id: const Uuid().v4(),
        name: 'Test',
        type: 'cash',
        balance: 0,
        icon: 'wallet',
        sortOrder: 0,
        isArchived: false,
        createdAt: DateTime.now(),
      ));

      await loanDao.insertLoan(Loan(
        id: loanId,
        amount: 50000000,
        remaining: 50000000,
        status: 'active',
        disbursedAt: DateTime.now(),
        trackerId: 'default_personal',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final accountId = (await accountDao.getAllAccounts()).first.id;
      final txId = const Uuid().v4();
      await transactionDao.writeTransactionWithBalanceAdjustment(Transaction(
        id: txId,
        accountId: accountId,
        categoryId: salaryCat.id,
        loanId: loanId,
        amount: 1000000,
        type: 'expense',
        description: 'Loan payment',
        source: 'manual',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await loanDao.deleteLoan(loanId);
      expect(await loanDao.getLoanById(loanId), isNull);
    });

    test('calculateAmortization returns correct schedule', () {
      final schedule = LoanDao.calculateAmortization(120000000, 12.0, 12);
      expect(schedule.length, 12);
      expect(schedule.first['payment'], greaterThan(0));
      expect(schedule.first['principal'], greaterThan(0));
      expect(schedule.first['interest'], greaterThan(0));
      expect(schedule.first['balance'], lessThan(120000000));
      expect(schedule.last['balance'], closeTo(0, 100));
    });
  });
}
