import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import 'state_providers.dart';

class InsightData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  InsightData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

final dynamicInsightsProvider = FutureProvider<List<InsightData>>((ref) async {
  final totals = await ref.watch(monthlyTotalsProvider.future);
  final topCategories = await ref.watch(topCategoriesProvider.future);
  final budgets = await ref.watch(budgetProgressProvider.future);
  final monthlySnapshots = await ref.watch(monthlySnapshotsProvider.future);
  final savingsGoals = await ref.watch(savingsGoalsStreamProvider.future);

  final insights = <InsightData>[];
  final now = DateTime.now();

  // 1. Monthly spending trend: compare this month to last month
  final currentExpense = totals['expense'] ?? 0;
  if (monthlySnapshots.length >= 2) {
    final prevSnapshot = monthlySnapshots[monthlySnapshots.length - 2];
    final prevExpense = prevSnapshot.totalExpense;
    if (prevExpense > 0 && currentExpense > 0) {
      final changePct = ((currentExpense - prevExpense) / prevExpense * 100)
          .round();
      final increased = changePct > 0;
      insights.add(
        InsightData(
          title: increased ? 'Spending Up' : 'Spending Down',
          subtitle: increased
              ? 'Spending is $changePct% higher than last month'
              : 'Spending is ${-changePct}% lower than last month',
          icon: increased ? PesaFlowIcons.income : PesaFlowIcons.expense,
          color: increased ? const Color(0xFFFF453A) : const Color(0xFF34C759),
        ),
      );
    }
  } else if (currentExpense > 0 && monthlySnapshots.length == 1) {
    final prevSnapshot = monthlySnapshots[0];
    if (prevSnapshot.totalExpense > 0) {
      final changePct =
          ((currentExpense - prevSnapshot.totalExpense) /
                  prevSnapshot.totalExpense *
                  100)
              .round();
      final increased = changePct > 0;
      insights.add(
        InsightData(
          title: increased ? 'Spending Up' : 'Spending Down',
          subtitle: increased
              ? 'Spending is $changePct% higher than last month'
              : 'Spending is ${-changePct}% lower than last month',
          icon: increased ? PesaFlowIcons.income : PesaFlowIcons.expense,
          color: increased ? const Color(0xFFFF453A) : const Color(0xFF34C759),
        ),
      );
    }
  }

  // 2. Category breakdown: highest category this month
  if (topCategories.isNotEmpty) {
    final top = topCategories.first;
    insights.add(
      InsightData(
        title: 'Top Category: ${top.categoryName}',
        subtitle:
            'Tsh ${(top.amount ~/ 100).toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} spent this month',
        icon: Icons.category_rounded,
        color: const Color(0xFF0F4C5C),
      ),
    );
  }

  // 3. Budget status: most over / under
  if (budgets.isNotEmpty) {
    budgets.sort((a, b) => (a.percentage - b.percentage).sign.round());
    final worst = budgets.last;
    final pct = (worst.percentage * 100).round();
    final overBudget = pct > 100;
    insights.add(
      InsightData(
        title: '${overBudget ? 'Over' : 'Under'} Budget: ${worst.budget.name}',
        subtitle: overBudget
            ? '${pct - 100}% over the ${worst.budget.period} limit'
            : '${100 - pct}% remaining in the ${worst.budget.period} budget',
        icon: overBudget ? PesaFlowIcons.warning : PesaFlowIcons.success,
        color: overBudget ? const Color(0xFFFF453A) : const Color(0xFF34C759),
      ),
    );
  }

  // 4. Weekly average: average daily spending
  if (currentExpense > 0) {
    final dayOfMonth = now.day;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final effectiveDays = dayOfMonth.clamp(1, daysInMonth);
    final dailyAvg = currentExpense ~/ effectiveDays;
    final weeklyAvg = dailyAvg * 7;
    insights.add(
      InsightData(
        title: 'Weekly Average',
        subtitle:
            'Spending about Tsh ${(weeklyAvg ~/ 100).toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} per week',
        icon: Icons.calendar_view_week_rounded,
        color: const Color(0xFF0F4C5C),
      ),
    );
  }

  // 5. Savings progress: goal with highest completion
  if (savingsGoals.isNotEmpty) {
    SavingsGoal? bestGoal;
    double bestPct = 0;
    for (final goal in savingsGoals) {
      if (goal.targetAmount > 0) {
        final pct = goal.currentAmount / goal.targetAmount;
        if (pct > bestPct) {
          bestPct = pct;
          bestGoal = goal;
        }
      }
    }
    if (bestGoal != null) {
      final pctDisplay = (bestPct * 100).round();
      insights.add(
        InsightData(
          title: 'Savings: ${bestGoal.name}',
          subtitle: pctDisplay >= 100
              ? 'Goal completed! Tsh ${(bestGoal.currentAmount ~/ 100).toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} saved'
              : '$pctDisplay% complete — Tsh ${((bestGoal.targetAmount - bestGoal.currentAmount) ~/ 100).toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} to go',
          icon: PesaFlowIcons.savings,
          color: bestPct >= 1.0
              ? const Color(0xFF34C759)
              : const Color(0xFFFF9F0A),
        ),
      );
    }
  }

  return insights;
});
