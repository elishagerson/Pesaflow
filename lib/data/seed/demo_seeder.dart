import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/account_dao.dart';
import 'package:pesaflow/data/database/daos/category_dao.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/database/daos/budget_dao.dart';
import 'package:pesaflow/data/database/daos/loan_dao.dart';
import 'package:pesaflow/data/database/daos/savings_goal_dao.dart';

class DemoSeeder {
  final AppDatabase db;
  const DemoSeeder(this.db);

  Future<void> seedDemoData() async {
    final accountDao = AccountDao(db);
    final categoryDao = CategoryDao(db);
    final transactionDao = TransactionDao(db);
    final budgetDao = BudgetDao(db);
    final loanDao = LoanDao(db);
    final savingsGoalDao = SavingsGoalDao(db);

    const uuid = Uuid();
    final now = DateTime.now();

    // 1. Clear database tables first to ensure clean state
    await db.customStatement('DELETE FROM transactions;');
    await db.customStatement('DELETE FROM accounts;');
    await db.customStatement('DELETE FROM budget_periods;');
    await db.customStatement('DELETE FROM budgets;');
    await db.customStatement('DELETE FROM loans;');
    await db.customStatement('DELETE FROM savings_goal_contributions;');
    await db.customStatement('DELETE FROM savings_goals;');

    // 2. Seed Accounts
    final mpesaId = uuid.v4();
    final nmbId = uuid.v4();
    final cashId = uuid.v4();

    await accountDao.insertAccount(
      Account(
        id: mpesaId,
        name: 'M-Pesa',
        type: 'mobile_money',
        provider: 'M-Pesa_TZ',
        balance: 145000,
        icon: 'phone',
        sortOrder: 0,
        isArchived: false,
        createdAt: now,
      ),
    );

    await accountDao.insertAccount(
      Account(
        id: nmbId,
        name: 'NMB Bank',
        type: 'bank',
        provider: 'NMB',
        balance: 850000,
        icon: 'account_balance',
        sortOrder: 1,
        isArchived: false,
        createdAt: now,
      ),
    );

    await accountDao.insertAccount(
      Account(
        id: cashId,
        name: 'Cash Wallet',
        type: 'cash',
        balance: 23000,
        icon: 'wallet',
        sortOrder: 2,
        isArchived: false,
        createdAt: now,
      ),
    );

    // 3. Get or Seed Categories
    var categories = await categoryDao.getAllCategories();
    if (categories.isEmpty) {
      final defaultCategories = [
        ('Food', 'restaurant', 0, 'expense'),
        ('Transport', 'directions_bus', 1, 'expense'),
        ('Utilities', 'bolt', 2, 'expense'),
        ('Entertainment', 'movie', 3, 'expense'),
        ('Health', 'local_hospital', 4, 'expense'),
        ('Shopping', 'shopping_bag', 5, 'expense'),
        ('Income', 'work', 6, 'income'),
        ('Other', 'category', 7, 'expense'),
      ];

      for (final (name, icon, order, type) in defaultCategories) {
        await categoryDao.insertCategory(
          Category(
            id: uuid.v4(),
            name: name,
            icon: icon,
            color: '#6B7280',
            type: type,
            sortOrder: order,
            isSystem: true,
            createdAt: now,
          ),
        );
      }
      categories = await categoryDao.getAllCategories();
    }

    final foodCat = categories.firstWhere((c) => c.name == 'Food');
    final transCat = categories.firstWhere((c) => c.name == 'Transport');
    final utilCat = categories.firstWhere((c) => c.name == 'Utilities');
    final shoppingCat = categories.firstWhere((c) => c.name == 'Shopping');
    final incCat = categories.firstWhere((c) => c.name == 'Income');

    // 4. Seed Budgets & Periods
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    final foodBudgetId = uuid.v4();
    await budgetDao.insertBudget(
      Budget(
        id: foodBudgetId,
        name: 'Monthly Food',
        categoryId: foodCat.id,
        period: 'monthly',
        amount: 400000,
        rollover: false,
        rolloverType: 'none',
        startDate: startOfMonth,
        endDate: endOfMonth,
        notificationThreshold: 0.8,
        isActive: true,
        createdAt: now,
      ),
    );

    await db
        .into(db.budgetPeriods)
        .insert(
          BudgetPeriod(
            id: uuid.v4(),
            budgetId: foodBudgetId,
            periodStart: startOfMonth,
            periodEnd: endOfMonth,
            allocated: 400000,
            createdAt: now,
          ),
        );

    final transBudgetId = uuid.v4();
    await budgetDao.insertBudget(
      Budget(
        id: transBudgetId,
        name: 'Commute Budget',
        categoryId: transCat.id,
        period: 'monthly',
        amount: 150000,
        rollover: false,
        rolloverType: 'none',
        startDate: startOfMonth,
        endDate: endOfMonth,
        notificationThreshold: 0.8,
        isActive: true,
        createdAt: now,
      ),
    );

    await db
        .into(db.budgetPeriods)
        .insert(
          BudgetPeriod(
            id: uuid.v4(),
            budgetId: transBudgetId,
            periodStart: startOfMonth,
            periodEnd: endOfMonth,
            allocated: 150000,
            createdAt: now,
          ),
        );

    // 5. Seed Transactions (distributed over past 30 days)
    final random = Random();
    final List<Transaction> sampleTxList = [];

    // Salary Credit
    sampleTxList.add(
      Transaction(
        id: uuid.v4(),
        accountId: nmbId,
        categoryId: incCat.id,
        amount: 1200000,
        type: 'income',
        description: 'Monthly Salary Credit',
        reference: 'SAL-NMB-2026',
        source: 'manual',
        createdAt: now.subtract(const Duration(days: 15)),
        updatedAt: now.subtract(const Duration(days: 15)),
      ),
    );

    for (int i = 1; i <= 20; i++) {
      final daysAgo = random.nextInt(30);
      final date = now.subtract(Duration(days: daysAgo));

      if (i == 5) {
        // Utilities Expense
        sampleTxList.add(
          Transaction(
            id: uuid.v4(),
            accountId: mpesaId,
            categoryId: utilCat.id,
            amount: 35000,
            type: 'expense',
            description: 'Luku Electricity purchase',
            reference: 'MP-${100000 + random.nextInt(900000)}',
            source: 'manual',
            createdAt: date,
            updatedAt: date,
          ),
        );
      }

      if (i % 3 == 0) {
        // Food Expense
        sampleTxList.add(
          Transaction(
            id: uuid.v4(),
            accountId: mpesaId,
            categoryId: foodCat.id,
            amount: 15000 + random.nextInt(8) * 2000,
            type: 'expense',
            description: 'Lunch at Cafe',
            reference: 'MP-${100000 + random.nextInt(900000)}',
            source: 'manual',
            createdAt: date,
            updatedAt: date,
          ),
        );
      } else if (i % 3 == 1) {
        // Transport Expense
        sampleTxList.add(
          Transaction(
            id: uuid.v4(),
            accountId: cashId,
            categoryId: transCat.id,
            amount: 3000 + random.nextInt(5) * 1000,
            type: 'expense',
            description: 'Bodaboda ride',
            source: 'manual',
            createdAt: date,
            updatedAt: date,
          ),
        );
      } else {
        // Shopping Expense
        sampleTxList.add(
          Transaction(
            id: uuid.v4(),
            accountId: nmbId,
            categoryId: shoppingCat.id,
            amount: 25000 + random.nextInt(15) * 5000,
            type: 'expense',
            description: 'Supermarket shopping',
            reference: 'CR-${100000 + random.nextInt(900000)}',
            source: 'manual',
            createdAt: date,
            updatedAt: date,
          ),
        );
      }
    }

    // Insert all transactions
    for (final tx in sampleTxList) {
      await transactionDao.insertTransactionWithoutBalanceAdjustment(tx);
    }

    // 6. Seed Loans
    final loanId = uuid.v4();
    await loanDao.insertLoan(
      Loan(
        id: loanId,
        amount: 500000,
        description: 'Emergency Cash Loan',
        sender: 'Elisha Gerson',
        interestRate: 0.0,
        disbursedAt: now.subtract(const Duration(days: 20)),
        dueAt: now.add(const Duration(days: 40)),
        reference: 'LOAN-EG-99',
        status: 'active',
        createdAt: now,
        updatedAt: now,
      ),
    );

    // 7. Seed Savings Goal & Contributions
    final goalId = uuid.v4();
    await savingsGoalDao.insertGoal(
      SavingsGoal(
        id: goalId,
        name: 'Emergency Fund',
        targetAmount: 1000000,
        currentAmount: 300000,
        targetDate: now.add(const Duration(days: 180)),
        color: '#FFD700',
        icon: 'savings',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await db
        .into(db.savingsGoalContributions)
        .insert(
          SavingsGoalContribution(
            id: uuid.v4(),
            goalId: goalId,
            amount: 300000,
            notes: 'Initial savings allocation',
            createdAt: now.subtract(const Duration(days: 10)),
          ),
        );
  }
}
