import 'package:drift/drift.dart';

@DataClassName('Subscription')
class Subscriptions extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get categoryId => text().nullable()();
  IntColumn get amount => integer()();
  TextColumn get name => text()();
  TextColumn get merchantKeywords => text()();
  TextColumn get frequency => text()();
  IntColumn get intervalValue => integer().withDefault(const Constant(1))();
  DateTimeColumn get nextDueDate => dateTime()();
  DateTimeColumn get lastPaidDate => dateTime().nullable()();
  IntColumn get totalPaid => integer().withDefault(const Constant(0))();
  IntColumn get paymentCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get trackerId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
