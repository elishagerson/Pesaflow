import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';
import 'daos/account_dao.dart';
import 'daos/category_dao.dart';
import 'daos/transaction_dao.dart';
import 'daos/budget_dao.dart';
import 'daos/analytics_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/tracker_dao.dart';
import 'daos/savings_goals_dao.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final accountDaoProvider = Provider<AccountDao>((ref) {
  final db = ref.watch(databaseProvider);
  return AccountDao(db);
});

final categoryDaoProvider = Provider<CategoryDao>((ref) {
  final db = ref.watch(databaseProvider);
  return CategoryDao(db);
});

final transactionDaoProvider = Provider<TransactionDao>((ref) {
  final db = ref.watch(databaseProvider);
  return TransactionDao(db);
});

final budgetDaoProvider = Provider<BudgetDao>((ref) {
  final db = ref.watch(databaseProvider);
  return BudgetDao(db);
});

final analyticsDaoProvider = Provider<AnalyticsDao>((ref) {
  final db = ref.watch(databaseProvider);
  return AnalyticsDao(db);
});

final settingsDaoProvider = Provider<SettingsDao>((ref) {
  final db = ref.watch(databaseProvider);
  return SettingsDao(db);
});

final trackerDaoProvider = Provider<TrackerDao>((ref) {
  final db = ref.watch(databaseProvider);
  return TrackerDao(db);
});

final savingsGoalsDaoProvider = Provider<SavingsGoalsDao>((ref) {
  final db = ref.watch(databaseProvider);
  return SavingsGoalsDao(db);
});
