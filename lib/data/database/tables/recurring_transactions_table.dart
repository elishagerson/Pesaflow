import 'package:drift/drift.dart';

@DataClassName('RecurringTransaction')
class RecurringTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get categoryId => text().nullable()();
  IntColumn get amount => integer()(); // in TZS cents
  TextColumn get type => text()(); // income/expense/transfer
  TextColumn get description =>
      text().withLength(min: 0, max: 255).nullable()();
  TextColumn get frequency =>
      text()(); // weekly/biweekly/monthly/quarterly/yearly
  IntColumn get intervalValue => integer().withDefault(const Constant(1))();
  DateTimeColumn get nextDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('active'))(); // active/paused/cancelled
  TextColumn get trackerId => text().nullable()();
  TextColumn get merchantKeywords => text().nullable()();
  DateTimeColumn get lastPaidAt => dateTime().nullable()();
  IntColumn get totalPaid => integer().withDefault(const Constant(0))();
  IntColumn get paymentCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
