import 'dart:developer' as developer;
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../database/daos/budget_dao.dart';
import '../database/daos/category_dao.dart';
import '../database/daos/savings_goals_dao.dart';
import '../database/database_providers.dart';
import '../../services/notification_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../domain/budget/budget_engine.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final budgetDao = ref.watch(budgetDaoProvider);
  final categoryDao = ref.watch(categoryDaoProvider);
  final savingsGoalsDao = ref.watch(savingsGoalsDaoProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  return BudgetRepository(
    budgetDao,
    categoryDao: categoryDao,
    savingsGoalsDao: savingsGoalsDao,
    notificationService: notificationService,
  );
});

class BudgetRepository {
  final BudgetDao _budgetDao;
  final CategoryDao? _categoryDao;
  final SavingsGoalsDao? _savingsGoalsDao;
  final NotificationService? _notificationService;
  static const _uuid = Uuid();

  BudgetRepository(
    this._budgetDao, {
    CategoryDao? categoryDao,
    SavingsGoalsDao? savingsGoalsDao,
    NotificationService? notificationService,
  })  : _categoryDao = categoryDao,
        _savingsGoalsDao = savingsGoalsDao,
        _notificationService = notificationService;

  Stream<List<Budget>> watchAllActiveBudgets() =>
      _budgetDao.watchAllActiveBudgets();

  Future<List<Budget>> getAllActiveBudgets() =>
      _budgetDao.getAllActiveBudgets();

  Future<Budget?> getBudgetById(String id) => _budgetDao.getBudgetById(id);

  Future<BudgetPeriod?> getCurrentPeriod(String budgetId) =>
      _budgetDao.getCurrentPeriod(budgetId);

  Future<List<BudgetPeriod>> getPeriodsForBudget(String budgetId) =>
      _budgetDao.getPeriodsForBudget(budgetId);

  Stream<List<BudgetPeriod>> watchPeriodsForBudget(String budgetId) =>
      _budgetDao.watchPeriodsForBudget(budgetId);

  Future<int> getSpentForCategoryInPeriod(
    String categoryId,
    DateTime start,
    DateTime end,
  ) => _budgetDao.getSpentForCategoryInPeriod(categoryId, start, end);

  /// Creates a new budget with its first period auto-generated.
  Future<void> createBudget({
    required String name,
    required String categoryId,
    required String period,
    required int amount,
    required bool rollover,
    required String rolloverType,
    int? rolloverCap,
    required DateTime startDate,
    double notificationThreshold = 0.8,
    String? groupId,
  }) async {
    final budgetId = _uuid.v4();
    final normalizedStart = period == 'monthly'
        ? DateTime(startDate.year, startDate.month, 1)
        : DateTime(
            startDate.year,
            startDate.month,
            startDate.day,
          );
    final periodEnd = BudgetEngine.computePeriodEnd(normalizedStart, period);

    final budget = Budget(
      id: budgetId,
      name: name,
      categoryId: categoryId,
      period: period,
      amount: amount,
      groupId: groupId,
      rollover: rollover,
      rolloverType: rolloverType,
      rolloverCap: rolloverCap,
      startDate: normalizedStart,
      notificationThreshold: notificationThreshold,
      isActive: true,
      createdAt: DateTime.now(),
    );

    final firstPeriod = BudgetPeriod(
      id: _uuid.v4(),
      budgetId: budgetId,
      periodStart: normalizedStart,
      periodEnd: periodEnd,
      allocated: amount,
      spent: 0,
      isClosed: false,
      createdAt: DateTime.now(),
    );

    await _budgetDao.insertBudgetWithPeriod(budget, firstPeriod);
  }

  /// Updates an existing budget.
  Future<void> updateBudget(Budget budget) => _budgetDao.updateBudget(budget);

  Future<void> updateBudgetWithPeriodAllocation(Budget budget) async {
    await _budgetDao.updateBudgetWithPeriodAtomically(budget);
  }

  /// Deletes a budget and all periods.
  Future<void> deleteBudget(String budgetId) =>
      _budgetDao.deleteBudget(budgetId);

  /// Gets all active budgets enriched with progress data using optimized queries.
  /// This avoids the N+1 query problem by batching database operations.
  Future<List<BudgetWithProgress>> getActiveBudgetsWithProgress() async {
    return await _budgetDao.getActiveBudgetsWithProgressOptimized();
  }

