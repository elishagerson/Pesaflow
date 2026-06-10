import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/budgets/widgets/savings_goal_form_sheet.dart';
import 'package:pesaflow/presentation/budgets/widgets/savings_goal_detail_sheet.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:fl_chart/fl_chart.dart';

class BudgetActiveTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  @override
  set state(int value) => super.state = value;
}

final budgetActiveTabProvider = NotifierProvider<BudgetActiveTabNotifier, int>(() {
  return BudgetActiveTabNotifier();
});

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
      appBar: IosNavBar(
        title: activeTab == 0 ? 'Budgets' : 'Savings Goals',
        largeTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 28),
            onPressed: () {
              HapticFeedback.lightImpact();
              if (activeTab == 0) {
                context.go('/budgets/add');
              } else {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const SavingsGoalFormSheet(),
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(top: false, child: Column(
          children: [
            // HIG Segmented Control Slider
            _buildSegmentedControl(context, ref),

            // Main Content Area
            Expanded(
              child: activeTab == 0
                  ? budgetProgressAsync.when(
                      data: (budgets) => _buildCategoryBudgets(context, ref, budgets, theme),
                      loading: () => const Center(child: CupertinoActivityIndicator()),
                      error: (err, _) => Center(child: Text('Error loading budgets: $err')),
                    )
                  : _buildSavingsGoals(context, ref, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedControl(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeTab = ref.watch(budgetActiveTabProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: activeTab == 0
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'Category Budgets',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: activeTab == 0 ? FontWeight.w700 : FontWeight.w500,
                    color: activeTab == 0
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: 0.5),
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: activeTab == 1
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'Savings Goals',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: activeTab == 1 ? FontWeight.w700 : FontWeight.w500,
                    color: activeTab == 1
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: 0.5),
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
  Widget _buildCategoryBudgets(BuildContext context, WidgetRef ref, List<BudgetWithProgress> budgets, ThemeData theme) {
    if (budgets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.pie_chart_outline_rounded,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Budgets Yet',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create envelope budgets to track spending limits on categories like Food, Transport, or Entertainment.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () => context.go('/budgets/add'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create First Budget'),
              ),
            ],
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

    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Card
          GlassCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Budget Overview',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Spent', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 2),
                        AmountText(
                          amountInCents: totalSpent,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Total Allocated', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 2),
                        AmountText(
                          amountInCents: totalAllocated,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: totalAllocated > 0 ? (totalSpent / totalAllocated).clamp(0.0, 1.0) : 0,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    color: totalSpent > totalAllocated
                        ? AppTheme.expenseColor
                        : Theme.of(context).colorScheme.primary,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  totalAllocated > 0
                      ? '${(totalSpent / totalAllocated * 100).round()}% used'
                      : '0% used',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Active Budgets',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Budget cards list
          ...budgets.map((bp) {
            final status = BudgetEngine.computeStatus(
              allocated: bp.currentPeriod?.allocated ?? bp.budget.amount,
              spent: bp.spentInPeriod,
              periodStart: bp.currentPeriod?.periodStart ?? bp.budget.startDate,
              periodEnd: bp.currentPeriod?.periodEnd ?? DateTime.now().add(const Duration(days: 30)),
            );

            final catColor = hexToColor(bp.category.color);

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              child: GlassCard(
                borderRadius: 20,
                onTap: () => context.go('/budgets/${bp.budget.id}'),
                backgroundColor: isDark ? const Color(0xFF1B1C22).withOpacity(0.65) : Colors.white,
                accentColor: catColor,
                accentWidth: 2.5,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
              Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              getCategoryIcon(bp.category.icon),
                              color: catColor,
                              size: 22,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bp.budget.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                bp.category.name,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: status.isOverBudget
                                    ? const Color(0xFFFF453A).withOpacity(0.15)
                                    : status.isOnTrack
                                        ? AppTheme.transferColorDark.withOpacity(0.15)
                                        : Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                status.paceLabel,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: status.isOverBudget
                                      ? const Color(0xFFFF453A)
                                      : status.isOnTrack
                                          ? AppTheme.transferColorDark
                                          : Colors.orange,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${status.daysLeft} days left',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white30 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AmountText(
                          amountInCents: bp.spentInPeriod,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: status.isOverBudget ? const Color(0xFFFF453A) : (isDark ? Colors.white : Colors.black),
                          ),
                        ),
                        AmountText(
                          amountInCents: status.allocated,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: status.percentage.clamp(0.0, 1.0),
                        backgroundColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.05),
                        color: status.isOverBudget ? const Color(0xFFFF453A) : catColor,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(status.percentage * 100).round()}% used',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white30 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 2. DEDICATED SAVINGS GOALS DASHBOARD RENDERER (Brand New Screen Area)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildSavingsGoals(BuildContext context, WidgetRef ref, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final savingsGoalsAsync = ref.watch(savingsGoalsStreamProvider);
    final totalSaved = ref.watch(savingsGoalsTotalSavedProvider);

    return savingsGoalsAsync.when(
      data: (goals) {
        if (goals.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.savings_rounded,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Emergency Reserves & Goals',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set visual targets for big purchases, safety vaults, or long-term dreams. Log progress with optional account wallet deductions.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const SavingsGoalFormSheet(),
                      );
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Set First Savings Goal'),
                  ),
                ],
              ),
            ),
          );
        }

        // Calculate totals
        int totalTarget = 0;
        for (final goal in goals) {
          totalTarget += goal.targetAmount;
        }

        final overallPct = totalTarget > 0 ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0.0;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall Savings Summary Box
              GlassCard(
                padding: const EdgeInsets.all(20),
                borderRadius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Savings Overview',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Saved', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyFormatter.formatCents(totalSaved),
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Combined Target', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyFormatter.formatCents(totalTarget),
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: overallPct,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        color: AppTheme.incomeColorDark,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(overallPct * 100).round()}% overall progress',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Active Goals',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Savings goals list
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: goals.length,
                itemBuilder: (context, index) {
                  final goal = goals[index];
                  final goalColor = hexToColor(goal.color);
                  final goalPct = goal.targetAmount > 0 
                      ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
                      : 0.0;
                  final daysLeft = _calculateDaysRemaining(goal.targetDate);

                  return TactileSpringContainer(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => SavingsGoalDetailSheet(goal: goal),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        color: isDark
                            ? goalColor.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.65),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(width: 4, color: goalColor),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        // Circular Progress Ring
                                        SizedBox(
                                          height: 48,
                                          width: 48,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              PieChart(PieChartData(
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
                                                    value: (1.0 - goalPct) * 100,
                                                    color: goalColor.withOpacity(0.12),
                                                    radius: 4,
                                                    showTitle: false,
                                                  ),
                                                ],
                                              )),
                                              Icon(
                                                getGoalIcon(goal.icon),
                                                color: goalColor,
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                goal.name,
                                                style: theme.textTheme.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                'Deadline: ${goal.targetDate.day}/${goal.targetDate.month}/${goal.targetDate.year}',
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            if (goal.isCompleted)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.transferColorDark.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Text(
                                                  'COMPLETED',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w900,
                                                    color: AppTheme.transferColorDark,
                                                  ),
                                                ),
                                              )
                                            else
                                              Text(
                                                '$daysLeft days remaining',
                                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                                              ),
                                            const SizedBox(height: 4),
                                            GestureDetector(
                                              onTap: () {
                                                showModalBottomSheet(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  backgroundColor: Colors.transparent,
                                                  builder: (context) => SavingsGoalFormSheet(existingGoal: goal),
                                                );
                                              },
                                              child: Text(
                                                'Edit',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: theme.colorScheme.primary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          CurrencyFormatter.formatCents(goal.currentAmount),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          'Target: ' + CurrencyFormatter.formatCents(goal.targetAmount),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: goalPct,
                                        backgroundColor: goalColor.withOpacity(0.12),
                                        color: goalColor,
                                        minHeight: 6,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(goalPct * 100).round()}% completed',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
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
        );
      },
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (err, _) => Center(child: Text('Error loading savings goals: $err')),
    );
  }
}
