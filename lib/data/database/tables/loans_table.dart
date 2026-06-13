import 'package:drift/drift.dart';

@DataClassName('Loan')
class Loans extends Table {
  TextColumn get id => text()();
  IntColumn get amount => integer()(); // in TZS cents
  IntColumn get remaining => integer()(); // in TZS cents
  TextColumn get status => text()(); // active, paid, defaulted
  TextColumn get provider => text().nullable()();
  TextColumn get description => text().withLength(min: 0, max: 255).nullable()();
  TextColumn get sender => text().nullable()();
  TextColumn get reference => text().nullable()();
  DateTimeColumn get disbursedAt => dateTime()();
  DateTimeColumn get dueAt => dateTime().nullable()();
  DateTimeColumn get paidAt => dateTime().nullable()();
  TextColumn get trackerId => text().nullable()();
  RealColumn get interestRate => real().nullable()();
  IntColumn get installmentAmount => integer().nullable()();
  IntColumn get totalInstallments => integer().nullable()();
  IntColumn get paidInstallments => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
