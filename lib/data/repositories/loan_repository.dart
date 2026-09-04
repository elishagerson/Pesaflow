import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/daos/loan_dao.dart';
import '../database/daos/transaction_dao.dart';
import '../database/database_providers.dart';
import 'analytics_repository.dart';
import '../../services/budget_alert_service.dart';

final loanRepositoryProvider = Provider<LoanRepository>((ref) {
  final dao = ref.watch(loanDaoProvider);
  final transactionDao = ref.watch(transactionDaoProvider);
  final db = ref.watch(databaseProvider);
  final analyticsRepo = ref.watch(analyticsRepositoryProvider);
  final budgetAlert = ref.watch(budgetAlertServiceProvider);
  return LoanRepository(dao, transactionDao, db, analyticsRepo, budgetAlert);
});

class LoanRepository {
  final LoanDao _loanDao;
  final TransactionDao _transactionDao;
  final AppDatabase _db;
  final AnalyticsRepository _analyticsRepo;
  final BudgetAlertService _budgetAlertService;

  LoanRepository(
    this._loanDao,
    this._transactionDao,
    this._db,
    this._analyticsRepo,
    this._budgetAlertService,
  );

  Stream<List<Loan>> watchAllLoans({String? trackerId}) =>
      _loanDao.watchAllLoans(trackerId: trackerId);

  Future<List<Loan>> getAllLoans({String? trackerId}) =>
      _loanDao.getAllLoans(trackerId: trackerId);

  Stream<List<Loan>> watchActiveLoans({String? trackerId}) =>
      _loanDao.watchActiveLoans(trackerId: trackerId);

  Future<List<Loan>> getActiveLoans({String? trackerId}) =>
      _loanDao.getActiveLoans(trackerId: trackerId);

  Stream<List<Loan>> watchPaidLoans({String? trackerId}) =>
      _loanDao.watchPaidLoans(trackerId: trackerId);

  Future<List<Loan>> getPaidLoans({String? trackerId}) =>
      _loanDao.getPaidLoans(trackerId: trackerId);

  Future<int> getActiveLoanCountPastMonths(int months, {String? trackerId}) =>
      _loanDao.getActiveLoanCountPastMonths(months, trackerId: trackerId);

  Future<int> getTotalPaid({String? trackerId}) =>
      _loanDao.getTotalPaid(trackerId: trackerId);

  Future<Loan?> getLoanById(String id) => _loanDao.getLoanById(id);

  Future<int> createLoan(Loan loan) => _loanDao.insertLoan(loan);

  Future<bool> updateLoan(Loan loan) => _loanDao.updateLoan(loan);

  Future<void> deleteLoan(String id) => _loanDao.deleteLoan(id);

  Stream<List<Transaction>> watchLoanTransactions(String loanId) =>
      _loanDao.watchLoanTransactions(loanId);

  Future<List<Transaction>> getLoanTransactions(String loanId) =>
      _loanDao.getLoanTransactions(loanId);

  Future<int> getTotalOutstanding({String? trackerId}) =>
      _loanDao.getTotalOutstanding(trackerId: trackerId);

  Future<void> markLoanAsPaid(String loanId) => _loanDao.markLoanAsPaid(loanId);

  Future<void> applyPayment(String loanId, int paymentAmount) =>
      _loanDao.applyPayment(loanId, paymentAmount);

  Future<void> recordPaymentWithTransaction({
    required Transaction transaction,
    required String loanId,
    required int paymentAmount,
  }) async {
    await _db.transaction(() async {
      if (transaction.accountId == null) {
        await _transactionDao.insertTransactionWithoutBalanceAdjustment(
          transaction,
        );
      } else {
        await _transactionDao.writeTransactionWithBalanceAdjustment(
          transaction,
        );
      }
      await _loanDao.applyPayment(loanId, paymentAmount);
    });
    _budgetAlertService.checkBudgetsAfterTransaction(transaction.categoryId);
    _analyticsRepo.refreshAllSnapshots(transaction.createdAt).catchError((e) {
      developer.log(
        'Loan analytics refresh failed: $e',
        name: 'LoanRepository',
      );
    });
  }
}
