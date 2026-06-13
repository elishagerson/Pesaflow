import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';

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
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              StaggeredFadeSlide(
                index: 0,
                child: _buildLoanHeader(loan, theme, isDark),
              ),
              const SizedBox(height: 16),
              StaggeredFadeSlide(
                index: 1,
                child: _buildLoanInfo(loan, theme, isDark),
              ),
              const SizedBox(height: 16),
              StaggeredFadeSlide(
                index: 2,
                child: _buildStatusTimeline(loan, theme, isDark),
              ),
              if (loan.installmentAmount != null) ...[
                const SizedBox(height: 16),
                StaggeredFadeSlide(
                  index: 3,
                  child: _buildInstallmentSchedule(loan, theme, isDark),
                ),
              ],
              StaggeredFadeSlide(
                index: 4,
                child: _buildPayoffProjection(loan, theme, isDark),
              ),
              const SizedBox(height: 20),
              StaggeredFadeSlide(
                index: 5,
                child: Text(
                  'Payment History',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              transactionsAsync.when(
                data: (txs) {
                  if (txs.isEmpty) {
                    return StaggeredFadeSlide(
                      index: 6,
                      child: GlassCard(
                        padding: const EdgeInsets.all(20),
                        borderRadius: AppTheme.radiusCard,
                        child: Center(
                          child: Text(
                            'No payment transactions recorded',
                            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
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
                        child: _buildTransactionTile(tx, theme, isDark),
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
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildLoanHeader(Loan loan, ThemeData theme, bool isDark) {
    final isActive = loan.status == 'active';
    final isPaid = loan.status == 'paid';
    final ratio = loan.amount > 0 ? loan.remaining / loan.amount : 0.0;
    final statusColor = isActive
        ? (ratio > 0.5 ? const Color(0xFFE53935) : const Color(0xFFFF9F0A))
        : const Color(0xFF609F8A);

    return GlassCard(
      borderRadius: AppTheme.radiusCard,
      elevation: CardElevation.medium,
      accentColor: statusColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPaid ? Icons.check_circle_rounded : Icons.account_balance_rounded,
                color: statusColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              CurrencyFormatter.formatCents(isActive ? loan.remaining : loan.amount),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isActive ? 'Remaining Balance' : isPaid ? 'Fully Paid' : 'Defaulted',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
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
    );
  }

  Widget _buildLoanInfo(Loan loan, ThemeData theme, bool isDark) {
    return GlassCard(
      borderRadius: AppTheme.radiusCard,
      elevation: CardElevation.low,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Loan Information',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _infoRow('Provider', loan.provider ?? 'N/A', isDark),
            if (loan.interestRate != null)
              _infoRow('APR', '${loan.interestRate!.toStringAsFixed(1)}%', isDark),
            _infoRow('Reference', loan.reference ?? 'N/A', isDark),
            _infoRow('Sender', loan.sender ?? 'N/A', isDark),
            _infoRow('Disbursed', _formatDate(loan.disbursedAt), isDark),
            if (loan.dueAt != null)
              _infoRow('Due Date', _formatDate(loan.dueAt!), isDark),
            _infoRow('Status', loan.status == 'paid' ? 'Paid' : loan.status == 'active' ? 'Active' : 'Defaulted', isDark),
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
      final isOverdue = loan.dueAt!.isBefore(DateTime.now()) && loan.status == 'active';
      events.add(_TimelineEvent(
        title: isOverdue ? 'Due Date (Overdue)' : 'Due Date',
        subtitle: isOverdue ? 'PAYMENT OVERDUE' : 'Scheduled repayment',
        date: loan.dueAt!,
        isCompleted: loan.status == 'paid',
        isWarning: isOverdue,
      ));
    }
    if (loan.status == 'paid' && loan.paidAt != null) {
      events.add(_TimelineEvent(
        title: 'Loan Paid',
        subtitle: CurrencyFormatter.formatCents(loan.amount),
        date: loan.paidAt!,
        isCompleted: true,
        isLast: true,
      ));
    } else {
      events.add(_TimelineEvent(
        title: 'Repayment',
        subtitle: 'In progress',
        date: null,
        isCompleted: false,
        isLast: true,
      ));
    }

    return GlassCard(
      borderRadius: AppTheme.radiusCard,
      elevation: CardElevation.low,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status Timeline',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
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
                          : event.isCompleted ? const Color(0xFF609F8A) : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (!event.isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: event.isCompleted ? const Color(0xFF609F8A).withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: event.isLast ? 0 : 20),
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
                  const SizedBox(height: 2),
                  Text(
                    event.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  if (event.date != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(event.date!),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
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

  Widget _buildInstallmentSchedule(Loan loan, ThemeData theme, bool isDark) {
    final total = loan.totalInstallments ?? 0;
    final paid = loan.paidInstallments ?? 0;
    final amount = loan.installmentAmount ?? 0;
    final ratio = total > 0 ? paid / total : 0.0;

    return GlassCard(
      borderRadius: AppTheme.radiusCard,
      elevation: CardElevation.low,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Schedule',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
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
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio.clamp(0.0, 1.0),
                          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF609F8A),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(ratio * 100).round()}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color.lerp(const Color(0xFFE53935), const Color(0xFF609F8A), ratio),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(total, (i) {
              final isPaid = i < paid;
              return Padding(
                padding: EdgeInsets.only(bottom: i < total - 1 ? 6 : 0),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isPaid
                            ? const Color(0xFF609F8A).withValues(alpha: 0.15)
                            : (isDark ? Colors.grey[800] : Colors.grey[200]),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPaid ? Icons.check_rounded : Icons.schedule_rounded,
                        size: 12,
                        color: isPaid
                            ? const Color(0xFF609F8A)
                            : (isDark ? Colors.grey[500] : Colors.grey[400]),
                      ),
                    ),
                    const SizedBox(width: 10),
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? const Color(0xFF609F8A).withValues(alpha: 0.12)
                            : const Color(0xFFFF9F0A).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isPaid ? 'Paid' : 'Pending',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isPaid ? const Color(0xFF609F8A) : const Color(0xFFFF9F0A),
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
      final remaining = (loan.totalInstallments! - (loan.paidInstallments ?? 0)).clamp(0, loan.totalInstallments!);
      final freqDays = loan.frequencyInDays ?? 30;
      estimatedDate = DateTime.now().add(Duration(days: remaining * freqDays));
      description = remaining > 0
          ? 'Estimated payoff in $remaining installments'
          : 'All installments completed';
    } else {
      // Estimate based on remaining balance assuming 30-day cycle
      estimatedDate = DateTime.now().add(const Duration(days: 365));
      description = 'Estimated payoff within 1 year';
    }

    if (estimatedDate == null) return const SizedBox.shrink();

    final daysLeft = DateTime.now().difference(estimatedDate).inDays.abs();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GlassCard(
        borderRadius: AppTheme.radiusCard,
        elevation: CardElevation.low,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9F0A).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.event_rounded, size: 20, color: Color(0xFFFF9F0A)),
              ),
              const SizedBox(width: 14),
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
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(estimatedDate),
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

  Widget _buildTransactionTile(Transaction tx, ThemeData theme, bool isDark) {
    final isCredit = tx.type == 'income';
    final amountColor = isCredit ? const Color(0xFF609F8A) : const Color(0xFFE53935);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceContainerDark : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: isDark ? const Color(0x12FFFFFF) : const Color(0x1F000000),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: amountColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: amountColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description.isNotEmpty ? tx.description : (tx.type == 'income' ? 'Payment Received' : 'Payment Sent'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(tx.createdAt),
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[500]),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}${CurrencyFormatter.formatCents(tx.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _TimelineEvent {
  final String title;
  final String subtitle;
  final DateTime? date;
  final bool isCompleted;
  final bool isLast;
  final bool isWarning;

  _TimelineEvent({
    required this.title,
    required this.subtitle,
    this.date,
    this.isCompleted = false,
    this.isLast = false,
    this.isWarning = false,
  });
}
