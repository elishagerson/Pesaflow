import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/theme/app_colors_theme.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/motion/skeleton_crossfade.dart';

class MonthlyOverviewSection extends ConsumerWidget {
  const MonthlyOverviewSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColorsTheme>()!;
    final totalsAsync = ref.watch(monthlyTotalsProvider);

    return SkeletonCrossfade(
      isLoading: totalsAsync is AsyncLoading && !totalsAsync.hasValue,
      skeleton: const Padding(
        padding: EdgeInsets.symmetric(horizontal: kSpacing16),
        child: SkeletonCard(height: 120),
      ),
      child: totalsAsync.when(
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
          final savingsPct = income > 0
              ? (netSavings / income * 100).round()
              : 0;

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
                              ? appColors.incomeColor.withValues(alpha: 0.12)
                              : appColors.expenseColor.withValues(alpha: 0.12),
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
                                ? appColors.incomeColor
                                : appColors.expenseColor,
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
                        child: _BudgetPulseDonut(
                          incomePct: incomePct,
                          expensePct: expensePct,
                          incomeColor: appColors.incomeColor,
                          expenseColor: appColors.expenseColor,
                          netSavings: netSavings,
                          savingsPct: savingsPct,
                          pulse: expense > 0.8 * income,
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
                                      color: appColors.incomeColor,
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
                                style: context.ts(
                                  13,
                                  fontWeight: FontWeight.bold,
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
                                      color: appColors.expenseColor,
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
                                style: context.ts(
                                  13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: kSpacing8),
                          Divider(
                            height: 0.5,
                            thickness: 0.5,
                            color: appColors.scaffoldLine,
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
                                          ? appColors.incomeColor
                                          : appColors.expenseColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: kSpacing8),
                                  Text(
                                    netSavings >= 0 ? 'Saved' : 'Deficit',
                                    style: context.ts(
                                      12,
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
                                style: context.ts(
                                  13,
                                  fontWeight: FontWeight.bold,
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
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: kSpacing16),
          child: SkeletonCard(height: 120),
        ),
      ),
    );
  }
}

class _BudgetPulseDonut extends StatefulWidget {
  final double incomePct;
  final double expensePct;
  final Color incomeColor;
  final Color expenseColor;
  final int netSavings;
  final int savingsPct;
  final bool pulse;

  const _BudgetPulseDonut({
    required this.incomePct,
    required this.expensePct,
    required this.incomeColor,
    required this.expenseColor,
    required this.netSavings,
    required this.savingsPct,
    required this.pulse,
  });

  @override
  State<_BudgetPulseDonut> createState() => _BudgetPulseDonutState();
}

class _BudgetPulseDonutState extends State<_BudgetPulseDonut>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _glowAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) {
      _initAnimation();
    }
  }

  void _initAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(
      begin: 4.0,
      end: 14.0,
    ).animate(CurvedAnimation(parent: _controller!, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_BudgetPulseDonut oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && _controller == null) {
      _initAnimation();
    } else if (!widget.pulse && _controller != null) {
      _controller!.dispose();
      _controller = null;
      _glowAnimation = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chart = PieChart(
      PieChartData(
        startDegreeOffset: -90,
        sectionsSpace: 2,
        centerSpaceRadius: 28,
        sections: [
          PieChartSectionData(
            value: widget.incomePct,
            color: widget.incomeColor,
            radius: 12,
            showTitle: false,
          ),
          PieChartSectionData(
            value: widget.expensePct,
            color: widget.expenseColor,
            radius: 12,
            showTitle: false,
          ),
        ],
      ),
    );

    final label = Text(
      widget.netSavings >= 0
          ? '+${widget.savingsPct}%'
          : '-${widget.savingsPct.abs()}%',
      style: context.ts(
        10,
        fontWeight: FontWeight.w900,
        color: widget.netSavings >= 0
            ? widget.incomeColor
            : widget.expenseColor,
      ),
    );

    if (!widget.pulse || _glowAnimation == null) {
      return Stack(alignment: Alignment.center, children: [chart, label]);
    }

    return AnimatedBuilder(
      animation: _glowAnimation!,
      builder: (context, child) {
        return Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.expenseColor.withValues(alpha: 0.15),
                blurRadius: _glowAnimation!.value,
                spreadRadius: _glowAnimation!.value * 0.3,
              ),
            ],
          ),
          child: Stack(alignment: Alignment.center, children: [chart, label]),
        );
      },
    );
  }
}
