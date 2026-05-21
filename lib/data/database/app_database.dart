import 'dart:io';
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

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Accounts,
  Categories,
  Transactions,
  Budgets,
  BudgetPeriods,
  DailySnapshots,
  MonthlySnapshots,
  AppSettings,
  Trackers,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

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
          _cat(uuid.v4(), 'Other Income', 'plus-circle', '#808080', 'income', 3, true),

          // Expense categories
          _cat(uuid.v4(), 'Food & Groceries', 'cart', '#FF9800', 'expense', 1, true),
          _cat(uuid.v4(), 'Transport', 'bus', '#FFC107', 'expense', 2, true),
          _cat(uuid.v4(), 'Rent', 'home', '#F44336', 'expense', 3, true),
          _cat(uuid.v4(), 'Utilities', 'zap', '#E91E63', 'expense', 4, true),
          _cat(uuid.v4(), 'Airtime & Data', 'phone', '#9C27B0', 'expense', 5, true),
          _cat(uuid.v4(), 'Health', 'heart', '#E91E63', 'expense', 6, true),
          _cat(uuid.v4(), 'Education', 'book', '#2196F3', 'expense', 7, true),
          _cat(uuid.v4(), 'Entertainment', 'film', '#673AB7', 'expense', 8, true),
          _cat(uuid.v4(), 'Shopping', 'shopping-bag', '#00BCD4', 'expense', 9, true),
          _cat(uuid.v4(), 'Eating Out', 'coffee', '#795548', 'expense', 10, true),
          _cat(uuid.v4(), 'Mobile Money Transfer', 'send', '#607D8B', 'expense', 11, true),
          _cat(uuid.v4(), 'Bank Fees', 'credit-card', '#D32F2F', 'expense', 12, true),
          _cat(uuid.v4(), 'ATM Withdrawal', 'banknote', '#4CAF50', 'expense', 13, true),
          _cat(uuid.v4(), 'Savings', 'piggy-bank', '#4CAF50', 'expense', 14, true),
          _cat(uuid.v4(), 'Other', 'more-horizontal', '#9E9E9E', 'expense', 15, true),
          
          // Transfer categories
          _cat(uuid.v4(), 'Between Accounts', 'arrow-left-right', '#9E9E9E', 'transfer', 1, true),
        ];

        for (final category in defaultCategories) {
          await into(categories).insert(category);
        }

        // Seed default tracker
        await into(trackers).insert(Tracker(
          id: 'default_personal',
          name: 'Personal',
          icon: 'person',
          color: '#006B4F',
          isArchived: false,
          createdAt: DateTime.now(),
        ));

        // Seed default app settings
        await into(appSettings).insert(AppSetting(
          key: 'onboarding_complete',
          value: 'false',
          updatedAt: DateTime.now(),
        ));
        await into(appSettings).insert(AppSetting(
          key: 'theme',
          value: 'system',
          updatedAt: DateTime.now(),
        ));
        await into(appSettings).insert(AppSetting(
          key: 'active_tracker_id',
          value: 'default_personal',
          updatedAt: DateTime.now(),
        ));
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
          await into(appSettings).insert(AppSetting(
            key: 'onboarding_complete',
            value: 'true', // Existing users skip onboarding
            updatedAt: DateTime.now(),
          ));
          await into(appSettings).insert(AppSetting(
            key: 'theme',
            value: 'system',
            updatedAt: DateTime.now(),
          ));
        }

        // Migration from schema version 2 → 3: add trackers table & trackerId to transactions
        if (from < 3) {
          await m.createTable(trackers);
          await m.addColumn(transactions, transactions.trackerId);

          // Seed default tracker for existing users
          await into(trackers).insert(Tracker(
            id: 'default_personal',
            name: 'Personal',
            icon: 'person',
            color: '#006B4F',
            isArchived: false,
            createdAt: DateTime.now(),
          ));

          // Set existing transactions to the default tracker
          await (update(transactions)..where((t) => t.trackerId.isNull())).write(
            TransactionsCompanion(trackerId: const Value('default_personal')),
          );

          // Seed active tracker setting
          await into(appSettings).insert(AppSetting(
            key: 'active_tracker_id',
            value: 'default_personal',
            updatedAt: DateTime.now(),
          ));
        }
      },
    );
  }

  Category _cat(String id, String name, String icon, String color, String type, int sortOrder, bool isSystem) {
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
