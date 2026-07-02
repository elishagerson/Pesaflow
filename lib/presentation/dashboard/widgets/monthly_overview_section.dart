import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';

class MonthlyOverviewSection extends ConsumerWidget {
  const MonthlyOverviewSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalsAsync = ref.watch(monthlyTotalsProvider);

    return totalsAsync.when(
      data: (totals) {
        final income = totals['income'] ?? 0;
        final expense = totals['expense'] ?? 0;

        if (income == 0 && expense == 0) {
          return GlassCard(
            padding: const EdgeInsets.all(kSpacing20),
            borderRadius: AppTheme.radiusCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(kSpacing16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    PesaFlowIcons.analytics,
                    color: theme.colorScheme.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: kSpacing16),
                Text(
                  'No transactions yet this month',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: kSpacing8),
                Text(
                  'Start automatic SMS synchronization or log transactions manually to view your financial charts here.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.7,
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final double total = (income + expense).toDouble();
        final double incomePct = total > 0 ? (income / total) * 100 : 50;
        final double expensePct = total > 0 ? (expense / total) * 100 : 50;

        final netSavings = income - expense;
        final savingsPct = income > 0 ? (netSavings / income * 100).round() : 0;

        return GlassCard(
          padding: const EdgeInsets.all(kSpacing18),
          borderRadius: AppTheme.radiusCard,
          elevation: CardElevation.medium,
          accentColor: theme.colorScheme.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (income > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kSpacing8,
                        vertical: kSpacing4,
                      ),
                      decoration: BoxDecoration(
                        color: netSavings >= 0
                            ? (isDark
                                      ? AppTheme.incomeColorDark
                                      : AppTheme.incomeColor)
                                  .withValues(alpha: 0.12)
                            : (isDark
                                      ? AppTheme.expenseColorDark
                                      : AppTheme.expenseColor)
                                  .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        netSavings >= 0
                            ? '$savingsPct% SAVED'
                            : '${savingsPct.abs()}% DEFICIT',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: netSavings >= 0
                              ? (isDark
                                    ? AppTheme.incomeColorDark
                                    : AppTheme.incomeColor)
                              : (isDark
                                    ? AppTheme.expenseColorDark
                                    : AppTheme.expenseColor),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: kSpacing12),
              ],
              Row(
                children: [
                  Semantics(
                    label:
                        'Monthly cashflow ratio: ${(incomePct).round()}% income vs ${(expensePct).round()}% expense.',
                    excludeSemantics: true,
                    child: SizedBox(
                      height: 84,
                      width: 84,
                      child: PieChart(
                        PieChartData(
                          startDegreeOffset: -90,
                          sectionsSpace: 2,
                          centerSpaceRadius: 26,
                          sections: [
                            PieChartSectionData(
                              value: incomePct,
                              color: isDark
                                  ? AppTheme.incomeColorDark
                                  : AppTheme.incomeColor,
                              radius: 10,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              value: expensePct,
                              color: isDark
                                  ? AppTheme.expenseColorDark
                                  : AppTheme.expenseColor,
                              radius: 10,
                              showTitle: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: kSpacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppTheme.incomeColorDark
                                        : AppTheme.incomeColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: kSpacing8),
                                Text(
                                  'Income',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            AmountText(
                              amountInCents: income,
                              type: AmountType.income,
                              useMonospace: true,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: kSpacing8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppTheme.expenseColorDark
                                        : AppTheme.expenseColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: kSpacing8),
                                Text(
                                  'Expense',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            AmountText(
                              amountInCents: expense,
                              type: AmountType.expense,
                              useMonospace: true,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: kSpacing8),
                        Divider(
                          height: 0.5,
                          thickness: 0.5,
                          color: isDark
                              ? const Color(0x1AFFFFFF)
                              : const Color(0x1A000000),
                        ),
                        const SizedBox(height: kSpacing8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: netSavings >= 0
                                        ? (isDark
                                              ? AppTheme.incomeColorDark
                                              : AppTheme.incomeColor)
                                        : (isDark
                                              ? AppTheme.expenseColorDark
                                              : AppTheme.expenseColor),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: kSpacing8),
                                Text(
                                  netSavings >= 0 ? 'Saved' : 'Deficit',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            AmountText(
                              amountInCents: netSavings.abs(),
                              type: netSavings >= 0
                                  ? AmountType.income
                                  : AmountType.expense,
                              useMonospace: true,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: kSpacing16),
        child: SkeletonCard(height: 120),
      ),
      error: (_, _) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: kSpacing16),
        child: SkeletonCard(height: 120),
      ),
    );
  }
}
