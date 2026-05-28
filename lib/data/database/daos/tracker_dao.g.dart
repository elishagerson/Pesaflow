// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracker_dao.dart';

// ignore_for_file: type=lint
mixin _$TrackerDaoMixin on DatabaseAccessor<AppDatabase> {
  $TrackersTable get trackers => attachedDatabase.trackers;
  TrackerDaoManager get managers => TrackerDaoManager(this);
}

class TrackerDaoManager {
  final _$TrackerDaoMixin _db;
  TrackerDaoManager(this._db);
  $$TrackersTableTableManager get trackers =>
      $$TrackersTableTableManager(_db.attachedDatabase, _db.trackers);
}
