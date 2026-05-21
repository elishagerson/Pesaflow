import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/analytics_dao.dart';
import 'package:pesaflow/domain/analytics/insight_generator.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analytics'),
          bottom: TabBar(
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorColor: theme.colorScheme.primary,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Trends'),
              Tab(text: 'Insights'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(theme: theme, ref: ref, hexToColor: _hexToColor),
            _TrendsTab(theme: theme, ref: ref),
            _InsightsTab(theme: theme, ref: ref),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final ThemeData theme;
  final WidgetRef ref;
  final Color Function(String) hexToColor;
  const _OverviewTab({required this.theme, required this.ref, required this.hexToColor});

  @override
  Widget build(BuildContext context) {
    final totalsAsync = ref.watch(monthlyTotalsProvider);
    final categoriesAsync = ref.watch(topCategoriesProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Monthly Summary
          totalsAsync.when(
            data: (totals) {
              final income = totals['income'] ?? 0;
              final expense = totals['expense'] ?? 0;
              final net = income - expense;
              final savingsRate = income > 0 ? ((net / income) * 100).round() : 0;
              return Container(
                width: double.infinity, padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('THIS MONTH', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Income', style: TextStyle(color: Colors.white60, fontSize: 12)),
                      AmountText(amountInCents: income, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    ])),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const Text('Expense', style: TextStyle(color: Colors.white60, fontSize: 12)),
                      AmountText(amountInCents: expense, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    ])),
                  ]),
                  const SizedBox(height: 12),
                  Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(net >= 0 ? 'Net Savings' : 'Net Deficit', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    AmountText(amountInCents: net.abs(), type: net >= 0 ? AmountType.income : AmountType.expense, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ]),
                  const SizedBox(height: 4),
                  Text('Savings rate: $savingsRate%', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ]),
              );
            },
            loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 24),

          // Category Donut
          Text('Top Spending Categories', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          categoriesAsync.when(
            data: (cats) {
              if (cats.isEmpty) return const Center(child: Text('No spending data yet', style: TextStyle(color: Colors.grey)));
              final total = cats.fold<int>(0, (s, c) => s + c.amount);
              final colors = [const Color(0xFF006B4F), const Color(0xFFFF9800), const Color(0xFF2196F3), const Color(0xFF9C27B0), const Color(0xFFF44336)];
              return Row(children: [
                SizedBox(
                  height: 160, width: 160,
                  child: PieChart(PieChartData(
                    sectionsSpace: 2, centerSpaceRadius: 45,
                    sections: List.generate(cats.length, (i) => PieChartSectionData(
                      value: cats[i].amount.toDouble(), color: i < colors.length ? colors[i] : hexToColor(cats[i].categoryColor),
                      radius: 25, showTitle: false,
                    )),
                  )),
                ),
                const SizedBox(width: 20),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: List.generate(cats.length, (i) {
                  final pct = total > 0 ? (cats[i].amount / total * 100).round() : 0;
                  return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: i < colors.length ? colors[i] : hexToColor(cats[i].categoryColor), shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(cats[i].categoryName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                    Text('$pct%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ]));
                }))),
              ]);
            },
            loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _TrendsTab extends StatelessWidget {
  final ThemeData theme;
  final WidgetRef ref;
  const _TrendsTab({required this.theme, required this.ref});

  @override
  Widget build(BuildContext context) {
    final snapshotsAsync = ref.watch(monthlySnapshotsProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Income vs Expense', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Last 12 months', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          snapshotsAsync.when(
            data: (snapshots) {
              if (snapshots.isEmpty) return const SizedBox(height: 200, child: Center(child: Text('No data yet', style: TextStyle(color: Colors.grey))));
              final reversed = snapshots.reversed.toList();
              return SizedBox(
                height: 250,
                child: BarChart(BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: reversed.fold<double>(0, (m, s) => [s.totalIncome.toDouble(), s.totalExpense.toDouble(), m].reduce((a, b) => a > b ? a : b)) * 1.2 / 100,
                  barGroups: List.generate(reversed.length, (i) => BarChartGroupData(x: i, barRods: [
                    BarChartRodData(toY: reversed[i].totalIncome / 100, color: AppTheme.incomeColor, width: 8, borderRadius: BorderRadius.circular(4)),
                    BarChartRodData(toY: reversed[i].totalExpense / 100, color: AppTheme.expenseColor, width: 8, borderRadius: BorderRadius.circular(4)),
                  ])),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, _) {
                      final idx = val.toInt();
                      if (idx < 0 || idx >= reversed.length) return const SizedBox();
                      final ym = reversed[idx].yearMonth;
                      return Padding(padding: const EdgeInsets.only(top: 4), child: Text(ym.substring(5), style: const TextStyle(fontSize: 10)));
                    })),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                )),
              );
            },
            loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 16),
          // Legend
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: AppTheme.incomeColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 4), const Text('Income', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 16),
            Container(width: 12, height: 12, decoration: BoxDecoration(color: AppTheme.expenseColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 4), const Text('Expense', style: TextStyle(fontSize: 12)),
          ]),
        ],
      ),
    );
  }
}

class _InsightsTab extends StatelessWidget {
  final ThemeData theme;
  final WidgetRef ref;
  const _InsightsTab({required this.theme, required this.ref});

  IconData _getInsightIcon(String iconName) {
    switch (iconName) {
      case 'trending_up': return Icons.trending_up_rounded;
      case 'trending_down': return Icons.trending_down_rounded;
      case 'savings': return Icons.savings_rounded;
      case 'arrow_upward': return Icons.arrow_upward_rounded;
      case 'arrow_downward': return Icons.arrow_downward_rounded;
      case 'account_balance_wallet': return Icons.account_balance_wallet_rounded;
      case 'category': return Icons.category_rounded;
      default: return Icons.lightbulb_rounded;
    }
  }

  Color _getSeverityColor(InsightSeverity severity) {
    switch (severity) {
      case InsightSeverity.positive: return AppTheme.incomeColor;
      case InsightSeverity.warning: return Colors.orange;
      case InsightSeverity.critical: return AppTheme.expenseColor;
      case InsightSeverity.neutral: return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final insightsAsync = ref.watch(insightsProvider);
    return insightsAsync.when(
      data: (insights) {
        if (insights.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.lightbulb_outline_rounded, size: 48, color: Colors.grey), SizedBox(height: 16), Text('No insights yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), SizedBox(height: 8), Text('Insights will appear after you have transactions recorded.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))])));
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: insights.length,
          itemBuilder: (context, index) {
            final insight = insights[index];
            final color = _getSeverityColor(insight.severity);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark ? AppTheme.surfaceContainerDark : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(_getInsightIcon(insight.icon), color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(insight.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(insight.message, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ])),
              ]),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
