import 'package:drift/drift.dart';

@DataClassName('DailySnapshot')
class DailySnapshots extends Table {
  TextColumn get date => text()(); // Format: "2026-05-15"
  IntColumn get totalIncome => integer().withDefault(const Constant(0))();
  IntColumn get totalExpense => integer().withDefault(const Constant(0))();
  IntColumn get netCashflow => integer().withDefault(const Constant(0))();
  TextColumn get byCategory =>
      text().withDefault(const Constant('{}'))(); // JSON map
  IntColumn get dayOfWeek =>
      integer().withDefault(const Constant(1))(); // 1=Mon, 7=Sun
  BoolColumn get isWeekend => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {date};
}
