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

  Stream<List<Budget>> watchAllActiveBudgets() => _budgetDao.watchAllActiveBudgets();

  Future<List<Budget>> getAllActiveBudgets() => _budgetDao.getAllActiveBudgets();

  Future<Budget?> getBudgetById(String id) => _budgetDao.getBudgetById(id);

  Future<BudgetPeriod?> getCurrentPeriod(String budgetId) => _budgetDao.getCurrentPeriod(budgetId);

  Future<List<BudgetPeriod>> getPeriodsForBudget(String budgetId) => _budgetDao.getPeriodsForBudget(budgetId);

  Stream<List<BudgetPeriod>> watchPeriodsForBudget(String budgetId) => _budgetDao.watchPeriodsForBudget(budgetId);

  Future<int> getSpentForCategoryInPeriod(String categoryId, DateTime start, DateTime end) =>
      _budgetDao.getSpentForCategoryInPeriod(categoryId, start, end);

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
    final periodEnd = _computePeriodEnd(startDate, period);

    final budget = Budget(
      id: budgetId,
      name: name,
      categoryId: categoryId,
      period: period,
      amount: amount,
      rollover: rollover,
      rolloverType: rolloverType,
      rolloverCap: rolloverCap,
      startDate: startDate,
      notificationThreshold: notificationThreshold,
      isActive: true,
      createdAt: DateTime.now(),
    );

    final firstPeriod = BudgetPeriod(
      id: _uuid.v4(),
      budgetId: budgetId,
      periodStart: startDate,
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

  /// Deletes a budget and all periods.
  Future<void> deleteBudget(String budgetId) => _budgetDao.deleteBudget(budgetId);

   /// Gets all active budgets enriched with progress data using optimized queries.
   /// This avoids the N+1 query problem by batching database operations.
   Future<List<BudgetWithProgress>> getActiveBudgetsWithProgress() async {
     return await _budgetDao.getActiveBudgetsWithProgressOptimized();
   }

  Future<List<MapEntry<DateTime, int>>> getDailySpendForBudget(
    String budgetId,
    DateTime periodStart,
    DateTime periodEnd,
  ) =>
      _budgetDao.getDailySpendForBudget(budgetId, periodStart, periodEnd);

  Future<int> getSpentForBudgetInRange(String budgetId, DateTime start, DateTime end) =>
      _budgetDao.getSpentForBudgetInRange(budgetId, start, end);

   /// Checks and closes any expired budget periods, creating new ones with rollover.
   Future<void> checkAndCloseExpiredPeriods() async {
     final activeBudgets = await _budgetDao.getAllActiveBudgets();
     final now = DateTime.now();

     for (final budget in activeBudgets) {
       final currentPeriod = await _budgetDao.getCurrentPeriod(budget.id);
       if (currentPeriod == null) continue;

       if (now.isAfter(currentPeriod.periodEnd)) {
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

         final nextStart = currentPeriod.periodEnd;
         final nextEnd = _computePeriodEnd(nextStart, budget.period);

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
       }
     }
   }

  /// Computes the end date for a budget period.
  DateTime _computePeriodEnd(DateTime start, String period) {
    switch (period) {
      case 'weekly':
        return start.add(const Duration(days: 7));
      case 'biweekly':
        return start.add(const Duration(days: 14));
      case 'monthly':
        return DateTime(start.year, start.month + 1, start.day);
      case 'yearly':
        return DateTime(start.year + 1, start.month, start.day);
      default:
        return DateTime(start.year, start.month + 1, start.day);
    }
  }
}
