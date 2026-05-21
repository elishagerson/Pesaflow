import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/analytics_repository.dart';

final insightGeneratorProvider = Provider<InsightGenerator>((ref) {
  final repo = ref.watch(analyticsRepositoryProvider);
  return InsightGenerator(repo);
});

/// On-device insight engine generating financial observations.
class InsightGenerator {
  final AnalyticsRepository _analyticsRepository;

  InsightGenerator(this._analyticsRepository);

  /// Generates insights for the current month.
  Future<List<Insight>> generateInsights() async {
    final insights = <Insight>[];
    final now = DateTime.now();

    try {
      // Current month totals
      final currentTotals = await _analyticsRepository.getMonthTotals(now);
      final currentIncome = currentTotals['income'] ?? 0;
      final currentExpense = currentTotals['expense'] ?? 0;

      // Previous month totals
      final prevMonth = DateTime(now.year, now.month - 1, 1);
      final prevTotals = await _analyticsRepository.getMonthTotals(prevMonth);
      final prevIncome = prevTotals['income'] ?? 0;
      final prevExpense = prevTotals['expense'] ?? 0;

      // 1. Net Cashflow Insight
      if (currentIncome > 0 || currentExpense > 0) {
        final netCashflow = currentIncome - currentExpense;
        final isPositive = netCashflow >= 0;
        insights.add(Insight(
          type: InsightType.netCashflow,
          title: isPositive ? 'Positive Cash Flow' : 'Negative Cash Flow',
          message: isPositive
              ? 'You\'ve saved Tsh ${_formatAmount(netCashflow)} this month so far.'
              : 'You\'ve spent Tsh ${_formatAmount(-netCashflow)} more than earned this month.',
          severity: isPositive ? InsightSeverity.positive : InsightSeverity.warning,
          icon: isPositive ? 'trending_up' : 'trending_down',
        ));
      }

      // 2. Savings Rate
      if (currentIncome > 0) {
        final savingsRate = ((currentIncome - currentExpense) / currentIncome * 100).round();
        String message;
        InsightSeverity severity;
        if (savingsRate >= 20) {
          message = 'Savings rate: $savingsRate%. Excellent discipline!';
          severity = InsightSeverity.positive;
        } else if (savingsRate >= 10) {
          message = 'Savings rate: $savingsRate%. Aim for 20% to build stronger reserves.';
          severity = InsightSeverity.neutral;
        } else {
          message = 'Savings rate: $savingsRate%. Consider reducing discretionary spending.';
          severity = InsightSeverity.warning;
        }
        insights.add(Insight(
          type: InsightType.savingsRate,
          title: 'Savings Rate',
          message: message,
          severity: severity,
          icon: 'savings',
        ));
      }

      // 3. Month-over-Month Spending Comparison
      if (prevExpense > 0 && currentExpense > 0) {
        final changePercent = ((currentExpense - prevExpense) / prevExpense * 100).round();
        if (changePercent.abs() > 5) {
          final increased = changePercent > 0;
          insights.add(Insight(
            type: InsightType.spendingTrend,
            title: increased ? 'Spending Up' : 'Spending Down',
            message: increased
                ? 'Spending is ${changePercent}% higher than last month.'
                : 'Spending is ${-changePercent}% lower than last month. Great work!',
            severity: increased ? InsightSeverity.warning : InsightSeverity.positive,
            icon: increased ? 'arrow_upward' : 'arrow_downward',
          ));
        }
      }

      // 4. Income Consistency
      if (prevIncome > 0 && currentIncome > 0) {
        final incomeChange = ((currentIncome - prevIncome) / prevIncome * 100).round();
        if (incomeChange.abs() > 10) {
          insights.add(Insight(
            type: InsightType.incomeConsistency,
            title: incomeChange > 0 ? 'Income Increase' : 'Income Decrease',
            message: incomeChange > 0
                ? 'Income is ${incomeChange}% higher than last month.'
                : 'Income dropped by ${-incomeChange}% compared to last month.',
            severity: incomeChange > 0 ? InsightSeverity.positive : InsightSeverity.warning,
            icon: 'account_balance_wallet',
          ));
        }
      }

      // 5. Top Spending Categories
      final topCategories = await _analyticsRepository.getTopCategoriesForMonth(now, limit: 3);
      if (topCategories.isNotEmpty) {
        final top = topCategories.first;
        insights.add(Insight(
          type: InsightType.topCategory,
          title: 'Top Spending: ${top.categoryName}',
          message: 'Tsh ${_formatAmount(top.amount)} spent on ${top.categoryName} this month.',
          severity: InsightSeverity.neutral,
          icon: 'category',
        ));
      }
    } catch (_) {
      // Silently handle errors — insights are non-critical
    }

    return insights;
  }

  String _formatAmount(int cents) {
    final whole = cents ~/ 100;
    if (whole >= 1000) {
      final formatted = whole.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
      );
      return formatted;
    }
    return whole.toString();
  }
}

class Insight {
  final InsightType type;
  final String title;
  final String message;
  final InsightSeverity severity;
  final String icon;

  const Insight({
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
    required this.icon,
  });
}

enum InsightType {
  netCashflow,
  savingsRate,
  spendingTrend,
  incomeConsistency,
  topCategory,
  anomaly,
  budgetForecast,
}

enum InsightSeverity {
  positive,
  neutral,
  warning,
  critical,
}
