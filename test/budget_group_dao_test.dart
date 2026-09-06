import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/budget_dao.dart';
import 'package:pesaflow/data/database/daos/budget_group_dao.dart';
import 'package:pesaflow/data/database/daos/category_dao.dart';
import 'package:pesaflow/data/repositories/budget_group_repository.dart';
import 'package:pesaflow/data/repositories/budget_repository.dart';
import 'package:pesaflow/domain/models/enums.dart' hide BudgetPeriod;

void main() {
  late AppDatabase database;
  late BudgetGroupDao groupDao;
  late BudgetDao budgetDao;
  late CategoryDao categoryDao;
  late BudgetRepository budgetRepo;
  late BudgetGroupRepository groupRepo;
  const uuid = Uuid();

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    groupDao = BudgetGroupDao(database);
    budgetDao = BudgetDao(database);
    categoryDao = CategoryDao(database);
    budgetRepo = BudgetRepository(budgetDao);
    groupRepo = BudgetGroupRepository(groupDao, budgetRepo);
  });

  tearDown(() async {
    await database.close();
  });

  group('BudgetGroupDao', () {
    test('creates and retrieves active budget groups', () async {
      final groupId = uuid.v4();
      await groupDao.insertGroup(
        BudgetGroup(
          id: groupId,
          name: 'Needs',
          groupType: BudgetGroupType.needs.toDbString(),
          percentage: 0.50,
          allocatedAmount: 50000000,
          icon: 'home',
          color: '#2196F3',
          sortOrder: 0,
          isActive: true,
          createdAt: DateTime.now(),
        ),
      );

      final groups = await groupDao.getAllActiveGroups();
      expect(groups.length, equals(1));
      expect(groups.first.name, equals('Needs'));
      expect(groups.first.percentage, equals(0.50));
      expect(groups.first.allocatedAmount, equals(50000000));
    });

    test('retrieves group by id', () async {
      final groupId = uuid.v4();
      await groupDao.insertGroup(
        BudgetGroup(
          id: groupId,
          name: 'Wants',
          groupType: BudgetGroupType.wants.toDbString(),
          percentage: 0.30,
          allocatedAmount: 30000000,
          icon: 'shopping-bag',
          color: '#FF9800',
          sortOrder: 1,
          isActive: true,
          createdAt: DateTime.now(),
        ),
      );

      final found = await groupDao.getGroupById(groupId);
      expect(found, isNotNull);
      expect(found!.name, equals('Wants'));
      expect(found.groupType, equals('wants'));
    });

    test('getGroupsWithChildren rolls up sub-budgets and progress', () async {
      // 1. Create group
      final groupId = uuid.v4();
      await groupDao.insertGroup(
        BudgetGroup(
          id: groupId,
          name: 'Needs',
          groupType: BudgetGroupType.needs.toDbString(),
          percentage: 0.50,
          allocatedAmount: 50000000,
          icon: 'home',
          color: '#2196F3',
          sortOrder: 0,
          isActive: true,
          createdAt: DateTime.now(),
        ),
      );

      // 2. Fetch seeded category
      final categories = await categoryDao.getAllCategories();
      final cat = categories.first;

      // 3. Create sub-budget in group
      final budgetId = uuid.v4();
      final now = DateTime.now();
      final periodStart = DateTime(now.year, now.month, 1);
      final periodEnd = DateTime(now.year, now.month + 1, 0);

      await budgetDao.insertBudgetWithPeriod(
        Budget(
          id: budgetId,
          name: 'Food & Groceries',
          categoryId: cat.id,
          groupId: groupId,
          period: 'monthly',
          amount: 30000000,
          rollover: false,
          rolloverType: 'none',
          startDate: periodStart,
          endDate: periodEnd,
          notificationThreshold: 0.8,
          isActive: true,
          createdAt: now,
        ),
        BudgetPeriod(
          id: uuid.v4(),
          budgetId: budgetId,
          periodStart: periodStart,
          periodEnd: periodEnd,
          allocated: 30000000,
          spent: 10000000,
          isClosed: false,
          createdAt: now,
        ),
      );

      // 4. Query joined data
      final groupsWithChildren = await groupDao.getGroupsWithChildren();
      expect(groupsWithChildren.length, equals(1));

      final groupData = groupsWithChildren.first;
      expect(groupData.group.name, equals('Needs'));
      expect(groupData.subBudgets.length, equals(1));
      expect(groupData.totalAllocated, equals(30000000));
      expect(groupData.totalSpent, equals(10000000));
      expect(groupData.percentage, closeTo(0.333, 0.01));
    });
  });

  group('BudgetGroupRepository', () {
    test('createBudgetPlan creates 3 groups matching rule', () async {
      const income = 100000000; // 1,000,000 TZS
      final groupIds = await groupRepo.createBudgetPlan(
        rule: BudgetRuleType.rule503020,
        monthlyIncomeCents: income,
      );

      expect(groupIds.length, equals(3));

      final allGroups = await groupRepo.getAllActiveGroups();
      expect(allGroups.length, equals(3));

      final needs = allGroups.firstWhere((g) => g.groupType == 'needs');
      final wants = allGroups.firstWhere((g) => g.groupType == 'wants');
      final investments =
          allGroups.firstWhere((g) => g.groupType == 'investments');

      expect(needs.allocatedAmount, equals(50000000));
      expect(wants.allocatedAmount, equals(30000000));
      expect(investments.allocatedAmount, equals(20000000));
    });

    test('getStandaloneBudgetsWithProgress returns only ungrouped budgets', () async {
      final categories = await categoryDao.getAllCategories();
      final cat = categories.first;

      // Grouped budget
      final groupId = uuid.v4();
      await groupDao.insertGroup(
        BudgetGroup(
          id: groupId,
          name: 'Needs',
          groupType: 'needs',
          percentage: 0.5,
          allocatedAmount: 500000,
          icon: 'home',
          color: '#2196F3',
          sortOrder: 0,
          isActive: true,
          createdAt: DateTime.now(),
        ),
      );

      await budgetRepo.createBudget(
        name: 'Grouped Budget',
        categoryId: cat.id,
        groupId: groupId,
        period: 'monthly',
        amount: 200000,
        rollover: false,
        rolloverType: 'none',
        startDate: DateTime.now(),
      );

      // Standalone budget
      await budgetRepo.createBudget(
        name: 'Standalone Budget',
        categoryId: cat.id,
        groupId: null,
        period: 'monthly',
        amount: 100000,
        rollover: false,
        rolloverType: 'none',
        startDate: DateTime.now(),
      );

      final standalone = await groupRepo.getStandaloneBudgetsWithProgress();
      expect(standalone.length, equals(1));
      expect(standalone.first.budget.name, equals('Standalone Budget'));
      expect(standalone.first.budget.groupId, isNull);
    });
  });
}
