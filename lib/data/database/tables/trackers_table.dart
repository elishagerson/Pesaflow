import 'package:drift/drift.dart';

@DataClassName('Tracker')
class Trackers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get icon =>
      text()(); // icon name string (e.g. 'briefcase', 'home', 'person')
  TextColumn get color => text()(); // hex color string (e.g. '#7C3AED')
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
