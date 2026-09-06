// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_group_dao.dart';

// ignore_for_file: type=lint
mixin _$BudgetGroupDaoMixin on DatabaseAccessor<AppDatabase> {
  $BudgetGroupsTable get budgetGroups => attachedDatabase.budgetGroups;
  $BudgetsTable get budgets => attachedDatabase.budgets;
  $BudgetPeriodsTable get budgetPeriods => attachedDatabase.budgetPeriods;
  $TransactionsTable get transactions => attachedDatabase.transactions;
  $CategoriesTable get categories => attachedDatabase.categories;
  BudgetGroupDaoManager get managers => BudgetGroupDaoManager(this);
}

class BudgetGroupDaoManager {
  final _$BudgetGroupDaoMixin _db;
  BudgetGroupDaoManager(this._db);
  $$BudgetGroupsTableTableManager get budgetGroups =>
      $$BudgetGroupsTableTableManager(_db.attachedDatabase, _db.budgetGroups);
  $$BudgetsTableTableManager get budgets =>
      $$BudgetsTableTableManager(_db.attachedDatabase, _db.budgets);
  $$BudgetPeriodsTableTableManager get budgetPeriods =>
      $$BudgetPeriodsTableTableManager(_db.attachedDatabase, _db.budgetPeriods);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db.attachedDatabase, _db.transactions);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
}
