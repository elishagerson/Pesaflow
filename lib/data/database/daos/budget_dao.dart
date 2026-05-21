import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/budgets_table.dart';
import '../tables/budget_periods_table.dart';
import '../tables/transactions_table.dart';
import '../tables/categories_table.dart';

part 'budget_dao.g.dart';

/// Data class combining a budget with its current period and category info.
class BudgetWithProgress {
  final Budget budget;
  final Category category;
  final BudgetPeriod? currentPeriod;
  final int spentInPeriod;

  BudgetWithProgress({
    required this.budget,
    required this.category,
    this.currentPeriod,
    this.spentInPeriod = 0,
  });

  double get percentage {
    if (currentPeriod == null) return 0.0;
    final total = currentPeriod!.allocated;
    if (total <= 0) return 0.0;
    return (spentInPeriod / total).clamp(0.0, 2.0); // Allow over 100%
  }

  int get remaining {
    if (currentPeriod == null) return 0;
    return currentPeriod!.allocated - spentInPeriod;
  }
}

@DriftAccessor(tables: [Budgets, BudgetPeriods, Transactions, Categories])
class BudgetDao extends DatabaseAccessor<AppDatabase> with _$BudgetDaoMixin {
  BudgetDao(super.db);

  /// Streams all active budgets.
  Stream<List<Budget>> watchAllActiveBudgets() {
    return (select(budgets)..where((b) => b.isActive.equals(true)))
        .watch();
  }

  /// Gets all active budgets as a future.
  Future<List<Budget>> getAllActiveBudgets() {
    return (select(budgets)..where((b) => b.isActive.equals(true))).get();
  }

  /// Gets a single budget by ID.
  Future<Budget?> getBudgetById(String budgetId) {
    return (select(budgets)..where((b) => b.id.equals(budgetId)))
        .getSingleOrNull();
  }

  /// Gets the category for a budget.
  Future<Category?> getCategoryForBudget(String categoryId) {
    return (select(categories)..where((c) => c.id.equals(categoryId)))
        .getSingleOrNull();
  }

  /// Gets the current (non-closed) period for a budget.
  Future<BudgetPeriod?> getCurrentPeriod(String budgetId) {
    return (select(budgetPeriods)
          ..where((p) => p.budgetId.equals(budgetId) & p.isClosed.equals(false))
          ..orderBy([(p) => OrderingTerm.desc(p.periodStart)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Gets all periods for a budget, ordered by most recent first.
  Future<List<BudgetPeriod>> getPeriodsForBudget(String budgetId) {
    return (select(budgetPeriods)
          ..where((p) => p.budgetId.equals(budgetId))
          ..orderBy([(p) => OrderingTerm.desc(p.periodStart)]))
        .get();
  }

  /// Streams all periods for a budget.
  Stream<List<BudgetPeriod>> watchPeriodsForBudget(String budgetId) {
    return (select(budgetPeriods)
          ..where((p) => p.budgetId.equals(budgetId))
          ..orderBy([(p) => OrderingTerm.desc(p.periodStart)]))
        .watch();
  }

  /// Calculates total spent for a category within a date range from transactions.
  Future<int> getSpentForCategoryInPeriod(
    String categoryId,
    DateTime start,
    DateTime end,
  ) async {
    final query = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(transactions.categoryId.equals(categoryId) &
          transactions.createdAt.isBiggerOrEqual(Constant(start)) &
          transactions.createdAt.isSmallerOrEqual(Constant(end)) &
          (transactions.type.equals('expense') |
           transactions.type.equals('airtime') |
           transactions.type.equals('fee')));

    final result = await query.getSingle();
    return result.read(transactions.amount.sum()) ?? 0;
  }

  /// Inserts a new budget and auto-creates the first period.
  Future<void> insertBudgetWithPeriod(Budget budget, BudgetPeriod firstPeriod) async {
    await attachedDatabase.transaction(() async {
      await into(budgets).insert(budget);
      await into(budgetPeriods).insert(firstPeriod);
    });
  }

  /// Updates a budget.
  Future<void> updateBudget(Budget budget) async {
    await update(budgets).replace(budget);
  }

  /// Deletes a budget and all its periods.
  Future<void> deleteBudget(String budgetId) async {
    await attachedDatabase.transaction(() async {
      await (delete(budgetPeriods)..where((p) => p.budgetId.equals(budgetId))).go();
      await (delete(budgets)..where((b) => b.id.equals(budgetId))).go();
    });
  }

  /// Closes a period and creates the next one with rollover.
  Future<void> closePeriodAndCreateNext(
    BudgetPeriod closedPeriod,
    BudgetPeriod nextPeriod,
  ) async {
    await attachedDatabase.transaction(() async {
      await update(budgetPeriods).replace(closedPeriod);
      await into(budgetPeriods).insert(nextPeriod);
    });
  }

  /// Updates a period's spent amount.
  Future<void> updatePeriodSpent(String periodId, int newSpent) async {
    final period = await (select(budgetPeriods)..where((p) => p.id.equals(periodId))).getSingleOrNull();
    if (period != null) {
      await update(budgetPeriods).replace(period.copyWith(spent: newSpent));
    }
  }
}
