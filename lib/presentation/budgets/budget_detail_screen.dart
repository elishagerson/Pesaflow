import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/budget_dao.dart';
import 'package:pesaflow/data/repositories/budget_repository.dart';
import 'package:pesaflow/domain/budget/budget_engine.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

/// Provider for loading a specific budget's full data.
final budgetDetailProvider = FutureProvider.family<BudgetWithProgress?, String>((ref, budgetId) async {
  final repo = ref.watch(budgetRepositoryProvider);
  final budget = await repo.getBudgetById(budgetId);
  if (budget == null) return null;
  final allProgress = await repo.getActiveBudgetsWithProgress();
  return allProgress.where((b) => b.budget.id == budgetId).firstOrNull;
});

final budgetPeriodsProvider = FutureProvider.family<List<BudgetPeriod>, String>((ref, budgetId) {
  final repo = ref.watch(budgetRepositoryProvider);
  return repo.getPeriodsForBudget(budgetId);
});

final dailySpendProvider = FutureProvider.family<List<MapEntry<DateTime, int>>, String>((ref, budgetId) async {
  final repo = ref.watch(budgetRepositoryProvider);
  final budget = await repo.getBudgetById(budgetId);
  if (budget == null) return [];
  final currentPeriod = await repo.getCurrentPeriod(budgetId);
  if (currentPeriod == null) return [];
  return repo.getDailySpendForBudget(budgetId, currentPeriod.periodStart, currentPeriod.periodEnd);
});

