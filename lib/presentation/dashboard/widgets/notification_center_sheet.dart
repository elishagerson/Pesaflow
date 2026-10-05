import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/spring_sheet_route.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/savings_goals/widgets/quick_deposit_sheet.dart';
import 'package:pesaflow/presentation/state/notification_providers.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

/// Opens the unified Executive Notification Center sheet.
Future<void> showNotificationCenterSheet(BuildContext context) {
  return showSpringSheet(
    context,
    isScrollControlled: true,
    builder: (sheetContext) => const NotificationCenterSheet(),
  );
}

enum NotificationFilter { all, sms, bills, budgets, savings, loans }

class NotificationCenterSheet extends ConsumerStatefulWidget {
  const NotificationCenterSheet({super.key});

  @override
  ConsumerState<NotificationCenterSheet> createState() =>
      _NotificationCenterSheetState();
}

class _NotificationCenterSheetState
    extends ConsumerState<NotificationCenterSheet> {
  NotificationFilter _selectedFilter = NotificationFilter.all;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = ref.watch(notificationCountsProvider);

    final reviewQueue = ref.watch(reviewQueueStreamProvider).value ?? [];
    final dueBills = (ref.watch(dueRecurringTransactionsProvider).value ?? [])
        .where((b) => b.type == 'expense')
        .toList();
    final budgets = (ref.watch(budgetProgressProvider).value ?? [])
        .where((b) => b.remaining < 0 || b.percentage >= 0.9)
        .toList();
    final activeLoans = (ref.watch(activeLoansStreamProvider).value ?? [])
        .where((l) {
          if (l.remaining <= 0 || l.dueAt == null) return false;
          final diff = l.dueAt!.difference(DateTime.now()).inDays;
          return diff <= 3;
        })
        .toList();
    final activeSavings = (ref.watch(savingsGoalsStreamProvider).value ?? [])
        .where((g) => !g.isCompleted && g.currentAmount < g.targetAmount)
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.80,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      expand: false,
      builder: (sheetContext, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusDialog),
            ),
          ),
          child: Column(
            children: [
              // ── Handle Bar ──
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: kSpacing12, bottom: kSpacing8),
                  width: 36,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                ),
              ),

              // ── Executive Header ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacing20,
                  vertical: kSpacing6,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: context.isDark ? 0.18 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.squircleRadius(42),
                        ),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: context.isDark ? 0.32 : 0.18,
                          ),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: context.isDark ? 0.15 : 0.06,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        PesaFlowIcons.notification,
                        color: theme.colorScheme.primary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: kSpacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Notification Center',
                                style: context.ts(
                                  18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              if (counts.total > 0) ...[
                                const SizedBox(width: kSpacing8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: kSpacing8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.appColors.expenseColor,
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusPill,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.appColors.expenseColor
                                            .withValues(alpha: 0.25),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '${counts.total}',
                                    style: context.ts(
                                      10.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            counts.total > 0
                                ? '${counts.total} items require your attention'
                                : 'All systems normal • zero pending alerts',
                            style: context.ts(
                              12,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TactileSpringContainer(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(
                            AppTheme.squircleRadius(34),
                          ),
                          border: Border.all(
                            color: context.appColors.hairline,
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          PesaFlowIcons.close,
                          size: 15,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: kSpacing10),

              // ── Executive Telemetry Status Bar ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kSpacing16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpacing12,
                    vertical: kSpacing8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    border: Border.all(
                      color: context.appColors.hairline,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: counts.total > 0
                              ? context.appColors.expenseColor
                              : context.appColors.incomeColor,
                          borderRadius: BorderRadius.circular(
                            AppTheme.squircleRadius(7),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (counts.total > 0
                                      ? context.appColors.expenseColor
                                      : context.appColors.incomeColor)
                                  .withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: kSpacing8),
                      Text(
                        counts.total > 0 ? 'LIVE TELEMETRY' : 'ALL NOMINAL',
                        style: context.ts(
                          10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: counts.total > 0
                              ? context.appColors.expenseColor
                              : context.appColors.incomeColor,
                        ),
                      ),
                      const Spacer(),
                      _buildMiniBadge(
                        label: 'SMS',
                        count: counts.pendingSmsCount,
                        color: context.appColors.transferColor,
                      ),
                      const SizedBox(width: kSpacing6),
                      _buildMiniBadge(
                        label: 'BILLS',
                        count: counts.dueBillsCount,
                        color: context.appColors.expenseColor,
                      ),
                      const SizedBox(width: kSpacing6),
                      _buildMiniBadge(
                        label: 'SAVINGS',
                        count: counts.savingsRemindersCount,
                        color: context.appColors.incomeColor,
                      ),
                      const SizedBox(width: kSpacing6),
                      _buildMiniBadge(
                        label: 'BUDGETS',
                        count: counts.budgetAlertsCount,
                        color: theme.colorScheme.error,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: kSpacing10),

              // ── Filter Pills Row ──
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: kSpacing16),
                child: Row(
                  children: [
                    _buildFilterPill(
                      context: context,
                      label: 'All',
                      count: counts.total,
                      filter: NotificationFilter.all,
                      accentColor: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: kSpacing8),
                    _buildFilterPill(
                      context: context,
                      label: 'Carrier SMS',
                      count: counts.pendingSmsCount,
                      filter: NotificationFilter.sms,
                      accentColor: context.appColors.transferColor,
                    ),
                    const SizedBox(width: kSpacing8),
                    _buildFilterPill(
                      context: context,
                      label: 'Bills Due',
                      count: counts.dueBillsCount,
                      filter: NotificationFilter.bills,
                      accentColor: context.appColors.expenseColor,
                    ),
                    const SizedBox(width: kSpacing8),
                    _buildFilterPill(
                      context: context,
                      label: 'Savings',
                      count: counts.savingsRemindersCount,
                      filter: NotificationFilter.savings,
                      accentColor: context.appColors.incomeColor,
                    ),
                    const SizedBox(width: kSpacing8),
                    _buildFilterPill(
                      context: context,
                      label: 'Budgets',
                      count: counts.budgetAlertsCount,
                      filter: NotificationFilter.budgets,
                      accentColor: theme.colorScheme.error,
                    ),
                    const SizedBox(width: kSpacing8),
                    _buildFilterPill(
                      context: context,
                      label: 'Loans',
                      count: counts.dueLoansCount,
                      filter: NotificationFilter.loans,
                      accentColor: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: kSpacing10),
              Divider(
                height: 1,
                color: context.appColors.hairline,
              ),

              // ── Notifications Content List ──
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    kSpacing16,
                    kSpacing14,
                    kSpacing16,
                    kSpacing32,
                  ),
                  children: [
                    if (_shouldShowEmpty(counts))
                      _buildEmptyState(context)
                    else ...[
                      // 1. Carrier SMS Queue Section
                      if ((_selectedFilter == NotificationFilter.all ||
                              _selectedFilter == NotificationFilter.sms) &&
                          reviewQueue.isNotEmpty) ...[
                        _buildSectionHeader(
                          context,
                          title: 'CARRIER SMS PENDING REVIEW',
                          count: reviewQueue.length,
                          color: context.appColors.transferColor,
                        ),
                        const SizedBox(height: kSpacing8),
                        if (reviewQueue.length >= 2) ...[
                          _buildBatchReviewAffordance(
                            context,
                            count: reviewQueue.length,
                          ),
                          const SizedBox(height: kSpacing8),
                        ],
                        ...reviewQueue.map(
                          (item) => _buildSmsCard(context, item),
                        ),
                        const SizedBox(height: kSpacing16),
                      ],

                      // 2. Bills Due Today Section
                      if ((_selectedFilter == NotificationFilter.all ||
                              _selectedFilter == NotificationFilter.bills) &&
                          dueBills.isNotEmpty) ...[
                        _buildSectionHeader(
                          context,
                          title: 'RECURRING BILLS DUE TODAY',
                          count: dueBills.length,
                          color: context.appColors.expenseColor,
                        ),
                        const SizedBox(height: kSpacing8),
                        ...dueBills.map(
                          (bill) => _buildBillCard(context, bill),
                        ),
                        const SizedBox(height: kSpacing16),
                      ],

                      // 3. Savings Milestone Reminders Section
                      if ((_selectedFilter == NotificationFilter.all ||
                              _selectedFilter == NotificationFilter.savings) &&
                          activeSavings.isNotEmpty) ...[
                        _buildSectionHeader(
                          context,
                          title: 'SAVINGS MILESTONE REMINDERS',
                          count: activeSavings.length,
                          color: context.appColors.incomeColor,
                        ),
                        const SizedBox(height: kSpacing8),
                        ...activeSavings.map(
                          (goal) => _buildSavingsCard(context, goal),
                        ),
                        const SizedBox(height: kSpacing16),
                      ],

                      // 4. Budget Limit Warnings Section
                      if ((_selectedFilter == NotificationFilter.all ||
                              _selectedFilter == NotificationFilter.budgets) &&
                          budgets.isNotEmpty) ...[
                        _buildSectionHeader(
                          context,
                          title: 'BUDGET LIMIT WARNINGS',
                          count: budgets.length,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: kSpacing8),
                        ...budgets.map(
                          (progress) => _buildBudgetCard(context, progress),
                        ),
                        const SizedBox(height: kSpacing16),
                      ],

                      // 5. Loan Due Reminders Section
                      if ((_selectedFilter == NotificationFilter.all ||
                              _selectedFilter == NotificationFilter.loans) &&
                          activeLoans.isNotEmpty) ...[
                        _buildSectionHeader(
                          context,
                          title: 'LOAN REPAYMENT NOTIFICATIONS',
                          count: activeLoans.length,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: kSpacing8),
                        ...activeLoans.map(
                          (loan) => _buildLoanCard(context, loan),
                        ),
                        const SizedBox(height: kSpacing16),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniBadge({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: count > 0 ? 0.16 : 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: count > 0 ? color : Colors.grey,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: count > 0 ? color : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowEmpty(NotificationCounts counts) {
    switch (_selectedFilter) {
      case NotificationFilter.all:
        return counts.total == 0;
      case NotificationFilter.sms:
        return counts.pendingSmsCount == 0;
      case NotificationFilter.bills:
        return counts.dueBillsCount == 0;
      case NotificationFilter.savings:
        return counts.savingsRemindersCount == 0;
      case NotificationFilter.budgets:
        return counts.budgetAlertsCount == 0;
      case NotificationFilter.loans:
        return counts.dueLoansCount == 0;
    }
  }

  Widget _buildFilterPill({
    required BuildContext context,
    required String label,
    required int count,
    required NotificationFilter filter,
    required Color accentColor,
  }) {
    final theme = Theme.of(context);
    final isSelected = _selectedFilter == filter;

    return TactileSpringContainer(
      onTap: () {
        PesaHaptics.selection();
        setState(() => _selectedFilter = filter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: kSpacing12,
          vertical: kSpacing6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(
                  alpha: context.isDark ? 0.20 : 0.12,
                )
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(
            color: isSelected ? accentColor : context.appColors.hairline,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5.5,
              height: 5.5,
              decoration: BoxDecoration(
                color: isSelected ? accentColor : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppTheme.squircleRadius(5.5)),
              ),
            ),
            const SizedBox(width: kSpacing6),
            Text(
              label,
              style: context.ts(
                11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? accentColor : theme.colorScheme.onSurface,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: kSpacing6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required int count,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpacing4),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppTheme.squircleRadius(7)),
            ),
          ),
          const SizedBox(width: kSpacing8),
          Text(
            title,
            style: context.ts(
              10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            '$count pending',
            style: context.ts(
              11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchReviewAffordance(BuildContext context, {required int count}) {
    final theme = Theme.of(context);
    return TactileSpringContainer(
      onTap: () {
        Navigator.of(context).pop();
        context.push('/sms-review');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: kSpacing14,
          vertical: kSpacing10,
        ),
        decoration: BoxDecoration(
          color: context.appColors.transferColor.withValues(
            alpha: context.isDark ? 0.16 : 0.10,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(
            color: context.appColors.transferColor.withValues(
              alpha: context.isDark ? 0.32 : 0.20,
            ),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              PesaFlowIcons.sms,
              color: context.appColors.transferColor,
              size: 16,
            ),
            const SizedBox(width: kSpacing10),
            Expanded(
              child: Text(
                'Review All $count SMS at Once',
                style: context.ts(
                  12.5,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Icon(
              PesaFlowIcons.arrowForward,
              size: 14,
              color: context.appColors.transferColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmsCard(BuildContext context, dynamic item) {
    final theme = Theme.of(context);
    final tx = item.transaction;
    final accountName = item.account?.name ?? 'Carrier SMS';

    // Extract carrier tag
    final desc = tx.description?.toUpperCase() ?? '';
    String carrierTag = 'MOBILE MONEY';
    if (desc.contains('M-PESA') || desc.contains('MPESA')) {
      carrierTag = 'M-PESA';
    } else if (desc.contains('AIRTEL')) {
      carrierTag = 'AIRTEL';
    } else if (desc.contains('SELCOM')) {
      carrierTag = 'SELCOM';
    } else if (desc.contains('NMB')) {
      carrierTag = 'NMB';
    } else if (desc.contains('CRDB')) {
      carrierTag = 'CRDB';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: kSpacing8),
      padding: const EdgeInsets.all(kSpacing12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: context.appColors.hairline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: context.appColors.transferColor.withValues(
                    alpha: context.isDark ? 0.16 : 0.09,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppTheme.squircleRadius(32),
                  ),
                  border: Border.all(
                    color: context.appColors.transferColor.withValues(
                      alpha: context.isDark ? 0.28 : 0.16,
                    ),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  PesaFlowIcons.sms,
                  color: context.appColors.transferColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: kSpacing10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacing6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: context.appColors.transferColor.withValues(
                    alpha: context.isDark ? 0.20 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  carrierTag,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: context.appColors.transferColor,
                  ),
                ),
              ),
              const Spacer(),
              FittedBox(
                child: Text(
                  CurrencyFormatter.formatCents(tx.amount),
                  style: context.ts(
                    14,
                    fontWeight: FontWeight.w800,
                    color: context.appColors.incomeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing8),
          Text(
            tx.description ?? 'Carrier Transaction',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.ts(
              13,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            accountName,
            style: context.ts(
              11,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: kSpacing10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TactileSpringContainer(
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/sms-review');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpacing12,
                    vertical: kSpacing6,
                  ),
                  decoration: BoxDecoration(
                    color: context.appColors.transferColor.withValues(
                      alpha: context.isDark ? 0.20 : 0.12,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(
                      color: context.appColors.transferColor.withValues(
                        alpha: context.isDark ? 0.35 : 0.20,
                      ),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Review',
                        style: context.ts(
                          11,
                          fontWeight: FontWeight.w700,
                          color: context.appColors.transferColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        PesaFlowIcons.arrowForward,
                        size: 11,
                        color: context.appColors.transferColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillCard(BuildContext context, dynamic bill) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: kSpacing8),
      padding: const EdgeInsets.all(kSpacing12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: context.appColors.hairline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: context.appColors.expenseColor.withValues(
                    alpha: context.isDark ? 0.16 : 0.09,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppTheme.squircleRadius(32),
                  ),
                  border: Border.all(
                    color: context.appColors.expenseColor.withValues(
                      alpha: context.isDark ? 0.28 : 0.16,
                    ),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  PesaFlowIcons.subscriptions,
                  color: context.appColors.expenseColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: kSpacing10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacing6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: context.appColors.expenseColor.withValues(
                    alpha: context.isDark ? 0.20 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  'Due Today',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: context.appColors.expenseColor,
                  ),
                ),
              ),
              const Spacer(),
              FittedBox(
                child: Text(
                  CurrencyFormatter.formatCents(bill.amount),
                  style: context.ts(
                    14,
                    fontWeight: FontWeight.w800,
                    color: context.appColors.expenseColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing8),
          Text(
            bill.description ?? 'Recurring Bill',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.ts(
              13,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${bill.frequency.toUpperCase()} • Interval: ${bill.intervalValue}',
            style: context.ts(
              11,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: kSpacing10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TactileSpringContainer(
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/recurring');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpacing14,
                    vertical: kSpacing6,
                  ),
                  decoration: BoxDecoration(
                    color: context.appColors.expenseColor.withValues(
                      alpha: context.isDark ? 0.20 : 0.12,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(
                      color: context.appColors.expenseColor.withValues(
                        alpha: context.isDark ? 0.35 : 0.20,
                      ),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Pay Now',
                    style: context.ts(
                      11,
                      fontWeight: FontWeight.w700,
                      color: context.appColors.expenseColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsCard(BuildContext context, dynamic goal) {
    final theme = Theme.of(context);
    final goalColor = hexToColor(goal.color);
    final now = DateTime.now();
    final daysUntilTarget = goal.targetDate.difference(now).inDays;
    final isOverdue = goal.targetDate.isBefore(now);
    final pct = goal.targetAmount > 0
        ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final pctInt = (pct * 100).toInt();

    String statusLabel = 'SAVINGS PACE';
    Color statusColor = context.appColors.incomeColor;
    if (isOverdue) {
      statusLabel = 'OVERDUE TARGET';
      statusColor = theme.colorScheme.error;
    } else if (daysUntilTarget <= 30) {
      statusLabel = 'DUE IN $daysUntilTarget DAYS';
      statusColor = goalColor;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: kSpacing8),
      padding: const EdgeInsets.all(kSpacing12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: context.appColors.hairline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: goalColor.withValues(
                    alpha: context.isDark ? 0.16 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppTheme.squircleRadius(32),
                  ),
                  border: Border.all(
                    color: goalColor.withValues(
                      alpha: context.isDark ? 0.30 : 0.18,
                    ),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  getGoalIcon(goal.icon),
                  color: goalColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: kSpacing10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacing6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(
                    alpha: context.isDark ? 0.20 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: statusColor,
                  ),
                ),
              ),
              const Spacer(),
              FittedBox(
                child: Text(
                  '$pctInt% Saved',
                  style: context.ts(
                    13,
                    fontWeight: FontWeight.w800,
                    color: goalColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing8),
          Text(
            goal.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.ts(
              13,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${CurrencyFormatter.formatCents(goal.currentAmount)} of ${CurrencyFormatter.formatCents(goal.targetAmount)}',
            style: context.ts(
              11,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: kSpacing8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: theme.colorScheme.surface,
              valueColor: AlwaysStoppedAnimation<Color>(goalColor),
            ),
          ),
          const SizedBox(height: kSpacing10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TactileSpringContainer(
                onTap: () {
                  showQuickDepositSheet(context, ref, goal);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpacing14,
                    vertical: kSpacing6,
                  ),
                  decoration: BoxDecoration(
                    color: goalColor.withValues(
                      alpha: context.isDark ? 0.20 : 0.12,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(
                      color: goalColor.withValues(
                        alpha: context.isDark ? 0.35 : 0.20,
                      ),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Deposit',
                    style: context.ts(
                      11,
                      fontWeight: FontWeight.w700,
                      color: goalColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(BuildContext context, dynamic progress) {
    final theme = Theme.of(context);
    final isExceeded = progress.remaining < 0;
    final diffAmount = CurrencyFormatter.formatCents(progress.remaining.abs());
    final pct = progress.percentage as double;
    final pctInt = (pct * 100).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: kSpacing8),
      padding: const EdgeInsets.all(kSpacing12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: theme.colorScheme.error.withValues(
            alpha: isExceeded ? 0.38 : 0.22,
          ),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(
                    alpha: context.isDark ? 0.16 : 0.09,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppTheme.squircleRadius(32),
                  ),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(
                      alpha: context.isDark ? 0.28 : 0.16,
                    ),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  PesaFlowIcons.budgets,
                  color: theme.colorScheme.error,
                  size: 16,
                ),
              ),
              const SizedBox(width: kSpacing10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacing6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(
                    alpha: context.isDark ? 0.20 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  isExceeded ? '$pctInt% EXCEEDED' : '$pctInt% LIMIT',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
              const Spacer(),
              TactileSpringContainer(
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/budgets');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpacing10,
                    vertical: kSpacing4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(
                      alpha: context.isDark ? 0.20 : 0.12,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(
                      color: theme.colorScheme.error.withValues(
                        alpha: context.isDark ? 0.35 : 0.20,
                      ),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Adjust',
                    style: context.ts(
                      10.5,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing8),
          Text(
            '${progress.budget.name} Alert',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.ts(
              13,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isExceeded
                ? 'Over budget by $diffAmount'
                : 'Near limit: ${CurrencyFormatter.formatCents(progress.spentInPeriod)} spent',
            style: context.ts(
              11,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: kSpacing8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: theme.colorScheme.surface,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanCard(BuildContext context, dynamic loan) {
    final theme = Theme.of(context);
    final isOverdue =
        loan.dueAt != null && loan.dueAt!.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: kSpacing8),
      padding: const EdgeInsets.all(kSpacing12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: context.appColors.hairline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(
                    alpha: context.isDark ? 0.16 : 0.09,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppTheme.squircleRadius(32),
                  ),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(
                      alpha: context.isDark ? 0.28 : 0.16,
                    ),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  PesaFlowIcons.loans,
                  color: theme.colorScheme.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: kSpacing10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacing6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: (isOverdue ? theme.colorScheme.error : theme.colorScheme.primary)
                      .withValues(alpha: context.isDark ? 0.20 : 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  isOverdue ? 'OVERDUE' : 'DUE SOON',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: isOverdue ? theme.colorScheme.error : theme.colorScheme.primary,
                  ),
                ),
              ),
              const Spacer(),
              FittedBox(
                child: Text(
                  CurrencyFormatter.formatCents(loan.remaining),
                  style: context.ts(
                    14,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing8),
          Text(
            loan.description ?? 'Active Loan',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.ts(
              13,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isOverdue ? 'Repayment Overdue' : 'Due Soon',
            style: context.ts(
              11,
              fontWeight: FontWeight.w600,
              color: isOverdue
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: kSpacing10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TactileSpringContainer(
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/loans');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpacing12,
                    vertical: kSpacing6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(
                      alpha: context.isDark ? 0.20 : 0.12,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(
                        alpha: context.isDark ? 0.35 : 0.20,
                      ),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Details',
                    style: context.ts(
                      11,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kSpacing40),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: context.appColors.incomeColor.withValues(
                  alpha: context.isDark ? 0.16 : 0.10,
                ),
                borderRadius: BorderRadius.circular(
                  AppTheme.squircleRadius(58),
                ),
                border: Border.all(
                  color: context.appColors.incomeColor.withValues(
                    alpha: context.isDark ? 0.30 : 0.20,
                  ),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.appColors.incomeColor.withValues(
                      alpha: context.isDark ? 0.15 : 0.05,
                    ),
                    blurRadius: 16,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                PesaFlowIcons.check,
                color: context.appColors.incomeColor,
                size: 28,
              ),
            ),
            const SizedBox(height: kSpacing16),
            Text(
              'All Caught Up!',
              style: context.ts(
                16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: kSpacing6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kSpacing32),
              child: Text(
                'No pending carrier SMS, overdue bills, or budget warnings at this time.',
                textAlign: TextAlign.center,
                style: context.ts(
                  12.5,
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
