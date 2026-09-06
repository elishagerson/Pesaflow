import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../database/daos/budget_group_dao.dart';
import '../database/daos/budget_dao.dart';
import '../database/database_providers.dart';
import '../../domain/models/enums.dart';
import '../../domain/budget/budget_engine.dart';
import 'budget_repository.dart';

final budgetGroupRepositoryProvider = Provider<BudgetGroupRepository>((ref) {
  final groupDao = ref.watch(budgetGroupDaoProvider);
  final budgetDao = ref.watch(budgetDaoProvider);
  final budgetRepo = ref.watch(budgetRepositoryProvider);
  return BudgetGroupRepository(groupDao, budgetDao, budgetRepo);
});

class BudgetGroupRepository {
  final BudgetGroupDao _groupDao;
  final BudgetDao _budgetDao;
  final BudgetRepository _budgetRepo;
  static const _uuid = Uuid();

  BudgetGroupRepository(this._groupDao, this._budgetDao, this._budgetRepo);

  /// Gets all active budget groups.
  Future<List<BudgetGroup>> getAllActiveGroups() =>
      _groupDao.getAllActiveGroups();

  /// Streams all active budget groups.
  Stream<List<BudgetGroup>> watchAllActiveGroups() =>
      _groupDao.watchAllActiveGroups();

  /// Gets a single group by ID.
  Future<BudgetGroup?> getGroupById(String id) => _groupDao.getGroupById(id);

  /// Gets all groups with their child budgets and progress data.
  Future<List<BudgetGroupWithChildren>> getGroupsWithProgress() =>
      _groupDao.getGroupsWithChildren();

  /// Gets standalone (ungrouped) budgets with progress.
  Future<List<BudgetWithProgress>> getStandaloneBudgetsWithProgress() async {
    final allProgress = await _budgetRepo.getActiveBudgetsWithProgress();
    return allProgress.where((bp) => bp.budget.groupId == null).toList();
  }

  /// Creates a single budget group.
  Future<String> createGroup({
    required String name,
    required BudgetGroupType groupType,
    required double percentage,
    required int allocatedAmount,
    String icon = 'wallet',
    String color = '#6B7280',
    int sortOrder = 0,
  }) async {
    final id = _uuid.v4();
    final group = BudgetGroup(
      id: id,
      name: name,
      groupType: groupType.toDbString(),
      percentage: percentage,
      allocatedAmount: allocatedAmount,
      icon: icon,
      color: color,
      sortOrder: sortOrder,
      isActive: true,
      createdAt: DateTime.now(),
    );
    await _groupDao.insertGroup(group);
    return id;
  }

  /// Updates an existing budget group.
  Future<void> updateGroup(BudgetGroup group) => _groupDao.updateGroup(group);

  /// Deletes a budget group and unlinks its child budgets.
  Future<void> deleteGroup(String groupId) => _groupDao.deleteGroup(groupId);

  /// Creates a full budget plan from a rule and income amount.
  ///
  /// Creates 3 budget groups (Needs, Wants, Investments) with amounts
  /// calculated from the income and the rule's percentages.
  Future<List<String>> createBudgetPlan({
    required BudgetRuleType rule,
    required int monthlyIncomeCents,
    double? customNeeds,
    double? customWants,
    double? customInvestments,
  }) async {
    final allocations = BudgetEngine.computeGroupAllocations(
      monthlyIncome: monthlyIncomeCents,
      rule: rule,
      customNeeds: customNeeds,
      customWants: customWants,
      customInvestments: customInvestments,
    );

    final groupIds = <String>[];

    for (var i = 0; i < allocations.length; i++) {
      final alloc = allocations[i];
      final (icon, color) = _groupTypeVisuals(alloc.type);
      final id = await createGroup(
        name: alloc.type.displayName,
        groupType: alloc.type,
        percentage: alloc.percentage,
        allocatedAmount: alloc.amount,
        icon: icon,
        color: color,
        sortOrder: i,
      );
      groupIds.add(id);
    }

    return groupIds;
  }

  /// Adds a sub-budget within a group.
  Future<void> addSubBudget({
    required String groupId,
    required String name,
    required String categoryId,
    required int amountCents,
    required String period,
    required DateTime startDate,
    bool rollover = false,
    String rolloverType = 'none',
    int? rolloverCap,
    double notificationThreshold = 0.8,
  }) async {
    await _budgetRepo.createBudget(
      name: name,
      categoryId: categoryId,
      period: period,
      amount: amountCents,
      rollover: rollover,
      rolloverType: rolloverType,
      rolloverCap: rolloverCap,
      startDate: startDate,
      notificationThreshold: notificationThreshold,
      groupId: groupId,
    );
  }

  /// Recalculates group allocated amounts when income changes.
  Future<void> updateGroupAllocations(int newMonthlyIncomeCents) async {
    final groups = await _groupDao.getAllActiveGroups();
    for (final group in groups) {
      final newAmount = (newMonthlyIncomeCents * group.percentage).round();
      await _groupDao.updateGroup(
        group.copyWith(allocatedAmount: newAmount),
      );
    }
  }

  /// Returns visual properties (icon, color) for each group type.
  (String, String) _groupTypeVisuals(BudgetGroupType type) {
    return switch (type) {
      BudgetGroupType.needs => ('home', '#2196F3'),
      BudgetGroupType.wants => ('shopping-bag', '#FF9800'),
      BudgetGroupType.investments => ('trending-up', '#4CAF50'),
      BudgetGroupType.custom => ('wallet', '#6B7280'),
    };
  }
}