class BudgetDetailScreen extends ConsumerWidget {
  final String budgetId;
  const BudgetDetailScreen({required this.budgetId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(budgetDetailProvider(budgetId));
    final periodsAsync = ref.watch(budgetPeriodsProvider(budgetId));
    final dailyAsync = ref.watch(dailySpendProvider(budgetId));
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: detailAsync.when(
        data: (bp) {
          if (bp == null) return const Center(child: Text('Budget not found'));
          final status = BudgetEngine.computeStatus(
            allocated: bp.currentPeriod?.allocated ?? bp.budget.amount,
            spent: bp.spentInPeriod,
            periodStart: bp.currentPeriod?.periodStart ?? bp.budget.startDate,
            periodEnd: bp.currentPeriod?.periodEnd ?? DateTime.now().add(const Duration(days: 30)),
          );
          final catColor = hexToColor(bp.category.color);

          return Column(
            children: [
              IosNavBar(
                title: bp.budget.name,
                largeTitle: false,
                leading: IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () => context.go('/budgets/$budgetId/edit')),
                  IconButton(
                    icon: const Icon(Icons.delete_rounded),
                    onPressed: () async {
                      final confirm = await ModernDialog.show<bool>(
                        context: context,
                        title: const Text('Delete Budget?'),
                        titleIcon: Icons.delete_forever_rounded,
                        iconColor: Colors.red,
                        content: const Text('This will permanently remove this budget and all its history.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      );
                      if (confirm == true) {
                        await ref.read(budgetRepositoryProvider).deleteBudget(budgetId);
                        ref.invalidate(budgetProgressProvider);
                        if (context.mounted) context.pop();
                      }
                    },
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Radial ring chart
                StaggeredFadeSlide(
                  index: 0,
                  child: Center(
                    child: SizedBox(
                      height: 200, width: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(PieChartData(
                            startDegreeOffset: -90,
                            sectionsSpace: 0,
                            centerSpaceRadius: 70,
                            sections: [
                              PieChartSectionData(value: status.percentage.clamp(0.0, 1.0) * 100, color: status.isOverBudget ? theme.colorScheme.error : catColor, radius: 20, showTitle: false),
                              PieChartSectionData(value: (1.0 - status.percentage.clamp(0.0, 1.0)) * 100, color: catColor.withValues(alpha: 0.15), radius: 20, showTitle: false),
                            ],
                          )),
                          Column(mainAxisSize: MainAxisSize.min, children: [
                            Text('${(status.percentage * 100).round()}%', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                            Text('used', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Stats row
                StaggeredFadeSlide(
                  index: 1,
                  child: Row(children: [
                    Expanded(child: _StatCard(label: 'Spent', amount: bp.spentInPeriod, color: status.isOverBudget ? theme.colorScheme.error : catColor, theme: theme)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(label: 'Remaining', amount: status.remaining, color: status.remaining >= 0 ? theme.colorScheme.primary : theme.colorScheme.error, theme: theme)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(label: 'Allocated', amount: status.allocated, color: theme.colorScheme.primary, theme: theme)),
                  ]),
                ),
                const SizedBox(height: 20),

                // Pace card
                StaggeredFadeSlide(
                  index: 2,
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    frosted: false,
                    child: Row(children: [
                      Icon(
                        status.isOnTrack ? Icons.check_circle_rounded : Icons.warning_rounded,
                        color: status.isOnTrack ? theme.colorScheme.primary : Colors.orange,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(status.paceLabel, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        Text('${status.daysLeft} days remaining in this period', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                        if (!status.isOnTrack && !status.isOverBudget && status.daysLeft > 0 && status.percentage > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _projectedOverspendDate(status),
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ])),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),

                // Daily spend bar chart
                dailyAsync.when(
                  data: (dailyData) {
                    if (dailyData.isEmpty) return const SizedBox.shrink();
                    final maxAmount = dailyData.map((e) => e.value).reduce((a, b) => a > b ? a : b);
                    return StaggeredFadeSlide(
                      index: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Daily Spend', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 120,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: maxAmount * 1.2,
                                barTouchData: BarTouchData(enabled: false),
                                titlesData: FlTitlesData(
                                  show: true,
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text('${value.toInt()}', style: const TextStyle(fontSize: 9)),
                                        );
                                      },
                                      reservedSize: 20,
                                    ),
                                  ),
                                ),
                                gridData: FlGridData(
                                  show: true,
                                  horizontalInterval: maxAmount / 4,
                                  drawVerticalLine: false,
                                  getDrawingHorizontalLine: (value) => FlLine(
                                    color: Colors.grey.withValues(alpha: 0.2),
                                    strokeWidth: 0.5,
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: dailyData.map((entry) {
                                  return BarChartGroupData(
                                    x: entry.key.day,
                                    barRods: [
                                      BarChartRodData(
                                        toY: entry.value.toDouble(),
                                        color: catColor,
                                        width: 8,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(4),
                                          topRight: Radius.circular(4),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),

                // Previous period comparison
                _buildPeriodComparison(periodsAsync, bp, theme),
                const SizedBox(height: 24),

                // Period info
                StaggeredFadeSlide(
                  index: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Period: ${bp.budget.period}', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                      Text('Rollover: ${bp.budget.rollover ? bp.budget.rolloverType : "disabled"}', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Historical Periods
                StaggeredFadeSlide(
                  index: 6,
                  child: Text('Period History', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                periodsAsync.when(
                  data: (periods) => Column(
                    children: periods.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final p = entry.value;
                      final pctUsed = p.allocated > 0 ? (p.spent / p.allocated * 100).round() : 0;
                      return StaggeredFadeSlide(
                        index: 7 + idx,
                        child: GlassCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          borderRadius: 8,
                          frosted: false,
                          child: Row(children: [
                            Icon(p.isClosed ? Icons.lock_rounded : Icons.lock_open_rounded, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${p.periodStart.day}/${p.periodStart.month} — ${p.periodEnd.day}/${p.periodEnd.month}/${p.periodEnd.year}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('$pctUsed% used${p.rolledFrom != null && p.rolledFrom != 0 ? " • Rolled: Tsh ${p.rolledFrom! ~/ 100}" : ""}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ])),
                            AmountText(amountInCents: p.spent, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                ),
              ],
            ),
          ),
      ),
    ],
  );
},
loading: () => const Center(child: CircularProgressIndicator()),
error: (e, _) => Center(child: Text('Error: $e')),
),
    ));
  }

  String _projectedOverspendDate(BudgetStatus status) {
    final daysElapsed = status.totalDays - status.daysLeft;
    if (daysElapsed <= 0 || status.spent <= 0) return '';
    final dailyRate = status.spent / daysElapsed;
    if (dailyRate <= 0) return '';
    final remaining = status.remaining;
    final daysUntilExhaustion = remaining / dailyRate;
    if (daysUntilExhaustion <= 0) return '';
    final projectedDate = DateTime.now().add(Duration(days: daysUntilExhaustion.ceil()));
    return 'Projected to overspend on ${projectedDate.day}/${projectedDate.month}/${projectedDate.year}';
  }

  Widget _buildPeriodComparison(AsyncValue<List<BudgetPeriod>> periodsAsync, BudgetWithProgress bp, ThemeData theme) {
    return periodsAsync.when(
      data: (periods) {
        final closed = periods.where((p) => p.isClosed).toList()
          ..sort((a, b) => b.periodStart.compareTo(a.periodStart));
        if (closed.length < 2) return const SizedBox.shrink();
        final prev = closed[1];
        if (prev.spent <= 0) return const SizedBox.shrink();
        final diff = ((bp.spentInPeriod - prev.spent) / prev.spent * 100);
        return StaggeredFadeSlide(
          index: 4,
          child: Row(
            children: [
              Icon(
                diff > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 14,
                color: diff > 0 ? Colors.orange : theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                '${diff.abs().round()}% ${diff > 0 ? 'higher' : 'lower'} than last period',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: diff > 0 ? Colors.orange : theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final ThemeData theme;
  const _StatCard({required this.label, required this.amount, required this.color, required this.theme});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      frosted: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        AmountText(amountInCents: amount.abs(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: color, letterSpacing: -0.3)),
      ]),
    );
  }
}
