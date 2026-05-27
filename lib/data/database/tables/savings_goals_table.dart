import 'package:drift/drift.dart';

@DataClassName('SavingsGoal')
class SavingsGoals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get targetAmount => integer()(); // in TZS cents (Tsh * 100)
  IntColumn get currentAmount => integer().withDefault(const Constant(0))(); // in TZS cents
  DateTimeColumn get targetDate => dateTime()();
  TextColumn get color => text()(); // hex color e.g. "#4CAF50"
  TextColumn get icon => text()(); // icon name string e.g. "piggy-bank"
  TextColumn get trackerId => text().nullable()(); // FK to Trackers
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
