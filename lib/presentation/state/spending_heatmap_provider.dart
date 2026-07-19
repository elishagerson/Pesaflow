import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/analytics_repository.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:drift/drift.dart';
import 'package:pesaflow/data/database/database_providers.dart';

class HeatmapData {
  final int totalExpenditure;
  final int maxExpense;
  final Map<String, int> dailyExpenses;
  final DateTime startDate;
  final DateTime endDate;

  HeatmapData({
    required this.totalExpenditure,
    required this.maxExpense,
    required this.dailyExpenses,
    required this.startDate,
    required this.endDate,
  });
}

// Watch table updates for transactions so we automatically rebuild the heatmap on changes
final _heatmapRefreshProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .tableUpdates(TableUpdateQuery.onTable(db.transactions))
      .map((_) => DateTime.now().microsecondsSinceEpoch);
});

final spendingHeatmapProvider = FutureProvider<HeatmapData>((ref) async {
  ref.watch(_heatmapRefreshProvider);
  final analyticsRepo = ref.watch(analyticsRepositoryProvider);

  // We show 20 weeks (140 days) ending today
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  // Subtract 20 weeks - 1 day to align columns nicely
  final startDate = today.subtract(const Duration(days: 139));
  final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

  final snapshots = await analyticsRepo.getDailySnapshots(startDate, endDate);

  int totalExpenditure = 0;
  int maxExpense = 0;
  final Map<String, int> dailyExpenses = {};

  for (final s in snapshots) {
    final expense = s.totalExpense;
    dailyExpenses[s.date] = expense;
    totalExpenditure += expense;
    if (expense > maxExpense) {
      maxExpense = expense;
    }
  }

  return HeatmapData(
    totalExpenditure: totalExpenditure,
    maxExpense: maxExpense,
    dailyExpenses: dailyExpenses,
    startDate: startDate,
    endDate: today,
  );
});
