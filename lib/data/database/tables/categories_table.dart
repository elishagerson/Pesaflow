import 'package:drift/drift.dart';

@DataClassName('Category')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get icon => text()(); // Material icon string reference
  TextColumn get color => text()(); // Hex color string (e.g. "#FF0000")
  TextColumn get type => text()(); // enum: income, expense, transfer
  TextColumn get parentId => text().nullable()(); // self-reference for sub-categories
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
