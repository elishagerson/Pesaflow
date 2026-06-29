import 'dart:math';
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/loans_table.dart';
import '../tables/transactions_table.dart';

part 'loan_dao.g.dart';

class LoanWithTransactions {
  final Loan loan;
  final List<Transaction> transactions;

  LoanWithTransactions({required this.loan, required this.transactions});
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

  /// Stream only paid loans
  Stream<List<Loan>> watchPaidLoans({String? trackerId}) {
    final query = select(loans)
      ..where((l) => l.status.equals('paid'))
      ..orderBy([(l) => OrderingTerm.desc(l.paidAt)]);
    if (trackerId != null) {
      query.where((l) => l.trackerId.equals(trackerId));
    }
    return query.watch();
  }

  /// One-shot fetch of paid loans
  Future<List<Loan>> getPaidLoans({String? trackerId}) {
    final query = select(loans)
      ..where((l) => l.status.equals('paid'))
      ..orderBy([(l) => OrderingTerm.desc(l.paidAt)]);
    if (trackerId != null) {
      query.where((l) => l.trackerId.equals(trackerId));
    }
    return query.get();
  }

  /// Count how many active loans were taken in the last N months
  Future<int> getActiveLoanCountPastMonths(
    int months, {
    String? trackerId,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: 30 * months));
    final query = select(loans)
      ..where(
        (l) =>
            l.status.equals('active') &
            l.disbursedAt.isBiggerOrEqual(Constant(cutoff)),
      );
    if (trackerId != null) {
      query.where((l) => l.trackerId.equals(trackerId));
    }
    return query.get().then((r) => r.length);
  }

  /// Total amount (cents) ever paid across all paid loans
  Future<int> getTotalPaid({String? trackerId}) async {
    final query = selectOnly(loans)
      ..addColumns([loans.amount.sum()])
      ..where(loans.status.equals('paid'));
    if (trackerId != null) {
      query.where(loans.trackerId.equals(trackerId));
    }
    final result = await query.getSingle();
    return result.read(loans.amount.sum()) ?? 0;
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
    await update(loans).replace(
      loan.copyWith(
        status: 'paid',
        remaining: 0,
        paidAt: Value(DateTime.now()),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Calculate a simple amortization schedule for a loan.
  /// Returns a list of maps with keys: payment, principal, interest, balance.
  static List<Map<String, double>> calculateAmortization(
    int amount,
    double interestRate,
    int installments,
  ) {
    final monthlyRate = interestRate / 100 / 12;
    final compound = pow(1 + monthlyRate, installments).toDouble();
    final payment = amount * monthlyRate * compound / (compound - 1);
    final schedule = <Map<String, double>>[];
    var balance = amount.toDouble();

    for (var i = 0; i < installments; i++) {
      final interest = balance * monthlyRate;
      final principal = payment - interest;
      balance -= principal;
      schedule.add({
        'payment': payment,
        'principal': principal,
        'interest': interest,
        'balance': balance < 0 ? 0 : balance,
      });
    }

    return schedule;
  }

  /// Reduce remaining balance by a payment amount
  Future<void> applyPayment(String loanId, int paymentAmount) async {
    final loan = await getLoanById(loanId);
    if (loan == null) return;
    final newRemaining = (loan.remaining - paymentAmount).clamp(0, loan.amount);
    final isPaid = newRemaining == 0;
    await update(loans).replace(
      loan.copyWith(
        remaining: newRemaining,
        status: isPaid ? 'paid' : loan.status,
        paidAt: isPaid ? Value(DateTime.now()) : Value(loan.paidAt),
        updatedAt: DateTime.now(),
      ),
    );
  }
}
