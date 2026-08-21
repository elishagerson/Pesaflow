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
import 'package:pesaflow/presentation/common/widgets/glass_list_container.dart';
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
                    style: context.ts(34, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
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
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(PesaFlowIcons.add, color: Colors.white, size: 22),
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
        color: onSurface.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(100),
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
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: kSpacing8),
                decoration: BoxDecoration(
                  color: activeTab == 0
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'Category Budgets',
                  textAlign: TextAlign.center,
                  style: context.ts(
                    12,
                    fontWeight: activeTab == 0
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: activeTab == 0
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: kSpacing8),
                decoration: BoxDecoration(
                  color: activeTab == 1
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'Savings Goals',
                  textAlign: TextAlign.center,
                  style: context.ts(
                    12,
                    fontWeight: activeTab == 1
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: activeTab == 1
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
  // 1. CATEGORY BUDGETS RENDERER (Original code preserved & visual polished)
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Donut Chart
            Container(
              padding: const EdgeInsets.symmetric(vertical: kSpacing20),
              child: Row(
                children: [
                  SizedBox(
                    height: 120,
                    width: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 0,
                            centerSpaceRadius: 45,
                            startDegreeOffset: -90,
                            sections: [
                              PieChartSectionData(
                                color: totalSpent > totalAllocated
                                    ? context.appColors.expenseColor
                                    : theme.colorScheme.primary,
                                value: totalAllocated > 0
                                    ? (totalSpent / totalAllocated).clamp(0.0, 1.0) * 100
                                    : 0,
                                title: '',
                                radius: 12,
                              ),
                              PieChartSectionData(
                                color: onSurface.withValues(alpha: 0.07),
                                value: totalAllocated > 0
                                    ? (1 - (totalSpent / totalAllocated).clamp(0.0, 1.0)) * 100
                                    : 100,
                                title: '',
                                radius: 12,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              totalAllocated > 0
                                  ? '${(totalSpent / totalAllocated * 100).round()}%'
                                  : '0%',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: totalSpent > totalAllocated
                                    ? context.appColors.expenseColor
                                    : onSurface,
                              ),
                            ),
                            Text(
                              'Used',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: onSurface.withValues(alpha: 0.45),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: kSpacing24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Spent',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                        const SizedBox(height: kSpacing2),
                        AmountText(
                          amountInCents: totalSpent,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: totalSpent > totalAllocated
                                ? context.appColors.expenseColor
                                : onSurface,
                          ),
                        ),
                        const SizedBox(height: kSpacing16),
                        Text(
                          'Total Budget',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                        const SizedBox(height: kSpacing2),
                        AmountText(
                          amountInCents: totalAllocated,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Text(
              'Active Budgets',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: kSpacing12),

            // Budget cards list
            GlassListContainer(
              child: Column(
                children: budgets.asMap().entries.map((entry) {
                  final index = entry.key;
                  final bp = entry.value;
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
                final mutedCatColor = desaturateColor(catColor);

                return Hero(
                  tag: 'budget-${bp.budget.id}',
                  child: TactileSpringContainer(
                    onTap: () => context.push('/budgets/${bp.budget.id}'),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpacing20,
                            vertical: kSpacing16,
                          ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: catColor,
                              ),
                            ),
                            const SizedBox(width: kSpacing16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        bp.category.name,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: onSurface,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          if (status.isOverBudget) ...[
                                            Icon(
                                              PesaFlowIcons.error,
                                              color: context.appColors.expenseColor,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                          ],
                                          AmountText(
                                            amountInCents: bp.spentInPeriod,
                                            style: theme.textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: status.isOverBudget
                                                  ? context.appColors.expenseColor
                                                  : onSurface,
                                            ),
                                          ),
                                          Text(
                                            ' / ',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: onSurface.withValues(alpha: 0.54),
                                            ),
                                          ),
                                          AmountText(
                                            amountInCents: status.allocated,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: onSurface.withValues(alpha: 0.54),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: kSpacing8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(100),
                                    child: LinearProgressIndicator(
                                      value: status.percentage.clamp(0.0, 1.0),
                                      backgroundColor: onSurface.withValues(
                                        alpha: 0.05,
                                      ),
                                      color: status.isOverBudget
                                          ? context.appColors.expenseColor
                                          : mutedCatColor,
                                      minHeight: 6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (index < budgets.length - 1)
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: onSurface.withValues(alpha: 0.08),
                          indent: 20 + 12 + 16,
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
      ),
    ),
  );
}

  // ════════════════════════════════════════════════════════════════════════════
  // 2. DEDICATED SAVINGS GOALS DASHBOARD RENDERER (Brand New Screen Area)
  // ════════════════════════════════════════════════════════════════════════════
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
                        borderRadius: BorderRadius.circular(8),
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
                              Container(width: 4, color: goalColor),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(kSpacing16),
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
                                                          12,
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
