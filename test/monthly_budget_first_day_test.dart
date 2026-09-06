import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/budget_dao.dart';
import 'package:pesaflow/data/database/daos/category_dao.dart';
import 'package:pesaflow/data/repositories/budget_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late BudgetDao budgetDao;
  late CategoryDao categoryDao;
  late BudgetRepository budgetRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    budgetDao = BudgetDao(db);
    categoryDao = CategoryDao(db);
    budgetRepo = BudgetRepository(budgetDao);
  });

  tearDown(() async {
    await db.close();
  });

  group('Monthly Budget 1st-of-the-month Tracking', () {
    test('createBudget with period=monthly automatically sets startDate and periodStart to 1st of month', () async {
      final categories = await categoryDao.getAllCategories();
      final cat = categories.firstWhere((c) => c.name == 'Food & Groceries');

      // User creates budget mid-month on Sept 18, 2026
      final midMonthDate = DateTime(2026, 9, 18);
      await budgetRepo.createBudget(
        name: 'Food September',
        categoryId: cat.id,
        period: 'monthly',
        amount: 30000000, // 300,000 TZS
        rollover: false,
        rolloverType: 'none',
        startDate: midMonthDate,
      );

      final activeBudgets = await budgetDao.getAllActiveBudgets();
      final created = activeBudgets.firstWhere((b) => b.name == 'Food September');

      // The budget startDate must be normalized to 1st of Sept
      expect(created.startDate, equals(DateTime(2026, 9, 1)));

      final currentPeriod = await budgetDao.getCurrentPeriod(created.id);
      expect(currentPeriod, isNotNull);

      // Tracking period starts from Sept 1st and ends on Sept 30th
      expect(currentPeriod!.periodStart, equals(DateTime(2026, 9, 1)));
      expect(currentPeriod.periodEnd, equals(DateTime(2026, 9, 30)));
    });

    test('Monthly budget captures transactions that occurred earlier in the month before creation', () async {
      final categories = await categoryDao.getAllCategories();
      final cat = categories.firstWhere((c) => c.name == 'Food & Groceries');
      const uuid = Uuid();

      // Transaction occurred on Sept 3rd
      await db.into(db.transactions).insert(
        Transaction(
          id: uuid.v4(),
          amount: 2500000, // 25,000 TZS
          type: 'expense',
          categoryId: cat.id,
          description: 'Groceries at Shoppers',
          source: 'manual',
          createdAt: DateTime(2026, 9, 3, 14, 30),
          updatedAt: DateTime(2026, 9, 3, 14, 30),
        ),
      );

      // Transaction occurred on Sept 10th
      await db.into(db.transactions).insert(
        Transaction(
          id: uuid.v4(),
          amount: 1500000, // 15,000 TZS
          type: 'expense',
          categoryId: cat.id,
          description: 'Market shopping',
          source: 'manual',
          createdAt: DateTime(2026, 9, 10, 10, 0),
          updatedAt: DateTime(2026, 9, 10, 10, 0),
        ),
      );

      // Budget created on Sept 15th
      await budgetRepo.createBudget(
        name: 'Food September Tracked',
        categoryId: cat.id,
        period: 'monthly',
        amount: 10000000, // 100,000 TZS
        rollover: false,
        rolloverType: 'none',
        startDate: DateTime(2026, 9, 15),
      );

      final budgetsWithProgress =
          await budgetRepo.getActiveBudgetsWithProgress();
      final foodBudget = budgetsWithProgress.firstWhere(
        (b) => b.budget.name == 'Food September Tracked',
      );

      // Both earlier transactions (25,000 + 15,000 = 40,000 TZS = 4,000,000 cents)
      // are accurately captured because tracking starts on Sept 1st
      expect(foodBudget.spentInPeriod, equals(4000000));
      expect(foodBudget.currentPeriod!.periodStart, equals(DateTime(2026, 9, 1)));
      expect(foodBudget.currentPeriod!.periodEnd, equals(DateTime(2026, 9, 30)));
    });

    test('checkAndCloseExpiredPeriods automatically aligns existing monthly budgets starting mid-month to day 1', () async {
      final categories = await categoryDao.getAllCategories();
      final cat = categories.firstWhere((c) => c.name == 'Transport');
      const uuid = Uuid();
      final budgetId = uuid.v4();

      final now = DateTime.now();
      // Simulate an unaligned legacy monthly budget starting on the 12th of this month
      final unalignedStart = DateTime(now.year, now.month, 12);
      final unalignedEnd = DateTime(now.year, now.month + 1, 11);

      await budgetDao.insertBudgetWithPeriod(
        Budget(
          id: budgetId,
          name: 'Legacy Transport',
          categoryId: cat.id,
          period: 'monthly',
          amount: 5000000,
          rollover: false,
          rolloverType: 'none',
          startDate: unalignedStart,
          notificationThreshold: 0.8,
          isActive: true,
          createdAt: unalignedStart,
        ),
        BudgetPeriod(
          id: uuid.v4(),
          budgetId: budgetId,
          periodStart: unalignedStart,
          periodEnd: unalignedEnd,
          allocated: 5000000,
          spent: 0,
          isClosed: false,
          createdAt: unalignedStart,
        ),
      );

      // Run checkAndCloseExpiredPeriods
      await budgetRepo.checkAndCloseExpiredPeriods();

      final currentPeriod = await budgetDao.getCurrentPeriod(budgetId);
      expect(currentPeriod, isNotNull);
      // Period must now start on day 1 of the month
      expect(currentPeriod!.periodStart.day, equals(1));

      final budget = await budgetRepo.getBudgetById(budgetId);
      expect(budget!.startDate.day, equals(1));
    });
  });
}