  Future<List<MapEntry<DateTime, int>>> getDailySpendForBudget(
    String budgetId,
    DateTime periodStart,
    DateTime periodEnd,
  ) => _budgetDao.getDailySpendForBudget(budgetId, periodStart, periodEnd);

  Future<int> getSpentForBudgetInRange(
    String budgetId,
    DateTime start,
    DateTime end,
  ) => _budgetDao.getSpentForBudgetInRange(budgetId, start, end);

  /// Checks and closes any expired budget periods, creating new ones with rollover.
  ///
  /// Loops until the current period is no longer expired so that long gaps
  /// between app launches (e.g. a month without opening the app) catch up one
  /// period at a time instead of skipping straight to a single new period.
  Future<void> checkAndCloseExpiredPeriods() async {
    final activeBudgets = await _budgetDao.getAllActiveBudgets();
    final now = DateTime.now();

    for (final budget in activeBudgets) {
      var currentPeriod = await _budgetDao.getCurrentPeriod(budget.id);

      // Monthly budgets always track starting from the 1st day of the month
      if (budget.period == 'monthly') {
        if (budget.startDate.day != 1) {
          final alignedBudgetStart = DateTime(
            budget.startDate.year,
            budget.startDate.month,
            1,
          );
          await _budgetDao.updateBudget(
            budget.copyWith(startDate: alignedBudgetStart),
          );
        }

        if (currentPeriod != null && currentPeriod.periodStart.day != 1) {
          final alignedStart = DateTime(
            currentPeriod.periodStart.year,
            currentPeriod.periodStart.month,
            1,
          );
          final alignedEnd =
              BudgetEngine.computePeriodEnd(alignedStart, 'monthly');
          final alignedPeriod = currentPeriod.copyWith(
            periodStart: alignedStart,
            periodEnd: alignedEnd,
          );
          await _budgetDao.updatePeriod(alignedPeriod);
          currentPeriod = alignedPeriod;
        }
      }

      while (currentPeriod != null &&
          now.isAfter(
            // periodEnd is the inclusive last day stored at midnight (00:00:00).
            // Only close after the last day is fully elapsed — i.e. when we are
            // past midnight of the *next* day.
            DateTime(
              currentPeriod.periodEnd.year,
              currentPeriod.periodEnd.month,
              currentPeriod.periodEnd.day + 1,
            ),
          )) {
        // Period has expired — close it and create next
        final spent = await _budgetDao.getSpentForCategoryInPeriod(
          budget.categoryId,
          currentPeriod.periodStart,
          currentPeriod.periodEnd,
        );

        final isEmergency = await _isEmergencyBudget(budget);
        final remaining = currentPeriod.allocated - spent;

        int rolloverAmount = 0;
        if (isEmergency && remaining > 0) {
          // Emergency budget had unused or remaining amount — move to savings and notify user
          await _handleEmergencyBudgetSavings(
            budget: budget,
            closedPeriod: currentPeriod,
            remaining: remaining,
          );
          // Funds are moved to savings, so do not roll over to next budget period
          rolloverAmount = 0;
        } else if (budget.rollover) {
          rolloverAmount = BudgetEngine.computeRollover(
            allocated: currentPeriod.allocated,
            spent: spent,
            rolloverType: budget.rolloverType,
            rolloverCap: budget.rolloverCap,
          );
        }

        // Next period starts the day after the current one ends so the
        // boundary day is never counted twice.
        final nextStart = currentPeriod.periodEnd.add(const Duration(days: 1));
        final nextEnd = BudgetEngine.computePeriodEnd(nextStart, budget.period);

        final closedPeriod = currentPeriod.copyWith(
          spent: spent,
          isClosed: true,
          rolledTo: Value(rolloverAmount),
        );

        final nextPeriod = BudgetPeriod(
          id: _uuid.v4(),
          budgetId: budget.id,
          periodStart: nextStart,
          periodEnd: nextEnd,
          allocated: budget.amount + rolloverAmount,
          spent: 0,
          rolledFrom: rolloverAmount,
          isClosed: false,
          createdAt: DateTime.now(),
        );

        await _budgetDao.closePeriodAndCreateNext(closedPeriod, nextPeriod);
        currentPeriod = await _budgetDao.getCurrentPeriod(budget.id);
      }
    }
  }

