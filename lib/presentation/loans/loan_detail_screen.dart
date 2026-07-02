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

class LoanDetailScreen extends ConsumerWidget {
  final String loanId;

  const LoanDetailScreen({required this.loanId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loansAsync = ref.watch(loansStreamProvider);
    final transactionsAsync = ref.watch(loanTransactionsStreamProvider(loanId));

    return loansAsync.when(
      data: (loans) {
        final loan = loans.where((l) => l.id == loanId).firstOrNull;
        if (loan == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Loan')),
            body: const Center(child: Text('Loan not found')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Loan Details'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(PesaFlowIcons.edit),
                onPressed: () => context.push('/loans/${loan.id}/edit'),
              ),
              IconButton(
                icon: Icon(
                  PesaFlowIcons.delete,
                  color: theme.colorScheme.error,
                ),
                onPressed: () => _confirmDelete(context, ref, loan),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(kSpacing16),
            children: [
              StaggeredFadeSlide(
                index: 0,
                child: _buildLoanHeader(loan, theme, isDark),
              ),
              const SizedBox(height: kSpacing16),
              StaggeredFadeSlide(
                index: 1,
                child: _buildLoanInfo(context, loan, theme),
              ),
              const SizedBox(height: kSpacing16),
              StaggeredFadeSlide(
                index: 2,
                child: _buildStatusTimeline(loan, theme, isDark),
              ),
              if (loan.installmentAmount != null) ...[
                const SizedBox(height: kSpacing16),
                StaggeredFadeSlide(
                  index: 3,
                  child: _buildInstallmentSchedule(loan, theme, isDark),
                ),
              ],
              StaggeredFadeSlide(
                index: 4,
                child: _buildPayoffProjection(loan, theme, isDark),
              ),
              if (loan.status == 'active') ...[
                const SizedBox(height: kSpacing16),
                StaggeredFadeSlide(
                  index: 5,
                  child: _buildPaymentButton(context, loan, theme, isDark, ref),
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
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
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
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildLoanHeader(Loan loan, ThemeData theme, bool isDark) {
    final isActive = loan.status == 'active';
    final isPaid = loan.status == 'paid';
    final ratio = loan.amount > 0 ? loan.remaining / loan.amount : 0.0;
    final statusColor = isActive
        ? (ratio > 0.5 ? const Color(0xFFE53935) : const Color(0xFFFF9F0A))
        : const Color(0xFF10B981);

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
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: kSpacing4),
              Text(
                isActive
                    ? 'Remaining Balance'
                    : isPaid
                    ? 'Fully Paid'
                    : 'Defaulted',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
              if (isActive) ...[
                const SizedBox(height: kSpacing16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
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
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
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

  Widget _buildStatusTimeline(Loan loan, ThemeData theme, bool isDark) {
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
            ...events.map((e) => _buildTimelineRow(e, theme, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRow(_TimelineEvent event, ThemeData theme, bool isDark) {
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
                        ? const Color(0xFFE53935)
                        : event.isCompleted
                        ? const Color(0xFF10B981)
                        : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!event.isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: event.isCompleted
                          ? const Color(0xFF10B981).withValues(alpha: 0.3)
                          : Colors.grey.withValues(alpha: 0.3),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: kSpacing2),
                  Text(
                    event.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  if (event.date != null) ...[
                    const SizedBox(height: kSpacing2),
                    Text(
                      DateFormatter.shortDate(event.date!),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
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

  Widget _buildInstallmentSchedule(Loan loan, ThemeData theme, bool isDark) {
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
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: kSpacing6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio.clamp(0.0, 1.0),
                          backgroundColor: isDark
                              ? Colors.grey[800]
                              : Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF10B981),
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color.lerp(
                      const Color(0xFFE53935),
                      const Color(0xFF10B981),
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
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : (isDark ? Colors.grey[800] : Colors.grey[200]),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPaid ? Icons.check_rounded : Icons.schedule_rounded,
                        size: 12,
                        color: isPaid
                            ? const Color(0xFF10B981)
                            : (isDark ? Colors.grey[500] : Colors.grey[400]),
                      ),
                    ),
                    const SizedBox(width: kSpacing10),
                    Expanded(
                      child: Text(
                        'Installment ${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatCents(amount),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
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
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : const Color(0xFFFF9F0A).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isPaid ? 'Paid' : 'Pending',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isPaid
                              ? const Color(0xFF10B981)
                              : const Color(0xFFFF9F0A),
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

  Widget _buildPayoffProjection(Loan loan, ThemeData theme, bool isDark) {
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
                  color: const Color(0xFFFF9F0A).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PesaFlowIcons.calendar,
                  size: 20,
                  color: Color(0xFFFF9F0A),
                ),
              ),
              const SizedBox(width: kSpacing14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: kSpacing2),
                    Text(
                      DateFormatter.shortDate(estimatedDate),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${daysLeft}d',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFFF9F0A),
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
    bool isDark,
    WidgetRef ref,
  ) {
    return GlassCard(
      borderRadius: AppTheme.radiusCard,
      elevation: CardElevation.low,
      accentColor: const Color(0xFF10B981),
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
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    PesaFlowIcons.cash,
                    size: 20,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: kSpacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready to pay?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        '${CurrencyFormatter.formatCents(loan.remaining)} remaining',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
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
                icon: const Icon(Icons.payment_rounded, size: 18),
                label: const Text('Make a Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: kSpacing14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                label: Text(
                  'Record Offline Payment',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: kSpacing10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
          style: const TextStyle(fontSize: 14),
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
              try {
                await ref.read(loanRepositoryProvider).deleteLoan(loan.id);
                ref.invalidate(loansStreamProvider);
                ref.invalidate(activeLoansStreamProvider);
                ref.invalidate(paidLoansStreamProvider);
                if (context.mounted) {
                  Navigator.of(ctx, rootNavigator: true).pop();
                  context.pop();
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(ctx, rootNavigator: true).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
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
