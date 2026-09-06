import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/budget_groups_table.dart';
import '../tables/budgets_table.dart';
import '../tables/budget_periods_table.dart';
import '../tables/transactions_table.dart';
import '../tables/categories_table.dart';

part 'budget_group_dao.g.dart';

/// Data class combining a budget group with its child budgets and progress.
class BudgetGroupWithChildren {
  final BudgetGroup group;
  final List<BudgetWithChildProgress> subBudgets;

  BudgetGroupWithChildren({
    required this.group,
    required this.subBudgets,
  });

  int get totalAllocated => subBudgets.fold(
        0,
        (s, b) =>
            s + (b.currentPeriod?.allocated ?? b.budget.amount),
      );

  int get totalSpent => subBudgets.fold(0, (s, b) => s + b.spentInPeriod);

  double get percentage =>
      totalAllocated > 0
          ? (totalSpent / totalAllocated).clamp(0.0, 2.0)
          : 0.0;

  int get remaining => totalAllocated - totalSpent;
}

/// Progress data for a single sub-budget within a group.
class BudgetWithChildProgress {
  final Budget budget;
  final Category category;
  final BudgetPeriod? currentPeriod;
  final int spentInPeriod;

  BudgetWithChildProgress({
    required this.budget,
    required this.category,
    this.currentPeriod,
    this.spentInPeriod = 0,
  });

  double get percentage {
    if (currentPeriod == null) return 0.0;
    final total = currentPeriod!.allocated;
    if (total <= 0) return 0.0;
    return (spentInPeriod / total).clamp(0.0, 2.0);
  }

  int get remaining {
    if (currentPeriod == null) return 0;
    return currentPeriod!.allocated - spentInPeriod;
  }
}

