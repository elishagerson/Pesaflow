import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/trackers_table.dart';

part 'tracker_dao.g.dart';

@DriftAccessor(tables: [Trackers])
class TrackerDao extends DatabaseAccessor<AppDatabase> with _$TrackerDaoMixin {
  TrackerDao(super.db);

  Stream<List<Tracker>> watchAllTrackers() {
    return (select(trackers)
          ..where((t) => t.isArchived.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<Tracker>> getAllTrackers() {
    return (select(trackers)
          ..where((t) => t.isArchived.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  Future<Tracker?> getTrackerById(String id) {
    return (select(trackers)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertTracker(Tracker tracker) => into(trackers).insert(tracker);

  Future<bool> updateTracker(Tracker tracker) => update(trackers).replace(tracker);

  Future<int> deleteTracker(String id) =>
      (delete(trackers)..where((t) => t.id.equals(id))).go();
}
