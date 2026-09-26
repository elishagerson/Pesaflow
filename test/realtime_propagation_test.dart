import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/database_providers.dart';
import 'package:pesaflow/data/repositories/savings_goal_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/state/spending_pattern_provider.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

/// These tests exercise the REAL providers against a REAL database. They exist
/// because the widget tests override providers with `Stream.value(...)`, which
/// mocks away the very reactivity that was broken in production.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  final closers = <void Function()>[];

  /// A category that actually exists in the seeded DB. The transaction list
  /// inner-joins categories, so an unknown id would hide the row entirely.
  late String existingCategoryId;

  /// Keeps a live subscription so StreamProviders actually recompute.
  /// `container.read(...)` alone does not subscribe, which would make
  /// reactive providers look frozen and produce false failures.
  void watch(dynamic provider) {
    closers.add(container.listen<dynamic>(provider, (_, _) {}).close);
  }

  const trackerId = 'default_personal';

  final t0 = DateTime(2026, 4, 1, 9);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    existingCategoryId = (await db.select(db.categories).get()).first.id;
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    for (final close in closers) {
      close();
    }
    closers.clear();
    container.dispose();
    await db.close();
  });

  Category cat(String id, String name) => Category(
    id: id,
    name: name,
    type: 'expense',
    color: '#FF9800',
    icon: 'restaurant',
    isSystem: false,
    sortOrder: 0,
    createdAt: t0,
  );

  group('categories', () {
    test('provider reflects a category inserted AFTER first read', () async {
      // Seed a row, then subscribe and let the provider resolve.
      await db.into(db.categories).insert(cat('c1', 'ZZ Food'));
      watch(categoriesFutureProvider);
      await container.read(categoriesFutureProvider.future);
      expect(
        container.read(categoriesFutureProvider).value!.map((c) => c.name),
        contains('ZZ Food'),
      );

      // Now insert another row the way the rest of the app would. Note we read
      // `.value` (current state), not `.future` (a cached Future).
      await db.into(db.categories).insert(cat('c2', 'ZZ Transport'));
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(
        container.read(categoriesFutureProvider).value!.map((c) => c.name),
        containsAll(['ZZ Food', 'ZZ Transport']),
        reason: 'a newly added category must appear without a manual refresh',
      );
    });
  });

  group('accounts', () {
    test('provider reflects an account inserted AFTER first read', () async {
      watch(accountsStreamProvider);
      await db.into(db.accounts).insert(
        Account(
          id: 'a1',
          name: 'M-Pesa',
          type: 'mobile_money',
          balance: 500000,
          provider: 'M-Pesa_TZ',
          icon: 'wallet',
          sortOrder: 0,
          isArchived: false,
          createdAt: t0,
        ),
      );
      final first = await container.read(accountsStreamProvider.future);
      expect(first.length, 1);

      await db.into(db.accounts).insert(
        Account(
          id: 'a2',
          name: 'Tigo Pesa',
          type: 'mobile_money',
          balance: 250000,
          provider: 'Tigo_TZ',
          icon: 'wallet',
          sortOrder: 1,
          isArchived: false,
          createdAt: t0,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final second = await container.read(accountsStreamProvider.future);
      expect(
        second.map((a) => a.name),
        containsAll(['M-Pesa', 'Tigo Pesa']),
        reason: 'a newly added account must appear without a manual refresh',
      );
    });
  });

  group('savings goals', () {
    Future<void> seedGoal(String id, {int current = 0, int target = 1000000}) async {
      await db.into(db.savingsGoals).insert(
        SavingsGoal(
          id: id,
          trackerId: trackerId,
          name: 'Emergency Fund',
          targetAmount: target,
          currentAmount: current,
          targetDate: DateTime(2026, 12, 31),
          color: '#4CAF50',
          icon: 'savings',
          isCompleted: false,
          createdAt: t0,
        ),
      );
    }

    test('goal progress updates in real time after a contribution', () async {
      watch(savingsGoalsStreamProvider);
      await seedGoal('g1');

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(container.read(savingsGoalsStreamProvider).value!.first.currentAmount, 0);

      final repo = container.read(savingsGoalRepositoryProvider);
      await repo.addContribution(savingsGoalId: 'g1', amount: 250000);

      await Future<void>.delayed(const Duration(milliseconds: 80));

      final goals = container.read(savingsGoalsStreamProvider).value!;
      expect(
        goals.first.currentAmount,
        250000,
        reason: 'the goal card must show the new saved amount immediately',
      );
    });

    test('deleting a goal removes it from the list in real time', () async {
      watch(savingsGoalsStreamProvider);
      await seedGoal('g1');
      await seedGoal('g2');

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        container.read(savingsGoalsStreamProvider).value!.length,
        2,
      );

      final repo = container.read(savingsGoalRepositoryProvider);
      await repo.deleteSavingsGoal('g1');

      await Future<void>.delayed(const Duration(milliseconds: 80));

      final goals = container.read(savingsGoalsStreamProvider).value!;
      expect(
        goals.length,
        1,
        reason: 'a deleted goal must disappear immediately',
      );
      expect(goals.single.id, 'g2');
    });

    test('deleting a contribution reverts the saved amount in real time', () async {
      watch(savingsGoalsStreamProvider);
      await seedGoal('g1');
      final repo = container.read(savingsGoalRepositoryProvider);
      await repo.addContribution(savingsGoalId: 'g1', amount: 100000);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        container.read(savingsGoalsStreamProvider).value!.first.currentAmount,
        100000,
      );

      final contributions = await repo.getContributions('g1');
      await repo.deleteContribution(contributions.single.id);

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(
        container.read(savingsGoalsStreamProvider).value!.first.currentAmount,
        0,
        reason: 'removing a deposit must immediately reduce the saved amount',
      );
    });
  });

  group('tracker', () {
    test('active tracker resolves from the seeded row', () async {
      // `default_personal` is seeded by AppDatabase onCreate.
      watch(activeTrackerProvider);
      final t = await container.read(activeTrackerProvider.future);
      expect(t?.id, trackerId);
    });
  });

  group('transactions', () {
    Future<void> seedTxn(String id, {int amount = 50000}) async {
      await db.into(db.transactions).insert(
        Transaction(
          id: id,
          accountId: null,
          categoryId: existingCategoryId,
          trackerId: trackerId,
          amount: amount,
          type: 'expense',
          description: 'Txn $id',
          reference: 'REF-$id',
          provider: 'M-Pesa_TZ',
          smsTimestamp: t0,
          source: 'manual',
          createdAt: t0,
          updatedAt: t0,
        ),
      );
    }

    test('a new transaction appears in the filtered list in real time', () async {
      watch(filteredTransactionsStreamProvider);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final before = container.read(filteredTransactionsStreamProvider).value!;
      expect(before.where((t) => t.transaction.id == 'tx-new'), isEmpty);

      await seedTxn('tx-new');

      await Future<void>.delayed(const Duration(milliseconds: 80));
      final after = container.read(filteredTransactionsStreamProvider).value!;
      expect(
        after.map((t) => t.transaction.id),
        contains('tx-new'),
        reason: 'a saved transaction must show up without leaving the screen',
      );
    });

    test('deleting a transaction removes it from the list in real time', () async {
      await seedTxn('tx-del');
      watch(filteredTransactionsStreamProvider);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        container
            .read(filteredTransactionsStreamProvider)
            .value!
            .map((t) => t.transaction.id),
        contains('tx-del'),
      );

      await container
          .read(transactionRepositoryProvider)
          .deleteTransaction('tx-del');

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(
        container
            .read(filteredTransactionsStreamProvider)
            .value!
            .map((t) => t.transaction.id),
        isNot(contains('tx-del')),
        reason: 'a deleted transaction must disappear immediately',
      );
    });

    test('recent transactions reflect a new transaction', () async {
      watch(recentTransactionsStreamProvider);
      await seedTxn('tx-recent');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(
        container
            .read(recentTransactionsStreamProvider)
            .value!
            .map((t) => t.transaction.id),
        contains('tx-recent'),
      );
    });
  });

  group('analytics aggregates', () {
    test('monthly totals re-query after a transaction is added', () async {
      watch(monthlyTotalsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final before = container.read(monthlyTotalsProvider).value!;

      await db.into(db.transactions).insert(
        Transaction(
          id: 'tx-tot',
          accountId: null,
          categoryId: existingCategoryId,
          trackerId: trackerId,
          amount: 777000,
          type: 'expense',
          description: 'Big expense',
          reference: 'REF-tx-tot',
          provider: 'M-Pesa_TZ',
          smsTimestamp: DateTime.now(),
          source: 'manual',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 120));
      final after = container.read(monthlyTotalsProvider).value!;
      expect(
        after,
        isNot(equals(before)),
        reason: 'monthly totals must recompute when transactions change',
      );
    });

    test('insights re-query after a transaction is added', () async {
      watch(insightsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      container.read(insightsProvider); // resolve initial

      await db.into(db.transactions).insert(
        Transaction(
          id: 'tx-ins',
          accountId: null,
          categoryId: existingCategoryId,
          trackerId: trackerId,
          amount: 999000,
          type: 'expense',
          description: 'Huge expense',
          reference: 'REF-tx-ins',
          provider: 'M-Pesa_TZ',
          smsTimestamp: DateTime.now(),
          source: 'manual',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(
        container.read(insightsProvider).hasValue,
        isTrue,
        reason: 'insights must stay populated and refresh on new data',
      );
    });
  });

  group('settings-backed providers', () {
    test('monthly income updates when the setting changes', () async {
      watch(monthlyIncomeProvider);
      await container.read(monthlyIncomeProvider.future);
      expect(container.read(monthlyIncomeProvider).value, 0);

      await container
          .read(settingsRepositoryProvider)
          .setSetting('monthly_income', '4500000');

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(
        container.read(monthlyIncomeProvider).value,
        4500000,
        reason: 'monthly income must refresh immediately after being set',
      );
    });
  });

  group('spending pattern', () {
    test('recomputes when a transaction is added', () async {
      watch(currentSpendingPatternProvider);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      container.read(currentSpendingPatternProvider); // resolve initial

      final now = DateTime.now();
      await db.into(db.transactions).insert(
        Transaction(
          id: 'tx-pat',
          accountId: null,
          categoryId: existingCategoryId,
          trackerId: trackerId,
          amount: 42000,
          type: 'expense',
          description: 'Pattern txn',
          reference: 'REF-tx-pat',
          provider: 'M-Pesa_TZ',
          smsTimestamp: now,
          source: 'manual',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(
        container.read(currentSpendingPatternProvider).hasValue,
        isTrue,
        reason:
            'spending pattern previously watched nothing and never recomputed',
      );
    });
  });

  group('transaction detail', () {
    test('re-reads when the underlying transaction is edited', () async {
      await db.into(db.transactions).insert(
        Transaction(
          id: 'tx-detail',
          accountId: null,
          categoryId: existingCategoryId,
          trackerId: trackerId,
          amount: 1000,
          type: 'expense',
          description: 'Original',
          reference: 'REF-tx-detail',
          provider: 'M-Pesa_TZ',
          smsTimestamp: t0,
          source: 'manual',
          createdAt: t0,
          updatedAt: t0,
        ),
      );
      watch(transactionDetailProvider('tx-detail'));
      await container.read(transactionDetailProvider('tx-detail').future);
      expect(
        container.read(transactionDetailProvider('tx-detail')).value!
            .transaction
            .description,
        'Original',
      );

      await (db.update(db.transactions)
            ..where((t) => t.id.equals('tx-detail')))
          .write(const TransactionsCompanion(description: Value('Edited')));
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(
        container.read(transactionDetailProvider('tx-detail')).value!
            .transaction
            .description,
        'Edited',
        reason: 'an edit made elsewhere must show up without re-opening',
      );
    });
  });

  group('due recurring', () {
    test('re-evaluates when a recurring flow is added', () async {
      watch(dueRecurringTransactionsProvider);
      await container.read(dueRecurringTransactionsProvider.future);
      final before = container.read(dueRecurringTransactionsProvider).value!;

      await db.into(db.recurringTransactions).insert(
        RecurringTransaction(
          id: 'rec-1',
          trackerId: trackerId,
          accountId: 'no-account',
          categoryId: existingCategoryId,
          description: 'LUKU',
          amount: 50000,
          type: 'expense',
          frequency: 'monthly',
          intervalValue: 1,
          nextDate: DateTime.now().subtract(const Duration(days: 1)),
          status: 'active',
          totalPaid: 0,
          paymentCount: 0,
          createdAt: t0,
          updatedAt: t0,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        container.read(dueRecurringTransactionsProvider).value!.length,
        greaterThan(before.length),
        reason: 'a newly overdue flow must appear without a manual refresh',
      );
    });
  });
}
