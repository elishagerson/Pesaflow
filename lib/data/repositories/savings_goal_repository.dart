import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../database/daos/savings_goals_dao.dart';
import '../database/database_providers.dart';

final savingsGoalRepositoryProvider = Provider<SavingsGoalRepository>((ref) {
  final dao = ref.watch(savingsGoalsDaoProvider);
  return SavingsGoalRepository(dao);
});

class SavingsGoalRepository {
  final SavingsGoalsDao _savingsGoalsDao;
  static const _uuid = Uuid();

  SavingsGoalRepository(this._savingsGoalsDao);

  Stream<List<SavingsGoal>> watchAllSavingsGoals(String trackerId) =>
      _savingsGoalsDao.watchAllSavingsGoals(trackerId);

  Future<List<SavingsGoal>> getAllSavingsGoals(String trackerId) =>
      _savingsGoalsDao.getAllSavingsGoals(trackerId);

  Future<SavingsGoal?> getSavingsGoalById(String id) =>
      _savingsGoalsDao.getSavingsGoalById(id);

  Future<void> createSavingsGoal({
    required String name,
    required int targetAmount,
    required DateTime targetDate,
    required String color,
    required String icon,
    String? trackerId,
  }) async {
    final goal = SavingsGoal(
      id: _uuid.v4(),
      name: name,
      targetAmount: targetAmount,
      currentAmount: 0,
      targetDate: targetDate,
      color: color,
      icon: icon,
      trackerId: trackerId,
      isCompleted: false,
      createdAt: DateTime.now(),
    );
    await _savingsGoalsDao.insertSavingsGoal(goal);
  }

  Future<void> updateSavingsGoal(SavingsGoal goal) =>
      _savingsGoalsDao.updateSavingsGoal(goal);

  Future<void> deleteSavingsGoal(String id) =>
      _savingsGoalsDao.deleteSavingsGoal(id);

  Stream<List<SavingsGoalContribution>> watchContributions(
    String savingsGoalId,
  ) => _savingsGoalsDao.watchContributionsForGoal(savingsGoalId);

  Future<List<SavingsGoalContribution>> getContributions(
    String savingsGoalId,
  ) => _savingsGoalsDao.getContributionsForGoal(savingsGoalId);

  Future<void> addContribution({
    required String savingsGoalId,
    required int amount,
    String? notes,
  }) async {
    final contribution = SavingsGoalContribution(
      id: _uuid.v4(),
      savingsGoalId: savingsGoalId,
      amount: amount,
      notes: notes,
      createdAt: DateTime.now(),
    );
    await _savingsGoalsDao.addContribution(contribution);
  }

  Future<void> deleteContribution(String contributionId) =>
      _savingsGoalsDao.deleteContribution(contributionId);
}
