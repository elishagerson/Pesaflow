import 'package:drift/drift.dart';

@DataClassName('BudgetGroup')
class BudgetGroups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get groupType =>
      text()(); // needs, wants, investments, custom
  RealColumn get percentage =>
      real()(); // 0.0–1.0 share of income
  IntColumn get allocatedAmount =>
      integer()(); // Computed from income * percentage (TZS cents)
  TextColumn get icon =>
      text().withDefault(const Constant('wallet'))();
  TextColumn get color =>
      text().withDefault(const Constant('#6B7280'))();
  IntColumn get sortOrder =>
      integer().withDefault(const Constant(0))();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
