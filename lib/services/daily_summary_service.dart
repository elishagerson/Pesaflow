import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/data/database/database_providers.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/services/notification_service.dart';

final dailySummaryServiceProvider = Provider<DailySummaryService>((ref) {
  return DailySummaryService(
    transactionDao: ref.watch(transactionDaoProvider),
    notificationService: ref.watch(notificationServiceProvider),
    trackerId: ref.watch(activeTrackerIdProvider),
  );
});

class DailySummaryService {
  final TransactionDao _transactionDao;
  final NotificationService _notificationService;
  final String _trackerId;
  static const int _notificationId = 4000;

  DailySummaryService({
    required TransactionDao transactionDao,
    required NotificationService notificationService,
    required String trackerId,
  })  : _transactionDao = transactionDao,
        _notificationService = notificationService,
        _trackerId = trackerId;

  Future<void> checkDailySummary() async {
    try {
      final now = DateTime.now();
      final startOfYesterday = DateTime(now.year, now.month, now.day - 1);
      final startOfToday = DateTime(now.year, now.month, now.day);

      final transactions = await _transactionDao.getFilteredTransactions(
        type: 'expense',
        startDate: startOfYesterday,
        endDate: startOfToday.subtract(const Duration(milliseconds: 1)),
        trackerId: _trackerId,
      );

      if (transactions.isEmpty) return;

      final totalSpending = transactions.fold<int>(
        0,
        (sum, t) => sum + t.transaction.amount,
      );

      if (totalSpending <= 0) return;

      final totalStr = (totalSpending / 100).toStringAsFixed(0);

      // Find the top spending category
      final categoryTotals = <String, int>{};
      for (final t in transactions) {
        final catName = t.category.name;
        categoryTotals[catName] =
            (categoryTotals[catName] ?? 0) + t.transaction.amount;
      }

      String body = 'You spent Tsh $totalStr on expenses yesterday';
      if (categoryTotals.isNotEmpty) {
        final topEntry = categoryTotals.entries.fold<MapEntry<String, int>?>(
          null,
          (prev, e) => prev == null || e.value > prev.value ? e : prev,
        );
        if (topEntry != null) {
          body += '. Top category: ${topEntry.key}';
        }
      }

      await _notificationService.showNotification(
        id: _notificationId,
        title: "Yesterday's spending summary",
        body: body,
      );
      developer.log(
        'Daily spending summary sent: Tsh $totalStr',
        name: 'DailySummary',
      );
    } catch (e) {
      developer.log('Daily summary check failed: $e', name: 'DailySummary');
    }
  }
}