  /// Checks if a budget belongs to the Emergencies category or has an emergency name.
  Future<bool> _isEmergencyBudget(Budget budget) async {
    if (budget.name.toLowerCase().contains('emergenc')) {
      return true;
    }
    if (_categoryDao != null) {
      try {
        final category = await _categoryDao!.getCategoryById(budget.categoryId);
        if (category != null &&
            category.name.toLowerCase().contains('emergenc')) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// Automatically moves remaining emergency budget funds into a savings goal
  /// and delivers a local notification prompting the user to deposit into savings.
  Future<void> _handleEmergencyBudgetSavings({
    required Budget budget,
    required BudgetPeriod closedPeriod,
    required int remaining,
  }) async {
    if (_savingsGoalsDao == null || remaining <= 0) return;

    try {
      final allGoals = await _savingsGoalsDao!.getAllGoals();

      // Look for an Emergency Fund goal first, or any active goal
      SavingsGoal? targetGoal = allGoals
          .where(
            (g) =>
                g.name.toLowerCase().contains('emergenc') && !g.isCompleted,
          )
          .firstOrNull;

      targetGoal ??= allGoals
          .where((g) => g.name.toLowerCase().contains('emergenc'))
          .firstOrNull;

      targetGoal ??= allGoals.where((g) => !g.isCompleted).firstOrNull;

      targetGoal ??= allGoals.firstOrNull;

      if (targetGoal == null) {
        // Auto-create dedicated Emergency Fund savings goal
        final now = DateTime.now();
        final newGoalId = _uuid.v4();
        final target =
            remaining * 6 > 100000000 ? remaining * 6 : 100000000;
        final newGoal = SavingsGoal(
          id: newGoalId,
          name: 'Emergency Fund',
          targetAmount: target,
          currentAmount: 0,
          targetDate: DateTime(now.year + 1, now.month, now.day),
          color: '#E11D48',
          icon: 'alert-circle',
          trackerId: budget.trackerId,
          isCompleted: false,
          createdAt: now,
        );
        await _savingsGoalsDao!.insertSavingsGoal(newGoal);
        targetGoal = newGoal;
      }

      // Record contribution to the savings goal
      final contribution = SavingsGoalContribution(
        id: _uuid.v4(),
        savingsGoalId: targetGoal.id,
        amount: remaining,
        notes:
            'Unused budget from ${budget.name} (${closedPeriod.periodStart.month}/${closedPeriod.periodStart.year})',
        createdAt: DateTime.now(),
      );
      await _savingsGoalsDao!.addContribution(contribution);

      // Send local notification to user
      if (_notificationService != null) {
        try {
          final formattedAmount = CurrencyFormatter.formatCents(remaining);
          final notifId =
              (budget.id.hashCode ^ closedPeriod.id.hashCode) & 0x7FFFFFFF;
          await _notificationService!.showNotification(
            id: notifId,
            title: 'Move to Savings: ${budget.name}',
            body:
                'You had $formattedAmount unspent in your Emergencies budget. It has been allocated to "${targetGoal.name}". Remember to move that money into your savings account!',
          );
        } catch (e) {
          developer.log(
            'Failed to send emergency savings notification: $e',
            name: 'BudgetRepository',
          );
        }
      }
    } catch (e) {
      developer.log(
        'Failed to process emergency budget savings: $e',
        name: 'BudgetRepository',
      );
    }
  }

  /// Allows manually moving unspent emergency budget remainder into savings
  /// during the active period. Adjusts current period allocated to match spent
  /// so funds are not swept again on period close.
  Future<bool> moveEmergencyBudgetRemainderToSavings(String budgetId) async {
    final budget = await _budgetDao.getBudgetById(budgetId);
    if (budget == null) return false;

    final currentPeriod = await _budgetDao.getCurrentPeriod(budgetId);
    if (currentPeriod == null || currentPeriod.isClosed) return false;

    final spent = await _budgetDao.getSpentForCategoryInPeriod(
      budget.categoryId,
      currentPeriod.periodStart,
      currentPeriod.periodEnd,
    );

    final remaining = currentPeriod.allocated - spent;
    if (remaining <= 0) return false;

    await _handleEmergencyBudgetSavings(
      budget: budget,
      closedPeriod: currentPeriod,
      remaining: remaining,
    );

    // Adjust period allocation so remaining is 0 and won't re-trigger at period close
    final updatedPeriod = currentPeriod.copyWith(
      allocated: spent,
    );
    await _budgetDao.updatePeriod(updatedPeriod);
    return true;
  }
}
