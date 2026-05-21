import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/daos/tracker_dao.dart';
import '../database/database_providers.dart';

final trackerRepositoryProvider = Provider<TrackerRepository>((ref) {
  final dao = ref.watch(trackerDaoProvider);
  return TrackerRepository(dao);
});

class TrackerRepository {
  final TrackerDao _trackerDao;

  TrackerRepository(this._trackerDao);

  Stream<List<Tracker>> watchAllTrackers() => _trackerDao.watchAllTrackers();

  Future<List<Tracker>> getAllTrackers() => _trackerDao.getAllTrackers();

  Future<Tracker?> getTrackerById(String id) => _trackerDao.getTrackerById(id);

  Future<int> createTracker(Tracker tracker) => _trackerDao.insertTracker(tracker);

  Future<bool> updateTracker(Tracker tracker) => _trackerDao.updateTracker(tracker);

  Future<int> deleteTracker(String id) => _trackerDao.deleteTracker(id);
}
