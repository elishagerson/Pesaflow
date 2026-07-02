import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/budget_dao.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/press_scale.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/state/insight_provider.dart';
import 'package:pesaflow/presentation/state/sms_stats_provider.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';
import 'package:pesaflow/presentation/common/widgets/morphing_insight_card.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:flutter/services.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/state/palette_provider.dart';
import 'package:pesaflow/presentation/common/widgets/motion/spring_button.dart';
import 'package:pesaflow/presentation/common/widgets/motion/haptic_pattern.dart';
import 'package:pesaflow/presentation/dashboard/widgets/add_account_dialog.dart';
import 'package:pesaflow/presentation/dashboard/widgets/workspace_dialogs.dart';
import 'package:pesaflow/presentation/dashboard/widgets/monthly_overview_section.dart';
import 'package:pesaflow/presentation/dashboard/widgets/sms_review_card.dart';
import 'package:pesaflow/presentation/dashboard/widgets/loan_overview_section.dart';
import 'package:pesaflow/presentation/dashboard/widgets/recurring_section.dart';
import 'package:pesaflow/presentation/dashboard/widgets/savings_section.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _selectedAccountId;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _showAddAccountDialog(BuildContext context) {
    showAddAccountDialog(context, ref);
  }

  String _formatCompact(int amountInCents) {
    final double value = amountInCents / 100.0;
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    }
    return value.toStringAsFixed(0);
  }

  Widget _buildSingleBudgetRing({
    required BuildContext context,
    required BudgetWithProgress bp,
    required Color catColor,
    required IconData catIcon,
    required double pct,
    required ThemeData theme,
    required bool isDark,
  }) {
    final remainingCents =
        (bp.currentPeriod?.allocated ?? bp.budget.amount) - bp.spentInPeriod;
    final remainingText = remainingCents >= 0
        ? '${_formatCompact(remainingCents)} left'
        : '${_formatCompact(remainingCents.abs())} over';
    final remainingColor = remainingCents >= 0
        ? (isDark ? Colors.grey[400] : Colors.grey[600])
        : AppTheme.expenseColor;

    return GlassCard(
      borderRadius: AppTheme.radiusCard,
      margin: const EdgeInsets.only(right: kSpacing12),
      elevation: CardElevation.low,
      accentColor: desaturateColor(hexToColor(bp.category.color)),
      onTap: () => context.go('/budgets/${bp.budget.id}'),
      padding: EdgeInsets.zero,
      child: Container(
        width: 105,
        padding: const EdgeInsets.symmetric(
          horizontal: kSpacing8,
          vertical: kSpacing8,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: kSpacing56,
              width: kSpacing56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Progress ring background track
                  SizedBox(
                    height: 52,
                    width: 52,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 4.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        desaturateColor(catColor).withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  // Progress ring foreground filled track
                  SizedBox(
                    height: 52,
                    width: 52,
                    child: CircularProgressIndicator(
                      value: pct,
                      strokeWidth: 5.5,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        remainingCents < 0 ? AppTheme.expenseColor : desaturateColor(catColor),
                      ),
                    ),
                  ),
                  // Centered Category Icon
                  Icon(
                    catIcon,
                    color: remainingCents < 0
                        ? AppTheme.expenseColor
                        : catColor,
                    size: 18,
                  ),
                ],
              ),
            ),
            const SizedBox(height: kSpacing10),
            Text(
              bp.budget.name,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : theme.colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: kSpacing4),
            Text(
              remainingText,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: remainingColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyOverview(ThemeData theme) {
    return const MonthlyOverviewSection();
  }

  Widget _buildSmsReviewCard(
    ThemeData theme,
    bool isDark,
    int pendingReviewCount,
  ) {
    return SmsReviewCard(
      theme: theme,
      isDark: isDark,
      pendingReviewCount: pendingReviewCount,
    );
  }

  Widget _buildBudgetRings(ThemeData theme, BuildContext context) {
    final budgetsAsync = ref.watch(budgetProgressProvider);
    final isDark = theme.brightness == Brightness.dark;

    return budgetsAsync.when(
      data: (budgets) {
        if (budgets.isEmpty) {
          return GlassCard(
            padding: const EdgeInsets.all(kSpacing24),
            borderRadius: AppTheme.radiusCard,
            elevation: CardElevation.low,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(kSpacing14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.donut_large_rounded,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: kSpacing16),
                Text(
                  'No Active Budgets',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: kSpacing8),
                Text(
                  'Set spending targets for Food, Shopping, Transport, and more to monitor your limits automatically.',
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
        return SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: budgets.length,
            itemBuilder: (_, i) {
              final bp = budgets[i];
              final pct = bp.percentage.clamp(0.0, 1.0);
              final catColor = hexToColor(bp.category.color);
              final catIcon = getCategoryIcon(bp.category.icon);

              return StaggeredFadeSlide(
                index: i,
                child: _buildSingleBudgetRing(
                  context: context,
                  bp: bp,
                  catColor: catColor,
                  catIcon: catIcon,
                  pct: pct,
                  theme: theme,
                  isDark: isDark,
                ),
              );
            },
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: kSpacing16),
        child: SkeletonCard(height: 140),
      ),
      error: (_, _) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: kSpacing16),
        child: SkeletonCard(height: 140),
      ),
    );
  }

  Widget _buildSavingsReminder(ThemeData theme) {
    return const SavingsReminder();
  }

  Widget _buildSavingsGoalsDashboard(ThemeData theme, BuildContext context) {
    return const SavingsSection();
  }

  Widget _buildLoanOverview(ThemeData theme, BuildContext context) {
    return const LoanOverviewSection();
  }

  void _showWorkspaceSelectorSheet(BuildContext context) {
    showWorkspaceSelectorSheet(context, ref);
  }

  Widget _buildRecurringExpensesDashboard(
    ThemeData theme,
    BuildContext context,
  ) {
    return const RecurringSection();
  }

  @override
  Widget build(BuildContext context) {
    final netWorth = ref.watch(netWorthProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final recentTransAsync = ref.watch(recentTransactionsStreamProvider);
    final budgetsAsync = ref.watch(budgetProgressProvider);
    final reviewQueueAsync = ref.watch(reviewQueueStreamProvider);
    final totalsAsync = ref.watch(monthlyTotalsProvider);
    final savingsGoalsAsync = ref.watch(savingsGoalsStreamProvider);
    final daysSinceLastSaveAsync = ref.watch(daysSinceLastSaveProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final showReminder = daysSinceLastSaveAsync.maybeWhen(
      data: (days) => days >= 5,
      orElse: () => false,
    );

    final showSavingsGoals = savingsGoalsAsync.maybeWhen(
      data: (goals) => goals.isNotEmpty,
      orElse: () => false,
    );

    // Active tracker properties for dynamic aesthetic blending
    final activeTrackerAsync = ref.watch(activeTrackerProvider);
    final trackerColor = activeTrackerAsync.maybeWhen(
      data: (tracker) => tracker != null
          ? hexToColor(tracker.color)
          : theme.colorScheme.primary,
      orElse: () => theme.colorScheme.primary,
    );
    final trackerName = activeTrackerAsync.maybeWhen(
      data: (tracker) => tracker != null ? tracker.name : 'Personal',
      orElse: () => 'Personal',
    );

    // Calculate budget overall spent percentage
    final budgets = budgetsAsync.value ?? [];
    double overallPct = 0.0;
    if (budgets.isNotEmpty) {
      double totalSpent = 0;
      double totalAllocated = 0;
      for (final bp in budgets) {
        totalSpent += bp.spentInPeriod;
        totalAllocated += bp.currentPeriod?.allocated ?? bp.budget.amount;
      }
      if (totalAllocated > 0) {
        overallPct = (totalSpent / totalAllocated).clamp(0.0, 1.0);
      }
    } else {
      // Dynamic fallback if no budgets are set: compute spent vs income from actual transactions!
      final totals = totalsAsync.value;
      if (totals != null) {
        final income = totals['income'] ?? 0;
        final expense = totals['expense'] ?? 0;
        if (income > 0) {
          overallPct = (expense / income).clamp(0.0, 1.0);
        } else if (expense > 0) {
          overallPct = 1.0; // Has expenses but no income logged -> 100% spent
        } else {
          overallPct = 0.0; // Fresh app startup, no transactions -> 0% spent
        }
      } else {
        overallPct = 0.0;
      }
    }

    final pendingReviewCount = reviewQueueAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    final accounts = accountsAsync.value ?? [];

    // Dynamic Balance card color properties matching HIG/M3 design brief
    final cardGradient = isDark
        ? LinearGradient(
            colors: [
              trackerColor.withValues(alpha: 0.35),
              const Color(0xFF05080C),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [trackerColor, const Color(0xFF062028)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final Color heroTextColor = Colors.white;
    final Color heroSubColor = isDark
        ? Colors.grey[400]!
        : Colors.white.withValues(alpha: 0.8);
    final Color pillBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.18);
    final Color pillBorder = isDark
        ? const Color(0x1AFFFFFF)
        : const Color(0x33FFFFFF);

    final paidLoansCountAsync = ref.watch(paidLoansCountProvider);
    final recsAsync = ref.watch(recurringTransactionsStreamProvider);
    final dueAsync = ref.watch(dueRecurringTransactionsProvider);

    // Dynamic Action Buttons for Collapsible Sections
    final budgetAction = budgetsAsync.maybeWhen(
      data: (budgets) => budgets.isEmpty
          ? TextButton.icon(
              onPressed: () => context.go('/budgets/add'),
              icon: const Icon(PesaFlowIcons.add, size: 16),
              label: const Text('Add Budget'),
            )
          : TextButton(
              onPressed: () => context.go('/budgets'),
              child: const Text('See All'),
            ),
      orElse: () => const SizedBox.shrink(),
    );

    final savingsAction = savingsGoalsAsync.maybeWhen(
      data: (goals) => goals.isNotEmpty
          ? TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.push('/savings-goals');
              },
              child: const Text('See All'),
            )
          : null,
      orElse: () => null,
    );

    final subscriptionsAction = recsAsync.maybeWhen(
      data: (recs) {
        final expenses = recs
            .where((r) => r.type == 'expense' && r.status == 'active')
            .toList();
        if (expenses.isEmpty) {
          return TextButton(
            onPressed: () => context.push('/recurring'),
            child: const Text('Manage'),
          );
        }
        final due = dueAsync.asData?.value ?? [];
        final dueExpensesCount = due.where((d) => d.type == 'expense').length;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dueExpensesCount > 0)
              Container(
                margin: const EdgeInsets.only(right: kSpacing8),
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacing10,
                  vertical: kSpacing4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$dueExpensesCount due',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFFF6B35),
                  ),
                ),
              ),
            TextButton(
              onPressed: () => context.push('/recurring'),
              child: const Text('Manage'),
            ),
          ],
        );
      },
      orElse: () => TextButton(
        onPressed: () => context.push('/recurring'),
        child: const Text('Manage'),
      ),
    );

    final loansAction = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        paidLoansCountAsync.maybeWhen(
          data: (count) => count > 0
              ? Padding(
                  padding: const EdgeInsets.only(right: kSpacing8),
                  child: Text(
                    '$count paid',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF609F8A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
          orElse: () => const SizedBox.shrink(),
        ),
        TextButton(
          onPressed: () => context.go('/loans'),
          child: const Text('See All'),
        ),
      ],
    );

    final activeCount = recsAsync.maybeWhen(
      data: (recs) =>
          recs.where((r) => r.type == 'expense' && r.status == 'active').length,
      orElse: () => 0,
    );

    return Scaffold(
      appBar: IosNavBar(
        title: _getGreeting(),
        largeTitle: true,
        leading: TactileSpringContainer(
          onTap: () => _showWorkspaceSelectorSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: kSpacing14,
              vertical: kSpacing8,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.05),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: trackerColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: kSpacing8),
                Text(
                  trackerName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: kSpacing4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TactileSpringContainer(
            onTap: () => ref.read(paletteVisibilityProvider.notifier).toggle(),
            child: Container(
              padding: const EdgeInsets.all(kSpacing10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.03),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 0.8,
                ),
              ),
              child: Icon(
                Icons.search_rounded,
                color: isDark ? Colors.white : Colors.black,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: kSpacing8),
          TactileSpringContainer(
            onTap: () => context.go('/settings'),
            child: Container(
              padding: const EdgeInsets.all(kSpacing10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.03),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 0.8,
                ),
              ),
              child: Icon(
                Icons.person_outline_rounded,
                color: isDark ? Colors.white : Colors.black,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: kSpacing8),
          TactileSpringContainer(
            onTap: () => context.push('/sms-review'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(kSpacing10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.03),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.06),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    size: 20,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                if (pendingReviewCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kSpacing4,
                        vertical: kSpacing2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF453A),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: isDark ? Colors.black : Colors.white,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '$pendingReviewCount',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: const Color(0xFF0F4C5C),
          backgroundColor: const Color(0xFFF5F6F8),
          onRefresh: () async {
            ref.invalidate(monthlyTotalsProvider);
            ref.invalidate(netWorthProvider);
            ref.invalidate(accountsStreamProvider);
            ref.invalidate(budgetProgressProvider);
            ref.invalidate(recentTransactionsStreamProvider);
            ref.invalidate(reviewQueueStreamProvider);
            ref.invalidate(savingsGoalsStreamProvider);
          },
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(
              left: kSpacing16,
              right: kSpacing16,
              top: kSpacing4,
              bottom: kSpacing16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 2. Balance Hero Card — "Your Money" ──
                StaggeredFadeSlide(
                  index: 0,
                  child: _AnimatedHeroGradient(
                    trackerColor: trackerColor,
                    isDark: isDark,
                    cardGradient: cardGradient,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(kSpacing24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        border: Border.all(
                          color: isDark
                              ? trackerColor.withValues(alpha: 0.25)
                              : trackerColor.withValues(alpha: 0.12),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: trackerColor.withValues(alpha: isDark ? 0.2 : 0.15),
                            blurRadius: 40,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Brand & Budget Gauge Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'pesa',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 19,
                                    color: isDark
                                        ? const Color(0xFF0F4C5C)
                                        : Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  'flow',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w300,
                                    fontSize: 19,
                                    color: heroTextColor,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                            // Dynamic Spent Progress Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: kSpacing10,
                                vertical: kSpacing4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    height: kSpacing12,
                                    width: kSpacing12,
                                    child: CircularProgressIndicator(
                                      value: overallPct,
                                      strokeWidth: 2,
                                      backgroundColor: Colors.white24,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        overallPct > 0.9
                                            ? const Color(0xFFFF453A)
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: kSpacing6),
                                  Text(
                                    '${(overallPct * 100).round()}% SPENT',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: heroTextColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: kSpacing24),
                        // Title Label & Main Value
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: kSpacing6),
                            Text(
                              _selectedAccountId != null
                                  ? (accounts
                                        .firstWhere(
                                          (a) => a.id == _selectedAccountId,
                                          orElse: () => accounts.first,
                                        )
                                        .name
                                        .toUpperCase())
                                  : 'TOTAL NET WORTH',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: heroSubColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: kSpacing8),
                        AmountText(
                          amountInCents: _selectedAccountId != null
                              ? (accounts
                                    .firstWhere(
                                      (a) => a.id == _selectedAccountId,
                                      orElse: () => accounts.first,
                                    )
                                    .balance)
                              : netWorth,
                          useMonospace: false,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 42,
                            color: heroTextColor,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: kSpacing24),
                        Divider(height: 0.5, thickness: 0.5, color: pillBorder),

                        // Dynamic scrolling Account Pills in the Balance Hero Card
                        if (accounts.isNotEmpty) ...[
                          const SizedBox(height: kSpacing18),
                          SizedBox(
                            height: 36,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: accounts.length,
                              itemBuilder: (context, index) {
                                final account = accounts[index];
                                final isSelected =
                                    _selectedAccountId == account.id;

                                return Padding(
                                  padding: EdgeInsets.only(
                                    right: kSpacing8,
                                    left: index == 0 ? kSpacing2 : 0.0,
                                  ),
                                  child: TactileSpringContainer(
                                    onTap: () {
                                      setState(() {
                                        if (_selectedAccountId == account.id) {
                                          _selectedAccountId =
                                              null; // Clear filter
                                        } else {
                                          _selectedAccountId =
                                              account.id; // Apply filter
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: kSpacing14,
                                        vertical: kSpacing6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? (isDark
                                                  ? trackerColor.withValues(
                                                      alpha: 0.35,
                                                    )
                                                  : Colors.white)
                                            : pillBg,
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                        border: Border.all(
                                          color: isSelected
                                              ? (isDark
                                                    ? trackerColor
                                                    : Colors.white)
                                              : pillBorder,
                                          width: isSelected ? 1.5 : 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            getAccountIcon(account.icon),
                                            size: 14,
                                            color: isSelected
                                                ? (isDark
                                                      ? Colors.white
                                                      : trackerColor)
                                                : heroTextColor,
                                          ),
                                          const SizedBox(width: kSpacing6),
                                          Text(
                                            account.name,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: isSelected
                                                      ? (isDark
                                                            ? Colors.white
                                                            : trackerColor)
                                                      : heroTextColor,
                                                ),
                                          ),
                                          const SizedBox(width: kSpacing8),
                                          Text(
                                            _formatCompact(account.balance),
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  fontFamily: 'monospace',
                                                  fontWeight: FontWeight.bold,
                                                  color: isSelected
                                                      ? (isDark
                                                            ? Colors.white
                                                                  .withValues(
                                                                    alpha: 0.9,
                                                                  )
                                                            : trackerColor
                                                                  .withValues(
                                                                    alpha: 0.9,
                                                                  ))
                                                      : heroTextColor
                                                            .withValues(
                                                              alpha: 0.8,
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
                          ),
                        ] else ...[
                          const SizedBox(height: kSpacing18),
                          Center(
                            child: Text(
                              'No active accounts. Tap Add Account below to start.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: heroSubColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                ),
                const SizedBox(height: kSpacing16),

                // ── 3. High-Contrast Action Buttons ──
                StaggeredFadeSlide(
                  index: 1,
                  child: Row(
                    children: [
                      Expanded(
                        child: PressScale(
                          onTap: () => context.go('/transactions/add'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: kSpacing16,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(
                                      0xFF1B1C22,
                                    ).withValues(alpha: 0.8)
                                  : Colors.black,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: isDark
                                    ? trackerColor.withValues(alpha: 0.4)
                                    : Colors.black,
                                width: 1.0,
                              ),
                              boxShadow: isDark
                                  ? [
                                      BoxShadow(
                                        color: trackerColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        blurRadius: 10,
                                        spreadRadius: 0.5,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  PesaFlowIcons.add,
                                  color: isDark ? trackerColor : Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: kSpacing6),
                                Text(
                                  'Add transaction',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: isDark ? trackerColor : Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: kSpacing12),
                      Expanded(
                        child: TactileSpringContainer(
                          onTap: () => _showAddAccountDialog(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: kSpacing16,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(
                                      0xFF1B1C22,
                                    ).withValues(alpha: 0.8)
                                  : const Color(0xFFE5E5EA),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0x10FFFFFF)
                                    : const Color(0x0F000000),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  PesaFlowIcons.wallet,
                                  color: isDark ? Colors.white : Colors.black,
                                  size: 18,
                                ),
                                const SizedBox(width: kSpacing6),
                                Text(
                                  'Add account',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: isDark
                                        ? Colors.white
                                        : theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: kSpacing20),

                // ── 3b. Quick Actions ──
                StaggeredFadeSlide(
                  index: 2,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: kSpacing20),
                    child: Row(
                      children: [
                        _QuickActionButton(
                          icon: PesaFlowIcons.expense,
                          label: 'Expense',
                          color: const Color(0xFFEF4444),
                          onTap: () => context.go('/transactions/add'),
                        ),
                        const SizedBox(width: kSpacing10),
                        _QuickActionButton(
                          icon: PesaFlowIcons.income,
                          label: 'Income',
                          color: const Color(0xFF10B981),
                          onTap: () => context.go('/transactions/add'),
                        ),
                        const SizedBox(width: kSpacing10),
                        _QuickActionButton(
                          icon: PesaFlowIcons.transfer,
                          label: 'Transfer',
                          color: const Color(0xFF6366F1),
                          onTap: () => context.go('/transactions/add'),
                        ),
                        const SizedBox(width: kSpacing10),
                        _QuickActionButton(
                          icon: PesaFlowIcons.goal,
                          label: 'Goal',
                          color: const Color(0xFFD4942D),
                          onTap: () => context.go('/savings-goals/add'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: kSpacing20),

                // ── SMS auto-categorization count ──
                Consumer(
                  builder: (context, ref, _) {
                    final smsCountAsync = ref.watch(todaySmsCountProvider);
                    return smsCountAsync.when(
                      data: (count) {
                        if (count == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: EdgeInsets.only(
                            top: kSpacing12,
                            left: kSpacing20,
                            right: kSpacing20,
                          ),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: kSpacing16,
                              vertical: kSpacing12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F4C5C).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF0F4C5C).withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.message_rounded,
                                  size: 18,
                                  color: const Color(0xFF0F4C5C),
                                ),
                                SizedBox(width: kSpacing10),
                                Expanded(
                                  child: Text(
                                    'Auto-categorized $count message${count == 1 ? '' : 's'} today  ↗',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF0F4C5C),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      error: (_, _) => const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                    );
                  },
                ),
                const SizedBox(height: kSpacing12),

                // ── 3. Insights — contextual nudges ──
                _CollapsibleSection(
                  title: 'Insights',
                  icon: Icons.lightbulb_outline_rounded,
                  child: _InsightsCarousel(),
                ),
                const SizedBox(height: kSpacing20),

                // ── 4. Monthly Overview — "How your money moved" ──
                // (StaggeredFadeSlide indices below are scoped per-column, not sequential)
                StaggeredFadeSlide(
                  index: 2,
                  child: _CollapsibleSection(
                    title: 'Monthly Overview',
                    icon: PesaFlowIcons.income,
                    child: _buildMonthlyOverview(theme),
                  ),
                ),
                const SizedBox(height: kSpacing20),

                // ── 5. Recent Activity — "The transactions behind it" ──
                _CollapsibleSection(
                  title: 'Recent Activity',
                  icon: Icons.history_rounded,
                  action: TextButton(
                    onPressed: () {
                      context.go('/transactions');
                    },
                    child: const Text('See All'),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Clear account filter chip row if _selectedAccountId is active
                      if (_selectedAccountId != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                            top: kSpacing4,
                            bottom: kSpacing12,
                          ),
                          child: Row(
                            children: [
                              InputChip(
                                label: Text(
                                  'Filtered by: ${accounts.firstWhere(
                                    (a) => a.id == _selectedAccountId,
                                    orElse: () => Account(id: '', name: 'Account', type: '', balance: 0, icon: 'wallet', sortOrder: 0, isArchived: false, createdAt: DateTime.now()),
                                  ).name}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                backgroundColor: theme.colorScheme.primary
                                    .withValues(alpha: 0.08),
                                side: BorderSide(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                  width: 0.8,
                                ),
                                deleteIcon: Icon(
                                  Icons.cancel_rounded,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                onDeleted: () {
                                  setState(() {
                                    _selectedAccountId = null;
                                  });
                                },
                                onPressed: () {
                                  setState(() {
                                    _selectedAccountId = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: kSpacing4),
                      ],

                      recentTransAsync.when(
                        data: (transactions) {
                          // Client-side dynamic filtering of recent transactions by account
                          final filteredTransactions =
                              _selectedAccountId == null
                              ? transactions
                              : transactions
                                    .where(
                                      (t) =>
                                          t.transaction.accountId ==
                                          _selectedAccountId,
                                    )
                                    .toList();

                          if (filteredTransactions.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: kSpacing40,
                              ),
                              decoration: BoxDecoration(
                                color: theme.brightness == Brightness.dark
                                    ? AppTheme.surfaceContainerDark
                                    : AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusCard,
                                ),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0x12FFFFFF)
                                      : const Color(0x0F000000),
                                  width: 0.5,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    PesaFlowIcons.transactions,
                                    size: 40,
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(height: kSpacing12),
                                  Text(
                                    'No transactions found.',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: kSpacing4),
                                  Text(
                                    _selectedAccountId == null
                                        ? 'Your offline financial logs will display here.'
                                        : 'No activity recorded for this specific account.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredTransactions.length,
                            itemBuilder: (context, index) {
                              final item = filteredTransactions[index];
                              final trans = item.transaction;

                              AmountType amtType = AmountType.neutral;
                              if (trans.type.toLowerCase() == 'income') {
                                amtType = AmountType.income;
                              } else if (trans.type.toLowerCase() ==
                                      'expense' ||
                                  trans.type.toLowerCase() == 'airtime' ||
                                  trans.type.toLowerCase() == 'fee') {
                                amtType = AmountType.expense;
                              }

                              return StaggeredFadeSlide(
                                index: index,
                                child: Dismissible(
                                  key: Key(trans.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(
                                      right: kSpacing20,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.error,
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusCard,
                                      ),
                                    ),
                                    child: const Icon(
                                      PesaFlowIcons.delete,
                                      color: Colors.white,
                                    ),
                                  ),
                                  onDismissed: (_) async {
                                    await ref
                                        .read(transactionRepositoryProvider)
                                        .deleteTransaction(trans.id);
                                    ref.invalidate(
                                      recentTransactionsStreamProvider,
                                    );
                                    ref.invalidate(accountsStreamProvider);
                                    ref.invalidate(netWorthProvider);
                                    ref.invalidate(monthlyTotalsProvider);
                                  },
                                  child: TactileSpringContainer(
                                    onTap: () => context.push(
                                      '/transactions/${trans.id}',
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: kSpacing6,
                                      ),
                                      padding: const EdgeInsets.all(kSpacing16),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(
                                                0xFF1B1C22,
                                              ).withValues(alpha: 0.65)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0x10FFFFFF)
                                              : const Color(0x0F000000),
                                          width: 0.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: isDark ? 0.2 : 0.03,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          // Category Icon Container (Squircle Style)
                                          Container(
                                            width: 46,
                                            height: 46,
                                            decoration: BoxDecoration(
                                          color: desaturateColor(
                                            hexToColor(
                                              item.category.color,
                                            ),
                                          ).withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            getCategoryIcon(
                                              item.category.icon,
                                            ),
                                            color: hexToColor(
                                              item.category.color,
                                            ),
                                                size: 22,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: kSpacing14),
                                          // Content
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  trans.description.isNotEmpty
                                                      ? trans.description
                                                      : item.category.name,
                                                  style: theme
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: isDark
                                                            ? Colors.white
                                                            : theme
                                                                  .colorScheme
                                                                  .onSurface,
                                                      ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(
                                                  height: kSpacing4,
                                                ),
                                                Row(
                                                  children: [
                                                    Text(
                                                      item.account?.name ??
                                                          'Offline',
                                                      style: theme
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                            color: theme
                                                                .colorScheme
                                                                .onSurface
                                                                .withValues(
                                                                  alpha: 0.6,
                                                                ),
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                    const SizedBox(
                                                      width: kSpacing8,
                                                    ),
                                                    Text(
                                                      trans.createdAt
                                                          .toString()
                                                          .substring(0, 10),
                                                      style: theme
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
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
                                          const SizedBox(width: kSpacing12),
                                          // Amount
                                          AmountText(
                                            amountInCents: trans.amount,
                                            type: amtType,
                                            showDecimals: true,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 16,
                                                  color:
                                                      amtType ==
                                                          AmountType.income
                                                      ? AppTheme
                                                            .transferColorDark
                                                      : (amtType ==
                                                                AmountType
                                                                    .expense
                                                            ? const Color(
                                                                0xFFFF453A,
                                                              )
                                                            : theme
                                                                  .colorScheme
                                                                  .onSurfaceVariant),
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        loading: () => Column(
                          children: const [
                            SkeletonCard(height: 80),
                            SizedBox(height: kSpacing8),
                            SkeletonCard(height: 80),
                          ],
                        ),
                        error: (err, _) =>
                            Center(child: Text('Error loading activity: $err')),
                      ),
                    ],
                  ),
                ),

                // ── 6. Budget Progress — "Your Financial Targets" ──
                _CollapsibleSection(
                  title: 'Budget Progress',
                  icon: PesaFlowIcons.budgets,
                  subtitle: 'LIMITS & SPENDING',
                  action: budgetAction,
                  child: _buildBudgetRings(theme, context),
                ),

                if (showSavingsGoals) ...[
                  const SizedBox(height: kSpacing20),
                  StaggeredFadeSlide(
                    index: 4,
                    child: _CollapsibleSection(
                      title: 'Savings Goals',
                      icon: PesaFlowIcons.target,
                      subtitle: 'ACTIVE EMERGENCY VAULT',
                      action: savingsAction,
                      child: _buildSavingsGoalsDashboard(theme, context),
                    ),
                  ),
                ],

                if (showReminder) ...[
                  const SizedBox(height: kSpacing20),
                  StaggeredFadeSlide(
                    index: 5,
                    child: _buildSavingsReminder(theme),
                  ),
                ],

                const SizedBox(height: kSpacing20),

                // ── 6. Recurring Flows ──
                StaggeredFadeSlide(
                  index: 6,
                  child: _CollapsibleSection(
                    title: 'Recurring Flows',
                    icon: PesaFlowIcons.calendar,
                    subtitle: activeCount > 0
                        ? '$activeCount active'
                        : 'track recurring bills',
                    action: subscriptionsAction,
                    child: _buildRecurringExpensesDashboard(theme, context),
                  ),
                ),

                const SizedBox(height: kSpacing20),

                // ── 8. Loan / Debt Overview ──
                StaggeredFadeSlide(
                  index: 7,
                  child: _CollapsibleSection(
                    title: 'Loans',
                    icon: Icons.credit_score_rounded,
                    subtitle: 'DEBT OVERVIEW',
                    action: loansAction,
                    child: _buildLoanOverview(theme, context),
                  ),
                ),

                const SizedBox(height: kSpacing20),

                // ── 9. SMS Auto-Tracking — "How it works" ──
                StaggeredFadeSlide(
                  index: 8,
                  child: _CollapsibleSection(
                    title: 'SMS Tracking',
                    icon: Icons.message_rounded,
                    child: _buildSmsReviewCard(
                      theme,
                      isDark,
                      pendingReviewCount,
                    ),
                  ),
                ),
                const SizedBox(height: kSpacing24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsibleSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget? action;
  final Widget child;

  const _CollapsibleSection({
    required this.title,
    required this.icon,
    this.subtitle,
    this.action,
    required this.child,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: kSpacing8,
                    right: kSpacing8,
                    top: kSpacing6,
                    bottom: kSpacing6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            widget.icon,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: kSpacing8),
                          Text(
                            widget.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: kSpacing6),
                          AnimatedRotation(
                            turns: _isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: kSpacing2),
                        Padding(
                          padding: const EdgeInsets.only(left: 26.0),
                          child: Text(
                            widget.subtitle!.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (widget.action != null) ...[
              const SizedBox(width: kSpacing8),
              widget.action!,
            ],
          ],
        ),
        const SizedBox(height: kSpacing8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kSpacing8),
          child: AnimatedCrossFade(
            firstChild: widget.child,
            secondChild: const SizedBox.shrink(),
            crossFadeState: _isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
          ),
        ),
      ],
    );
  }
}

class _InsightsCarousel extends ConsumerStatefulWidget {
  const _InsightsCarousel();

  @override
  ConsumerState<_InsightsCarousel> createState() => _InsightsCarouselState();
}

class _InsightsCarouselState extends ConsumerState<_InsightsCarousel> {
  final Set<int> _expandedIndices = {};

  @override
  Widget build(BuildContext context) {
    final insightsAsync = ref.watch(dynamicInsightsProvider);

    return insightsAsync.when(
      data: (insights) {
        if (insights.isEmpty) {
          return const SizedBox.shrink();
        }
        // Animated height between 114 (all collapsed) and 176 (any expanded)
        final double height = _expandedIndices.isNotEmpty ? 176.0 : 114.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 8),
            clipBehavior: Clip.none,
            itemCount: insights.length,
            separatorBuilder: (_, _) => const SizedBox(width: kSpacing10),
            itemBuilder: (_, i) {
              final isExpanded = _expandedIndices.contains(i);
              return Align(
                alignment: Alignment.topCenter,
                child: MorphingInsightCard(
                  data: insights[i],
                  index: i,
                  expanded: isExpanded,
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedIndices.remove(i);
                      } else {
                        _expandedIndices.add(i);
                      }
                    });
                  },
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _AnimatedHeroGradient extends StatefulWidget {
  final Color trackerColor;
  final bool isDark;
  final LinearGradient cardGradient;
  final Widget child;

  const _AnimatedHeroGradient({
    required this.trackerColor,
    required this.isDark,
    required this.cardGradient,
    required this.child,
  });

  @override
  State<_AnimatedHeroGradient> createState() => _AnimatedHeroGradientState();
}

class _AnimatedHeroGradientState extends State<_AnimatedHeroGradient>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final shiftedBegin = Alignment(
          -0.3 + t * 0.6,
          -0.3 + t * 0.6,
        );
        final shiftedEnd = Alignment(
          0.3 - t * 0.6,
          0.3 - t * 0.6,
        );
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: widget.isDark
                ? LinearGradient(
                    colors: [
                      widget.trackerColor.withValues(alpha: 0.12 + t * 0.08),
                      const Color(0xFF0F1013),
                    ],
                    begin: shiftedBegin,
                    end: shiftedEnd,
                  )
                : LinearGradient(
                    colors: [
                      widget.trackerColor.withValues(alpha: 0.08 + t * 0.06),
                      const Color(0xFFF5F3F0),
                    ],
                    begin: shiftedBegin,
                    end: shiftedEnd,
                  ),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SpringButton(
        haptic: HapticType.selection,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: kSpacing12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              SizedBox(height: kSpacing4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
