import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/data/database/daos/savings_goals_dao.dart';
import 'package:pesaflow/data/database/database_providers.dart';
import 'package:pesaflow/services/notification_service.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

final savingsReminderServiceProvider = Provider<SavingsReminderService>((ref) {
  return SavingsReminderService(
    dao: ref.watch(savingsGoalsDaoProvider),
    notificationService: ref.watch(notificationServiceProvider),
    trackerIdProvider: ref.watch(activeTrackerIdProvider),
  );
});

class SavingsReminderService {
  final SavingsGoalsDao _dao;
  final NotificationService _notificationService;
  final String _trackerId;
  int _notificationCounter = 2000;

  static const int _reminderIntervalDays = 7;

  SavingsReminderService({
    required this._dao,
    required this._notificationService,
    required String trackerIdProvider,
  })  : _trackerId = trackerIdProvider;

  Future<DateTime?> getLastContributionDate() async {
    try {
      final goals = await _dao.getAllSavingsGoals(_trackerId);
      DateTime? lastDate;

      for (final goal in goals) {
        final contributions = await _dao.getContributionsForGoal(goal.id);
        for (final c in contributions) {
          if (c.amount > 0) {
            if (lastDate == null || c.createdAt.isAfter(lastDate)) {
              lastDate = c.createdAt;
            }
          }
        }
      }

      return lastDate;
    } catch (e) {
      developer.log('Failed to get last contribution date: $e', name: 'SavingsReminder');
      return null;
    }
  }

  Future<bool> hasSavedRecently({int withinDays = _reminderIntervalDays}) async {
    final lastDate = await getLastContributionDate();
    if (lastDate == null) return false;
    return DateTime.now().difference(lastDate).inDays < withinDays;
  }

  Future<List<String>> getGoalsNeedingAttention() async {
    final needingAttention = <String>[];
    try {
      final goals = await _dao.getAllSavingsGoals(_trackerId);
      for (final goal in goals) {
        if (goal.isCompleted) continue;
        final contributions = await _dao.getContributionsForGoal(goal.id);
        final lastDeposit = contributions
            .where((c) => c.amount > 0)
            .fold<DateTime?>(null, (prev, c) {
          if (prev == null || c.createdAt.isAfter(prev)) return c.createdAt;
          return prev;
        });

        if (lastDeposit == null ||
            DateTime.now().difference(lastDeposit).inDays >= _reminderIntervalDays) {
          needingAttention.add(goal.name);
        }
      }
    } catch (e) {
      developer.log('Failed to check goals needing attention: $e', name: 'SavingsReminder');
    }
    return needingAttention;
  }

  Future<void> checkAndSendReminder() async {
    try {
      final goalsNeedingAttention = await getGoalsNeedingAttention();
      if (goalsNeedingAttention.isEmpty) return;

      final totalSaved = await _getTotalSaved();
      final lastDate = await getLastContributionDate();
      final daysSinceLastSave = lastDate != null
          ? DateTime.now().difference(lastDate).inDays
          : 0;

      String title;
      String body;

      if (goalsNeedingAttention.length == 1) {
        title = 'Time to save for ${goalsNeedingAttention.first}';
        body = daysSinceLastSave > 0
            ? 'It\'s been $daysSinceLastSave days since your last deposit.'
            : 'You haven\'t made your first deposit yet!';
      } else {
        title = '${goalsNeedingAttention.length} savings goals need attention';
        body = daysSinceLastSave > 0
            ? 'It\'s been $daysSinceLastSave days since your last savings deposit.'
            : 'Set aside some money for your goals today.';
      }

      if (totalSaved > 0) {
        body += ' Total saved: ${totalSaved ~/ 100} Tsh.';
      }

      _notificationCounter++;
      await _notificationService.showNotification(
        id: _notificationCounter,
        title: title,
        body: body,
      );

      developer.log('Savings reminder sent: $title', name: 'SavingsReminder');
    } catch (e) {
      developer.log('Failed to send savings reminder: $e', name: 'SavingsReminder');
    }
  }

  Future<int> _getTotalSaved() async {
    try {
      final goals = await _dao.getAllSavingsGoals(_trackerId);
      return goals.fold<int>(0, (sum, g) => sum + g.currentAmount);
    } catch (e) {
      developer.log('Failed to get total saved: $e', name: 'SavingsReminder');
      return 0;
    }
  }
}
