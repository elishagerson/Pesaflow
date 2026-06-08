import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/data/database/daos/budget_dao.dart';
import 'package:pesaflow/data/database/database_providers.dart';
import 'package:pesaflow/domain/budget/budget_engine.dart';
import 'package:pesaflow/services/notification_service.dart';

final budgetAlertServiceProvider = Provider<BudgetAlertService>((ref) {
  return BudgetAlertService(
    budgetDao: ref.watch(budgetDaoProvider),
    notificationService: ref.watch(notificationServiceProvider),
  );
});

class BudgetAlertService {
  final BudgetDao _budgetDao;
  final NotificationService _notificationService;
  int _notificationCounter = 1000;

  BudgetAlertService({
    required BudgetDao budgetDao,
    required NotificationService notificationService,
  })  : _budgetDao = budgetDao,
        _notificationService = notificationService;

  Future<void> checkBudgetsAfterTransaction(String categoryId) async {
    try {
      final budgets = await _budgetDao.getAllActiveBudgets();
      for (final budget in budgets) {
        if (budget.categoryId != categoryId) continue;
        await _checkSingleBudget(budget);
      }
    } catch (e) {
      developer.log('Budget alert check failed: $e', name: 'BudgetAlertService');
    }
  }

  Future<void> checkAllBudgets() async {
    try {
      final budgets = await _budgetDao.getAllActiveBudgets();
      for (final budget in budgets) {
        await _checkSingleBudget(budget);
      }
    } catch (e) {
      developer.log('Budget alert check all failed: $e', name: 'BudgetAlertService');
    }
  }

  Future<void> _checkSingleBudget(Budget budget) async {
    final period = await _budgetDao.getCurrentPeriod(budget.id);
    if (period == null) return;

    final spent = await _budgetDao.getSpentForCategoryInPeriod(
      budget.categoryId,
      period.periodStart,
      period.periodEnd,
    );

    final percentage = period.allocated > 0 ? spent / period.allocated : 0.0;

    final alerts = BudgetEngine.checkThresholds(
      percentage: percentage,
      notificationThreshold: budget.notificationThreshold,
    );

    for (final alert in alerts) {
      await _sendAlert(budget, alert, percentage, spent, period.allocated);
    }
  }

  Future<void> _sendAlert(
    Budget budget,
    BudgetAlert alert,
    double percentage,
    int spent,
    int allocated,
  ) async {
    final (title, body) = switch (alert) {
      BudgetAlert.halfway => (
        '${budget.name}: Halfway there',
        'You\'ve used ${(percentage * 100).round()}% of your ${budget.name} budget.',
      ),
      BudgetAlert.warning => (
        '${budget.name}: Approaching limit',
        'You\'ve used ${(percentage * 100).round()}% of your ${budget.name} budget.',
      ),
      BudgetAlert.reached => (
        '${budget.name}: Budget reached',
        'You\'ve used 100% of your ${budget.name} budget.',
      ),
      BudgetAlert.exceeded => (
        '${budget.name}: Over budget!',
        'You\'ve exceeded your ${budget.name} budget by ${(spent - allocated) ~/ 100} Tsh.',
      ),
    };

    _notificationCounter++;
    await _notificationService.showNotification(
      id: _notificationCounter,
      title: title,
      body: body,
    );
  }
}
