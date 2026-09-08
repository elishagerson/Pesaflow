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
import 'package:pesaflow/data/database/daos/budget_group_dao.dart';
import 'package:pesaflow/domain/models/enums.dart';
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
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/data/repositories/budget_repository.dart';
import 'package:pesaflow/data/repositories/budget_group_repository.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/presentation/common/widgets/spring_sheet_route.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/ios_large_title_header.dart';

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

class BudgetListScreen extends ConsumerStatefulWidget {
  const BudgetListScreen({super.key});

  @override
  ConsumerState<BudgetListScreen> createState() => _BudgetListScreenState();
}

class _BudgetListScreenState extends ConsumerState<BudgetListScreen> {
  final ScrollController _scrollController = ScrollController();

  int _calculateDaysRemaining(DateTime targetDate) {
    final diff = targetDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.offset <= 0) return;
    if (context.isReducedMotion) {
      _scrollController.jumpTo(0);
    } else {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(scrollToTopProvider, (_, _) => _scrollToTop());
    final theme = Theme.of(context);
    final activeTab = ref.watch(budgetActiveTabProvider);

    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // ── Floating Top Bar ──
            IosLargeTitleHeader(
              title: activeTab == 0 ? 'Budgets' : 'Savings Goals',
              scrollController: _scrollController,
              actions: [
                if (activeTab == 0) ...[
                  TactileSpringContainer(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push('/budgets/setup');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.appColors.onBgColor.withValues(
                          alpha: 0.1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        PesaFlowIcons.settings,
                        color: context.appColors.onBgColor,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: kSpacing8),
                ],
                TactileSpringContainer(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (activeTab == 0) {
                      context.push('/budgets/add');
                    } else {
                      showSpringSheet(
                        context,
                        isScrollControlled: true,
                        builder: (context) =>
                            const SavingsGoalFormSheet(),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.appColors.onBgColor.withValues(
                        alpha: 0.1,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PesaFlowIcons.add,
                      color: context.appColors.onBgColor,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),

            // HIG Segmented Control Slider
            _buildSegmentedControl(context, ref),

            // Main Content Area
            Expanded(
              child: activeTab == 0
                  ? _buildCategoryBudgets(context, ref, theme)
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
                            color: context.appColors.shadowSubtle,
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
                            color: context.appColors.shadowSubtle,
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
  // 1. CATEGORY BUDGETS RENDERER (Hierarchical Groups + Hero)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildCategoryBudgets(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    final groupsAsync = ref.watch(budgetGroupsProvider);
    final standaloneAsync = ref.watch(standaloneBudgetsProvider);
    final allBudgetsAsync = ref.watch(budgetProgressProvider);
    final monthlyIncomeAsync = ref.watch(monthlyIncomeProvider);
    final budgetRuleAsync = ref.watch(budgetRuleProvider);

    if (groupsAsync.isLoading && !groupsAsync.hasValue) {
      return const Padding(
        padding: EdgeInsets.all(kSpacing16),
        child: Column(
          children: [
            SkeletonCard(height: 160),
            SizedBox(height: kSpacing12),
            SkeletonCard(height: 120),
            SizedBox(height: kSpacing12),
            SkeletonCard(height: 120),
            SizedBox(height: kSpacing12),
            SkeletonCard(height: 120),
          ],
        ),
      );
    }

    final groups = groupsAsync.value ?? [];
    final standaloneBudgets = standaloneAsync.value ?? [];
    final allBudgets = allBudgetsAsync.value ?? [];
    final monthlyIncome = monthlyIncomeAsync.value ?? 0;
    final budgetRule = budgetRuleAsync.value;

    final onSurface = theme.colorScheme.onSurface;

    Future<void> onRefresh() async {
      ref.invalidate(budgetGroupsProvider);
      ref.invalidate(standaloneBudgetsProvider);
      ref.invalidate(budgetProgressProvider);
      ref.invalidate(monthlyIncomeProvider);
      ref.invalidate(budgetRuleProvider);
      ref.invalidate(savingsGoalsStreamProvider);
      ref.invalidate(categoriesFutureProvider);
    }

    // CASE 1: Has budget groups (Modern hierarchical model)
    if (groups.isNotEmpty) {
      return RefreshIndicator(
        color: theme.colorScheme.primary,
        backgroundColor: theme.scaffoldBackgroundColor,
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          controller: _scrollController,
          key: const PageStorageKey('budget_list_groups'),
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
              _buildPlanHeroCard(
                context,
                theme,
                groups,
                monthlyIncome,
                budgetRule,
                ref,
              ),
              const SizedBox(height: kSpacing20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'BUDGET GROUPS',
                    style: context.ts(
                      12,
                      fontWeight: FontWeight.w700,
                      color: onSurface.withValues(alpha: 0.5),
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    '${groups.length} groups',
                    style: context.ts(
                      12,
                      fontWeight: FontWeight.w600,
                      color: onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: kSpacing12),
              ...groups.map((g) => _buildGroupCard(context, theme, g, ref)),
              if (standaloneBudgets.isNotEmpty) ...[
                const SizedBox(height: kSpacing24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'STANDALONE BUDGETS',
                      style: context.ts(
                        12,
                        fontWeight: FontWeight.w700,
                        color: onSurface.withValues(alpha: 0.5),
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      '${standaloneBudgets.length} envelopes',
                      style: context.ts(
                        12,
                        fontWeight: FontWeight.w600,
                        color: onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: kSpacing12),
                ...standaloneBudgets.map(
                  (bp) => _buildBudgetCard(context, theme, bp, ref),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // CASE 2: No groups, but has legacy flat budgets
    if (allBudgets.isNotEmpty) {
      return RefreshIndicator(
        color: theme.colorScheme.primary,
        backgroundColor: theme.scaffoldBackgroundColor,
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          controller: _scrollController,
          key: const PageStorageKey('budget_list_legacy'),
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
              _buildUpgradeBanner(context, theme),
              const SizedBox(height: kSpacing16),
              ...allBudgets.map(
                (bp) => _buildBudgetCard(context, theme, bp, ref),
              ),
            ],
          ),
        ),
      );
    }

    // CASE 3: Empty state
    return _buildEmptyBudgets(context, theme);
  }

  Widget _buildPlanHeroCard(
    BuildContext context,
    ThemeData theme,
    List<BudgetGroupWithChildren> groups,
    int monthlyIncome,
    String? budgetRuleName,
    WidgetRef ref,
  ) {
    final onSurface = theme.colorScheme.onSurface;
    final totalAllocated = groups.fold<int>(
      0,
      (sum, g) => sum + g.group.allocatedAmount,
    );
    final totalSpent = groups.fold<int>(0, (sum, g) => sum + g.totalSpent);
    final overallPct = totalAllocated > 0
        ? (totalSpent / totalAllocated).clamp(0.0, 2.0)
        : 0.0;
    final isOverBudget = totalSpent > totalAllocated;

    String ruleLabel = 'Budget Plan';
    if (budgetRuleName != null) {
      final rule = BudgetRuleType.values
          .where((r) => r.name == budgetRuleName)
          .firstOrNull;
      if (rule != null) {
        ruleLabel = '${rule.displayName} Rule';
      }
    }

    return GlassCard(
      padding: const EdgeInsets.all(kSpacing20),
      borderRadius: AppTheme.radiusCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacing8,
                  vertical: kSpacing4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PesaFlowIcons.settings,
                      size: 13,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: kSpacing4),
                    Text(
                      ruleLabel,
                      style: context.ts(
                        11,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TactileSpringContainer(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/budgets/setup');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpacing10,
                    vertical: kSpacing4,
                  ),
                  decoration: BoxDecoration(
                    color: onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Edit Split',
                        style: context.ts(
                          11,
                          fontWeight: FontWeight.w600,
                          color: onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        PesaFlowIcons.chevronRight,
                        size: 14,
                        color: onSurface.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: kSpacing8),
              TactileSpringContainer(
                onTap: () => _showPlanOptions(context, ref, groups),
                child: Container(
                  padding: const EdgeInsets.all(kSpacing4),
                  decoration: BoxDecoration(
                    color: onSurface.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                    child: Icon(
                      PesaFlowIcons.more,
                      size: 16,
                      color: onSurface.withValues(alpha: 0.7),
                    ),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Spent this Month',
                    style: context.ts(
                      12,
                      fontWeight: FontWeight.w600,
                      color: onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: kSpacing4),
                  AmountText(
                    amountInCents: totalSpent,
                    style: context.ts(
                      28,
                      fontWeight: FontWeight.w900,
                      color: isOverBudget
                          ? context.appColors.expenseColor
                          : onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total Allocated',
                    style: context.ts(
                      12,
                      fontWeight: FontWeight.w600,
                      color: onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: kSpacing4),
                  AmountText(
                    amountInCents: totalAllocated,
                    style: context.ts(
                      18,
                      fontWeight: FontWeight.w700,
                      color: onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: kSpacing16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: SizedBox(
              height: 10,
              child: Row(
                children: groups.map((g) {
                  final type = BudgetGroupType.fromDbString(g.group.groupType);
                  final (_, color) = _groupVisuals(context, type);
                  final flex = (g.group.percentage * 100).round().clamp(1, 100);
                  return Expanded(
                    flex: flex,
                    child: Container(
                      color: color,
                      margin: const EdgeInsets.symmetric(horizontal: 0.5),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: kSpacing12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: groups.map((g) {
              final type = BudgetGroupType.fromDbString(g.group.groupType);
              final (_, color) = _groupVisuals(context, type);
              final pctLabel = '${(g.group.percentage * 100).round()}%';
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: kSpacing4),
                  Text(
                    '${g.group.name} ($pctLabel)',
                    style: context.ts(
                      11,
                      fontWeight: FontWeight.w600,
                      color: onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: kSpacing14),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            tween: Tween<double>(begin: 0, end: overallPct.clamp(0.0, 1.0)),
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: onSurface.withValues(alpha: 0.06),
                  color: isOverBudget
                      ? context.appColors.expenseColor
                      : (overallPct > 0.85
                            ? context.appColors.warningColor
                            : theme.colorScheme.primary),
                  minHeight: 6,
                ),
              );
            },
          ),
          const SizedBox(height: kSpacing6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(overallPct * 100).round()}% of total plan used',
                style: context.ts(
                  11,
                  fontWeight: FontWeight.w500,
                  color: onSurface.withValues(alpha: 0.5),
                ),
              ),
              if (monthlyIncome > 0)
                Text(
                  'Income: ${CurrencyFormatter.formatCents(monthlyIncome)}',
                  style: context.ts(
                    11,
                    fontWeight: FontWeight.w600,
                    color: onSurface.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showPlanOptions(
    BuildContext context,
    WidgetRef ref,
    List<BudgetGroupWithChildren> groups,
  ) async {
    final confirm = await ModernDialog.show<bool>(
      context: context,
      title: const Text('Delete Budget Plan?'),
      titleIcon: PesaFlowIcons.delete,
      iconColor: context.appColors.expenseColor,
      content: const Text(
        'This will remove the Needs, Wants, and Investments groups. Any category budgets inside will be preserved as standalone envelopes.',
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
          child: Text(
            'Delete Plan',
            style: TextStyle(color: context.appColors.expenseColor),
          ),
        ),
      ],
    );

    if (confirm != true || !context.mounted) return;

    try {
      final groupRepo = ref.read(budgetGroupRepositoryProvider);
      final settingsRepo = ref.read(settingsRepositoryProvider);

      await groupRepo.deleteAllGroups(keepSubBudgets: true);
      await settingsRepo.setSetting('budget_rule', '');

      ref.invalidate(budgetGroupsProvider);
      ref.invalidate(standaloneBudgetsProvider);
      ref.invalidate(activeBudgetsStreamProvider);
      ref.invalidate(budgetProgressProvider);
      ref.invalidate(budgetRuleProvider);

      if (context.mounted) {
        CustomToast.show(
          context,
          message: 'Budget plan deleted',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        CustomToast.show(
          context,
          message: 'Error deleting plan: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Widget _buildGroupCard(
    BuildContext context,
    ThemeData theme,
    BudgetGroupWithChildren g,
    WidgetRef ref,
  ) {
    final onSurface = theme.colorScheme.onSurface;
    final type = BudgetGroupType.fromDbString(g.group.groupType);
    final (icon, color) = _groupVisuals(context, type);
    final allocated = g.group.allocatedAmount;
    final spent = g.totalSpent;
    final isOver = spent > allocated;
    final pct = allocated > 0 ? (spent / allocated).clamp(0.0, 2.0) : 0.0;

    Color progressColor;
    if (isOver) {
      progressColor = context.appColors.expenseColor;
    } else if (pct > 0.85) {
      progressColor = context.appColors.warningColor;
    } else {
      progressColor = color;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: kSpacing12),
      child: Dismissible(
        key: ValueKey('group-dismiss-${g.group.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          final subCount = g.subBudgets.length;
          final contentText = subCount > 0
              ? 'Deleting the "${g.group.name}" group will preserve its $subCount sub-budget${subCount > 1 ? 's' : ''} as standalone envelopes.'
              : 'Are you sure you want to delete the "${g.group.name}" group?';
          return await ModernDialog.show<bool>(
            context: context,
            title: Text('Delete ${g.group.name} Group?'),
            titleIcon: PesaFlowIcons.delete,
            iconColor: context.appColors.expenseColor,
            content: Text(contentText),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(true),
                child: Text(
                  'Delete Group',
                  style: TextStyle(color: context.appColors.expenseColor),
                ),
              ),
            ],
          );
        },
        onDismissed: (direction) async {
          final repo = ref.read(budgetGroupRepositoryProvider);
          await repo.deleteGroup(g.group.id);
          ref.invalidate(budgetGroupsProvider);
          ref.invalidate(standaloneBudgetsProvider);
          ref.invalidate(activeBudgetsStreamProvider);
          ref.invalidate(budgetProgressProvider);
          if (context.mounted) {
            CustomToast.show(
              context,
              message: '"${g.group.name}" group deleted',
              type: ToastType.success,
            );
          }
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: kSpacing20),
          decoration: BoxDecoration(
            color: context.appColors.expenseColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          ),
          child: Icon(
            PesaFlowIcons.delete,
            color: context.appColors.expenseColor,
          ),
        ),
        child: TactileSpringContainer(
          onTap: () => context.push('/budgets/groups/${g.group.id}'),
          selectedColor: theme.colorScheme.onSurface,
          child: GlassCard(
            padding: const EdgeInsets.all(kSpacing16),
            borderRadius: AppTheme.radiusCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusInput,
                        ),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: kSpacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                g.group.name,
                                style: context.ts(
                                  17,
                                  fontWeight: FontWeight.w700,
                                  color: onSurface,
                                ),
                              ),
                              const SizedBox(width: kSpacing8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusPill,
                                  ),
                                ),
                                child: Text(
                                  '${(g.group.percentage * 100).round()}%',
                                  style: context.ts(
                                    10,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            g.subBudgets.isEmpty
                                ? 'No envelopes yet'
                                : '${g.subBudgets.length} envelopes',
                            style: context.ts(
                              12,
                              color: onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TactileSpringContainer(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/budgets/groups/${g.group.id}/add');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: onSurface.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          PesaFlowIcons.add,
                          size: 16,
                          color: onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    const SizedBox(width: kSpacing4),
                    Icon(
                      PesaFlowIcons.chevronRight,
                      size: 18,
                      color: onSurface.withValues(alpha: 0.35),
                    ),
                  ],
                ),
                const SizedBox(height: kSpacing14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        AmountText(
                          amountInCents: spent,
                          style: context.ts(
                            16,
                            fontWeight: FontWeight.w800,
                            color: isOver
                                ? context.appColors.expenseColor
                                : onSurface,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'of ${CurrencyFormatter.formatCents(allocated)}',
                          style: context.ts(
                            12,
                            color: onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${(pct * 100).round()}%',
                      style: context.ts(
                        13,
                        fontWeight: FontWeight.w700,
                        color: progressColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: kSpacing8),
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(begin: 0, end: pct.clamp(0.0, 1.0)),
                  builder: (context, value, _) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      child: LinearProgressIndicator(
                        value: value,
                        backgroundColor: onSurface.withValues(alpha: 0.05),
                        color: progressColor,
                        minHeight: 6,
                      ),
                    );
                  },
                ),
                if (g.subBudgets.isNotEmpty) ...[
                  const SizedBox(height: kSpacing10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: g.subBudgets.take(4).map((sub) {
                        final catColor = hexToColor(sub.category.color);
                        return Container(
                          margin: const EdgeInsets.only(right: kSpacing6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpacing8,
                            vertical: kSpacing4,
                          ),
                          decoration: BoxDecoration(
                            color: onSurface.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusPill,
                            ),
                            border: Border.all(
                              color: onSurface.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                getCategoryIcon(sub.category.icon),
                                size: 12,
                                color: catColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                sub.category.name,
                                style: context.ts(
                                  11,
                                  fontWeight: FontWeight.w500,
                                  color: onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                CurrencyFormatter.formatCents(
                                  sub.spentInPeriod,
                                ),
                                style: context.ts(
                                  10,
                                  fontWeight: FontWeight.w700,
                                  color: onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetCard(
    BuildContext context,
    ThemeData theme,
    BudgetWithProgress bp,
    WidgetRef ref,
  ) {
    final onSurface = theme.colorScheme.onSurface;
    final status = BudgetEngine.computeStatus(
      allocated: bp.currentPeriod?.allocated ?? bp.budget.amount,
      spent: bp.spentInPeriod,
      periodStart: bp.currentPeriod?.periodStart ?? bp.budget.startDate,
      periodEnd:
          bp.currentPeriod?.periodEnd ??
          DateTime.now().add(const Duration(days: 30)),
    );
    final catColor = hexToColor(bp.category.color);

    Color paceColor;
    if (status.isOverBudget) {
      paceColor = context.appColors.expenseColor;
    } else if (!status.isOnTrack) {
      paceColor = context.appColors.warningColor;
    } else {
      paceColor = context.appColors.incomeColor;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: kSpacing12),
      child: Dismissible(
        key: ValueKey('budget-dismiss-${bp.budget.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          return await ModernDialog.show<bool>(
            context: context,
            title: const Text('Delete Budget?'),
            titleIcon: PesaFlowIcons.delete,
            iconColor: context.appColors.expenseColor,
            content: Text(
              'Permanently remove the "${bp.budget.name}" budget and all its history?',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(true),
                child: Text(
                  'Delete',
                  style: TextStyle(color: context.appColors.expenseColor),
                ),
              ),
            ],
          );
        },
        onDismissed: (direction) async {
          final budget = bp.budget;
          final budgetRepo = ref.read(budgetRepositoryProvider);
          await budgetRepo.deleteBudget(budget.id);
          ref.invalidate(budgetGroupsProvider);
          ref.invalidate(standaloneBudgetsProvider);
          ref.invalidate(activeBudgetsStreamProvider);
          ref.invalidate(budgetProgressProvider);
          if (context.mounted) {
            CustomToast.show(
              context,
              message: '"${budget.name}" deleted',
              type: ToastType.success,
              duration: const Duration(seconds: 5),
              actionLabel: 'Undo',
              onAction: () async {
                await budgetRepo.createBudget(
                  name: budget.name,
                  categoryId: budget.categoryId,
                  period: budget.period,
                  amount: budget.amount,
                  rollover: budget.rollover,
                  rolloverType: budget.rolloverType,
                  rolloverCap: budget.rolloverCap,
                  startDate: budget.startDate,
                  notificationThreshold: budget.notificationThreshold,
                  groupId: budget.groupId,
                );
                ref.invalidate(budgetGroupsProvider);
                ref.invalidate(standaloneBudgetsProvider);
                ref.invalidate(activeBudgetsStreamProvider);
                ref.invalidate(budgetProgressProvider);
              },
            );
          }
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: kSpacing20),
          decoration: BoxDecoration(
            color: context.appColors.expenseColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          ),
          child: Icon(
            PesaFlowIcons.delete,
            color: context.appColors.expenseColor,
          ),
        ),
        child: Hero(
          tag: 'budget-${bp.budget.id}',
          child: TactileSpringContainer(
            onTap: () => context.push('/budgets/${bp.budget.id}'),
            selectedColor: theme.colorScheme.onSurface,
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
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusInput,
                          ),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                    color: paceColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
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
                                      color: onSurface.withValues(alpha: 0.5),
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
                                  color: onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                              AmountText(
                                amountInCents:
                                    bp.currentPeriod?.allocated ??
                                    bp.budget.amount,
                                style: context.ts(
                                  12,
                                  fontWeight: FontWeight.w700,
                                  color: onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpacing12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      tween: Tween<double>(
                        begin: 0,
                        end: status.percentage.clamp(0.0, 1.0),
                      ),
                      builder: (context, value, _) {
                        return LinearProgressIndicator(
                          value: value,
                          backgroundColor: onSurface.withValues(alpha: 0.05),
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
      ),
    );
  }

  Widget _buildUpgradeBanner(BuildContext context, ThemeData theme) {
    final onSurface = theme.colorScheme.onSurface;
    return GlassCard(
      padding: const EdgeInsets.all(kSpacing16),
      borderRadius: AppTheme.radiusCard,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(kSpacing10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusInput),
            ),
            child: Icon(
              PesaFlowIcons.settings,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: kSpacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set Up 50/30/20 Budget Plan',
                  style: context.ts(
                    14,
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Organize into Needs, Wants & Investments',
                  style: context.ts(
                    12,
                    color: onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: kSpacing8),
          TactileSpringContainer(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/budgets/setup');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: kSpacing12,
                vertical: kSpacing8,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              child: Text(
                'Get Started',
                style: context.ts(
                  12,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBudgets(BuildContext context, ThemeData theme) {
    return EmptyState(
      icon: PesaFlowIcons.budgets,
      title: 'No Budgets Yet',
      subtitle:
          'Set up a 50/30/20 budget plan based on your income, or create individual category envelopes.',
      illustration: PesaFlowIllustration.emptyBudgets(),
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TactileSpringContainer(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/budgets/setup');
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
                    PesaFlowIcons.income,
                    color: theme.colorScheme.onPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: kSpacing8),
                  Text(
                    'Set Up Budget Plan',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: kSpacing12),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/budgets/add');
            },
            child: Text(
              'Create Single Envelope Budget',
              style: context.ts(
                13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _groupVisuals(BuildContext context, BudgetGroupType type) {
    final appColors = context.appColors;
    return switch (type) {
      BudgetGroupType.needs => (PesaFlowIcons.home, appColors.needsColor),
      BudgetGroupType.wants => (
        PesaFlowIcons.shoppingBag,
        appColors.wantsColor,
      ),
      BudgetGroupType.investments => (
        PesaFlowIcons.income,
        appColors.investColor,
      ),
      BudgetGroupType.custom => (PesaFlowIcons.budgets, appColors.neutralColor),
    };
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
            controller: _scrollController,
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
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSmall,
                        ),
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
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusSmall,
                                        ),
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
