import 'package:drift/drift.dart';

@DataClassName('MonthlySnapshot')
class MonthlySnapshots extends Table {
  TextColumn get yearMonth => text()(); // Format: "2026-05"
  IntColumn get totalIncome => integer().withDefault(const Constant(0))();
  IntColumn get totalExpense => integer().withDefault(const Constant(0))();
  IntColumn get netSavings => integer().withDefault(const Constant(0))();
  TextColumn get byCategory =>
      text().withDefault(const Constant('{}'))(); // JSON map
  TextColumn get byDay =>
      text().withDefault(const Constant('{}'))(); // JSON map
  RealColumn get avgDailySpend => real().withDefault(const Constant(0.0))();
  TextColumn get topMerchants =>
      text().withDefault(const Constant('{}'))(); // JSON map
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {yearMonth};
}
