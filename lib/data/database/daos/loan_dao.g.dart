// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loan_dao.dart';

// ignore_for_file: type=lint
mixin _$LoanDaoMixin on DatabaseAccessor<AppDatabase> {
  $LoansTable get loans => attachedDatabase.loans;
  $TransactionsTable get transactions => attachedDatabase.transactions;
  LoanDaoManager get managers => LoanDaoManager(this);
}

class LoanDaoManager {
  final _$LoanDaoMixin _db;
  LoanDaoManager(this._db);
  $$LoansTableTableManager get loans =>
      $$LoansTableTableManager(_db.attachedDatabase, _db.loans);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db.attachedDatabase, _db.transactions);
}
