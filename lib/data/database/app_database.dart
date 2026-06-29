import 'dart:io';
import 'dart:developer' as developer;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'tables/accounts_table.dart';
import 'tables/categories_table.dart';
import 'tables/transactions_table.dart';
import 'tables/budgets_table.dart';
import 'tables/budget_periods_table.dart';
import 'tables/daily_snapshots_table.dart';
import 'tables/monthly_snapshots_table.dart';
import 'tables/app_settings_table.dart';
import 'tables/trackers_table.dart';
import 'tables/savings_goals_table.dart';
import 'tables/savings_goal_contributions_table.dart';
import 'tables/loans_table.dart';
import 'tables/recurring_transactions_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    Budgets,
    BudgetPeriods,
    DailySnapshots,
    MonthlySnapshots,
    AppSettings,
    Trackers,
    SavingsGoals,
    SavingsGoalContributions,
    Loans,
    RecurringTransactions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();

        // Seed default system categories (strictly in English)
        final uuid = const Uuid();

        final defaultCategories = [
          // Income categories
          _cat(uuid.v4(), 'Salary', 'briefcase', '#2E7D32', 'income', 1, true),
          _cat(uuid.v4(), 'Business', 'store', '#008080', 'income', 2, true),
          _cat(
            uuid.v4(),
            'Other Income',
            'plus-circle',
            '#808080',
            'income',
            3,
            true,
          ),

          // Expense categories
          _cat(
            uuid.v4(),
            'Food & Groceries',
            'cart',
            '#FF9800',
            'expense',
            1,
            true,
          ),
          _cat(uuid.v4(), 'Transport', 'bus', '#FFC107', 'expense', 2, true),
          _cat(uuid.v4(), 'Rent', 'home', '#F44336', 'expense', 3, true),
          _cat(uuid.v4(), 'Utilities', 'zap', '#E91E63', 'expense', 4, true),
          _cat(
            uuid.v4(),
            'Airtime & Data',
            'phone',
            '#9C27B0',
            'expense',
            5,
            true,
          ),
          _cat(uuid.v4(), 'Health', 'heart', '#E91E63', 'expense', 6, true),
          _cat(uuid.v4(), 'Education', 'book', '#2196F3', 'expense', 7, true),
          _cat(
            uuid.v4(),
            'Entertainment',
            'film',
            '#673AB7',
            'expense',
            8,
            true,
          ),
          _cat(
            uuid.v4(),
            'Shopping',
            'shopping-bag',
            '#00BCD4',
            'expense',
            9,
            true,
          ),
          _cat(
            uuid.v4(),
            'Eating Out',
            'coffee',
            '#795548',
            'expense',
            10,
            true,
          ),
          _cat(
            uuid.v4(),
            'Mobile Money Transfer',
            'send',
            '#607D8B',
            'expense',
            11,
            true,
          ),
          _cat(
            uuid.v4(),
            'Bank Fees',
            'credit-card',
            '#D32F2F',
            'expense',
            12,
            true,
          ),
          _cat(
            uuid.v4(),
            'ATM Withdrawal',
            'banknote',
            '#4CAF50',
            'expense',
            13,
            true,
          ),
          _cat(
            uuid.v4(),
            'Savings',
            'piggy-bank',
            '#4CAF50',
            'expense',
            14,
            true,
          ),
          _cat(
            uuid.v4(),
            'Other',
            'more-horizontal',
            '#9E9E9E',
            'expense',
            15,
            true,
          ),

          // Transfer categories
          _cat(
            uuid.v4(),
            'Between Accounts',
            'arrow-left-right',
            '#9E9E9E',
            'transfer',
            1,
            true,
          ),
        ];

        for (final category in defaultCategories) {
          await into(categories).insert(category);
        }

        // Seed default tracker
        await into(trackers).insert(
          Tracker(
            id: 'default_personal',
            name: 'Personal',
            icon: 'person',
            color: '#0A84FF',
            isArchived: false,
            createdAt: DateTime.now(),
          ),
        );

        // Seed default app settings
        await into(appSettings).insert(
          AppSetting(
            key: 'onboarding_complete',
            value: 'false',
            updatedAt: DateTime.now(),
          ),
        );
        await into(appSettings).insert(
          AppSetting(key: 'theme', value: 'system', updatedAt: DateTime.now()),
        );
        await into(appSettings).insert(
          AppSetting(
            key: 'active_tracker_id',
            value: 'default_personal',
            updatedAt: DateTime.now(),
          ),
        );
      },
      onUpgrade: (m, from, to) async {
        // Migration from schema version 1 → 2: add Phase 3 tables
        if (from < 2) {
          await m.createTable(budgets);
          await m.createTable(budgetPeriods);
          await m.createTable(dailySnapshots);
          await m.createTable(monthlySnapshots);
          await m.createTable(appSettings);

          // Seed default app settings for existing users
          await into(appSettings).insert(
            AppSetting(
              key: 'onboarding_complete',
              value: 'true', // Existing users skip onboarding
              updatedAt: DateTime.now(),
            ),
          );
          await into(appSettings).insert(
            AppSetting(
              key: 'theme',
              value: 'system',
              updatedAt: DateTime.now(),
            ),
          );
        }

        // Migration from schema version 2 → 3: add trackers table & trackerId to transactions
        if (from < 3) {
          await m.createTable(trackers);
          await m.addColumn(transactions, transactions.trackerId);

          // Seed default tracker for existing users
          await into(trackers).insert(
            Tracker(
              id: 'default_personal',
              name: 'Personal',
              icon: 'person',
              color: '#0A84FF',
              isArchived: false,
              createdAt: DateTime.now(),
            ),
          );

          // Set existing transactions to the default tracker
          await (update(
            transactions,
          )..where((t) => t.trackerId.isNull())).write(
            TransactionsCompanion(trackerId: const Value('default_personal')),
          );

          // Seed active tracker setting
          await into(appSettings).insert(
            AppSetting(
              key: 'active_tracker_id',
              value: 'default_personal',
              updatedAt: DateTime.now(),
            ),
          );
        }

        // Migration from schema version 3 → 4: add savingsGoals and savingsGoalContributions tables
        if (from < 4) {
          await m.createTable(savingsGoals);
          await m.createTable(savingsGoalContributions);
        }

        // Migration from schema version 4 → 5: add destinationAccountId to transactions
        if (from < 5) {
          await m.addColumn(transactions, transactions.destinationAccountId);
        }

        // Migration from schema version 5 → 6: add Loans table & loanId to transactions
        if (from < 6) {
          await m.createTable(loans);
          await m.addColumn(transactions, transactions.loanId);
        }

        // Migration from schema version 6 → 7: add recurring_transactions & loan polish columns
        if (from < 7) {
          await m.createTable(recurringTransactions);
          await m.addColumn(loans, loans.interestRate);
          await m.addColumn(loans, loans.installmentAmount);
          await m.addColumn(loans, loans.totalInstallments);
          await m.addColumn(loans, loans.paidInstallments);
          await m.addColumn(loans, loans.frequencyInDays);
        }

        // Migration from schema version 7 → 8: add subscriptions table (raw SQL since table class is removed)
        if (from < 8) {
          await m.database.customStatement('''
            CREATE TABLE IF NOT EXISTS subscriptions (
              id TEXT NOT NULL PRIMARY KEY,
              account_id TEXT NOT NULL,
              category_id TEXT,
              amount INTEGER NOT NULL,
              name TEXT NOT NULL,
              merchant_keywords TEXT NOT NULL,
              frequency TEXT NOT NULL,
              interval_value INTEGER NOT NULL DEFAULT 1,
              next_due_date DATETIME NOT NULL,
              last_paid_date DATETIME,
              total_paid INTEGER NOT NULL DEFAULT 0,
              payment_count INTEGER NOT NULL DEFAULT 0,
              status TEXT NOT NULL DEFAULT 'active',
              tracker_id TEXT,
              created_at DATETIME NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now')),
              updated_at DATETIME NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now'))
            );
          ''');
        }

        // Migration from schema version 8 → 9: make accountId nullable in transactions
        if (from < 9) {
          await m.alterTable(TableMigration(transactions));
        }

        // Migration from schema version 9 → 10: consolidate subscriptions into recurring transactions
        if (from < 10) {
          // 1. Add columns to recurring_transactions table
          await m.addColumn(
            recurringTransactions,
            recurringTransactions.merchantKeywords,
          );
          await m.addColumn(
            recurringTransactions,
            recurringTransactions.lastPaidAt,
          );
          await m.addColumn(
            recurringTransactions,
            recurringTransactions.totalPaid,
          );
          await m.addColumn(
            recurringTransactions,
            recurringTransactions.paymentCount,
          );

          // 2. Query existing subscriptions and insert into recurring transactions
          try {
            final rows = await m.database
                .customSelect('SELECT * FROM subscriptions')
                .get();
            for (final row in rows) {
              await m.database
                  .into(recurringTransactions)
                  .insert(
                    RecurringTransactionsCompanion(
                      id: Value(row.read<String>('id')),
                      accountId: Value(row.read<String>('account_id')),
                      categoryId: Value(row.read<String?>('category_id')),
                      amount: Value(row.read<int>('amount')),
                      type: const Value('expense'),
                      description: Value(row.read<String>('name')),
                      frequency: Value(row.read<String>('frequency')),
                      intervalValue: Value(row.read<int>('interval_value')),
                      nextDate: Value(row.read<DateTime>('next_due_date')),
                      endDate: const Value.absent(),
                      status: Value(row.read<String>('status')),
                      trackerId: Value(row.read<String?>('tracker_id')),
                      merchantKeywords: Value(
                        row.read<String>('merchant_keywords'),
                      ),
                      lastPaidAt: Value(row.read<DateTime?>('last_paid_date')),
                      totalPaid: Value(row.read<int>('total_paid')),
                      paymentCount: Value(row.read<int>('payment_count')),
                      createdAt: Value(row.read<DateTime>('created_at')),
                      updatedAt: Value(row.read<DateTime>('updated_at')),
                    ),
                  );
            }
          } catch (e) {
            developer.log(
              'Subscription migration skipped or failed: $e',
              name: 'AppDatabase',
            );
          }

          // 3. Drop legacy subscriptions table
          await m.database.customStatement(
            'DROP TABLE IF EXISTS subscriptions;',
          );
        }
      },
    );
  }

  Category _cat(
    String id,
    String name,
    String icon,
    String color,
    String type,
    int sortOrder,
    bool isSystem,
  ) {
    return Category(
      id: id,
      name: name,
      icon: icon,
      color: color,
      type: type,
      isSystem: isSystem,
      sortOrder: sortOrder,
      createdAt: DateTime.now(),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'pesaflow.db'));
    return NativeDatabase.createInBackground(file);
  });
}
