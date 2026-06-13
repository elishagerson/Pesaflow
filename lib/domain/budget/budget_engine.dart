import 'package:pesaflow/data/database/daos/budget_dao.dart';

/// Budget computation engine for envelope-style budget management.
class BudgetEngine {
  /// Computes the budget status for a given period.
  static BudgetStatus computeStatus({
    required int allocated,
    required int spent,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    final remaining = allocated - spent;
    final percentage = allocated > 0 ? (spent / allocated) : 0.0;
    final now = DateTime.now();
    final totalDays = periodEnd.difference(periodStart).inDays;
    final daysElapsed = now.difference(periodStart).inDays;
    final daysLeft = periodEnd.difference(now).inDays.clamp(0, totalDays);

    // Daily pace projection
    double projectedSpend = 0;
    if (daysElapsed > 0) {
      final dailyRate = spent / daysElapsed;
      projectedSpend = dailyRate * totalDays;
    }

    final isOverBudget = spent > allocated;
    final isOnTrack = projectedSpend <= allocated;

    String paceLabel;
    if (isOverBudget) {
      paceLabel = 'Over budget';
    } else if (isOnTrack) {
      paceLabel = 'On track';
    } else {
      paceLabel = 'Over pace';
    }

    return BudgetStatus(
      allocated: allocated,
      spent: spent,
      remaining: remaining,
      percentage: percentage,
      daysLeft: daysLeft,
      totalDays: totalDays,
      projectedSpend: projectedSpend.round(),
      isOverBudget: isOverBudget,
      isOnTrack: isOnTrack,
      paceLabel: paceLabel,
    );
  }

  /// Computes the rollover amount when closing a period.
  static int computeRollover({
    required int allocated,
    required int spent,
    required String rolloverType,
    int? rolloverCap,
  }) {
    final remaining = allocated - spent;

    switch (rolloverType) {
      case 'all':
        return remaining; // Can be negative (deficit carry-forward)
      case 'capped':
        if (remaining > 0) {
          return rolloverCap != null ? remaining.clamp(0, rolloverCap) : remaining;
        }
        return remaining; // Carry deficit even when capped
      case 'none':
      default:
        return 0;
    }
  }

  /// Checks if the budget has crossed any notification thresholds.
  static List<BudgetAlert> checkThresholds({
    required double percentage,
    required double notificationThreshold,
  }) {
    final alerts = <BudgetAlert>[];

    if (percentage > 1.0) {
      alerts.add(BudgetAlert.exceeded);
    } else if (percentage >= 1.0) {
      alerts.add(BudgetAlert.reached);
    } else if (percentage >= notificationThreshold) {
      alerts.add(BudgetAlert.warning);
    } else if (percentage >= 0.5) {
      alerts.add(BudgetAlert.halfway);
    }

    return alerts;
  }

  /// Analyzes a list of budgets and returns categorized alert results.
  static BudgetThresholdResult checkBudgetThresholds(List<BudgetWithProgress> budgets) {
    final crossedThreshold = <String>[];
    final exceeded = <String>[];
    final projectedToExceed = <String>[];

    for (final bp in budgets) {
      if (bp.currentPeriod == null) continue;

      final status = computeStatus(
        allocated: bp.currentPeriod!.allocated,
        spent: bp.spentInPeriod,
        periodStart: bp.currentPeriod!.periodStart,
        periodEnd: bp.currentPeriod!.periodEnd,
      );

      final threshold = bp.budget.notificationThreshold;

      if (status.percentage >= 1.0 && status.spent > status.allocated) {
        exceeded.add(bp.budget.id);
      } else if (status.percentage >= threshold) {
        crossedThreshold.add(bp.budget.id);
      }

      if (!status.isOnTrack && !status.isOverBudget) {
        projectedToExceed.add(bp.budget.id);
      }
    }

    return BudgetThresholdResult(
      crossedThreshold: crossedThreshold,
      exceeded: exceeded,
      projectedToExceed: projectedToExceed,
    );
  }
}

/// Result of threshold checking across multiple budgets.
class BudgetThresholdResult {
  final List<String> crossedThreshold;
  final List<String> exceeded;
  final List<String> projectedToExceed;

  const BudgetThresholdResult({
    required this.crossedThreshold,
    required this.exceeded,
    required this.projectedToExceed,
  });
}

class BudgetStatus {
  final int allocated;
  final int spent;
  final int remaining;
  final double percentage;
  final int daysLeft;
  final int totalDays;
  final int projectedSpend;
  final bool isOverBudget;
  final bool isOnTrack;
  final String paceLabel;

  const BudgetStatus({
    required this.allocated,
    required this.spent,
    required this.remaining,
    required this.percentage,
    required this.daysLeft,
    required this.totalDays,
    required this.projectedSpend,
    required this.isOverBudget,
    required this.isOnTrack,
    required this.paceLabel,
  });
}

enum BudgetAlert {
  halfway,   // 50%
  warning,   // threshold (default 80%)
  reached,   // 100%
  exceeded,  // >100%
}
