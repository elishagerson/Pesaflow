import 'package:pesaflow/presentation/common/widgets/floating_top_bar.dart';
import 'dart:math' as math;
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
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/empty_state.dart';
import 'package:pesaflow/presentation/common/widgets/error_state.dart';
import 'package:pesaflow/presentation/common/widgets/undo_delete.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

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
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                body: Column(
                  children: [
                    const FloatingTopBar(
                      title: 'Budget Details',
                      forceWhite: true,
                    ),
                    const Expanded(
                      child: EmptyState(
                        icon: PesaFlowIcons.budgets,
                        title: 'Budget Not Found',
                        subtitle:
                            'The requested envelope budget could not be located.',
                      ),
                    ),
                  ],
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
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FloatingTopBar(
                        padding: EdgeInsets.zero,
                        forceWhite: true,
                        actions: [
                          TactileSpringContainer(
                            onTap: () =>
                                context.push('/budgets/$budgetId/edit'),
                            child: Container(
                              padding: const EdgeInsets.all(kSpacing10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                PesaFlowIcons.edit,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: kSpacing8),
                          TactileSpringContainer(
                            onTap: () async {
                              final confirm = await ModernDialog.show<bool>(
                                context: context,
                                title: const Text('Delete Budget?'),
                                titleIcon: PesaFlowIcons.delete,
                                iconColor: context.appColors.expenseColor,
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
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: context.appColors.expenseColor,
                                      ),
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
                            child: Container(
                              padding: const EdgeInsets.all(kSpacing10),
                              decoration: BoxDecoration(
                                color: context.appColors.expenseColor
                                    .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                PesaFlowIcons.delete,
                                size: 18,
                                color: context.appColors.expenseColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: kSpacing12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              bp.budget.name,
                              style: context.ts(
                                28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.8,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: kSpacing10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: kSpacing10,
                              vertical: kSpacing4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (status.isOverBudget
                                          ? theme.colorScheme.error
                                          : catColor)
                                      .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              status.isOverBudget
                                  ? 'Over budget'
                                  : '${(status.percentage * 100).round()}%',
                              style: context.ts(
                                12,
                                fontWeight: FontWeight.w600,
                                color: status.isOverBudget
                                    ? theme.colorScheme.error
                                    : catColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: kSpacing6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: kSpacing8,
                              vertical: kSpacing2,
                            ),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              bp.category.name,
                              style: context.ts(
                                11,
                                fontWeight: FontWeight.w600,
                                color: catColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: kSpacing8),
                          Text(
                            bp.budget.period.toUpperCase(),
                            style: context.ts(
                              11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      kSpacing16,
                      kSpacing12,
                      kSpacing16,
                      kSpacing24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── 1. HERO AMOUNT — remaining of allocated ──
                        StaggeredFadeSlide(
                          index: 0,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AmountText(
                                  amountInCents: status.remaining.abs(),
                                  style: context.ts(
                                    40,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1.0,
                                    color: status.remaining >= 0
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.error,
                                  ),
                                ),
                                Text(
                                  status.remaining >= 0
                                      ? 'remaining'
                                      : 'overspent',
                                  style: context.ts(
                                    13,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: kSpacing20),

                        // ── 2. LINEAR PROGRESS — time remaining + budget used ──
                        StaggeredFadeSlide(
                          index: 1,
                          child: _TimelineProgressBar(
                            status: status,
                            catColor: catColor,
                            theme: theme,
                          ),
                        ),
                        const SizedBox(height: kSpacing20),

                        // ── 3. STATS ROW — Spent / Allocated / Daily Avg ──
                        StaggeredFadeSlide(
                          index: 2,
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
                              const SizedBox(width: kSpacing10),
                              Expanded(
                                child: _StatCard(
                                  label: 'Allocated',
                                  amount: status.allocated,
                                  color: theme.colorScheme.primary,
                                  theme: theme,
                                  subtitle: () {
                                    final rolled =
                                        bp.currentPeriod?.rolledFrom ?? 0;
                                    if (rolled == 0) return null;
                                    final prefix = rolled > 0 ? '+' : '-';
                                    final label = rolled > 0 ? 'roll' : 'def';
                                    return Text(
                                      '$prefix Tsh ${rolled.abs() ~/ 100} $label',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: rolled > 0
                                                ? context.appColors.incomeColor
                                                : context
                                                      .appColors
                                                      .expenseColor,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    );
                                  }(),
                                ),
                              ),
                              const SizedBox(width: kSpacing10),
                              Expanded(
                                child: _StatCard(
                                  label: 'Daily Avg',
                                  amount:
                                      status.daysLeft +
                                              (status.totalDays -
                                                  status.daysLeft) >
                                          0
                                      ? (bp.spentInPeriod ~/
                                            ((status.totalDays -
                                                    status.daysLeft)
                                                .clamp(1, status.totalDays)))
                                      : 0,
                                  color: theme.colorScheme.secondary,
                                  theme: theme,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: kSpacing20),

                        // ── 4. DAILY SPEND CHART — with budget line + average ──
                        dailyAsync.when(
                          data: (dailyData) {
                            if (dailyData.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final maxAmount = dailyData
                                .map((e) => e.value)
                                .reduce((a, b) => a > b ? a : b);
                            final daysElapsed =
                                status.totalDays - status.daysLeft;
                            final dailyBudget = daysElapsed > 0
                                ? status.allocated / status.totalDays
                                : status.allocated.toDouble();
                            final dailyAvg = daysElapsed > 0
                                ? bp.spentInPeriod / daysElapsed
                                : 0.0;
                            return StaggeredFadeSlide(
                              index: 3,
                              child: GlassCard(
                                padding: const EdgeInsets.all(kSpacing16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Daily Spend',
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const Spacer(),
                                        _ChartLegend(
                                          color: mutedCatColor,
                                          label: 'Actual',
                                        ),
                                        const SizedBox(width: kSpacing10),
                                        _ChartLegend(
                                          color: theme.colorScheme.error
                                              .withValues(alpha: 0.5),
                                          label: 'Budget/day',
                                          dashed: true,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: kSpacing14),
                                    SizedBox(
                                      height: 140,
                                      child: BarChart(
                                        BarChartData(
                                          alignment:
                                              BarChartAlignment.spaceAround,
                                          maxY: math.max(
                                            maxAmount * 1.2,
                                            dailyBudget * 1.5,
                                          ),
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
                                                  final day = value.toInt();
                                                  if (day % 5 == 0 ||
                                                      day == 1) {
                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: kSpacing4,
                                                          ),
                                                      child: Text(
                                                        '$day',
                                                        style: theme
                                                            .textTheme
                                                            .labelSmall
                                                            ?.copyWith(
                                                              fontSize: 9,
                                                            ),
                                                      ),
                                                    );
                                                  }
                                                  return const SizedBox.shrink();
                                                },
                                                reservedSize: 20,
                                              ),
                                            ),
                                          ),
                                          gridData: const FlGridData(
                                            show: false,
                                          ),
                                          borderData: FlBorderData(show: false),
                                          extraLinesData: ExtraLinesData(
                                            horizontalLines: [
                                              HorizontalLine(
                                                y: dailyBudget,
                                                color: theme.colorScheme.error
                                                    .withValues(alpha: 0.35),
                                                strokeWidth: 1,
                                                dashArray: [6, 4],
                                                label: HorizontalLineLabel(
                                                  show: true,
                                                  alignment: Alignment.topRight,
                                                  style: context.ts(
                                                    9,
                                                    fontWeight: FontWeight.w500,
                                                    color: theme
                                                        .colorScheme
                                                        .error
                                                        .withValues(alpha: 0.6),
                                                  ),
                                                  labelResolver: (_) =>
                                                      'budget',
                                                ),
                                              ),
                                              if (dailyAvg > 0)
                                                HorizontalLine(
                                                  y: dailyAvg,
                                                  color: catColor.withValues(
                                                    alpha: 0.4,
                                                  ),
                                                  strokeWidth: 1,
                                                  dashArray: [3, 3],
                                                  label: HorizontalLineLabel(
                                                    show: true,
                                                    alignment:
                                                        Alignment.topRight,
                                                    style: context.ts(
                                                      9,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: catColor
                                                          .withValues(
                                                            alpha: 0.6,
                                                          ),
                                                    ),
                                                    labelResolver: (_) => 'avg',
                                                  ),
                                                ),
                                            ],
                                          ),
                                          barGroups: dailyData.map((entry) {
                                            final isOverDaily =
                                                entry.value > dailyBudget;
                                            return BarChartGroupData(
                                              x: entry.key.day,
                                              barRods: [
                                                BarChartRodData(
                                                  toY: entry.value.toDouble(),
                                                  color: isOverDaily
                                                      ? theme.colorScheme.error
                                                            .withValues(
                                                              alpha: 0.7,
                                                            )
                                                      : mutedCatColor,
                                                  width: 7,
                                                  borderRadius:
                                                      const BorderRadius.only(
                                                        topLeft:
                                                            Radius.circular(3),
                                                        topRight:
                                                            Radius.circular(3),
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
                              ),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                        ),

                        // ── 5. PACE + PROJECTED — inline, not a separate card ──
                        if (status.daysLeft > 0) ...[
                          const SizedBox(height: kSpacing16),
                          StaggeredFadeSlide(
                            index: 4,
                            child: _PaceInsight(
                              status: status,
                              catColor: catColor,
                              theme: theme,
                              projectedDate: _projectedOverspendDate(status),
                            ),
                          ),
                        ],

                        // ── 6. PERIOD COMPARISON — inline insight ──
                        const SizedBox(height: kSpacing16),
                        _buildPeriodComparison(periodsAsync, bp, theme),

                        // ── 7. PERIOD HISTORY ──
                        const SizedBox(height: kSpacing24),
                        StaggeredFadeSlide(
                          index: 5,
                          child: Row(
                            children: [
                              Text(
                                'Period History',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${bp.budget.period.toUpperCase()} · Rollover ${bp.budget.rollover ? bp.budget.rolloverType : "off"}',
                                style: context.ts(
                                  11,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: kSpacing10),
                        periodsAsync.when(
                          data: (periods) {
                            if (periods.isEmpty) return const SizedBox.shrink();
                            return Column(
                              children: periods.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final p = entry.value;
                                final pctUsed = p.allocated > 0
                                    ? (p.spent / p.allocated)
                                    : 0.0;
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: kSpacing6,
                                  ),
                                  child: _PeriodRow(
                                    period: p,
                                    pctUsed: pctUsed,
                                    isCurrent: idx == 0,
                                    catColor: catColor,
                                    theme: theme,
                                  ),
                                );
                              }).toList(),
                            );
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: kSpacing12),
                            child: SkeletonCard(height: 50),
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
          loading: () => Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: Column(
              children: [
                const FloatingTopBar(
                  title: 'Budget Details',
                  forceWhite: true,
                ),
                const Expanded(
                  child: Padding(
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
              ],
            ),
          ),
          error: (e, _) => Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: Column(
              children: [
                const FloatingTopBar(
                  title: 'Budget Details',
                  forceWhite: true,
                ),
                Expanded(
                  child: ErrorState(
                    title: 'Failed to Load Budget details',
                    message: e.toString(),
                    onRetry: () =>
                        ref.invalidate(budgetDetailProvider(budgetId)),
                  ),
                ),
              ],
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
            ).textTheme.labelSmall!.copyWith(
              color: context.appColors.textMedium,
            ),
          ),
          const SizedBox(height: kSpacing4),
          AmountText(
            amountInCents: amount.abs(),
            style: Theme.of(context).textTheme.titleSmall!.copyWith(
              fontWeight: FontWeight.w700,
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

class _TimelineProgressBar extends StatelessWidget {
  final BudgetStatus status;
  final Color catColor;
  final ThemeData theme;

  const _TimelineProgressBar({
    required this.status,
    required this.catColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final daysElapsed = status.totalDays - status.daysLeft;
    final timePct = status.totalDays > 0
        ? (daysElapsed / status.totalDays).clamp(0.0, 1.0)
        : 0.0;
    final budgetPct = status.percentage.clamp(0.0, 1.5);
    final isOverBudget = status.isOverBudget;

    return GlassCard(
      padding: const EdgeInsets.all(kSpacing14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Timeline',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${status.daysLeft} days left',
                style: context.ts(
                  12,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing12),
          LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth;
              return SizedBox(
                height: 32,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 20,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Stack(
                          children: [
                            Container(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.04,
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: math.min(budgetPct, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isOverBudget
                                        ? [
                                            theme.colorScheme.error,
                                            theme.colorScheme.error.withValues(
                                              alpha: 0.7,
                                            ),
                                          ]
                                        : [
                                            catColor,
                                            catColor.withValues(alpha: 0.6),
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 22,
                      left: (timePct * barWidth) - 1,
                      child: Container(
                        width: 2,
                        height: 10,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 30,
                      left: 0,
                      child: Text(
                        '${(timePct * 100).round()}% time',
                        style: context.ts(
                          9,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.35,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 30,
                      right: 0,
                      child: Text(
                        '${(budgetPct * 100).round()}% budget',
                        style: context.ts(
                          9,
                          color: isOverBudget
                              ? theme.colorScheme.error.withValues(alpha: 0.6)
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.35,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: kSpacing14),
          _LegendRow(
            items: [
              _LegendItem(catColor, 'Spent'),
              _LegendItem(
                theme.colorScheme.onSurface.withValues(alpha: 0.12),
                'Remaining',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;

  const _ChartLegend({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(16, 2),
          painter: _DashedLinePainter(color: color, dashed: dashed),
        ),
        const SizedBox(width: kSpacing4),
        Text(
          label,
          style: context.ts(
            10,
            fontWeight: FontWeight.w500,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  final bool dashed;

  _DashedLinePainter({required this.color, this.dashed = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    if (dashed) {
      const dashWidth = 3.0;
      const dashSpace = 2.0;
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, size.height / 2),
          Offset(x + dashWidth, size.height / 2),
          paint,
        );
        x += dashWidth + dashSpace;
      }
    } else {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) =>
      old.color != color || old.dashed != dashed;
}

class _PaceInsight extends StatelessWidget {
  final BudgetStatus status;
  final Color catColor;
  final ThemeData theme;
  final String projectedDate;

  const _PaceInsight({
    required this.status,
    required this.catColor,
    required this.theme,
    required this.projectedDate,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final IconData icon;
    final String title;
    final String subtitle;

    if (status.isOverBudget) {
      statusColor = theme.colorScheme.error;
      icon = PesaFlowIcons.expense;
      title = status.paceLabel;
      subtitle = 'You\'ve exceeded your budget for this period.';
    } else if (status.isOnTrack) {
      statusColor = context.appColors.incomeColor;
      icon = PesaFlowIcons.income;
      title = status.paceLabel;
      subtitle = 'At current pace, you\'ll stay within budget.';
    } else {
      statusColor = Colors.orange;
      icon = PesaFlowIcons.expense;
      title = status.paceLabel;
      subtitle = projectedDate.isNotEmpty
          ? projectedDate
          : 'You\'re spending faster than planned.';
    }

    return GlassCard(
      padding: const EdgeInsets.all(kSpacing14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: statusColor),
          ),
          const SizedBox(width: kSpacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.ts(
                    13,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: kSpacing2),
                Text(
                  subtitle,
                  style: context.ts(
                    11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  final BudgetPeriod period;
  final double pctUsed;
  final bool isCurrent;
  final Color catColor;
  final ThemeData theme;

  const _PeriodRow({
    required this.period,
    required this.pctUsed,
    required this.isCurrent,
    required this.catColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = pctUsed > 1.0
        ? theme.colorScheme.error
        : pctUsed > 0.8
        ? Colors.orange
        : catColor;

    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpacing12,
        vertical: kSpacing10,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _formatPeriodLabel(period),
                      style: context.ts(
                        12,
                        fontWeight: FontWeight.w600,
                        color: isCurrent
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.55,
                              ),
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: kSpacing6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kSpacing4,
                          vertical: kSpacing2,
                        ),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'NOW',
                          style: context.ts(
                            8,
                            fontWeight: FontWeight.w700,
                            color: catColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: kSpacing2),
                Text(
                  '${_formatDate(period.periodStart)} – ${_formatDate(period.periodEnd)}',
                  style: context.ts(
                    10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: kSpacing10),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pctUsed.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: theme.colorScheme.onSurface.withValues(
                      alpha: 0.06,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
                const SizedBox(height: kSpacing4),
                Text(
                  '${(pctUsed * 100).round()}% · Tsh ${period.spent ~/ 100} / ${period.allocated ~/ 100}',
                  style: context.ts(
                    10,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPeriodLabel(BudgetPeriod p) {
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (p.periodStart.month == p.periodEnd.month &&
        p.periodStart.year == p.periodEnd.year) {
      return '${months[p.periodStart.month]} ${p.periodStart.year}';
    }
    if (p.periodStart.year == p.periodEnd.year) {
      return '${months[p.periodStart.month]} – ${months[p.periodEnd.month]} ${p.periodStart.year}';
    }
    return '${months[p.periodStart.month]} ${p.periodStart.year} – ${months[p.periodEnd.month]} ${p.periodEnd.year}';
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}';
}

class _LegendRow extends StatelessWidget {
  final List<_LegendItem> items;

  const _LegendRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(right: kSpacing14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: kSpacing4),
                  Text(
                    item.label,
                    style: context.ts(
                      10,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _LegendItem {
  final Color color;
  final String label;
  const _LegendItem(this.color, this.label);
}
