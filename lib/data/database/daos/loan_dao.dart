import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/loans_table.dart';
import '../tables/transactions_table.dart';

part 'loan_dao.g.dart';

class LoanWithTransactions {
  final Loan loan;
  final List<Transaction> transactions;

  LoanWithTransactions({
    required this.loan,
    required this.transactions,
  });
}

@DriftAccessor(tables: [Loans, Transactions])
class LoanDao extends DatabaseAccessor<AppDatabase> with _$LoanDaoMixin {
  LoanDao(super.db);

  Stream<List<Loan>> watchAllLoans({String? trackerId}) {
    final query = select(loans)
      ..orderBy([(l) => OrderingTerm.desc(l.disbursedAt)]);
    if (trackerId != null) {
      query.where((l) => l.trackerId.equals(trackerId));
    }
    return query.watch();
  }

  Future<List<Loan>> getAllLoans({String? trackerId}) {
    final query = select(loans)
      ..orderBy([(l) => OrderingTerm.desc(l.disbursedAt)]);
    if (trackerId != null) {
      query.where((l) => l.trackerId.equals(trackerId));
    }
    return query.get();
  }

  Stream<List<Loan>> watchActiveLoans({String? trackerId}) {
    final query = select(loans)
      ..where((l) => l.status.equals('active'))
      ..orderBy([(l) => OrderingTerm.desc(l.disbursedAt)]);
    if (trackerId != null) {
      query.where((l) => l.trackerId.equals(trackerId));
    }
    return query.watch();
  }

  Future<List<Loan>> getActiveLoans({String? trackerId}) {
    final query = select(loans)
      ..where((l) => l.status.equals('active'))
      ..orderBy([(l) => OrderingTerm.desc(l.disbursedAt)]);
    if (trackerId != null) {
      query.where((l) => l.trackerId.equals(trackerId));
    }
    return query.get();
  }

  Future<Loan?> getLoanById(String id) {
    return (select(loans)..where((l) => l.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertLoan(Loan loan) => into(loans).insert(loan);

  Future<bool> updateLoan(Loan loan) => update(loans).replace(loan);

  Future<void> deleteLoan(String id) async {
    await transaction(() async {
      await (delete(transactions)..where((t) => t.loanId.equals(id))).go();
      await (delete(loans)..where((l) => l.id.equals(id))).go();
    });
  }

  /// Get all transactions linked to a loan
  Stream<List<Transaction>> watchLoanTransactions(String loanId) {
    return (select(transactions)
          ..where((t) => t.loanId.equals(loanId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<List<Transaction>> getLoanTransactions(String loanId) {
    return (select(transactions)
          ..where((t) => t.loanId.equals(loanId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Get total outstanding loan balance for active loans
  Future<int> getTotalOutstanding({String? trackerId}) async {
    final query = selectOnly(loans)
      ..addColumns([loans.remaining.sum()])
      ..where(loans.status.equals('active'));
    if (trackerId != null) {
      query.where(loans.trackerId.equals(trackerId));
    }
    final result = await query.getSingle();
    return result.read(loans.remaining.sum()) ?? 0;
  }

  /// Mark a loan as paid
  Future<void> markLoanAsPaid(String loanId) async {
    final loan = await getLoanById(loanId);
    if (loan == null) return;
    await update(loans).replace(loan.copyWith(
      status: 'paid',
      remaining: 0,
      paidAt: Value(DateTime.now()),
      updatedAt: DateTime.now(),
    ));
  }

  /// Reduce remaining balance by a payment amount
  Future<void> applyPayment(String loanId, int paymentAmount) async {
    final loan = await getLoanById(loanId);
    if (loan == null) return;
    final newRemaining = (loan.remaining - paymentAmount).clamp(0, loan.amount);
    final isPaid = newRemaining == 0;
    await update(loans).replace(loan.copyWith(
      remaining: newRemaining,
      status: isPaid ? 'paid' : loan.status,
      paidAt: isPaid ? Value(DateTime.now()) : loan.paidAt,
      updatedAt: DateTime.now(),
    ));
  }
}
