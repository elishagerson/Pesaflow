import 'package:drift/drift.dart';

@DataClassName('Budget')
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get categoryId => text()(); // FK to Categories
  TextColumn get period => text()(); // enum: weekly, biweekly, monthly, yearly
  IntColumn get amount => integer()(); // Budget limit in TZS cents
  BoolColumn get rollover => boolean().withDefault(const Constant(false))();
  TextColumn get rolloverType => text().withDefault(const Constant('none'))(); // all, capped, none
  IntColumn get rolloverCap => integer().nullable()(); // Max rollover amount in TZS cents
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  RealColumn get notificationThreshold => real().withDefault(const Constant(0.8))(); // 0.0–1.0
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
