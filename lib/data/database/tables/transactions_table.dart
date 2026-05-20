import 'package:drift/drift.dart';

@DataClassName('Transaction')
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()(); // FK to Accounts (referenced at Dart level)
  TextColumn get categoryId => text()(); // FK to Categories (referenced at Dart level)
  IntColumn get amount => integer()(); // in TZS cents (Tsh * 100)
  TextColumn get type => text()(); // enum: income, expense, transfer, airtime, fee
  TextColumn get description => text().withLength(min: 0, max: 255)();
  TextColumn get provider => text().nullable()(); // SMS provider identification (e.g. "M-Pesa_TZ")
  TextColumn get sender => text().nullable()();
  TextColumn get recipient => text().nullable()();
  TextColumn get reference => text().nullable()(); // Carrier transaction reference code
  TextColumn get rawSms => text().nullable()(); // Local encrypted raw SMS content
  DateTimeColumn get smsTimestamp => dateTime().nullable()();
  IntColumn get balanceAfter => integer().nullable()(); // Parsed remaining carrier balance
  TextColumn get source => text().withDefault(const Constant('manual'))(); // enum: manual, sms_auto, sms_reviewed
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
