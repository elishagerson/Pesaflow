import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/budget_dao.dart';
import 'package:pesaflow/data/repositories/budget_repository.dart';
import 'package:pesaflow/domain/budget/budget_engine.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/empty_state.dart';
import 'package:pesaflow/presentation/common/widgets/error_state.dart';
import 'package:pesaflow/presentation/common/widgets/undo_delete.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';

/// Provider for loading a specific budget's full data.
final budgetDetailProvider = FutureProvider.family<BudgetWithProgress?, String>(
  (ref, budgetId) async {
    final repo = ref.watch(budgetRepositoryProvider);
    final budget = await repo.getBudgetById(budgetId);
    if (budget == null) return null;
    final allProgress = await repo.getActiveBudgetsWithProgress();
    return allProgress.where((b) => b.budget.id == budgetId).firstOrNull;
  },
);

final budgetPeriodsProvider = FutureProvider.family<List<BudgetPeriod>, String>(
  (ref, budgetId) {
    final repo = ref.watch(budgetRepositoryProvider);
    return repo.getPeriodsForBudget(budgetId);
  },
);

final dailySpendProvider =
    FutureProvider.family<List<MapEntry<DateTime, int>>, String>((
      ref,
      budgetId,
    ) async {
      final repo = ref.watch(budgetRepositoryProvider);
      final budget = await repo.getBudgetById(budgetId);
      if (budget == null) return [];
      final currentPeriod = await repo.getCurrentPeriod(budgetId);
      if (currentPeriod == null) return [];
      return repo.getDailySpendForBudget(
        budgetId,
        currentPeriod.periodStart,
        currentPeriod.periodEnd,
      );
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
            if (bp == null) {
              return Scaffold(
                appBar: const IosNavBar(
                  title: 'Budget Details',
                  largeTitle: false,
                ),
                body: EmptyState(
                  icon: PesaFlowIcons.budgets,
                  title: 'Budget Not Found',
                  subtitle:
                      'The requested envelope budget could not be located.',
                ),
              );
            }
            final status = BudgetEngine.computeStatus(
              allocated: bp.currentPeriod?.allocated ?? bp.budget.amount,
              spent: bp.spentInPeriod,
              periodStart: bp.currentPeriod?.periodStart ?? bp.budget.startDate,
              periodEnd:
                  bp.currentPeriod?.periodEnd ??
                  DateTime.now().add(const Duration(days: 30)),
            );
            final catColor = hexToColor(bp.category.color);
            final mutedCatColor = desaturateColor(catColor);

            return Column(
              children: [
                IosNavBar(
                  title: bp.budget.name,
                  largeTitle: false,
                  actions: [
                    IconButton(
                      icon: const Icon(PesaFlowIcons.edit),
                      onPressed: () => context.push('/budgets/$budgetId/edit'),
                    ),
                    IconButton(
                      icon: const Icon(PesaFlowIcons.delete),
                      onPressed: () async {
                        final confirm = await ModernDialog.show<bool>(
                          context: context,
                          title: const Text('Delete Budget?'),
                          titleIcon: PesaFlowIcons.delete,
                          iconColor: Colors.red,
                          content: const Text(
                            'This will permanently remove this budget and all its history.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(
                                context,
                                rootNavigator: true,
                              ).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(
                                context,
                                rootNavigator: true,
                              ).pop(true),
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        );
                        if (confirm == true) {
                          if (!context.mounted) return;
                          final budget = bp.budget;
                          final savedBudgetName = budget.name;
                          await UndoDelete.show(
                            context: context,
                            entityName: 'Budget',
                            message: '"$savedBudgetName" deleted',
                            onUndo: () async {
                              await ref
                                  .read(budgetRepositoryProvider)
                                  .createBudget(
                                    name: budget.name,
                                    categoryId: budget.categoryId,
                                    period: budget.period,
                                    amount: budget.amount,
                                    rollover: budget.rollover,
                                    rolloverType: budget.rolloverType,
                                    rolloverCap: budget.rolloverCap,
                                    startDate: budget.startDate,
                                    notificationThreshold:
                                        budget.notificationThreshold,
                                  );
                            },
                            onDelete: () async {
                              await ref
                                  .read(budgetRepositoryProvider)
                                  .deleteBudget(budgetId);
                              if (context.mounted) context.pop();
                            },
                          );
                        }
                      },
                    ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(kSpacing16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Radial ring chart
                        StaggeredFadeSlide(
                          index: 0,
                          child: Hero(
                            tag: 'budget-$budgetId',
                            child: Center(
                              child: SizedBox(
                                height: 200,
                                width: 200,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    PieChart(
                                      PieChartData(
                                        startDegreeOffset: -90,
                                        sectionsSpace: 0,
                                        centerSpaceRadius: 70,
                                        sections: [
                                          PieChartSectionData(
                                            value:
                                                status.percentage.clamp(
                                                  0.0,
                                                  1.0,
                                                ) *
                                                100,
                                            color: status.isOverBudget
                                                ? theme.colorScheme.error
                                                : mutedCatColor,
                                            radius: 20,
                                            showTitle: false,
                                          ),
                                          PieChartSectionData(
                                            value:
                                                (1.0 -
                                                    status.percentage.clamp(
                                                      0.0,
                                                      1.0,
                                                    )) *
                                                100,
                                            color: mutedCatColor.withValues(
                                              alpha: 0.15,
                                            ),
                                            radius: 20,
                                            showTitle: false,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${(status.percentage * 100).round()}%',
                                          style: theme.textTheme.headlineMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        Text(
                                          'used',
                                          style: TextStyle(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: kSpacing24),

                        // Stats row
                        StaggeredFadeSlide(
                          index: 1,
                          child: Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  label: 'Spent',
                                  amount: bp.spentInPeriod,
                                  color: status.isOverBudget
                                      ? theme.colorScheme.error
                                      : catColor,
                                  theme: theme,
                                ),
                              ),
                              const SizedBox(width: kSpacing12),
                              Expanded(
                                child: _StatCard(
                                  label: 'Remaining',
                                  amount: status.remaining,
                                  color: status.remaining >= 0
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.error,
                                  theme: theme,
                                ),
                              ),
                              const SizedBox(width: kSpacing12),
                              Expanded(
                                child: _StatCard(
                                  label: 'Allocated',
                                  amount: status.allocated,
                                  color: theme.colorScheme.primary,
                                  theme: theme,
                                  subtitle: () {
                                    final rolled = bp.currentPeriod?.rolledFrom ?? 0;
                                    if (rolled == 0) return null;
                                    final prefix = rolled > 0 ? '+' : '-';
                                    final label = rolled > 0 ? 'roll' : 'def';
                                    return Text(
                                      '$prefix Tsh ${rolled.abs() ~/ 100} $label',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: rolled > 0 
                                            ? context.appColors.incomeColor 
                                            : context.appColors.expenseColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  }(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: kSpacing20),

                        // Pace card
                        StaggeredFadeSlide(
                          index: 2,
                          child: GlassCard(
                            padding: const EdgeInsets.all(kSpacing16),

                            child: Row(
                              children: [
                                Icon(
                                  status.isOnTrack
                                      ? PesaFlowIcons.success
                                      : PesaFlowIcons.warning,
                                  color: status.isOnTrack
                                      ? theme.colorScheme.primary
                                      : Colors.orange,
                                  size: 28,
                                ),
                                const SizedBox(width: kSpacing12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        status.paceLabel,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      Text(
                                        '${status.daysLeft} days remaining in this period',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: Colors.grey),
                                      ),
                                      if (!status.isOnTrack &&
                                          !status.isOverBudget &&
                                          status.daysLeft > 0 &&
                                          status.percentage > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: kSpacing4,
                                          ),
                                          child: Text(
                                            _projectedOverspendDate(status),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: Colors.orange,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: kSpacing24),

                        // Daily spend bar chart
                        dailyAsync.when(
                          data: (dailyData) {
                            if (dailyData.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final maxAmount = dailyData
                                .map((e) => e.value)
                                .reduce((a, b) => a > b ? a : b);
                            return StaggeredFadeSlide(
                              index: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Daily Spend',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: kSpacing12),
                                  SizedBox(
                                    height: 120,
                                    child: BarChart(
                                      BarChartData(
                                        alignment:
                                            BarChartAlignment.spaceAround,
                                        maxY: maxAmount * 1.2,
                                        barTouchData: BarTouchData(
                                          enabled: false,
                                        ),
                                        titlesData: FlTitlesData(
                                          show: true,
                                          leftTitles: const AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: false,
                                            ),
                                          ),
                                          topTitles: const AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: false,
                                            ),
                                          ),
                                          rightTitles: const AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: false,
                                            ),
                                          ),
                                          bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              getTitlesWidget: (value, meta) {
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: kSpacing4,
                                                      ),
                                                  child: Text(
                                                    '${value.toInt()}',
                                                    style: theme
                                                        .textTheme
                                                        .labelSmall!
                                                        .copyWith(fontSize: 9),
                                                  ),
                                                );
                                              },
                                              reservedSize: 20,
                                            ),
                                          ),
                                        ),
                                        gridData: const FlGridData(show: false),
                                        borderData: FlBorderData(show: false),
                                        barGroups: dailyData.map((entry) {
                                          return BarChartGroupData(
                                            x: entry.key.day,
                                            barRods: [
                                              BarChartRodData(
                                                toY: entry.value.toDouble(),
                                                color: mutedCatColor,
                                                width: 8,
                                                borderRadius:
                                                    const BorderRadius.only(
                                                      topLeft: Radius.circular(
                                                        4,
                                                      ),
                                                      topRight: Radius.circular(
                                                        4,
                                                      ),
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
                        const SizedBox(height: kSpacing16),

                        // Previous period comparison
                        _buildPeriodComparison(periodsAsync, bp, theme),
                        const SizedBox(height: kSpacing24),

                        // Period info
                        StaggeredFadeSlide(
                          index: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Period: ${bp.budget.period}',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Rollover: ${bp.budget.rollover ? bp.budget.rolloverType : "disabled"}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: kSpacing20),

                        // Historical Periods
                        StaggeredFadeSlide(
                          index: 6,
                          child: Text(
                            'Period History',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: kSpacing12),
                        periodsAsync.when(
                          data: (periods) => Column(
                            children: periods.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final p = entry.value;
                              final pctUsed = p.allocated > 0
                                  ? (p.spent / p.allocated * 100).round()
                                  : 0;
                              return StaggeredFadeSlide(
                                index: 7 + idx,
                                child: GlassCard(
                                  margin: const EdgeInsets.only(
                                    bottom: kSpacing8,
                                  ),
                                  padding: const EdgeInsets.all(kSpacing12),
                                  borderRadius: 8,

                                  child: Row(
                                    children: [
                                      Icon(
                                        p.isClosed
                                            ? PesaFlowIcons.lock
                                            : PesaFlowIcons.unlock,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: kSpacing8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${p.periodStart.day}/${p.periodStart.month} — ${p.periodEnd.day}/${p.periodEnd.month}/${p.periodEnd.year}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall!
                                                  .copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            Text(
                                              '$pctUsed% used${p.rolledFrom != null && p.rolledFrom != 0 ? " • Rolled: Tsh ${p.rolledFrom! ~/ 100}" : ""}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall!
                                                  .copyWith(color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                      AmountText(
                                        amountInCents: p.spent,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall!
                                            .copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: kSpacing12),
                            child: SkeletonCard(height: 70),
                          ),
                          error: (e, _) => ErrorState(
                            title: 'Failed to Load Periods',
                            message: e.toString(),
                            onRetry: () =>
                                ref.invalidate(budgetPeriodsProvider(budgetId)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(kSpacing20),
              child: Column(
                children: [
                  SkeletonCard(height: 160),
                  SizedBox(height: kSpacing16),
                  SkeletonCard(height: 120),
                ],
              ),
            ),
          ),
          error: (e, _) => Scaffold(
            body: ErrorState(
              title: 'Failed to Load Budget details',
              message: e.toString(),
              onRetry: () => ref.invalidate(budgetDetailProvider(budgetId)),
            ),
          ),
        ),
      ),
    );
  }

  String _projectedOverspendDate(BudgetStatus status) {
    final daysElapsed = status.totalDays - status.daysLeft;
    if (daysElapsed <= 0 || status.spent <= 0) return '';
    final dailyRate = status.spent / daysElapsed;
    if (dailyRate <= 0) return '';
    final remaining = status.remaining;
    final daysUntilExhaustion = remaining / dailyRate;
    if (daysUntilExhaustion <= 0) return '';
    final projectedDate = DateTime.now().add(
      Duration(days: daysUntilExhaustion.ceil()),
    );
    return 'Projected to overspend on ${projectedDate.day}/${projectedDate.month}/${projectedDate.year}';
  }

  Widget _buildPeriodComparison(
    AsyncValue<List<BudgetPeriod>> periodsAsync,
    BudgetWithProgress bp,
    ThemeData theme,
  ) {
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
                diff > 0 ? PesaFlowIcons.income : PesaFlowIcons.expense,
                size: 14,
                color: diff > 0 ? Colors.orange : theme.colorScheme.primary,
              ),
              const SizedBox(width: kSpacing4),
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
  final Widget? subtitle;
  const _StatCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.theme,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(kSpacing12),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall!.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: kSpacing4),
          AmountText(
            amountInCents: amount.abs(),
            style: Theme.of(context).textTheme.titleSmall!.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: kSpacing2),
            subtitle!,
          ],
        ],
      ),
    );
  }
}
