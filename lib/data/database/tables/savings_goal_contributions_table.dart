import 'package:drift/drift.dart';

@DataClassName('SavingsGoalContribution')
class SavingsGoalContributions extends Table {
  TextColumn get id => text()();
  TextColumn get savingsGoalId => text()(); // FK to SavingsGoals
  IntColumn get amount => integer()(); // positive for deposit, negative for withdrawal, in TZS cents
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
