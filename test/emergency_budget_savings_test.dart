import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/budget_dao.dart';
import 'package:pesaflow/data/database/daos/category_dao.dart';
import 'package:pesaflow/data/database/daos/savings_goals_dao.dart';
import 'package:pesaflow/data/repositories/budget_repository.dart';
import 'package:pesaflow/services/notification_service.dart';
import 'package:uuid/uuid.dart';

class MockNotificationService extends NotificationService {
  final List<({int id, String title, String body})> sentNotifications = [];

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    bool needsReview = false,
  }) async {
    sentNotifications.add((id: id, title: title, body: body));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late BudgetDao budgetDao;
  late CategoryDao categoryDao;
  late SavingsGoalsDao savingsGoalsDao;
  late MockNotificationService mockNotifService;
  late BudgetRepository budgetRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    budgetDao = BudgetDao(db);
    categoryDao = CategoryDao(db);
    savingsGoalsDao = SavingsGoalsDao(db);
    mockNotifService = MockNotificationService();

    budgetRepo = BudgetRepository(
      budgetDao,
      categoryDao: categoryDao,
      savingsGoalsDao: savingsGoalsDao,
      notificationService: mockNotifService,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Emergency Budget Savings Sweep & Notification', () {
    test('Unused emergency budget (never used) sweeps 100% to savings on period expiration and notifies user', () async {
      final categories = await categoryDao.getAllCategories();
      final emergencyCat = categories.firstWhere((c) => c.name == 'Emergencies');

      // Create an emergency budget starting last month (already expired)
      final pastStart = DateTime(2026, 7, 1);
      const allocatedCents = 20000000; // 200,000 TZS

      await budgetRepo.createBudget(
        name: 'Emergency Buffer',
        categoryId: emergencyCat.id,
        period: 'monthly',
        amount: allocatedCents,
        rollover: true,
        rolloverType: 'all',
        startDate: pastStart,
      );

      final activeBudgets = await budgetDao.getAllActiveBudgets();
      final budget = activeBudgets.firstWhere((b) => b.name == 'Emergency Buffer');

      // Verify no savings goals initially
      final initialGoals = await savingsGoalsDao.getAllGoals();
      expect(initialGoals, isEmpty);

      // Check and close expired periods
      await budgetRepo.checkAndCloseExpiredPeriods();

      // 1. A dedicated Emergency Fund savings goal should have been auto-created
      final goals = await savingsGoalsDao.getAllGoals();
      expect(goals.length, equals(1));
      final emergencyGoal = goals.first;
      expect(emergencyGoal.name, equals('Emergency Fund'));
      expect(emergencyGoal.currentAmount, equals(allocatedCents));

      // 2. A contribution record should exist with the transferred amount
      final contributions =
          await savingsGoalsDao.getContributionsForGoal(emergencyGoal.id);
      expect(contributions.length, equals(1));
      expect(contributions.first.amount, equals(allocatedCents));
      expect(contributions.first.notes, contains('Unused budget from Emergency Buffer'));

      // 3. User notification should have been dispatched
      expect(mockNotifService.sentNotifications.length, equals(1));
      final notif = mockNotifService.sentNotifications.first;
      expect(notif.title, contains('Move to Savings'));
      expect(notif.body, contains('Emergency Buffer'));
      expect(notif.body, contains('Emergency Fund'));

      // 4. Because funds were moved to savings, rollover into next budget period should be 0
      final currentPeriod = await budgetDao.getCurrentPeriod(budget.id);
      expect(currentPeriod, isNotNull);
      expect(currentPeriod!.rolledFrom, equals(0));
      expect(currentPeriod.allocated, equals(allocatedCents));
    });

    test('Partially used emergency budget moves remainder to existing savings goal and notifies user', () async {
      final categories = await categoryDao.getAllCategories();
      final emergencyCat = categories.firstWhere((c) => c.name == 'Emergencies');
      const uuid = Uuid();

      // Pre-create an existing savings goal
      final existingGoalId = uuid.v4();
      await savingsGoalsDao.insertSavingsGoal(
        SavingsGoal(
          id: existingGoalId,
          name: 'My Safety Cushion',
          targetAmount: 100000000,
          currentAmount: 10000000, // 100,000 TZS already saved
          targetDate: DateTime(2027, 1, 1),
          color: '#10B981',
          icon: 'shield',
          trackerId: null,
          isCompleted: false,
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      final pastStart = DateTime(2026, 7, 1);
      const allocatedCents = 15000000; // 150,000 TZS
      const spentCents = 5000000; // 50,000 TZS spent
      const remainingCents = 10000000; // 100,000 TZS remaining

      await budgetRepo.createBudget(
        name: 'Urgent Care',
        categoryId: emergencyCat.id,
        period: 'monthly',
        amount: allocatedCents,
        rollover: false,
        rolloverType: 'none',
        startDate: pastStart,
      );

      // Record a transaction during that past period
      await db.into(db.transactions).insert(
        Transaction(
          id: uuid.v4(),
          amount: spentCents,
          type: 'expense',
          categoryId: emergencyCat.id,
          description: 'Clinic medicine',
          source: 'manual',
          createdAt: DateTime(2026, 7, 10, 10, 0),
          updatedAt: DateTime(2026, 7, 10, 10, 0),
        ),
      );

      // Run period close
      await budgetRepo.checkAndCloseExpiredPeriods();

      // Goal currentAmount should be updated: 100,000 + 100,000 = 200,000 TZS (20,000,000 cents)
      final updatedGoal = await savingsGoalsDao.getSavingsGoalById(existingGoalId);
      expect(updatedGoal, isNotNull);
      expect(updatedGoal!.currentAmount, equals(20000000));

      // Contribution must match the remainder exactly
      final contributions =
          await savingsGoalsDao.getContributionsForGoal(existingGoalId);
      expect(contributions.length, equals(1));
      expect(contributions.first.amount, equals(remainingCents));

      // Notification sent with details
      expect(mockNotifService.sentNotifications.length, equals(1));
      expect(mockNotifService.sentNotifications.first.body, contains('My Safety Cushion'));
    });

    test('Fully spent emergency budget does NOT transfer to savings', () async {
      final categories = await categoryDao.getAllCategories();
      final emergencyCat = categories.firstWhere((c) => c.name == 'Emergencies');
      const uuid = Uuid();

      final pastStart = DateTime(2026, 7, 1);
      const allocatedCents = 10000000;

      await budgetRepo.createBudget(
        name: 'Emergency Expense',
        categoryId: emergencyCat.id,
        period: 'monthly',
        amount: allocatedCents,
        rollover: false,
        rolloverType: 'none',
        startDate: pastStart,
      );

      // Spend full amount
      await db.into(db.transactions).insert(
        Transaction(
          id: uuid.v4(),
          amount: allocatedCents,
          type: 'expense',
          categoryId: emergencyCat.id,
          description: 'Emergency repair',
          source: 'manual',
          createdAt: DateTime(2026, 7, 5, 12, 0),
          updatedAt: DateTime(2026, 7, 5, 12, 0),
        ),
      );

      await budgetRepo.checkAndCloseExpiredPeriods();

      // No savings goals or contributions created
      final goals = await savingsGoalsDao.getAllGoals();
      expect(goals, isEmpty);
      expect(mockNotifService.sentNotifications, isEmpty);
    });

    test('moveEmergencyBudgetRemainderToSavings moves funds on demand and adjusts allocated', () async {
      final categories = await categoryDao.getAllCategories();
      final emergencyCat = categories.firstWhere((c) => c.name == 'Emergencies');
      const uuid = Uuid();

      final now = DateTime.now();
      final currentMonthStart = DateTime(now.year, now.month, 1);
      const allocatedCents = 30000000; // 300,000 TZS
      const spentCents = 10000000; // 100,000 TZS

      await budgetRepo.createBudget(
        name: 'Active Emergency Budget',
        categoryId: emergencyCat.id,
        period: 'monthly',
        amount: allocatedCents,
        rollover: false,
        rolloverType: 'none',
        startDate: currentMonthStart,
      );

      final activeBudgets = await budgetDao.getAllActiveBudgets();
      final budget = activeBudgets.firstWhere((b) => b.name == 'Active Emergency Budget');

      // Add a spent transaction in current month
      await db.into(db.transactions).insert(
        Transaction(
          id: uuid.v4(),
          amount: spentCents,
          type: 'expense',
          categoryId: emergencyCat.id,
          description: 'Urgent clinic visit',
          source: 'manual',
          createdAt: DateTime(now.year, now.month, 2, 10, 0),
          updatedAt: DateTime(now.year, now.month, 2, 10, 0),
        ),
      );

      // Move remainder early (200,000 TZS)
      final moved =
          await budgetRepo.moveEmergencyBudgetRemainderToSavings(budget.id);
      expect(moved, isTrue);

      // Savings goal created and credited with 200,000 TZS
      final goals = await savingsGoalsDao.getAllGoals();
      expect(goals.length, equals(1));
      expect(goals.first.currentAmount, equals(20000000));

      // Period allocated should be adjusted to equal spent so remainder is now 0
      final updatedPeriod = await budgetDao.getCurrentPeriod(budget.id);
      expect(updatedPeriod!.allocated, equals(spentCents));

      // Trying to move again returns false
      final movedAgain =
          await budgetRepo.moveEmergencyBudgetRemainderToSavings(budget.id);
      expect(movedAgain, isFalse);
    });
  });
}