@DriftAccessor(
  tables: [BudgetGroups, Budgets, BudgetPeriods, Transactions, Categories],
)
class BudgetGroupDao extends DatabaseAccessor<AppDatabase>
    with _$BudgetGroupDaoMixin {
  BudgetGroupDao(super.db);

  /// Gets all active budget groups.
  Future<List<BudgetGroup>> getAllActiveGroups() {
    return (select(budgetGroups)
          ..where((g) => g.isActive.equals(true))
          ..orderBy([(g) => OrderingTerm.asc(g.sortOrder)]))
        .get();
  }

  /// Streams all active budget groups.
  Stream<List<BudgetGroup>> watchAllActiveGroups() {
    return (select(budgetGroups)
          ..where((g) => g.isActive.equals(true))
          ..orderBy([(g) => OrderingTerm.asc(g.sortOrder)]))
        .watch();
  }

  /// Gets a single budget group by ID.
  Future<BudgetGroup?> getGroupById(String groupId) {
    return (select(budgetGroups)..where((g) => g.id.equals(groupId)))
        .getSingleOrNull();
  }

  /// Gets all budgets belonging to a group.
  Future<List<Budget>> getBudgetsForGroup(String groupId) {
    return (select(budgets)
          ..where(
            (b) => b.groupId.equals(groupId) & b.isActive.equals(true),
          ))
        .get();
  }

  /// Gets all active budgets that have no group (standalone/legacy).
  Future<List<Budget>> getStandaloneBudgets() {
    return (select(budgets)
          ..where(
            (b) => b.groupId.isNull() & b.isActive.equals(true),
          ))
        .get();
  }

  /// Inserts a new budget group.
  Future<void> insertGroup(BudgetGroup group) async {
    await into(budgetGroups).insert(group);
  }

  /// Updates an existing budget group.
  Future<void> updateGroup(BudgetGroup group) async {
    await update(budgetGroups).replace(group);
  }

  /// Deletes a budget group and unlinks its child budgets.
  Future<void> deleteGroup(String groupId) async {
    await attachedDatabase.transaction(() async {
      // Unlink child budgets (set groupId to null)
      await (update(budgets)..where((b) => b.groupId.equals(groupId))).write(
        const BudgetsCompanion(groupId: Value(null)),
      );
      await (delete(budgetGroups)..where((g) => g.id.equals(groupId))).go();
    });
  }

  /// Gets all budget groups with their child budgets and progress data.
  Future<List<BudgetGroupWithChildren>>
      getGroupsWithChildren() async {
    final activeGroups = await getAllActiveGroups();
    if (activeGroups.isEmpty) return [];

    // Fetch all active budgets with a groupId in one query
    final groupIds = activeGroups.map((g) => g.id).toList();
    final groupedBudgets = await (select(budgets)
          ..where(
            (b) =>
                b.groupId.isIn(groupIds) & b.isActive.equals(true),
          ))
        .get();

    // Fetch all relevant categories
    final categoryIds = groupedBudgets.map((b) => b.categoryId).toSet().toList();
    final categoriesMap = <String, Category>{};
    if (categoryIds.isNotEmpty) {
      final cats = await (select(categories)
            ..where((c) => c.id.isIn(categoryIds)))
          .get();
      for (final cat in cats) {
        categoriesMap[cat.id] = cat;
      }
    }

    // Fetch current periods for all budgets
    final budgetIds = groupedBudgets.map((b) => b.id).toList();
    final periodsMap = <String, BudgetPeriod>{};
    if (budgetIds.isNotEmpty) {
      final periods = await (select(budgetPeriods)
            ..where(
              (p) =>
                  p.budgetId.isIn(budgetIds) & p.isClosed.equals(false),
            )
            ..orderBy([(p) => OrderingTerm.desc(p.periodStart)]))
          .get();

      final processedIds = <String>{};
      for (final period in periods) {
        if (!processedIds.contains(period.budgetId)) {
          periodsMap[period.budgetId] = period;
          processedIds.add(period.budgetId);
        }
      }
    }

    // Calculate spent for each budget
    final spentResults = <String, int>{};
    final spentFutures = <Future<void>>[];
    for (final budget in groupedBudgets) {
      final currentPeriod = periodsMap[budget.id];
      if (currentPeriod != null) {
        spentFutures.add(() async {
          final spent = await _getSpentForCategory(
            budget.categoryId,
            currentPeriod.periodStart,
            currentPeriod.periodEnd,
          );
          spentResults[budget.id] = spent;
        }());
      }
    }
    await Future.wait(spentFutures);

    // Assemble results
    final result = <BudgetGroupWithChildren>[];
    for (final group in activeGroups) {
      final children = <BudgetWithChildProgress>[];
      for (final budget in groupedBudgets) {
        if (budget.groupId != group.id) continue;
        final category = categoriesMap[budget.categoryId];
        if (category == null) continue;
        children.add(
          BudgetWithChildProgress(
            budget: budget,
            category: category,
            currentPeriod: periodsMap[budget.id],
            spentInPeriod: spentResults[budget.id] ?? 0,
          ),
        );
      }
      result.add(
        BudgetGroupWithChildren(group: group, subBudgets: children),
      );
    }

    return result;
  }

  /// Calculates total spent for a category within a date range.
  Future<int> _getSpentForCategory(
    String categoryId,
    DateTime start,
    DateTime end,
  ) async {
    // Include child categories
    final childIds = await _getChildCategoryIds(categoryId);
    final allCategoryIds = [categoryId, ...childIds];

    final effectiveDate = coalesce<DateTime>([
      transactions.smsTimestamp,
      transactions.createdAt,
    ]);

    final query = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(
        transactions.categoryId.isIn(allCategoryIds) &
            effectiveDate.isBiggerOrEqual(Constant(start)) &
            effectiveDate.isSmallerThan(
              Constant(end.add(const Duration(days: 1))),
            ) &
            (transactions.type.equals('expense') |
                transactions.type.equals('airtime') |
                transactions.type.equals('fee')),
      );

    final result = await query.getSingle();
    return result.read(transactions.amount.sum()) ?? 0;
  }

  Future<List<String>> _getChildCategoryIds(String categoryId) async {
    final children = await (select(categories)
          ..where((c) => c.parentId.equals(categoryId)))
        .get();
    return children.map((c) => c.id).toList();
  }
}
