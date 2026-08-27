import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/data/database/daos/budget_dao.dart';
import 'package:pesaflow/domain/budget/budget_engine.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/core/utils/app_illustrations.dart';
import 'package:pesaflow/presentation/common/widgets/empty_state.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_list.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/budgets/widgets/savings_goal_form_sheet.dart';
import 'package:pesaflow/presentation/budgets/widgets/savings_goal_detail_sheet.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/presentation/common/widgets/spring_sheet_route.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

class BudgetActiveTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  @override
  set state(int value) => super.state = value;
}

final budgetActiveTabProvider = NotifierProvider<BudgetActiveTabNotifier, int>(
  () {
    return BudgetActiveTabNotifier();
  },
);

class BudgetListScreen extends ConsumerWidget {
  const BudgetListScreen({super.key});

  int _calculateDaysRemaining(DateTime targetDate) {
    final diff = targetDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeTab = ref.watch(budgetActiveTabProvider);
    final budgetProgressAsync = ref.watch(budgetProgressProvider);

    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // ── Floating Top Bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    activeTab == 0 ? 'Budgets' : 'Savings Goals',
                    style: context.ts(
                      34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  TactileSpringContainer(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (activeTab == 0) {
                        context.push('/budgets/add');
                      } else {
                        showSpringSheet(
                          context,
                          isScrollControlled: true,
                          builder: (context) => const SavingsGoalFormSheet(),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: 0.1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        PesaFlowIcons.add,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // HIG Segmented Control Slider
            _buildSegmentedControl(context, ref),

            // Main Content Area
            Expanded(
              child: activeTab == 0
                  ? budgetProgressAsync.when(
                      data: (budgets) =>
                          _buildCategoryBudgets(context, ref, budgets, theme),
                      loading: () => const Padding(
                        padding: EdgeInsets.all(kSpacing16),
                        child: Column(
                          children: [
                            SkeletonCard(height: 120),
                            SizedBox(height: kSpacing10),
                            SkeletonCard(height: 120),
                            SizedBox(height: kSpacing10),
                            SkeletonCard(height: 120),
                            SizedBox(height: kSpacing10),
                            SkeletonCard(height: 120),
                          ],
                        ),
                      ),
                      error: (err, _) =>
                          Center(child: Text('Error loading budgets: $err')),
                    )
                  : _buildSavingsGoals(context, ref, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedControl(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final activeTab = ref.watch(budgetActiveTabProvider);

    return Container(
      margin: const EdgeInsets.only(
        left: kSpacing16,
        right: kSpacing16,
        top: kSpacing16,
        bottom: kSpacing8,
      ),
      padding: const EdgeInsets.all(kSpacing4),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: onSurface.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(budgetActiveTabProvider.notifier).state = 0;
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: kSpacing8),
                decoration: BoxDecoration(
                  color: activeTab == 0
                      ? theme.colorScheme.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  boxShadow: activeTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  'Category Budgets',
                  textAlign: TextAlign.center,
                  style: context.ts(
                    13,
                    fontWeight: activeTab == 0
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: activeTab == 0
                        ? onSurface
                        : onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(budgetActiveTabProvider.notifier).state = 1;
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: kSpacing8),
                decoration: BoxDecoration(
                  color: activeTab == 1
                      ? theme.colorScheme.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  boxShadow: activeTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  'Savings Goals',
                  textAlign: TextAlign.center,
                  style: context.ts(
                    13,
                    fontWeight: activeTab == 1
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: activeTab == 1
                        ? onSurface
                        : onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 1. CATEGORY BUDGETS RENDERER (Glass Stack UI)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildCategoryBudgets(
    BuildContext context,
    WidgetRef ref,
    List<BudgetWithProgress> budgets,
    ThemeData theme,
  ) {
    if (budgets.isEmpty) {
      return EmptyState(
        icon: PesaFlowIcons.budgets,
        title: 'No Budgets Yet',
        subtitle:
            'Create envelope budgets to track spending limits on categories like Food, Transport, or Entertainment.',
        illustration: PesaFlowIllustration.emptyBudgets(),
        action: TactileSpringContainer(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/budgets/add');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: kSpacing24,
              vertical: kSpacing14,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  PesaFlowIcons.add,
                  color: theme.colorScheme.onPrimary,
                  size: 20,
                ),
                const SizedBox(width: kSpacing8),
                Text(
                  'Create First Budget',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    int totalAllocated = 0;
    int totalSpent = 0;
    for (final bp in budgets) {
      totalAllocated += bp.currentPeriod?.allocated ?? bp.budget.amount;
      totalSpent += bp.spentInPeriod;
    }

    final onSurface = theme.colorScheme.onSurface;

    return RefreshIndicator(
      color: theme.colorScheme.primary,
      backgroundColor: theme.scaffoldBackgroundColor,
      onRefresh: () async {
        ref.invalidate(budgetProgressProvider);
        ref.invalidate(savingsGoalsStreamProvider);
        ref.invalidate(categoriesFutureProvider);
      },
      child: SingleChildScrollView(
        key: const PageStorageKey('budget_list'),
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          kSpacing16,
          kSpacing16,
          kSpacing16,
          IosTabBar.navBarHeight + kSpacing32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Summary Glass Card (Top Hero)
            GlassCard(
              padding: const EdgeInsets.all(kSpacing24),
              borderRadius: AppTheme.radiusCard,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Spent',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: kSpacing8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: AmountText(
                            amountInCents: totalSpent,
                            style: context.ts(
                              32,
                              fontWeight: FontWeight.w900,
                              color: totalSpent > totalAllocated
                                  ? context.appColors.expenseColor
                                  : onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: kSpacing16),
                        Row(
                          children: [
                            Text(
                              'Out of ',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                            AmountText(
                              amountInCents: totalAllocated,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: onSurface.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Sleek Circular Progress
                  SizedBox(
                    height: 100,
                    width: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.easeOutCubic,
                          tween: Tween<double>(
                            begin: 0,
                            end: totalAllocated > 0
                                ? (totalSpent / totalAllocated).clamp(0.0, 1.0)
                                : 0,
                          ),
                          builder: (context, value, _) {
                            return SizedBox(
                              width: 100,
                              height: 100,
                              child: CircularProgressIndicator(
                                value: value,
                                strokeWidth: 8,
                                strokeCap: StrokeCap.round,
                                backgroundColor: onSurface.withValues(
                                  alpha: 0.05,
                                ),
                                color: totalSpent > totalAllocated
                                    ? context.appColors.expenseColor
                                    : theme.colorScheme.primary,
                              ),
                            );
                          },
                        ),
                        SizedBox(
                          width: 70,
                          height: 70,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  totalAllocated > 0
                                      ? (((totalSpent / totalAllocated) * 100) >
                                                999
                                            ? '>999%'
                                            : '${(totalSpent / totalAllocated * 100).round()}%')
                                      : '0%',
                                  style: context.ts(
                                    20,
                                    fontWeight: FontWeight.w800,
                                    color: totalSpent > totalAllocated
                                        ? context.appColors.expenseColor
                                        : onSurface,
                                  ),
                                ),
                                Text(
                                  'Used',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: onSurface.withValues(alpha: 0.5),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: kSpacing24),

            // Budget cards list
            Column(
              children: budgets.map((bp) {
                final status = BudgetEngine.computeStatus(
                  allocated: bp.currentPeriod?.allocated ?? bp.budget.amount,
                  spent: bp.spentInPeriod,
                  periodStart:
                      bp.currentPeriod?.periodStart ?? bp.budget.startDate,
                  periodEnd:
                      bp.currentPeriod?.periodEnd ??
                      DateTime.now().add(const Duration(days: 30)),
                );

                final catColor = hexToColor(bp.category.color);

                Color paceColor;
                if (status.isOverBudget) {
                  paceColor = context.appColors.expenseColor;
                } else if (!status.isOnTrack) {
                  paceColor = Colors.orange;
                } else {
                  paceColor = context.appColors.incomeColor;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: kSpacing12),
                  child: Hero(
                    tag: 'budget-${bp.budget.id}',
                    child: TactileSpringContainer(
                      onTap: () => context.push('/budgets/${bp.budget.id}'),
                      child: GlassCard(
                        padding: const EdgeInsets.all(kSpacing16),
                        borderRadius: AppTheme.radiusCard,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(kSpacing10),
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                                  ),
                                  child: Icon(
                                    getCategoryIcon(bp.category.icon),
                                    color: catColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: kSpacing16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        bp.category.name,
                                        style: context.ts(
                                          16,
                                          fontWeight: FontWeight.bold,
                                          color: onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: paceColor.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              status.paceLabel,
                                              style: context.ts(
                                                10,
                                                fontWeight: FontWeight.w700,
                                                color: paceColor,
                                              ),
                                            ),
                                          ),
                                          if (status.daysLeft > 0) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              '${status.daysLeft} days left',
                                              style: context.ts(
                                                11,
                                                color: onSurface.withValues(
                                                  alpha: 0.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    AmountText(
                                      amountInCents: bp.spentInPeriod,
                                      style: context.ts(
                                        16,
                                        fontWeight: FontWeight.w800,
                                        color: status.isOverBudget
                                            ? context.appColors.expenseColor
                                            : onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          'of ',
                                          style: context.ts(
                                            12,
                                            color: onSurface.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                        ),
                                        AmountText(
                                          amountInCents: status.allocated,
                                          style: context.ts(
                                            12,
                                            color: onSurface.withValues(
                                              alpha: 0.5,
                                            ),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: kSpacing16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                              child: TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.easeOutCubic,
                                tween: Tween<double>(
                                  begin: 0,
                                  end: status.percentage.clamp(0.0, 1.0),
                                ),
                                builder: (context, value, _) {
                                  return LinearProgressIndicator(
                                    value: value,
                                    backgroundColor: onSurface.withValues(
                                      alpha: 0.05,
                                    ),
                                    color: paceColor,
                                    minHeight: 8,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsGoals(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    final onSurface = theme.colorScheme.onSurface;
    final savingsGoalsAsync = ref.watch(savingsGoalsStreamProvider);
    final totalSaved = ref.watch(savingsGoalsTotalSavedProvider);

    return savingsGoalsAsync.when(
      data: (goals) {
        if (goals.isEmpty) {
          return EmptyState(
            icon: PesaFlowIcons.savings,
            title: 'Emergency Reserves & Goals',
            subtitle:
                'Set visual targets for big purchases, safety vaults, or long-term dreams. Log progress with optional account wallet deductions.',
            illustration: PesaFlowIllustration.emptyGoals(),
            action: TactileSpringContainer(
              onTap: () {
                HapticFeedback.lightImpact();
                showSpringSheet(
                  context,
                  isScrollControlled: true,
                  builder: (context) => const SavingsGoalFormSheet(),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PesaFlowIcons.add,
                      color: theme.colorScheme.onPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: kSpacing8),
                    Text(
                      'Set First Savings Goal',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Calculate totals
        int totalTarget = 0;
        for (final goal in goals) {
          totalTarget += goal.targetAmount;
        }

        final overallPct = totalTarget > 0
            ? (totalSaved / totalTarget).clamp(0.0, 1.0)
            : 0.0;

        return RefreshIndicator(
          color: theme.colorScheme.primary,
          backgroundColor: theme.scaffoldBackgroundColor,
          onRefresh: () async {
            ref.invalidate(budgetProgressProvider);
            ref.invalidate(savingsGoalsStreamProvider);
            ref.invalidate(categoriesFutureProvider);
          },
          child: SingleChildScrollView(
            key: const PageStorageKey('savings_goals_tab'),
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              kSpacing16,
              kSpacing16,
              kSpacing16,
              IosTabBar.navBarHeight + kSpacing32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overall Savings Summary Box
                GlassCard(
                  padding: const EdgeInsets.all(kSpacing20),
                  borderRadius: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Savings Overview',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: onSurface.withValues(alpha: 0.45),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: kSpacing12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Saved',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: kSpacing2),
                              AmountText(
                                amountInCents: totalSaved,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Combined Target',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: kSpacing2),
                              AmountText(
                                amountInCents: totalTarget,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: kSpacing16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        child: LinearProgressIndicator(
                          value: overallPct,
                          backgroundColor: onSurface.withValues(alpha: 0.07),
                          color: AppTheme.incomeColorDark,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: kSpacing6),
                      Text(
                        '${(overallPct * 100).round()}% overall progress',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: kSpacing24),

                Text(
                  'Active Goals',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: kSpacing12),

                // Savings goals list
                StaggeredList(
                  itemCount: goals.length,
                  itemBuilder: (context, index) {
                    final goal = goals[index];
                    final goalColor = hexToColor(goal.color);
                    final goalPct = goal.targetAmount > 0
                        ? (goal.currentAmount / goal.targetAmount).clamp(
                            0.0,
                            1.0,
                          )
                        : 0.0;
                    final daysLeft = _calculateDaysRemaining(goal.targetDate);

                    return TactileSpringContainer(
                      onTap: () {
                        showSpringSheet(
                          context,
                          isScrollControlled: true,
                          builder: (context) =>
                              SavingsGoalDetailSheet(goal: goal),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: kSpacing12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusCard,
                          ),
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.85,
                          ),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 8,
                                  top: 12,
                                  bottom: 12,
                                ),
                                child: Container(
                                  width: 4,
                                  decoration: BoxDecoration(
                                    color: goalColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 12,
                                    right: kSpacing16,
                                    top: kSpacing16,
                                    bottom: kSpacing16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          // Circular Progress Ring
                                          Semantics(
                                            label:
                                                'Savings goal progress: ${(goalPct * 100).round()}% completed.',
                                            excludeSemantics: true,
                                            child: SizedBox(
                                              height: 48,
                                              width: 48,
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  PieChart(
                                                    PieChartData(
                                                      startDegreeOffset: -90,
                                                      sectionsSpace: 0,
                                                      centerSpaceRadius: 16,
                                                      sections: [
                                                        PieChartSectionData(
                                                          value: goalPct * 100,
                                                          color: goalColor,
                                                          radius: 4,
                                                          showTitle: false,
                                                        ),
                                                        PieChartSectionData(
                                                          value:
                                                              (1.0 - goalPct) *
                                                              100,
                                                          color: goalColor
                                                              .withValues(
                                                                alpha: 0.12,
                                                              ),
                                                          radius: 4,
                                                          showTitle: false,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Icon(
                                                    getGoalIcon(goal.icon),
                                                    color: goalColor,
                                                    size: 16,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: kSpacing14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  goal.name,
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(
                                                  height: kSpacing2,
                                                ),
                                                Text(
                                                  'by ${goal.targetDate.day}/${goal.targetDate.month}/${goal.targetDate.year}',
                                                  style:
                                                      theme.textTheme.bodySmall,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              if (goal.isCompleted)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: kSpacing8,
                                                        vertical: kSpacing2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme
                                                        .transferColorDark
                                                        .withValues(
                                                          alpha: 0.12,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              AppTheme.radiusInput,
                                                            ),
                                                  ),
                                                  child: Text(
                                                    'COMPLETED',
                                                    style: theme
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: AppTheme
                                                              .transferColorDark,
                                                        ),
                                                  ),
                                                )
                                              else
                                                Text(
                                                  '$daysLeft days remaining',
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              const SizedBox(height: kSpacing4),
                                              GestureDetector(
                                                onTap: () {
                                                  showSpringSheet(
                                                    context,
                                                    isScrollControlled: true,
                                                    builder: (context) =>
                                                        SavingsGoalFormSheet(
                                                          existingGoal: goal,
                                                        ),
                                                  );
                                                },
                                                child: Text(
                                                  'Edit',
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .primary,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: kSpacing14),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          AmountText(
                                            amountInCents: goal.currentAmount,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          Text(
                                            'Target: ${CurrencyFormatter.formatCents(goal.targetAmount)}',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: kSpacing8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                          value: goalPct,
                                          backgroundColor: goalColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          color: goalColor,
                                          minHeight: 6,
                                        ),
                                      ),
                                      const SizedBox(height: kSpacing4),
                                      Text(
                                        '${(goalPct * 100).round()}% completed',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(kSpacing16),
        child: Column(
          children: [
            SkeletonCard(height: 130),
            SizedBox(height: kSpacing12),
            SkeletonCard(height: 130),
            SizedBox(height: kSpacing12),
            SkeletonCard(height: 130),
            SizedBox(height: kSpacing12),
            SkeletonCard(height: 130),
          ],
        ),
      ),
      error: (err, _) =>
          Center(child: Text('Error loading savings goals: $err')),
    );
  }
}
