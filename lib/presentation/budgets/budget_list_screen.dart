import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/data/database/daos/budget_dao.dart';
import 'package:pesaflow/data/repositories/budget_repository.dart';
import 'package:pesaflow/domain/budget/budget_engine.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/budgets/widgets/savings_goal_form_sheet.dart';
import 'package:pesaflow/presentation/budgets/widgets/savings_goal_detail_sheet.dart';
import 'package:fl_chart/fl_chart.dart';

class BudgetActiveTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  set state(int value) => super.state = value;
}

final budgetActiveTabProvider = NotifierProvider<BudgetActiveTabNotifier, int>(() {
  return BudgetActiveTabNotifier();
});

class BudgetListScreen extends ConsumerWidget {
  const BudgetListScreen({super.key});

  Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
    return Colors.grey;
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'cart': return Icons.shopping_cart_rounded;
      case 'bus': return Icons.directions_bus_rounded;
      case 'home': return Icons.home_rounded;
      case 'zap': return Icons.electric_bolt_rounded;
      case 'phone': return Icons.phone_android_rounded;
      case 'heart': return Icons.favorite_rounded;
      case 'book': return Icons.menu_book_rounded;
      case 'film': return Icons.movie_rounded;
      case 'shopping-bag': return Icons.shopping_bag_rounded;
      case 'coffee': return Icons.coffee_rounded;
      case 'send': return Icons.send_rounded;
      case 'credit-card': return Icons.credit_card_rounded;
      case 'banknote': return Icons.payments_rounded;
      case 'piggy-bank': return Icons.savings_rounded;
      case 'briefcase': return Icons.work_rounded;
      case 'store': return Icons.storefront_rounded;
      default: return Icons.category_rounded;
    }
  }

  IconData _getGoalIcon(String iconName) {
    switch (iconName) {
      case 'savings': return Icons.savings_rounded;
      case 'laptop': return Icons.laptop_chromebook_rounded;
      case 'flight': return Icons.flight_takeoff_rounded;
      case 'home': return Icons.home_rounded;
      case 'car': return Icons.directions_car_rounded;
      case 'school': return Icons.school_rounded;
      case 'heart': return Icons.favorite_rounded;
      case 'gift': return Icons.card_giftcard_rounded;
      default: return Icons.savings_rounded;
    }
  }

  int _calculateDaysRemaining(DateTime targetDate) {
    final diff = targetDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeTab = ref.watch(budgetActiveTabProvider);
    final budgetProgressAsync = ref.watch(budgetProgressProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    activeTab == 0 ? 'Budgets' : 'Savings Goals',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
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
            ),

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
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(12),
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
                      ? (isDark ? const Color(0xFF2C2C2E) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: activeTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.4 : 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  'Category Budgets',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: activeTab == 0
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark ? Colors.grey[500] : Colors.grey[600]),
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
                      ? (isDark ? const Color(0xFF2C2C2E) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: activeTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.4 : 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  'Savings Goals',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: activeTab == 1
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark ? Colors.grey[500] : Colors.grey[600]),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F0F10) : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              border: Border.all(
                color: isDark ? const Color(0x12FFFFFF) : const Color(0x0F000000),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BUDGET OVERVIEW',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.grey[500],
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
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
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05),
                    color: totalSpent > totalAllocated
                        ? Colors.red[400]
                        : (isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF)),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  totalAllocated > 0
                      ? '${(totalSpent / totalAllocated * 100).round()}% used'
                      : '0% used',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
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

            final catColor = _hexToColor(bp.category.color);

            return TactileSpringContainer(
              onTap: () => context.go('/budgets/${bp.budget.id}'),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceContainerDark : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  border: Border.all(
                    color: isDark ? const Color(0x12FFFFFF) : const Color(0x1F000000),
                    width: 0.5,
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 5, color: catColor),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: catColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(bp.category.icon),
                                      color: catColor,
                                      size: 20,
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
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          bp.category.name,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: status.isOverBudget
                                              ? theme.colorScheme.error.withOpacity(0.1)
                                              : status.isOnTrack
                                                  ? (isDark ? const Color(0x1F00E5FF) : const Color(0x1F0A84FF))
                                                  : Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          status.paceLabel,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: status.isOverBudget
                                                ? theme.colorScheme.error
                                                : status.isOnTrack
                                                    ? (isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF))
                                                    : Colors.orange,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${status.daysLeft} days left',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  AmountText(
                                    amountInCents: bp.spentInPeriod,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: status.isOverBudget ? theme.colorScheme.error : null,
                                    ),
                                  ),
                                  AmountText(
                                    amountInCents: status.allocated,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: status.percentage.clamp(0.0, 1.0),
                                  backgroundColor: catColor.withOpacity(0.15),
                                  color: status.isOverBudget ? theme.colorScheme.error : catColor,
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(status.percentage * 100).round()}% used',
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F0F10) : Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  border: Border.all(
                    color: isDark ? const Color(0x12FFFFFF) : const Color(0x0F000000),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SAVINGS OVERVIEW',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey[500],
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
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
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.05),
                        color: const Color(0xFF30D158),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(overallPct * 100).round()}% overall progress',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
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
                  final goalColor = _hexToColor(goal.color);
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
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.surfaceContainerDark : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        border: Border.all(
                          color: isDark ? const Color(0x12FFFFFF) : const Color(0x1F000000),
                          width: 0.5,
                        ),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(width: 5, color: goalColor),
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
                                                _getGoalIcon(goal.icon),
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
                                                  color: const Color(0xFF30D158).withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Text(
                                                  'COMPLETED',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF30D158),
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

// ════════════════════════════════════════════════════════════════════════════
// PREMIUM TACTILE SPRING INTERACTION CONTAINER
// ════════════════════════════════════════════════════════════════════════════
class TactileSpringContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scaleFactor;

  const TactileSpringContainer({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleFactor = 0.96,
  });

  @override
  State<TactileSpringContainer> createState() => _TactileSpringContainerState();
}

class _TactileSpringContainerState extends State<TactileSpringContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}
