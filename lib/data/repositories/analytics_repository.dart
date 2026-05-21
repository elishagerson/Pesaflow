import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/daos/analytics_dao.dart';
import '../database/database_providers.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  final analyticsDao = ref.watch(analyticsDaoProvider);
  return AnalyticsRepository(analyticsDao);
});

class AnalyticsRepository {
  final AnalyticsDao _analyticsDao;

  AnalyticsRepository(this._analyticsDao);

  /// Refreshes the daily snapshot for a given date.
  Future<void> refreshSnapshotsForDate(DateTime date) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);
    await _analyticsDao.upsertDailySnapshot(dateStr, dayStart, dayEnd);
  }

  /// Refreshes the monthly snapshot for a given date's month.
  Future<void> refreshSnapshotsForMonth(DateTime date) async {
    final yearMonth = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    final monthStart = DateTime(date.year, date.month, 1);
    final monthEnd = DateTime(date.year, date.month + 1, 0, 23, 59, 59);
    await _analyticsDao.upsertMonthlySnapshot(yearMonth, monthStart, monthEnd);
  }

  /// Refreshes both daily and monthly snapshots for a date.
  Future<void> refreshAllSnapshots(DateTime date) async {
    await refreshSnapshotsForDate(date);
    await refreshSnapshotsForMonth(date);
  }

  /// Gets daily snapshots for a date range.
  Future<List<DailySnapshot>> getDailySnapshots(DateTime start, DateTime end) {
    final startStr = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final endStr = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    return _analyticsDao.getDailySnapshots(startStr, endStr);
  }

  /// Gets the last N monthly snapshots.
  Future<List<MonthlySnapshot>> getMonthlySnapshots(int count) {
    return _analyticsDao.getMonthlySnapshots(count);
  }

  /// Gets top spending categories for current month.
  Future<List<CategorySpending>> getTopCategoriesForMonth(DateTime date, {int limit = 5}) {
    final monthStart = DateTime(date.year, date.month, 1);
    final monthEnd = DateTime(date.year, date.month + 1, 0, 23, 59, 59);
    return _analyticsDao.getTopCategoriesForMonth(monthStart, monthEnd, limit);
  }

  /// Gets total income and expense for a month.
  Future<Map<String, int>> getMonthTotals(DateTime date) {
    final monthStart = DateTime(date.year, date.month, 1);
    final monthEnd = DateTime(date.year, date.month + 1, 0, 23, 59, 59);
    return _analyticsDao.getMonthTotals(monthStart, monthEnd);
  }
}
