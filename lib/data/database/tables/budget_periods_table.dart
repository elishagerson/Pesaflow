import 'package:drift/drift.dart';

@DataClassName('BudgetPeriod')
class BudgetPeriods extends Table {
  TextColumn get id => text()();
  TextColumn get budgetId => text()(); // FK to Budgets
  DateTimeColumn get periodStart => dateTime()();
  DateTimeColumn get periodEnd => dateTime()();
  IntColumn get allocated => integer()(); // TZS cents allocated for this period
  IntColumn get spent => integer().withDefault(const Constant(0))(); // TZS cents spent
  IntColumn get rolledFrom => integer().nullable()(); // Amount rolled in from previous period
  IntColumn get rolledTo => integer().nullable()(); // Amount rolled out to next period
  BoolColumn get isClosed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
