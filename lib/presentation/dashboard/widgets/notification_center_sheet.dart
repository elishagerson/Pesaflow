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
import 'package:pesaflow/core/theme/motion_constants.dart';

/// Opens the unified notification center sheet.
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
    final now = DateTime.now();
    final activeLoans = (ref.watch(activeLoansStreamProvider).value ?? [])
        .where((l) {
          if (l.remaining <= 0 || l.dueAt == null) return false;
          final diff = l.dueAt!.difference(now).inDays;
          return diff <= 3;
        })
        .toList();
    final allSavings = ref.watch(savingsGoalsStreamProvider).value ?? [];
    final urgentSavings = allSavings.where((g) {
      if (g.isCompleted || g.currentAmount >= g.targetAmount) return false;
      return g.targetDate.difference(now).inDays <= 30;
    }).toList();
    final List<dynamic> activeSavings = urgentSavings.isNotEmpty
        ? urgentSavings
        : (allSavings
              .where((g) => !g.isCompleted && g.currentAmount < g.targetAmount)
              .toList()
            ..sort((a, b) => a.targetDate.compareTo(b.targetDate)))
          .take(1)
          .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.40,
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
                  margin: const EdgeInsets.only(
                    top: kSpacing10,
                    bottom: kSpacing8,
                  ),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                ),
              ),

              // ── Clean Header ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacing16,
                  vertical: kSpacing6,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: context.appColors.badgeFillAlpha,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.squircleRadius(38),
                        ),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: context.appColors.badgeBorderAlpha,
                          ),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        PesaFlowIcons.notification,
                        color: theme.colorScheme.primary,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: kSpacing10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Notification Center',
                                style: context.ts(
                                  17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              if (counts.total > 0) ...[
                                const SizedBox(width: kSpacing8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: kSpacing6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.appColors.expenseColor,
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusPill,
                                    ),
                                  ),
                                  child: Text(
                                    '${counts.total}',
                                    style: context.ts(
                                      10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 5.5,
                                height: 5.5,
                                decoration: BoxDecoration(
                                  color: counts.total > 0
                                      ? context.appColors.expenseColor
                                      : context.appColors.incomeColor,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.squircleRadius(5.5),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                counts.total > 0
                                    ? '${counts.total} items require attention'
                                    : 'All systems normal • zero pending alerts',
                                style: context.ts(
                                  11.5,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    TactileSpringContainer(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(
                            AppTheme.squircleRadius(32),
                          ),
                          border: Border.all(
                            color: context.appColors.hairline,
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          PesaFlowIcons.close,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: kSpacing8),

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
                    if (counts.pendingSmsCount > 0) ...[
                      const SizedBox(width: kSpacing8),
                      _buildFilterPill(
                        context: context,
                        label: 'Carrier SMS',
                        count: counts.pendingSmsCount,
                        filter: NotificationFilter.sms,
                        accentColor: context.appColors.transferColor,
                      ),
                    ],
                    if (counts.dueBillsCount > 0) ...[
                      const SizedBox(width: kSpacing8),
                      _buildFilterPill(
                        context: context,
                        label: 'Bills Due',
                        count: counts.dueBillsCount,
                        filter: NotificationFilter.bills,
                        accentColor: context.appColors.expenseColor,
                      ),
                    ],
                    if (counts.savingsRemindersCount > 0) ...[
                      const SizedBox(width: kSpacing8),
                      _buildFilterPill(
                        context: context,
                        label: 'Savings',
                        count: counts.savingsRemindersCount,
                        filter: NotificationFilter.savings,
                        accentColor: context.appColors.incomeColor,
                      ),
                    ],
                    if (counts.budgetAlertsCount > 0) ...[
                      const SizedBox(width: kSpacing8),
                      _buildFilterPill(
                        context: context,
                        label: 'Budgets',
                        count: counts.budgetAlertsCount,
                        filter: NotificationFilter.budgets,
                        accentColor: theme.colorScheme.error,
                      ),
                    ],
                    if (counts.dueLoansCount > 0) ...[
                      const SizedBox(width: kSpacing8),
                      _buildFilterPill(
                        context: context,
                        label: 'Loans',
                        count: counts.dueLoansCount,
                        filter: NotificationFilter.loans,
                        accentColor: theme.colorScheme.primary,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: kSpacing10),
              Divider(height: 1, color: context.appColors.hairline),

              // ── Notifications Content List ──
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    kSpacing16,
                    kSpacing12,
                    kSpacing16,
                    kSpacing24,
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
                        if (reviewQueue.length >= 2) ...[
                          _buildBatchReviewAffordance(
                            context,
                            count: reviewQueue.length,
                          ),
                        ],
                        _buildGroupedSection(
                          children: reviewQueue
                              .map((item) => _buildSmsRow(context, item))
                              .toList(),
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
                        _buildGroupedSection(
                          children: dueBills
                              .map((bill) => _buildBillRow(context, bill))
                              .toList(),
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
                        _buildGroupedSection(
                          children: activeSavings
                              .map((goal) => _buildSavingsRow(context, goal))
                              .toList(),
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
                        _buildGroupedSection(
                          children: budgets
                              .map((progress) => _buildBudgetRow(context, progress))
                              .toList(),
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
                        _buildGroupedSection(
                          children: activeLoans
                              .map((loan) => _buildLoanRow(context, loan))
                              .toList(),
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
        duration: MotionTokens.durationMicro,
        padding: const EdgeInsets.symmetric(
          horizontal: kSpacing10,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: context.appColors.badgeFillAlpha)
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
            Text(
              label,
              style: context.ts(
                11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? accentColor : theme.colorScheme.onSurface,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  '$count',
                  style: context.ts(
                    9.5,
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
      padding: const EdgeInsets.only(bottom: kSpacing6, top: kSpacing4),
      child: Row(
        children: [
          Text(
            title,
            style: context.ts(
              10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: kSpacing6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: context.appColors.badgeFillAlpha),
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: Text(
              '$count',
              style: context.ts(9.5, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchReviewAffordance(
    BuildContext context, {
    required int count,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpacing8),
      child: TactileSpringContainer(
        onTap: () {
          Navigator.of(context).pop();
          context.push('/sms-review');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpacing12,
            vertical: kSpacing8,
          ),
          decoration: BoxDecoration(
            color: context.appColors.transferColor.withValues(
              alpha: context.appColors.badgeFillAlpha,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(
              color: context.appColors.transferColor.withValues(
                alpha: context.appColors.badgeBorderAlpha,
              ),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: context.appColors.transferColor.withValues(
                    alpha: 0.16,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppTheme.squircleRadius(26),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  PesaFlowIcons.sms,
                  color: context.appColors.transferColor,
                  size: 13,
                ),
              ),
              const SizedBox(width: kSpacing8),
              Expanded(
                child: Text(
                  'Review All $count SMS at Once',
                  style: context.ts(
                    12,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Icon(
                PesaFlowIcons.arrowForward,
                size: 13,
                color: context.appColors.transferColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedSection({required List<Widget> children}) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: context.appColors.hairline, width: 1),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 0.5,
                color: context.appColors.hairline,
              ),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _buildSmsRow(BuildContext context, dynamic item) {
    final theme = Theme.of(context);
    final tx = item.transaction;
    final accountName = item.account?.name ?? 'Carrier SMS';

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

    return TactileSpringContainer(
      onTap: () {
        Navigator.of(context).pop();
        context.push('/sms-review');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: kSpacing12,
          vertical: kSpacing10,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: context.appColors.transferColor.withValues(
                  alpha: context.appColors.badgeFillAlpha,
                ),
                borderRadius: BorderRadius.circular(
                  AppTheme.squircleRadius(34),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          tx.description ?? 'Carrier Transaction',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.ts(
                            13,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: kSpacing6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: context.appColors.transferColor.withValues(
                            alpha: context.appColors.badgeFillAlpha,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
                        ),
                        child: Text(
                          carrierTag,
                          style: context.ts(
                            8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: context.appColors.transferColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    accountName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.ts(
                      11,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: kSpacing10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  CurrencyFormatter.formatCents(tx.amount),
                  style: context.ts(
                    12.5,
                    fontWeight: FontWeight.w800,
                    color: context.appColors.incomeColor,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpacing10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: context.appColors.transferColor.withValues(
                      alpha: context.appColors.badgeFillAlpha,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(
                      color: context.appColors.transferColor.withValues(
                        alpha: context.appColors.badgeBorderAlpha,
                      ),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    'Review',
                    style: context.ts(
                      10,
                      fontWeight: FontWeight.w700,
                      color: context.appColors.transferColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillRow(BuildContext context, dynamic bill) {
    final theme = Theme.of(context);
    return TactileSpringContainer(
      onTap: () {
        Navigator.of(context).pop();
        context.push('/recurring');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: kSpacing12,
          vertical: kSpacing10,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: context.appColors.expenseColor.withValues(
                  alpha: context.appColors.badgeFillAlpha,
                ),
                borderRadius: BorderRadius.circular(
                  AppTheme.squircleRadius(34),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          bill.description ?? 'Recurring Bill',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.ts(
                            13,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: kSpacing6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: context.appColors.expenseColor.withValues(
                            alpha: context.appColors.badgeFillAlpha,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
                        ),
                        child: Text(
                          'Due Today',
                          style: context.ts(
                            8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: context.appColors.expenseColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${bill.frequency.toUpperCase()} • Interval: ${bill.intervalValue}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.ts(
                      11,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: kSpacing10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  CurrencyFormatter.formatCents(bill.amount),
                  style: context.ts(
                    12.5,
                    fontWeight: FontWeight.w800,
                    color: context.appColors.expenseColor,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpacing10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: context.appColors.expenseColor.withValues(
                      alpha: context.appColors.badgeFillAlpha,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(
                      color: context.appColors.expenseColor.withValues(
                        alpha: context.appColors.badgeBorderAlpha,
                      ),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    'Pay Now',
                    style: context.ts(
                      10,
                      fontWeight: FontWeight.w700,
                      color: context.appColors.expenseColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsRow(BuildContext context, dynamic goal) {
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

    return TactileSpringContainer(
      onTap: () {
        showQuickDepositSheet(context, ref, goal);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: kSpacing12,
          vertical: kSpacing10,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: goalColor.withValues(
                  alpha: context.appColors.badgeFillAlpha,
                ),
                borderRadius: BorderRadius.circular(
                  AppTheme.squircleRadius(34),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(getGoalIcon(goal.icon), color: goalColor, size: 16),
            ),
            const SizedBox(width: kSpacing10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          goal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.ts(
                            13,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: kSpacing6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(
                            alpha: context.appColors.badgeFillAlpha,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
                        ),
                        child: Text(
                          statusLabel,
                          style: context.ts(
                            8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${CurrencyFormatter.formatCents(goal.currentAmount)} of ${CurrencyFormatter.formatCents(goal.targetAmount)} • $pctInt% saved',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.ts(
                      11,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: kSpacing10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: kSpacing12,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: goalColor.withValues(
                  alpha: context.appColors.badgeFillAlpha,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(
                  color: goalColor.withValues(
                    alpha: context.appColors.badgeBorderAlpha,
                  ),
                  width: 0.8,
                ),
              ),
              child: Text(
                'Deposit',
                style: context.ts(
                  10.5,
                  fontWeight: FontWeight.w700,
                  color: goalColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetRow(BuildContext context, dynamic progress) {
    final theme = Theme.of(context);
    final isExceeded = progress.remaining < 0;
    final diffAmount = CurrencyFormatter.formatCents(progress.remaining.abs());
    final pct = progress.percentage as double;
    final pctInt = (pct * 100).toInt();

    return TactileSpringContainer(
      onTap: () {
        Navigator.of(context).pop();
        context.push('/budgets');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: kSpacing12,
          vertical: kSpacing10,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(
                  alpha: context.appColors.badgeFillAlpha,
                ),
                borderRadius: BorderRadius.circular(
                  AppTheme.squircleRadius(34),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          progress.budget.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.ts(
                            13,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: kSpacing6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withValues(
                            alpha: context.appColors.badgeFillAlpha,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
                        ),
                        child: Text(
                          isExceeded ? '$pctInt% EXCEEDED' : '$pctInt% LIMIT',
                          style: context.ts(
                            8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isExceeded
                        ? 'Over budget by $diffAmount'
                        : 'Near limit: ${CurrencyFormatter.formatCents(progress.spentInPeriod)} spent',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.ts(
                      11,
                      fontWeight: FontWeight.w500,
                      color: isExceeded
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: kSpacing10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: kSpacing12,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(
                  alpha: context.appColors.badgeFillAlpha,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(
                    alpha: context.appColors.badgeBorderAlpha,
                  ),
                  width: 0.8,
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
          ],
        ),
      ),
    );
  }

  Widget _buildLoanRow(BuildContext context, dynamic loan) {
    final theme = Theme.of(context);
    final isOverdue =
        loan.dueAt != null && loan.dueAt!.isBefore(DateTime.now());

    return TactileSpringContainer(
      onTap: () {
        Navigator.of(context).pop();
        context.push('/loans');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: kSpacing12,
          vertical: kSpacing10,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(
                  alpha: context.appColors.badgeFillAlpha,
                ),
                borderRadius: BorderRadius.circular(
                  AppTheme.squircleRadius(34),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          loan.description ?? 'Active Loan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.ts(
                            13,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: kSpacing6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (isOverdue
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.primary)
                                  .withValues(
                                    alpha: context.appColors.badgeFillAlpha,
                                  ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
                        ),
                        child: Text(
                          isOverdue ? 'OVERDUE' : 'DUE SOON',
                          style: context.ts(
                            8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: isOverdue
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isOverdue ? 'Repayment Overdue' : 'Due Soon',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.ts(
                      11,
                      fontWeight: FontWeight.w600,
                      color: isOverdue
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: kSpacing10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  CurrencyFormatter.formatCents(loan.remaining),
                  style: context.ts(
                    12.5,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpacing10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(
                      alpha: context.appColors.badgeFillAlpha,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(
                        alpha: context.appColors.badgeBorderAlpha,
                      ),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    'Details',
                    style: context.ts(
                      10,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kSpacing40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: context.appColors.incomeColor.withValues(
                  alpha: context.appColors.badgeFillAlpha,
                ),
                borderRadius: BorderRadius.circular(
                  AppTheme.squircleRadius(50),
                ),
                border: Border.all(
                  color: context.appColors.incomeColor.withValues(
                    alpha: context.appColors.badgeBorderAlpha,
                  ),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                PesaFlowIcons.check,
                color: context.appColors.incomeColor,
                size: 24,
              ),
            ),
            const SizedBox(height: kSpacing14),
            Text(
              'All Caught Up!',
              style: context.ts(
                15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: kSpacing4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kSpacing32),
              child: Text(
                'No pending carrier SMS, overdue bills, or budget warnings at this time.',
                textAlign: TextAlign.center,
                style: context.ts(
                  12,
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
