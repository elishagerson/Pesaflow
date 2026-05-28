// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_dao.dart';

// ignore_for_file: type=lint
mixin _$AnalyticsDaoMixin on DatabaseAccessor<AppDatabase> {
  $TransactionsTable get transactions => attachedDatabase.transactions;
  $CategoriesTable get categories => attachedDatabase.categories;
  $DailySnapshotsTable get dailySnapshots => attachedDatabase.dailySnapshots;
  $MonthlySnapshotsTable get monthlySnapshots =>
      attachedDatabase.monthlySnapshots;
  AnalyticsDaoManager get managers => AnalyticsDaoManager(this);
}

class AnalyticsDaoManager {
  final _$AnalyticsDaoMixin _db;
  AnalyticsDaoManager(this._db);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db.attachedDatabase, _db.transactions);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$DailySnapshotsTableTableManager get dailySnapshots =>
      $$DailySnapshotsTableTableManager(
        _db.attachedDatabase,
        _db.dailySnapshots,
      );
  $$MonthlySnapshotsTableTableManager get monthlySnapshots =>
      $$MonthlySnapshotsTableTableManager(
        _db.attachedDatabase,
        _db.monthlySnapshots,
      );
}
