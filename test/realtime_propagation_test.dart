import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/database_providers.dart';
import 'package:pesaflow/data/repositories/savings_goal_repository.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

/// These tests exercise the REAL providers against a REAL database. They exist
/// because the widget tests override providers with `Stream.value(...)`, which
/// mocks away the very reactivity that was broken in production.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  final closers = <void Function()>[];

  /// Keeps a live subscription so StreamProviders actually recompute.
  /// `container.read(...)` alone does not subscribe, which would make
  /// reactive providers look frozen and produce false failures.
  void watch(dynamic provider) {
    closers.add(container.listen<dynamic>(provider, (_, _) {}).close);
  }

  const trackerId = 'default_personal';

  final t0 = DateTime(2026, 4, 1, 9);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
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

  /// Records every value a provider emits so we can assert on propagation.
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
      // Seed one row and let the provider resolve.
      watch(categoriesFutureProvider);
      await db.into(db.categories).insert(cat('c1', 'ZZ Food'));
      final first = await container.read(categoriesFutureProvider.future);
      expect(first.map((c) => c.name), contains('ZZ Food'));

      // Now insert another row the way the rest of the app would.
      await db.into(db.categories).insert(cat('c2', 'ZZ Transport'));

      // Give any stream/rebuild a chance to propagate.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final second = await container.read(categoriesFutureProvider.future);
      expect(
        second.map((c) => c.name),
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
}
