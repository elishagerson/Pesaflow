import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/savings_goals_table.dart';
import '../tables/savings_goal_contributions_table.dart';

part 'savings_goals_dao.g.dart';

@DriftAccessor(tables: [SavingsGoals, SavingsGoalContributions])
class SavingsGoalsDao extends DatabaseAccessor<AppDatabase>
    with _$SavingsGoalsDaoMixin {
  SavingsGoalsDao(super.db);

  Stream<List<SavingsGoal>> watchAllSavingsGoals(String trackerId) {
    return (select(savingsGoals)
          ..where((t) => t.trackerId.equals(trackerId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<List<SavingsGoal>> getAllSavingsGoals(String trackerId) {
    return (select(savingsGoals)
          ..where((t) => t.trackerId.equals(trackerId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Future<SavingsGoal?> getSavingsGoalById(String id) {
    return (select(
      savingsGoals,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertSavingsGoal(SavingsGoal goal) =>
      into(savingsGoals).insert(goal);

  Future<bool> updateSavingsGoal(SavingsGoal goal) =>
      update(savingsGoals).replace(goal);

  Future<void> deleteSavingsGoal(String id) async {
    await transaction(() async {
      // Delete all contributions linked to this goal
      await (delete(
        savingsGoalContributions,
      )..where((t) => t.savingsGoalId.equals(id))).go();
      // Delete the goal itself
      await (delete(savingsGoals)..where((t) => t.id.equals(id))).go();
    });
  }

  Stream<List<SavingsGoalContribution>> watchContributionsForGoal(
    String savingsGoalId,
  ) {
    return (select(savingsGoalContributions)
          ..where((t) => t.savingsGoalId.equals(savingsGoalId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<List<SavingsGoalContribution>> getContributionsForGoal(
    String savingsGoalId,
  ) {
    return (select(savingsGoalContributions)
          ..where((t) => t.savingsGoalId.equals(savingsGoalId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  /// Adds a contribution and atomically updates the savings goal current balance & status
  Future<void> addContribution(SavingsGoalContribution contribution) async {
    await transaction(() async {
      await into(savingsGoalContributions).insert(contribution);
      final goal =
          await (select(savingsGoals)
                ..where((t) => t.id.equals(contribution.savingsGoalId)))
              .getSingleOrNull();
      if (goal == null) return;
      final newAmount = goal.currentAmount + contribution.amount;
      final isCompleted = newAmount >= goal.targetAmount;

      await (update(savingsGoals)..where((t) => t.id.equals(goal.id))).write(
        SavingsGoalsCompanion(
          currentAmount: Value(newAmount),
          isCompleted: Value(isCompleted),
        ),
      );
    });
  }

  /// Deletes a contribution and atomically updates the savings goal current balance & status
  Future<void> deleteContribution(String contributionId) async {
    await transaction(() async {
      final contribution = await (select(
        savingsGoalContributions,
      )..where((t) => t.id.equals(contributionId))).getSingleOrNull();
      if (contribution == null) return;
      await (delete(
        savingsGoalContributions,
      )..where((t) => t.id.equals(contributionId))).go();
      final goal =
          await (select(savingsGoals)
                ..where((t) => t.id.equals(contribution.savingsGoalId)))
              .getSingleOrNull();
      if (goal == null) return;
      final newAmount = goal.currentAmount - contribution.amount;
      final isCompleted = newAmount >= goal.targetAmount;

      await (update(savingsGoals)..where((t) => t.id.equals(goal.id))).write(
        SavingsGoalsCompanion(
          currentAmount: Value(newAmount),
          isCompleted: Value(isCompleted),
        ),
      );
    });
  }
}
