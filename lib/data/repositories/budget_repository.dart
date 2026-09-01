import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../database/daos/budget_dao.dart';
import '../database/database_providers.dart';
import '../../domain/budget/budget_engine.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final budgetDao = ref.watch(budgetDaoProvider);
  return BudgetRepository(budgetDao);
});

class BudgetRepository {
  final BudgetDao _budgetDao;
  static const _uuid = Uuid();

  BudgetRepository(this._budgetDao);

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
  }) async {
    final budgetId = _uuid.v4();
    final normalizedStart = DateTime(
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

  /// Updates the budget's amount and also updates the current period's allocated.
  Future<void> updateBudgetWithPeriodAllocation(Budget budget) async {
    await _budgetDao.updateBudget(budget);
    await _budgetDao.updateCurrentPeriodAllocated(budget.id, budget.amount);
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

        int rolloverAmount = 0;
        if (budget.rollover) {
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
}
