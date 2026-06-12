import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/daos/loan_dao.dart';
import '../database/database_providers.dart';

final loanRepositoryProvider = Provider<LoanRepository>((ref) {
  final dao = ref.watch(loanDaoProvider);
  return LoanRepository(dao);
});

class LoanRepository {
  final LoanDao _loanDao;

  LoanRepository(this._loanDao);

  Stream<List<Loan>> watchAllLoans({String? trackerId}) => _loanDao.watchAllLoans(trackerId: trackerId);

  Future<List<Loan>> getAllLoans({String? trackerId}) => _loanDao.getAllLoans(trackerId: trackerId);

  Stream<List<Loan>> watchActiveLoans({String? trackerId}) => _loanDao.watchActiveLoans(trackerId: trackerId);

  Future<List<Loan>> getActiveLoans({String? trackerId}) => _loanDao.getActiveLoans(trackerId: trackerId);

  Future<Loan?> getLoanById(String id) => _loanDao.getLoanById(id);

  Future<int> createLoan(Loan loan) => _loanDao.insertLoan(loan);

  Future<bool> updateLoan(Loan loan) => _loanDao.updateLoan(loan);

  Future<void> deleteLoan(String id) => _loanDao.deleteLoan(id);

  Stream<List<Transaction>> watchLoanTransactions(String loanId) => _loanDao.watchLoanTransactions(loanId);

  Future<List<Transaction>> getLoanTransactions(String loanId) => _loanDao.getLoanTransactions(loanId);

  Future<int> getTotalOutstanding({String? trackerId}) => _loanDao.getTotalOutstanding(trackerId: trackerId);

  Future<void> markLoanAsPaid(String loanId) => _loanDao.markLoanAsPaid(loanId);

  Future<void> applyPayment(String loanId, int paymentAmount) => _loanDao.applyPayment(loanId, paymentAmount);
}
