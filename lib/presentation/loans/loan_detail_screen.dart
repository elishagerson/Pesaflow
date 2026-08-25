import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/loan_repository.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/core/utils/date_formatter.dart';
import 'widgets/transaction_tile.dart';
import 'widgets/loan_info_rows.dart';
import 'widgets/payment_sheet.dart';
import 'widgets/offline_payment_sheet.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/presentation/common/widgets/empty_state.dart';
import 'package:pesaflow/presentation/common/widgets/undo_delete.dart';

import 'package:pesaflow/presentation/common/widgets/error_state.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

class LoanDetailScreen extends ConsumerWidget {
  final String loanId;

  const LoanDetailScreen({required this.loanId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final loansAsync = ref.watch(loansStreamProvider);
    final transactionsAsync = ref.watch(loanTransactionsStreamProvider(loanId));

    return loansAsync.when(
      data: (loans) {
        final loan = loans.where((l) => l.id == loanId).firstOrNull;
        if (loan == null) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    children: [
                      TactileSpringContainer(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(kSpacing10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: kSpacing12),
                      Text('Loan Details', style: context.ts(34, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
                    ],
                  ),
                ),
                const Expanded(
                  child: EmptyState(
                    icon: PesaFlowIcons.loans,
                    title: 'Loan Not Found',
                    subtitle: 'The requested loan details could not be located.',
                  ),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          TactileSpringContainer(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              padding: const EdgeInsets.all(kSpacing10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                            ),
                          ),
                          const SizedBox(width: kSpacing12),
                          Text('Loan Details', style: context.ts(34, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
                        ],
                      ),
                      Row(
                        children: [
                          TactileSpringContainer(
                            onTap: () => context.push('/loans/${loan.id}/edit'),
                            child: Container(
                              padding: const EdgeInsets.all(kSpacing10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(PesaFlowIcons.edit, size: 18, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: kSpacing8),
                          TactileSpringContainer(
                            onTap: () => _confirmDelete(context, ref, loan),
                            child: Container(
                              padding: const EdgeInsets.all(kSpacing10),
                              decoration: BoxDecoration(
                                color: context.appColors.expenseColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(PesaFlowIcons.delete, size: 18, color: context.appColors.expenseColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(kSpacing16),
                    children: [
              StaggeredFadeSlide(
                index: 0,
                child: _buildLoanHeader(context, loan, theme),
              ),
              const SizedBox(height: kSpacing16),
              StaggeredFadeSlide(
                index: 1,
                child: _buildLoanInfo(context, loan, theme),
              ),
              const SizedBox(height: kSpacing16),
              StaggeredFadeSlide(
                index: 2,
                child: _buildStatusTimeline(context, loan, theme),
              ),
              if (loan.installmentAmount != null) ...[
                const SizedBox(height: kSpacing16),
                StaggeredFadeSlide(
                  index: 3,
                  child: _buildInstallmentSchedule(context, loan, theme),
                ),
              ],
              StaggeredFadeSlide(
                index: 4,
                child: _buildPayoffProjection(context, loan, theme),
              ),
              if (loan.status == 'active') ...[
                const SizedBox(height: kSpacing16),
                StaggeredFadeSlide(
                  index: 5,
                  child: _buildPaymentButton(context, loan, theme, ref),
                ),
              ],
              const SizedBox(height: kSpacing20),
              StaggeredFadeSlide(
                index: loan.status == 'active' ? 6 : 5,
                child: Text(
                  'Payment History',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: kSpacing8),
              transactionsAsync.when(
                data: (txs) {
                  if (txs.isEmpty) {
                    return StaggeredFadeSlide(
                      index: 6,
                      child: GlassCard(
                        padding: const EdgeInsets.all(kSpacing20),
                        borderRadius: AppTheme.radiusCard,
                        child: Center(
                          child: Text(
                            'No payment transactions recorded',
                            style: context.ts(
                              14,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: txs.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final tx = entry.value;
                      return StaggeredFadeSlide(
                        index: 7 + idx,
                        child: TransactionTile(tx: tx),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: kSpacing20),
                  child: SkeletonCard(height: 80),
                ),
                error: (e, _) => ErrorState(
                  title: 'Failed to Load Payments',
                  message: e.toString(),
                  onRetry: () =>
                      ref.invalidate(loanTransactionsStreamProvider(loanId)),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
),
);
      },
      loading: () => Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  TactileSpringContainer(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(kSpacing10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: kSpacing12),
                  Text('Loan Details', style: context.ts(34, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
                ],
              ),
            ),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.all(kSpacing20),
                child: Column(
                  children: [
                    SkeletonCard(height: 180),
                    SizedBox(height: kSpacing16),
                    SkeletonCard(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  TactileSpringContainer(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(kSpacing10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: kSpacing12),
                  Text('Loan Details', style: context.ts(34, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
                ],
              ),
            ),
            Expanded(
              child: ErrorState(
                title: 'Failed to Load Loan Details',
                message: e.toString(),
                onRetry: () => ref.invalidate(loansStreamProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanHeader(BuildContext context, Loan loan, ThemeData theme) {
    final isActive = loan.status == 'active';
    final isPaid = loan.status == 'paid';
    final ratio = loan.amount > 0 ? loan.remaining / loan.amount : 0.0;
    final statusColor = isActive
        ? (ratio > 0.5
              ? context.appColors.expenseColor
              : theme.colorScheme.tertiary)
        : context.appColors.incomeColor;

    return Hero(
      tag: 'loan-${loan.id}',
      child: GlassCard(
        borderRadius: AppTheme.radiusCard,
        elevation: CardElevation.medium,
        accentColor: statusColor,
        child: Padding(
          padding: const EdgeInsets.all(kSpacing20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(kSpacing16),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPaid ? PesaFlowIcons.success : PesaFlowIcons.loans,
                  color: statusColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: kSpacing16),
              Text(
                CurrencyFormatter.formatCents(
                  isActive ? loan.remaining : loan.amount,
                ),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: kSpacing4),
              Text(
                isActive
                    ? 'Remaining Balance'
                    : isPaid
                    ? 'Fully Paid'
                    : 'Defaulted',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
              if (isActive) ...[
                const SizedBox(height: kSpacing16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(kSpacing6),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    backgroundColor: statusColor.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: kSpacing8),
                Text(
                  '${(ratio * 100).round()}% remaining of ${CurrencyFormatter.formatCents(loan.amount)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoanInfo(BuildContext context, Loan loan, ThemeData theme) {
    return GlassCard(
      borderRadius: AppTheme.radiusCard,
      elevation: CardElevation.low,
      child: Padding(
        padding: const EdgeInsets.all(kSpacing12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(kSpacing4),
              child: Text(
                'Loan Information',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: kSpacing12),
            CopyableInfoRow(label: 'Provider', value: loan.provider ?? 'N/A'),
            if (loan.category != null)
              CopyableInfoRow(label: 'Category', value: loan.category!),
            if (loan.interestRate != null)
              InfoRow(
                label: 'APR',
                value: '${loan.interestRate!.toStringAsFixed(1)}%',
              ),
            CopyableInfoRow(label: 'Reference', value: loan.reference ?? 'N/A'),
            CopyableInfoRow(label: 'Sender', value: loan.sender ?? 'N/A'),
            InfoRow(
              label: 'Disbursed',
              value: DateFormatter.shortDate(loan.disbursedAt),
            ),
            if (loan.dueAt != null)
              InfoRow(
                label: 'Due Date',
                value: DateFormatter.shortDate(loan.dueAt!),
              ),
            InfoRow(
              label: 'Status',
              value: loan.status == 'paid'
                  ? 'Paid'
                  : loan.status == 'active'
                  ? 'Active'
                  : 'Defaulted',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTimeline(
    BuildContext context,
    Loan loan,
    ThemeData theme,
  ) {
    final events = <_TimelineEvent>[
      _TimelineEvent(
        title: 'Loan Disbursed',
        subtitle: CurrencyFormatter.formatCents(loan.amount),
        date: loan.disbursedAt,
        isCompleted: true,
      ),
    ];
    if (loan.dueAt != null) {
      final isOverdue =
          loan.dueAt!.isBefore(DateTime.now()) && loan.status == 'active';
      events.add(
        _TimelineEvent(
          title: isOverdue ? 'Due Date (Overdue)' : 'Due Date',
          subtitle: isOverdue ? 'PAYMENT OVERDUE' : 'Scheduled repayment',
          date: loan.dueAt!,
          isCompleted: loan.status == 'paid',
          isWarning: isOverdue,
        ),
      );
    }
    if (loan.status == 'paid' && loan.paidAt != null) {
      events.add(
        _TimelineEvent(
          title: 'Loan Paid',
          subtitle: CurrencyFormatter.formatCents(loan.amount),
          date: loan.paidAt!,
          isCompleted: true,
          isLast: true,
        ),
      );
    } else {
      events.add(
        _TimelineEvent(
          title: 'Repayment',
          subtitle: 'In progress',
          date: null,
          isCompleted: false,
          isLast: true,
        ),
      );
    }

    return GlassCard(
      borderRadius: AppTheme.radiusCard,
      elevation: CardElevation.low,
      child: Padding(
        padding: const EdgeInsets.all(kSpacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status Timeline',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: kSpacing16),
            ...events.map((e) => _buildTimelineRow(context, e, theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRow(
    BuildContext context,
    _TimelineEvent event,
    ThemeData theme,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: event.isWarning
                        ? context.appColors.expenseColor
                        : event.isCompleted
                        ? context.appColors.incomeColor
                        : Colors.grey[400],
                    shape: BoxShape.circle,
                  ),
                ),
                if (!event.isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: event.isCompleted
                          ? context.appColors.incomeColor.withValues(alpha: 0.3)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.15),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: kSpacing12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: event.isLast ? 0 : kSpacing20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: kSpacing2),
                  Text(
                    event.subtitle,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  if (event.date != null) ...[
                    const SizedBox(height: kSpacing2),
                    Text(
                      DateFormatter.shortDate(event.date!),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallmentSchedule(
    BuildContext context,
    Loan loan,
    ThemeData theme,
  ) {
    final total = loan.totalInstallments ?? 0;
    final paid = loan.paidInstallments ?? 0;
    final amount = loan.installmentAmount ?? 0;
    final ratio = total > 0 ? paid / total : 0.0;

    return GlassCard(
      borderRadius: AppTheme.radiusCard,
      elevation: CardElevation.low,
      child: Padding(
        padding: const EdgeInsets.all(kSpacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Schedule',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: kSpacing12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$paid of $total installments paid',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: kSpacing6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(kSpacing4),
                        child: LinearProgressIndicator(
                          value: ratio.clamp(0.0, 1.0),
                          backgroundColor: theme.colorScheme.onSurface
                              .withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            context.appColors.incomeColor,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: kSpacing12),
                Text(
                  '${(ratio * 100).round()}%',
                  style: context.ts(
                    16,
                    fontWeight: FontWeight.w700,
                    color: Color.lerp(
                      context.appColors.expenseColor,
                      context.appColors.incomeColor,
                      ratio,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: kSpacing12),
            ...List.generate(total, (i) {
              final isPaid = i < paid;
              return Padding(
                padding: EdgeInsets.only(bottom: i < total - 1 ? kSpacing6 : 0),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isPaid
                            ? context.appColors.incomeColor.withValues(
                                alpha: 0.15,
                              )
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.05,
                              ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPaid ? PesaFlowIcons.check : PesaFlowIcons.schedule,
                        size: 12,
                        color: isPaid
                            ? context.appColors.incomeColor
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                      ),
                    ),
                    const SizedBox(width: kSpacing10),
                    Expanded(
                      child: Text(
                        'Installment ${i + 1}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatCents(amount),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: kSpacing8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kSpacing8,
                        vertical: kSpacing2,
                      ),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? context.appColors.incomeColor.withValues(
                                alpha: 0.12,
                              )
                            : AppTheme.tertiaryLight.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(kSpacing8),
                      ),
                      child: Text(
                        isPaid ? 'Paid' : 'Pending',
                        style: theme
                            .extension<AppTypographyTheme>()!
                            .labelMicro
                            .copyWith(
                              fontWeight: FontWeight.w700,
                              color: isPaid
                                  ? context.appColors.incomeColor
                                  : AppTheme.tertiaryLight,
                            ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoffProjection(
    BuildContext context,
    Loan loan,
    ThemeData theme,
  ) {
    if (loan.status == 'paid') return const SizedBox.shrink();

    DateTime? estimatedDate;
    String description;

    if (loan.installmentAmount != null && (loan.totalInstallments ?? 0) > 0) {
      final remaining = (loan.totalInstallments! - (loan.paidInstallments ?? 0))
          .clamp(0, loan.totalInstallments!);
      final freqDays = loan.frequencyInDays ?? 30;
      estimatedDate = DateTime.now().add(Duration(days: remaining * freqDays));
      description = remaining > 0
          ? 'Estimated payoff in $remaining installments'
          : 'All installments completed';
    } else {
      estimatedDate = DateTime.now().add(const Duration(days: 365));
      description = 'Estimated payoff within 1 year';
    }

    final daysLeft = DateTime.now().difference(estimatedDate).inDays.abs();

    return Padding(
      padding: const EdgeInsets.only(top: kSpacing16),
      child: GlassCard(
        borderRadius: AppTheme.radiusCard,
        elevation: CardElevation.low,
        child: Padding(
          padding: const EdgeInsets.all(kSpacing16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(kSpacing10),
                decoration: BoxDecoration(
                  color: AppTheme.tertiaryLight.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PesaFlowIcons.calendar,
                  size: 20,
                  color: AppTheme.tertiaryLight,
                ),
              ),
              const SizedBox(width: kSpacing14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      style: context.ts(
                        12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: kSpacing2),
                    Text(
                      DateFormatter.shortDate(estimatedDate),
                      style: context.ts(
                        16,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${daysLeft}d',
                style: context.ts(
                  22,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentButton(
    BuildContext context,
    Loan loan,
    ThemeData theme,
    WidgetRef ref,
  ) {
    return GlassCard(
      borderRadius: AppTheme.radiusCard,
      elevation: CardElevation.low,
      accentColor: context.appColors.incomeColor,
      child: Padding(
        padding: const EdgeInsets.all(kSpacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(kSpacing8),
                  decoration: BoxDecoration(
                    color: context.appColors.incomeColor.withValues(
                      alpha: 0.12,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    PesaFlowIcons.cash,
                    size: 20,
                    color: context.appColors.incomeColor,
                  ),
                ),
                const SizedBox(width: kSpacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready to pay?',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${CurrencyFormatter.formatCents(loan.remaining)} remaining',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: kSpacing16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => showPaymentSheet(context, ref, loan),
                icon: const Icon(PesaFlowIcons.payment, size: 18),
                label: const Text('Make a Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.appColors.incomeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: kSpacing14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: kSpacing10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => showOfflinePaymentSheet(context, ref, loan),
                icon: Icon(
                  PesaFlowIcons.transactions,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                label: Text(
                  'Record Offline Payment',
                  style: context.ts(
                    13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: kSpacing10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Loan loan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Loan?'),
        content: Text(
          loan.status == 'paid'
              ? 'Remove "${loan.description ?? loan.provider ?? 'Loan'}" from your records? All linked payment transactions will also be deleted.'
              : '"${loan.description ?? loan.provider ?? 'Loan'}" has an outstanding balance of ${CurrencyFormatter.formatCents(loan.remaining)}. Deleting it will also remove all linked payment transactions.',
          style: Theme.of(context).textTheme.titleSmall!,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx, rootNavigator: true).pop();
              final savedLoan = loan;
              UndoDelete.show(
                context: context,
                entityName: 'Loan',
                message:
                    '"${savedLoan.description ?? savedLoan.provider ?? 'Loan'}" deleted',
                onUndo: () async {
                  await ref.read(loanRepositoryProvider).createLoan(savedLoan);
                },
                onDelete: () async {
                  try {
                    await ref
                        .read(loanRepositoryProvider)
                        .deleteLoan(savedLoan.id);
                    if (context.mounted) context.pop();
                  } catch (e) {
                    if (context.mounted) {
                      CustomToast.show(
                        context,
                        message: 'Failed: $e',
                        type: ToastType.error,
                      );
                    }
                  }
                },
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _TimelineEvent {
  final String title;
  final String subtitle;
  final DateTime? date;
  final bool isCompleted;
  final bool isLast;
  final bool isWarning;

  const _TimelineEvent({
    required this.title,
    required this.subtitle,
    this.date,
    this.isCompleted = false,
    this.isLast = false,
    this.isWarning = false,
  });
}
