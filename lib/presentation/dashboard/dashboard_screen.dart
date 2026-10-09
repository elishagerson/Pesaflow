import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/presentation/common/widgets/glass_list_container.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/scroll_helpers.dart';
import 'package:pesaflow/presentation/state/palette_provider.dart';
import 'package:pesaflow/presentation/dashboard/widgets/dashboard_widgets.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/motion/skeleton_crossfade.dart';
import 'package:pesaflow/services/home_widgets_renderer.dart';
import 'package:pesaflow/presentation/state/spending_heatmap_provider.dart';
import 'package:pesaflow/presentation/dashboard/widgets/dashboard_hero_strip.dart';
import 'package:pesaflow/presentation/dashboard/widgets/notification_center_sheet.dart';
import 'package:pesaflow/presentation/state/notification_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _selectedAccountId;
  Timer? _homeWidgetCaptureTimer;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _homeWidgetCaptureTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrolls back to the top when the active Dashboard tab is re-tapped.
  void _scrollToTop() {
    _scrollController.scrollToTop(context);
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  /// Debounces AppWidget captures so launcher widgets only refresh after data
  /// settles, and only while the dashboard is the visible route.
  void _scheduleHomeWidgetCaptures() {
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    _homeWidgetCaptureTimer?.cancel();
    _homeWidgetCaptureTimer = Timer(const Duration(milliseconds: 1200), () {
      _captureHomeWidgets();
    });
  }

  Future<void> _captureHomeWidgets() async {
    await HomeWidgetsRenderer.captureAndUpdate(
      key: HomeWidgetsRenderer.heatmapKey,
      imageKey: 'heatmap_image_path',
      widgetName: 'SpendingHeatmapWidgetProvider',
    );
    await HomeWidgetsRenderer.captureAndUpdate(
      key: HomeWidgetsRenderer.safeToSpendKey,
      imageKey: 'safe_to_spend_image_path',
      widgetName: 'SafeToSpendWidgetProvider',
    );
    await HomeWidgetsRenderer.captureAndUpdate(
      key: HomeWidgetsRenderer.quickTemplatesKey,
      imageKey: 'quick_templates_image_path',
      widgetName: 'QuickTemplatesWidgetProvider',
    );
    await HomeWidgetsRenderer.captureAndUpdate(
      key: HomeWidgetsRenderer.recentTransactionsKey,
      imageKey: 'recent_transactions_image_path',
      widgetName: 'RecentTransactionsWidgetProvider',
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(scrollToTopProvider, (_, _) {
      _scrollToTop();
    });
    final accountsAsync = ref.watch(accountsStreamProvider);
    final recentTransAsync = ref.watch(recentTransactionsStreamProvider);
    final budgetsAsync = ref.watch(budgetProgressProvider);
    final reviewQueueAsync = ref.watch(reviewQueueStreamProvider);
    final totalsAsync = ref.watch(monthlyTotalsProvider);
    final savingsGoalsAsync = ref.watch(savingsGoalsStreamProvider);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final cardholderName =
        ref.watch(cardholderNameProvider).value ?? 'TOTAL NET WORTH';

    // Active tracker properties for dynamic aesthetic blending
    final activeTrackerAsync = ref.watch(activeTrackerProvider);
    final trackerColor = activeTrackerAsync.maybeWhen(
      data: (tracker) => tracker != null
          ? hexToColor(tracker.color)
          : theme.colorScheme.primary,
      orElse: () => theme.colorScheme.primary,
    );

    // Calculate budget overall spent percentage and Safe-to-Spend
    final budgets = budgetsAsync.value ?? [];
    double overallPct = 0.0;
    int remainingBudget = 0;
    int budgetTotal = 0;
    if (budgets.isNotEmpty) {
      double totalSpent = 0;
      double totalAllocated = 0;
      for (final bp in budgets) {
        totalSpent += bp.spentInPeriod;
        totalAllocated += bp.currentPeriod?.allocated ?? bp.budget.amount;
      }
      budgetTotal = totalAllocated.round();
      remainingBudget = (totalAllocated - totalSpent).round();
      if (totalAllocated > 0) {
        overallPct = (totalSpent / totalAllocated).clamp(0.0, 1.0);
      }
    } else {
      final totals = totalsAsync.value;
      if (totals != null) {
        final income = totals['income'] ?? 0;
        final expense = totals['expense'] ?? 0;
        budgetTotal = income;
        remainingBudget = income - expense;
        if (income > 0) {
          overallPct = (expense / income).clamp(0.0, 1.0);
        } else {
          // No budget and no income recorded: nothing to measure a spend
          // percentage against. Consumers treat this as "not set" rather
          // than as 100% spent.
          overallPct = 0.0;
        }
      } else {
        overallPct = 0.0;
      }
    }

    final pendingReviewCount = reviewQueueAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );
    final notificationCounts = ref.watch(notificationCountsProvider);

    final accounts = accountsAsync.value ?? [];
    final recsAsync = ref.watch(recurringTransactionsStreamProvider);
    final dueAsync = ref.watch(dueRecurringTransactionsProvider);
    final heatmapAsync = ref.watch(spendingHeatmapProvider);
    final templatesAsync = ref.watch(transactionTemplatesStreamProvider);
    final activeLoansAsync = ref.watch(activeLoansStreamProvider);

    // Debounce AppWidget captures
    _scheduleHomeWidgetCaptures();

    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            top: true,
            bottom: false,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
                  final double velocity =
                      notification.scrollDelta?.abs() ?? 0.0;
                  final double rawSpeed =
                      1.0 + (velocity / 12.0).clamp(0.0, 4.0);
                  final double quantized = (rawSpeed * 2).roundToDouble() / 2;
                  final current = ref.read(scrollSpeedProvider);
                  if (current != quantized) {
                    ref.read(scrollSpeedProvider.notifier).state = quantized;
                  }
                } else if (notification is ScrollEndNotification) {
                  if (ref.read(scrollSpeedProvider) != 1.0) {
                    ref.read(scrollSpeedProvider.notifier).state = 1.0;
                  }
                }
                return false;
              },
              child: RefreshIndicator(
                color: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surface,
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
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    top: kSpacing8,
                    bottom: IosTabBar.navBarHeight + kSpacing32,
                  ),
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Inset(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── 1. Top Bar: Greeting & Quick Tools ──
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Takes the space the actions do not. A
                                  // workspace name is user-supplied, so it
                                  // truncates rather than shoving the search
                                  // and review buttons off the bar.
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _getGreeting(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.ts(
                                            12,
                                            fontWeight: FontWeight.w500,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          cardholderName.isNotEmpty &&
                                                  cardholderName !=
                                                      'TOTAL NET WORTH'
                                              ? cardholderName
                                              : 'PesaFlow',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.ts(
                                            20,
                                            fontWeight: FontWeight.w800,
                                            color: theme.colorScheme.onSurface,
                                            letterSpacing: -0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      TactileSpringContainer(
                                        onTap: () => ref
                                            .read(
                                              paletteVisibilityProvider
                                                  .notifier,
                                            )
                                            .toggle(),
                                        selectedColor:
                                            theme.colorScheme.onSurface,
                                        child: Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: theme
                                                .colorScheme
                                                .surfaceContainerHigh,
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.squircleRadius(38),
                                            ),
                                            border: Border.all(
                                              color: context.appColors.hairline,
                                              width: 1,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Icon(
                                            PesaFlowIcons.search,
                                            color: theme.colorScheme.onSurface,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: kSpacing8),
                                      TactileSpringContainer(
                                        onTap: () =>
                                            showNotificationCenterSheet(
                                              context,
                                            ),
                                        selectedColor:
                                            theme.colorScheme.onSurface,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: theme
                                                    .colorScheme
                                                    .surfaceContainerHigh,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppTheme.squircleRadius(
                                                        38,
                                                      ),
                                                    ),
                                                border: Border.all(
                                                  color: context
                                                      .appColors
                                                      .hairline,
                                                  width: 1,
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: Icon(
                                                PesaFlowIcons.notification,
                                                size: 18,
                                                color:
                                                    theme.colorScheme.onSurface,
                                              ),
                                            ),
                                            if (notificationCounts.total > 0)
                                              Positioned(
                                                right: -2,
                                                top: -2,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: kSpacing6,
                                                        vertical: kSpacing2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: context
                                                        .appColors
                                                        .expenseColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          AppTheme.radiusPill,
                                                        ),
                                                    border: Border.all(
                                                      color: theme
                                                          .colorScheme
                                                          .surface,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    '${notificationCounts.total}',
                                                    style: context.ts(
                                                      9,
                                                      color: theme
                                                          .colorScheme
                                                          .onPrimary,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: kSpacing18),
                            ],
                          ),
                        ),

                        // ── 2. Hero Balance & Cash Flow Card ──
                        Consumer(
                          builder: (context, ref, _) {
                            final accounts = accountsAsync.value ?? [];
                            final netWorth = ref.watch(netWorthProvider);
                            final displayBalance = _selectedAccountId != null
                                ? (accounts
                                      .firstWhere(
                                        (a) => a.id == _selectedAccountId,
                                        orElse: () => accounts.first,
                                      )
                                      .balance)
                                : netWorth;
                            final activeAccountName = _selectedAccountId != null
                                ? accounts
                                      .firstWhere(
                                        (a) => a.id == _selectedAccountId,
                                        orElse: () => accounts.first,
                                      )
                                      .name
                                : cardholderName;

                            return StaggeredFadeSlide(
                              index: 0,
                              child: DashboardHeroStrip(
                                balance: displayBalance,
                                label: activeAccountName,
                                income: totalsAsync.value?['income'] ?? 0,
                                expense: totalsAsync.value?['expense'] ?? 0,
                                remainingBudget: remainingBudget,
                                budgetPct: overallPct,
                                budgetTotal: budgetTotal,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: kSpacing14),

                        _Inset(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── 2b. Account Filter Selector ──
                              if (accounts.isNotEmpty) ...[
                                SizedBox(
                                  height: 34,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: accounts.length + 1,
                                    itemBuilder: (context, index) {
                                      if (index == 0) {
                                        final isSelected =
                                            _selectedAccountId == null;
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            right: kSpacing8,
                                          ),
                                          child: TactileSpringContainer(
                                            onTap: () {
                                              setState(() {
                                                _selectedAccountId = null;
                                              });
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: kSpacing12,
                                                    vertical: kSpacing6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? theme.colorScheme.primary
                                                          .withValues(
                                                            alpha: 0.16,
                                                          )
                                                    : theme
                                                          .colorScheme
                                                          .surfaceContainerHigh,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppTheme.radiusPill,
                                                    ),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? theme
                                                            .colorScheme
                                                            .primary
                                                      : context
                                                            .appColors
                                                            .hairline,
                                                  width: isSelected ? 1.2 : 0.8,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  'All Accounts',
                                                  style: context.ts(
                                                    11,
                                                    fontWeight: FontWeight.w700,
                                                    color: isSelected
                                                        ? theme
                                                              .colorScheme
                                                              .primary
                                                        : theme
                                                              .colorScheme
                                                              .onSurface,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }

                                      final account = accounts[index - 1];
                                      final isSelected =
                                          _selectedAccountId == account.id;

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: kSpacing8,
                                        ),
                                        child: TactileSpringContainer(
                                          onTap: () {
                                            setState(() {
                                              _selectedAccountId = isSelected
                                                  ? null
                                                  : account.id;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: kSpacing10,
                                              vertical: kSpacing6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? theme.colorScheme.primary
                                                        .withValues(alpha: 0.16)
                                                  : theme
                                                        .colorScheme
                                                        .surfaceContainerHigh,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.radiusPill,
                                                  ),
                                              border: Border.all(
                                                color: isSelected
                                                    ? theme.colorScheme.primary
                                                    : context
                                                          .appColors
                                                          .hairline,
                                                width: isSelected ? 1.2 : 0.8,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  getAccountIcon(account.icon),
                                                  size: 13,
                                                  color: isSelected
                                                      ? theme
                                                            .colorScheme
                                                            .primary
                                                      : theme
                                                            .colorScheme
                                                            .onSurface,
                                                ),
                                                const SizedBox(
                                                  width: kSpacing6,
                                                ),
                                                Text(
                                                  account.name,
                                                  style: context.ts(
                                                    11,
                                                    fontWeight: FontWeight.w600,
                                                    color: isSelected
                                                        ? theme
                                                              .colorScheme
                                                              .primary
                                                        : theme
                                                              .colorScheme
                                                              .onSurface,
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: kSpacing6,
                                                ),
                                                Text(
                                                  _formatCompact(
                                                    account.balance,
                                                  ),
                                                  style: context.ts(
                                                    10,
                                                    fontWeight: FontWeight.w700,
                                                    color: isSelected
                                                        ? theme
                                                              .colorScheme
                                                              .primary
                                                        : theme
                                                              .colorScheme
                                                              .onSurfaceVariant,
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
                                const SizedBox(height: kSpacing16),
                              ] else ...[
                                const SizedBox(height: kSpacing8),
                              ],

                              // ── 3. Quick Action Row ──
                              Row(
                                children: [
                                  _QuickActionButton(
                                    icon: PesaFlowIcons.expense,
                                    label: 'Expense',
                                    color: context.appColors.expenseColor,
                                    onTap: () => context.push(
                                      '/transactions/add?type=Expense',
                                    ),
                                  ),
                                  const SizedBox(width: kSpacing10),
                                  _QuickActionButton(
                                    icon: PesaFlowIcons.income,
                                    label: 'Income',
                                    color: context.appColors.incomeColor,
                                    onTap: () => context.push(
                                      '/transactions/add?type=Income',
                                    ),
                                  ),
                                  const SizedBox(width: kSpacing10),
                                  _QuickActionButton(
                                    icon: PesaFlowIcons.transfer,
                                    label: 'Transfer',
                                    color: context.appColors.transferColor,
                                    onTap: () => context.push(
                                      '/transactions/add?type=Transfer',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: kSpacing20),
                            ],
                          ),
                        ),

                        // ── 4. Financial Overview 2x2 Hub Grid ──
                        FinancialHubGrid(
                          budgets: budgets,
                          overallPct: overallPct,
                          savingsGoals: savingsGoalsAsync.value ?? [],
                          activeRecurringCount: recsAsync.maybeWhen(
                            data: (recs) => recs
                                .where(
                                  (r) =>
                                      r.type == 'expense' &&
                                      r.status == 'active',
                                )
                                .length,
                            orElse: () => 0,
                          ),
                          dueCount: dueAsync.maybeWhen(
                            data: (due) =>
                                due.where((d) => d.type == 'expense').length,
                            orElse: () => 0,
                          ),
                          pendingReviewCount: pendingReviewCount,
                          activeLoansCount: activeLoansAsync.maybeWhen(
                            data: (loans) => loans.length,
                            orElse: () => 0,
                          ),
                          trackerColor: trackerColor,
                        ),
                        const SizedBox(height: kSpacing24),

                        // ── 6. Recent Activity Preview ──
                        Row(
                          children: [
                            // The section title yields; the "See All"
                            // affordance is the thing being aimed at.
                            Expanded(
                              child: Text(
                                'Recent Activity',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.ts(
                                  15,
                                  fontWeight: FontWeight.w700,
                                  color: onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: kSpacing8),
                            TactileSpringContainer(
                              onTap: () => context.push('/transactions'),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'See All',
                                    style: context.ts(
                                      12,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: kSpacing4),
                                  Icon(
                                    PesaFlowIcons.chevronRight,
                                    size: 14,
                                    color: theme.colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: kSpacing12),

                        SkeletonCrossfade(
                          isLoading:
                              recentTransAsync is AsyncLoading &&
                              !recentTransAsync.hasValue,
                          skeleton: const Column(
                            children: [
                              SkeletonCard(height: 64),
                              SizedBox(height: kSpacing8),
                              SkeletonCard(height: 64),
                            ],
                          ),
                          child: recentTransAsync.when(
                            data: (transactions) {
                              final filtered =
                                  (_selectedAccountId == null
                                          ? transactions
                                          : transactions.where(
                                              (t) =>
                                                  t.transaction.accountId ==
                                                  _selectedAccountId,
                                            ))
                                      .take(5)
                                      .toList();

                              if (filtered.isEmpty) {
                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: kSpacing28,
                                    horizontal: kSpacing16,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        theme.colorScheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusCard,
                                    ),
                                    border: Border.all(
                                      color: theme.colorScheme.outlineVariant
                                          .withValues(alpha: 0.25),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        PesaFlowIcons.transactions,
                                        size: 32,
                                        color: theme
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: 0.4),
                                      ),
                                      const SizedBox(height: kSpacing8),
                                      Text(
                                        _selectedAccountId != null
                                            ? 'No transactions for this account'
                                            : 'No recent activity yet',
                                        style: context.ts(
                                          13,
                                          fontWeight: FontWeight.w600,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return GlassListContainer(
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) => Divider(
                                    height: 1,
                                    thickness: 0.5,
                                    color: context.appColors.hairline,
                                    indent: 58,
                                  ),
                                  itemBuilder: (context, index) {
                                    final item = filtered[index];
                                    final trans = item.transaction;

                                    AmountType amtType = AmountType.neutral;
                                    final typeLower = trans.type.toLowerCase();
                                    if (typeLower == 'income') {
                                      amtType = AmountType.income;
                                    } else if (typeLower == 'expense' ||
                                        typeLower == 'airtime' ||
                                        typeLower == 'fee') {
                                      amtType = AmountType.expense;
                                    }

                                    final catColor = hexToColor(
                                      item.category.color,
                                    );

                                    return TactileSpringContainer(
                                      onTap: () => context.push(
                                        '/transactions/${trans.id}',
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: kSpacing16,
                                          vertical: kSpacing12,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: catColor.withValues(
                                                  alpha: context
                                                      .appColors
                                                      .badgeFillAlpha,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppTheme.squircleRadius(
                                                        38,
                                                      ),
                                                    ),
                                                border: Border.all(
                                                  color: catColor.withValues(
                                                    alpha: context
                                                        .appColors
                                                        .badgeBorderAlpha,
                                                  ),
                                                  width: 1,
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: Icon(
                                                getCategoryIcon(
                                                  item.category.icon,
                                                ),
                                                color: catColor,
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: kSpacing12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    trans.description.isNotEmpty
                                                        ? trans.description
                                                        : item.category.name,
                                                    style: context.ts(
                                                      13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: onSurface,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        item.account?.name ??
                                                            'Offline',
                                                        style: context.ts(
                                                          10,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: theme
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        width: kSpacing6,
                                                      ),
                                                      Text(
                                                        '•',
                                                        style: context.ts(
                                                          10,
                                                          color: theme
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        width: kSpacing6,
                                                      ),
                                                      Text(
                                                        DateFormat(
                                                          'MMM d',
                                                        ).format(
                                                          trans.createdAt,
                                                        ),
                                                        style: context.ts(
                                                          10,
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
                                            const SizedBox(width: kSpacing8),
                                            AmountText(
                                              amountInCents: trans.amount,
                                              type: amtType,
                                              animate: false,
                                              showDecimals: true,
                                              style: context.ts(
                                                14,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    amtType == AmountType.income
                                                    ? context
                                                          .appColors
                                                          .incomeColor
                                                    : (amtType ==
                                                              AmountType.expense
                                                          ? context
                                                                .appColors
                                                                .expenseColor
                                                          : theme
                                                                .colorScheme
                                                                .onSurfaceVariant),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (err, _) => Center(
                              child: Text('Error loading activity: $err'),
                            ),
                          ),
                        ),
                        const SizedBox(height: kSpacing80),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Offscreen Home Widgets Renderer for launcher widget captures
        Positioned(
          left: -9999,
          top: -9999,
          width: 360,
          // These four are not part of the dashboard. They are stand-ins for
          // surfaces the launcher draws at a fixed size, with their own
          // typography, and they are only ever read as pixels for the capture.
          //
          // Inheriting the app's text scale is therefore wrong twice over: the
          // text does not represent the real widget, and a user running a
          // larger-type setting overflows these fixed 180x180 boxes — which
          // threw layout errors on every dashboard frame at 1.3x, for a
          // surface nobody can see.
          child: MediaQuery.withNoTextScaling(
            child: Column(
              children: [
                if (heatmapAsync.value != null)
                  RepaintBoundary(
                    key: HomeWidgetsRenderer.heatmapKey,
                    child: WidgetHeatmap(
                      data: heatmapAsync.value!,
                      theme: theme,
                    ),
                  ),
                RepaintBoundary(
                  key: HomeWidgetsRenderer.safeToSpendKey,
                  child: WidgetSafeToSpend(
                    remainingCents: (remainingBudget * 100).toInt(),
                    limitCents: (budgetTotal * 100).toInt(),
                    percentage: overallPct,
                    theme: theme,
                  ),
                ),
                RepaintBoundary(
                  key: HomeWidgetsRenderer.quickTemplatesKey,
                  child: WidgetQuickTemplates(
                    templates: templatesAsync.value ?? [],
                    theme: theme,
                  ),
                ),
                RepaintBoundary(
                  key: HomeWidgetsRenderer.recentTransactionsKey,
                  child: WidgetRecentTransactions(
                    transactions: recentTransAsync.value ?? [],
                    theme: theme,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
    final theme = Theme.of(context);
    return Expanded(
      child: TactileSpringContainer(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: kSpacing8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(
              color: context.appColors.hairline,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(
                  alpha: context.appColors.badgeFillAlpha,
                ),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: context.appColors.shadowSubtle,
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color.withValues(
                    alpha: context.appColors.badgeFillAlpha,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppTheme.squircleRadius(26),
                  ),
                  border: Border.all(
                    color: color.withValues(
                      alpha: context.appColors.badgeBorderAlpha,
                    ),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: kSpacing8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.ts(
                    12,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dashboard's standard horizontal inset.
///
/// The hero runs edge to edge, so the inset is not applied once around the
/// whole scroll view — that would be a gutter around the hero too, which is the
/// one thing it must not have. Everything else opts back in through this.
class _Inset extends StatelessWidget {
  const _Inset({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSpacing16),
      child: child,
    );
  }
}
