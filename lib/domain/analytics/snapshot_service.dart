import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/analytics_repository.dart';

final snapshotServiceProvider = Provider<SnapshotService>((ref) {
  final repo = ref.watch(analyticsRepositoryProvider);
  return SnapshotService(repo);
});

/// Service that orchestrates snapshot computation after transaction changes.
class SnapshotService {
  final AnalyticsRepository _analyticsRepository;

  SnapshotService(this._analyticsRepository);

  /// Called after a transaction is inserted, updated, or deleted.
  /// Recomputes the daily and monthly snapshots for the affected date.
  Future<void> onTransactionChanged(DateTime transactionDate) async {
    await _analyticsRepository.refreshAllSnapshots(transactionDate);
  }

  /// Rebuilds snapshots for a range of dates (e.g. after bulk SMS import).
  Future<void> rebuildSnapshotsForRange(DateTime start, DateTime end) async {
    var current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    // Track which months we've already refreshed
    final refreshedMonths = <String>{};

    while (!current.isAfter(endDate)) {
      await _analyticsRepository.refreshSnapshotsForDate(current);

      final monthKey = '${current.year}-${current.month}';
      if (!refreshedMonths.contains(monthKey)) {
        await _analyticsRepository.refreshSnapshotsForMonth(current);
        refreshedMonths.add(monthKey);
      }

      current = current.add(const Duration(days: 1));
    }
  }
}
