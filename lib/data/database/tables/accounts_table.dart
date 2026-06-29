import 'package:drift/drift.dart';

@DataClassName('Account')
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get type => text()(); // enum: mobile_money, bank, cash
  IntColumn get balance => integer()(); // in TZS cents (Tsh * 100)
  TextColumn get provider =>
      text().nullable()(); // SMS provider identification (e.g. "M-Pesa_TZ")
  TextColumn get phoneNumber => text().nullable()();
  TextColumn get icon => text()(); // Material icon codepoint/string
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
