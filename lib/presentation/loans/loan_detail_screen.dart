import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/account_repository.dart';
import 'package:pesaflow/data/repositories/category_repository.dart';
import 'package:pesaflow/data/repositories/loan_repository.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/liquid_glass.dart';

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
                child: _buildLoanInfo(context, loan, theme, isDark),
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
        : const Color(0xFF609F8A);

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

  Widget _buildLoanInfo(
    BuildContext context,
    Loan loan,
    ThemeData theme,
    bool isDark,
  ) {
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
            _copyableInfoRow(
              context,
              'Provider',
              loan.provider ?? 'N/A',
              isDark,
            ),
            if (loan.interestRate != null)
              _infoRow(
                'APR',
                '${loan.interestRate!.toStringAsFixed(1)}%',
                isDark,
              ),
            _copyableInfoRow(
              context,
              'Reference',
              loan.reference ?? 'N/A',
              isDark,
            ),
            _copyableInfoRow(context, 'Sender', loan.sender ?? 'N/A', isDark),
            _infoRow('Disbursed', _formatDate(loan.disbursedAt), isDark),
            if (loan.dueAt != null)
              _infoRow('Due Date', _formatDate(loan.dueAt!), isDark),
            _infoRow(
              'Status',
              loan.status == 'paid'
                  ? 'Paid'
                  : loan.status == 'active'
                  ? 'Active'
                  : 'Defaulted',
              isDark,
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
                        ? const Color(0xFF609F8A)
                        : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!event.isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: event.isCompleted
                          ? const Color(0xFF609F8A).withValues(alpha: 0.3)
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
                            Color(0xFF609F8A),
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
                      const Color(0xFF609F8A),
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
                            ? const Color(0xFF609F8A).withValues(alpha: 0.12)
                            : const Color(0xFFFF9F0A).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isPaid ? 'Paid' : 'Pending',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isPaid
                              ? const Color(0xFF609F8A)
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
      // Estimate based on remaining balance assuming 30-day cycle
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
      accentColor: const Color(0xFF609F8A),
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
                    color: const Color(0xFF609F8A).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    PesaFlowIcons.cash,
                    size: 20,
                    color: Color(0xFF609F8A),
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
                onPressed: () => _showPaymentSheet(context, ref, loan),
                icon: const Icon(Icons.payment_rounded, size: 18),
                label: const Text('Make a Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF609F8A),
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
                onPressed: () => _showOfflinePaymentSheet(context, ref, loan),
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

  void _showPaymentSheet(BuildContext context, WidgetRef ref, Loan loan) {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remainingCents = loan.remaining;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        String? selectedAccountId;
        bool sheetIsProcessing = false;

        int paymentAmount() =>
            CurrencyFormatter.parseToCents(amountController.text);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final canSubmit =
                paymentAmount() > 0 &&
                selectedAccountId != null;

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              minChildSize: 0.5,
              expand: false,
              builder: (ctx, scrollController) => ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: LiquidGlassOverlay(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xF01C1C1E)
                            : const Color(0xF0F2F2F7),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          const SizedBox(height: kSpacing10),
                          Container(
                            width: 38,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.black.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                          const SizedBox(height: kSpacing16),
                          Expanded(
                            child: RawScrollbar(
                              controller: scrollController,
                              child: SingleChildScrollView(
                                controller: scrollController,
                                physics: const ClampingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  kSpacing20,
                                  0,
                                  kSpacing20,
                                  kSpacing24,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ── Header ──
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(
                                            kSpacing10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF609F8A,
                                            ).withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            PesaFlowIcons.cash,
                                            color: Color(0xFF609F8A),
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: kSpacing14),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Make a Payment',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: kSpacing2),
                                            Text(
                                              'Remaining: ${CurrencyFormatter.formatCents(remainingCents)}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isDark
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: kSpacing24),

                                    // ── Loan Progress Ring ──
                                    _buildLoanProgressRing(
                                      loan,
                                      remainingCents,
                                      isDark,
                                    ),
                                    const SizedBox(height: kSpacing24),

                                    // ── Amount Input ──
                                    const Text(
                                      'PAYMENT AMOUNT',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: kSpacing8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF1C1C1E)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.08,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.06,
                                                ),
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: kSpacing16,
                                        vertical: kSpacing4,
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            'TSh',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: isDark
                                                  ? Colors.white60
                                                  : Colors.black45,
                                            ),
                                          ),
                                          const SizedBox(width: kSpacing12),
                                          Expanded(
                                            child: TextField(
                                              controller: amountController,
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              autofocus: true,
                                              inputFormatters: [
                                                FilteringTextInputFormatter.allow(
                                                  RegExp(r'[\d.,]'),
                                                ),
                                              ],
                                              style: TextStyle(
                                                fontSize: 28,
                                                fontFamily: 'monospace',
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                              decoration: const InputDecoration(
                                                hintText: 'Enter amount',
                                                border: InputBorder.none,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      vertical: kSpacing12,
                                                    ),
                                              ),
                                              onChanged: (val) {
                                                setSheetState(() {});
                                              },
                                            ),
                                          ),
                                          if (paymentAmount() > 0)
                                            GestureDetector(
                                              onTap: () {
                                                amountController.clear();
                                                setSheetState(() {});
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  kSpacing4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? Colors.white.withValues(
                                                          alpha: 0.1,
                                                        )
                                                      : Colors.black.withValues(
                                                          alpha: 0.05,
                                                        ),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  PesaFlowIcons.close,
                                                  size: 18,
                                                  color: isDark
                                                      ? Colors.white54
                                                      : Colors.black45,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: kSpacing16),

                                    // ── Quick Amount Suggestions ──
                                    Row(
                                      children: [
                                        _QuickAmountChip(
                                          label: '25%',
                                          amount: (remainingCents * 0.25)
                                              .round(),
                                          isActive:
                                              paymentAmount() ==
                                              (remainingCents * 0.25).round(),
                                          onTap: () {
                                            amountController.text =
                                                ((remainingCents * 0.25)
                                                            .round() /
                                                        100)
                                                    .toStringAsFixed(0);
                                            amountController.selection =
                                                TextSelection.fromPosition(
                                                  TextPosition(
                                                    offset: amountController
                                                        .text
                                                        .length,
                                                  ),
                                                );
                                            setSheetState(() {});
                                          },
                                          isDark: isDark,
                                        ),
                                        const SizedBox(width: kSpacing8),
                                        _QuickAmountChip(
                                          label: '50%',
                                          amount: (remainingCents * 0.5)
                                              .round(),
                                          isActive:
                                              paymentAmount() ==
                                              (remainingCents * 0.5).round(),
                                          onTap: () {
                                            amountController.text =
                                                ((remainingCents * 0.5)
                                                            .round() /
                                                        100)
                                                    .toStringAsFixed(0);
                                            amountController.selection =
                                                TextSelection.fromPosition(
                                                  TextPosition(
                                                    offset: amountController
                                                        .text
                                                        .length,
                                                  ),
                                                );
                                            setSheetState(() {});
                                          },
                                          isDark: isDark,
                                        ),
                                        const SizedBox(width: kSpacing8),
                                        _QuickAmountChip(
                                          label: '75%',
                                          amount: (remainingCents * 0.75)
                                              .round(),
                                          isActive:
                                              paymentAmount() ==
                                              (remainingCents * 0.75).round(),
                                          onTap: () {
                                            amountController.text =
                                                ((remainingCents * 0.75)
                                                            .round() /
                                                        100)
                                                    .toStringAsFixed(0);
                                            amountController.selection =
                                                TextSelection.fromPosition(
                                                  TextPosition(
                                                    offset: amountController
                                                        .text
                                                        .length,
                                                  ),
                                                );
                                            setSheetState(() {});
                                          },
                                          isDark: isDark,
                                        ),
                                        const SizedBox(width: kSpacing8),
                                        _QuickAmountChip(
                                          label: '100%',
                                          amount: remainingCents,
                                          isActive:
                                              paymentAmount() == remainingCents,
                                          onTap: () {
                                            amountController.text =
                                                (remainingCents / 100)
                                                    .toStringAsFixed(0);
                                            amountController.selection =
                                                TextSelection.fromPosition(
                                                  TextPosition(
                                                    offset: amountController
                                                        .text
                                                        .length,
                                                  ),
                                                );
                                            setSheetState(() {});
                                          },
                                          isDark: isDark,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: kSpacing24),

                                    // ── Description Field ──
                                    const Text(
                                      'MEMO',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: kSpacing8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF1C1C1E)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.08,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.06,
                                                ),
                                        ),
                                      ),
                                      child: TextField(
                                        controller: descriptionController,
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Add a note (optional)',
                                          hintStyle: TextStyle(
                                            color: isDark
                                                ? Colors.white30
                                                : Colors.black26,
                                          ),
                                          prefixIcon: Icon(
                                            PesaFlowIcons.edit,
                                            size: 20,
                                            color: isDark
                                                ? Colors.white38
                                                : Colors.black26,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: kSpacing16,
                                                vertical: kSpacing14,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: kSpacing24),

                                    // ── Account Selection ──
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'FROM ACCOUNT',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        if (selectedAccountId != null)
                                          GestureDetector(
                                            onTap: () => setSheetState(
                                              () => selectedAccountId = null,
                                            ),
                                            child: Text(
                                              'Clear',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: const Color(
                                                  0xFFE53935,
                                                ).withValues(alpha: 0.8),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: kSpacing8),
                                    FutureBuilder<List<Account>>(
                                      future: ref
                                          .read(accountRepositoryProvider)
                                          .getAllAccounts(),
                                      builder: (context, snapshot) {
                                        final accounts = snapshot.data ?? [];
                                        if (accounts.isEmpty) {
                                          return Container(
                                            padding: const EdgeInsets.all(
                                              kSpacing16,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFFE53935,
                                              ).withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: const Color(
                                                  0xFFE53935,
                                                ).withValues(alpha: 0.2),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  PesaFlowIcons.warning,
                                                  size: 18,
                                                  color: Color(0xFFE53935),
                                                ),
                                                const SizedBox(
                                                  width: kSpacing10,
                                                ),
                                                Text(
                                                  'No accounts available. Create one first.',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: const Color(
                                                      0xFFE53935,
                                                    ).withValues(alpha: 0.9),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                        return Column(
                                          children: accounts.map((account) {
                                            final isSelected =
                                                account.id == selectedAccountId;
                                            final balanceCents =
                                                account.balance;
                                            final hasFunds =
                                                balanceCents >= paymentAmount();
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: kSpacing8,
                                              ),
                                              child: GestureDetector(
                                                onTap: () => setSheetState(
                                                  () => selectedAccountId =
                                                      account.id,
                                                ),
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 200,
                                                  ),
                                                  curve: Curves.easeOutCubic,
                                                  padding: const EdgeInsets.all(
                                                    kSpacing14,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? const Color(
                                                            0xFF609F8A,
                                                          ).withValues(
                                                            alpha: isDark
                                                                ? 0.15
                                                                : 0.08,
                                                          )
                                                        : isDark
                                                        ? const Color(
                                                            0xFF1C1C1E,
                                                          )
                                                        : Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                    border: Border.all(
                                                      color: isSelected
                                                          ? const Color(
                                                              0xFF609F8A,
                                                            ).withValues(
                                                              alpha: 0.5,
                                                            )
                                                          : isDark
                                                          ? Colors.white
                                                                .withValues(
                                                                  alpha: 0.08,
                                                                )
                                                          : Colors.black
                                                                .withValues(
                                                                  alpha: 0.06,
                                                                ),
                                                      width: isSelected
                                                          ? 1.5
                                                          : 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              kSpacing8,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: isSelected
                                                              ? const Color(
                                                                  0xFF609F8A,
                                                                ).withValues(
                                                                  alpha: 0.2,
                                                                )
                                                              : (isDark
                                                                    ? Colors
                                                                          .white
                                                                          .withValues(
                                                                            alpha:
                                                                                0.06,
                                                                          )
                                                                    : Colors
                                                                          .black
                                                                          .withValues(
                                                                            alpha:
                                                                                0.04,
                                                                          )),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: Icon(
                                                          isSelected
                                                              ? PesaFlowIcons
                                                                    .success
                                                              : PesaFlowIcons
                                                                    .wallet,
                                                          size: 20,
                                                          color: isSelected
                                                              ? const Color(
                                                                  0xFF609F8A,
                                                                )
                                                              : (isDark
                                                                    ? Colors
                                                                          .white54
                                                                    : Colors
                                                                          .black45),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        width: kSpacing12,
                                                      ),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              account.name,
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    isSelected
                                                                    ? FontWeight
                                                                          .w700
                                                                    : FontWeight
                                                                          .w500,
                                                                fontSize: 15,
                                                                color:
                                                                    isSelected
                                                                    ? (isDark
                                                                          ? Colors.white
                                                                          : const Color(
                                                                              0xFF609F8A,
                                                                            ))
                                                                    : (isDark
                                                                          ? Colors.white
                                                                          : Colors.black87),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: kSpacing2,
                                                            ),
                                                            Row(
                                                              children: [
                                                                Text(
                                                                  'Balance: ${CurrencyFormatter.formatCents(balanceCents)}',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    color:
                                                                        isDark
                                                                        ? Colors
                                                                              .white38
                                                                        : Colors
                                                                              .black38,
                                                                  ),
                                                                ),
                                                                if (selectedAccountId !=
                                                                        null &&
                                                                    !hasFunds &&
                                                                    paymentAmount() >
                                                                        0) ...[
                                                                  const SizedBox(
                                                                    width:
                                                                        kSpacing8,
                                                                  ),
                                                                  Container(
                                                                    padding: const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          kSpacing6,
                                                                      vertical:
                                                                          kSpacing2,
                                                                    ),
                                                                    decoration: BoxDecoration(
                                                                      color:
                                                                          const Color(
                                                                            0xFFE53935,
                                                                          ).withValues(
                                                                            alpha:
                                                                                0.12,
                                                                          ),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            4,
                                                                          ),
                                                                    ),
                                                                    child: const Text(
                                                                      'Insufficient',
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            10,
                                                                        color: Color(
                                                                          0xFFE53935,
                                                                        ),
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      if (isSelected)
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                kSpacing4,
                                                              ),
                                                          decoration:
                                                              BoxDecoration(
                                                                color:
                                                                    const Color(
                                                                      0xFF609F8A,
                                                                    ).withValues(
                                                                      alpha:
                                                                          0.15,
                                                                    ),
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                          child: const Icon(
                                                            Icons.check_rounded,
                                                            size: 16,
                                                            color: Color(
                                                              0xFF609F8A,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: kSpacing24),

                                    // ── Pay Button ──
                                    SizedBox(
                                      width: double.infinity,
                                      height: 54,
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          boxShadow: canSubmit
                                              ? [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFF609F8A,
                                                    ).withValues(alpha: 0.3),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: canSubmit && !sheetIsProcessing
                                              ? () async {
                                                  final desc =
                                                      descriptionController.text
                                                          .trim();
                                                  setSheetState(() {
                                                    sheetIsProcessing = true;
                                                  });
                                                  final success =
                                                      await _processPayment(
                                                    context: context,
                                                    ref: ref,
                                                    loan: loan,
                                                    amount: paymentAmount(),
                                                    description: desc.isNotEmpty
                                                        ? desc
                                                        : 'Manual loan payment',
                                                    accountId:
                                                        selectedAccountId!,
                                                  );
                                                  if (success) {
                                                    if (sheetContext.mounted) {
                                                      Navigator.of(
                                                        sheetContext,
                                                      ).pop();
                                                    }
                                                  } else {
                                                    setSheetState(() {
                                                      sheetIsProcessing = false;
                                                    });
                                                  }
                                                }
                                              : null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF609F8A,
                                            ),
                                            foregroundColor: Colors.white,
                                            disabledBackgroundColor: isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.05,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.05,
                                                  ),
                                            disabledForegroundColor: isDark
                                                ? Colors.white24
                                                : Colors.black26,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: kSpacing14,
                                            ),
                                          ),
                                          child: sheetIsProcessing
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    if (paymentAmount() > 0 &&
                                                        selectedAccountId !=
                                                            null)
                                                      Icon(
                                                        PesaFlowIcons.lock,
                                                        size: 16,
                                                        color: Colors.white
                                                            .withValues(
                                                          alpha: 0.8,
                                                        ),
                                                      ),
                                                    if (paymentAmount() > 0 &&
                                                        selectedAccountId !=
                                                            null)
                                                      const SizedBox(
                                                        width: kSpacing8,
                                                      ),
                                                    Text(
                                                      paymentAmount() <= 0
                                                          ? 'Enter an amount'
                                                          : selectedAccountId ==
                                                                null
                                                          ? 'Select an account'
                                                          : 'Pay ${CurrencyFormatter.formatCents(paymentAmount())}',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
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
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoanProgressRing(Loan loan, int remainingCents, bool isDark) {
    final totalInstallments = loan.totalInstallments ?? 0;
    final paidInstallments = loan.paidInstallments ?? 0;
    final totalAmount = loan.amount;
    final paidAmount = totalAmount - remainingCents;

    final paidFraction = totalAmount > 0
        ? (paidAmount / totalAmount).clamp(0.0, 1.0)
        : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  value: paidFraction,
                  strokeWidth: 5,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF609F8A),
                  ),
                ),
              ),
              Text(
                '${(paidFraction * 100).round()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: kSpacing16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Paid',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatCents(paidAmount),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF609F8A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: kSpacing4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Remaining',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatCents(remainingCents),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE53935),
                    ),
                  ),
                ],
              ),
              if (totalInstallments > 0) ...[
                const SizedBox(height: kSpacing4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Installments',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    Text(
                      '$paidInstallments/$totalInstallments',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<bool> _processPayment({
    required BuildContext context,
    required WidgetRef ref,
    required Loan loan,
    required int amount,
    required String description,
    required String accountId,
  }) async {
    try {
      final activeTrackerId =
          await ref
              .read(settingsRepositoryProvider)
              .getSetting('active_tracker_id') ??
          'default_personal';
      final categories = await ref
          .read(categoryRepositoryProvider)
          .getAllCategories();
      final expenseCat = categories.firstWhere(
        (c) => c.type == 'expense',
        orElse: () => categories.first,
      );

      final txn = Transaction(
        id: const Uuid().v4(),
        accountId: accountId,
        categoryId: expenseCat.id,
        trackerId: activeTrackerId,
        loanId: loan.id,
        amount: amount,
        type: 'expense',
        description: description,
        source: 'manual',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref
          .read(transactionRepositoryNoAlertsProvider)
          .createTransaction(txn);
      await ref.read(loanRepositoryProvider).applyPayment(loan.id, amount);

      HapticFeedback.mediumImpact();
      return true;
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
      return false;
    }
  }

  void _showOfflinePaymentSheet(
    BuildContext context,
    WidgetRef ref,
    Loan loan,
  ) {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remainingCents = loan.remaining;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        bool sheetIsProcessing = false;

        int paymentAmount() =>
            CurrencyFormatter.parseToCents(amountController.text);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final canSubmit = paymentAmount() > 0;

            return DraggableScrollableSheet(
              initialChildSize: 0.5,
              maxChildSize: 0.7,
              minChildSize: 0.4,
              expand: false,
              builder: (ctx, scrollController) => ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: LiquidGlassOverlay(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xF01C1C1E)
                            : const Color(0xF0F2F2F7),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          const SizedBox(height: kSpacing10),
                          Container(
                            width: 38,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.black.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                          const SizedBox(height: kSpacing16),
                          Expanded(
                            child: RawScrollbar(
                              controller: scrollController,
                              child: SingleChildScrollView(
                                controller: scrollController,
                                physics: const ClampingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  kSpacing20,
                                  0,
                                  kSpacing20,
                                  kSpacing24,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(
                                            kSpacing10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF609F8A,
                                            ).withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            PesaFlowIcons.transactions,
                                            color: Color(0xFF609F8A),
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: kSpacing14),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Record Offline Payment',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: kSpacing2),
                                            Text(
                                              'No wallet account will be affected',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.grey[500]
                                                    : Colors.grey[500],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: kSpacing24),
                                    const Text(
                                      'AMOUNT',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: kSpacing8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF1C1C1E)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.08,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.06,
                                                ),
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: kSpacing16,
                                        vertical: kSpacing4,
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            'TSh',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: isDark
                                                  ? Colors.white60
                                                  : Colors.black45,
                                            ),
                                          ),
                                          const SizedBox(width: kSpacing12),
                                          Expanded(
                                            child: TextField(
                                              controller: amountController,
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              autofocus: true,
                                              inputFormatters: [
                                                FilteringTextInputFormatter.allow(
                                                  RegExp(r'[\d.,]'),
                                                ),
                                              ],
                                              style: TextStyle(
                                                fontSize: 28,
                                                fontFamily: 'monospace',
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                              decoration: const InputDecoration(
                                                hintText: 'Enter amount',
                                                border: InputBorder.none,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      vertical: kSpacing12,
                                                    ),
                                              ),
                                              onChanged: (val) {
                                                setSheetState(() {});
                                              },
                                            ),
                                          ),
                                          if (paymentAmount() > 0)
                                            GestureDetector(
                                              onTap: () {
                                                amountController.clear();
                                                setSheetState(() {});
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  kSpacing4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? Colors.white.withValues(
                                                          alpha: 0.1,
                                                        )
                                                      : Colors.black.withValues(
                                                          alpha: 0.05,
                                                        ),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  PesaFlowIcons.close,
                                                  size: 18,
                                                  color: isDark
                                                      ? Colors.white54
                                                      : Colors.black45,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: kSpacing16),
                                    Row(
                                      children: [
                                        _QuickAmountChip(
                                          label: '25%',
                                          amount: (remainingCents * 0.25)
                                              .round(),
                                          isActive:
                                              paymentAmount() ==
                                              (remainingCents * 0.25).round(),
                                          onTap: () {
                                            amountController.text =
                                                ((remainingCents * 0.25)
                                                            .round() /
                                                        100)
                                                    .toStringAsFixed(0);
                                            amountController.selection =
                                                TextSelection.fromPosition(
                                                  TextPosition(
                                                    offset: amountController
                                                        .text
                                                        .length,
                                                  ),
                                                );
                                            setSheetState(() {});
                                          },
                                          isDark: isDark,
                                        ),
                                        const SizedBox(width: kSpacing8),
                                        _QuickAmountChip(
                                          label: '50%',
                                          amount: (remainingCents * 0.5)
                                              .round(),
                                          isActive:
                                              paymentAmount() ==
                                              (remainingCents * 0.5).round(),
                                          onTap: () {
                                            amountController.text =
                                                ((remainingCents * 0.5)
                                                            .round() /
                                                        100)
                                                    .toStringAsFixed(0);
                                            amountController.selection =
                                                TextSelection.fromPosition(
                                                  TextPosition(
                                                    offset: amountController
                                                        .text
                                                        .length,
                                                  ),
                                                );
                                            setSheetState(() {});
                                          },
                                          isDark: isDark,
                                        ),
                                        const SizedBox(width: kSpacing8),
                                        _QuickAmountChip(
                                          label: '75%',
                                          amount: (remainingCents * 0.75)
                                              .round(),
                                          isActive:
                                              paymentAmount() ==
                                              (remainingCents * 0.75).round(),
                                          onTap: () {
                                            amountController.text =
                                                ((remainingCents * 0.75)
                                                            .round() /
                                                        100)
                                                    .toStringAsFixed(0);
                                            amountController.selection =
                                                TextSelection.fromPosition(
                                                  TextPosition(
                                                    offset: amountController
                                                        .text
                                                        .length,
                                                  ),
                                                );
                                            setSheetState(() {});
                                          },
                                          isDark: isDark,
                                        ),
                                        const SizedBox(width: kSpacing8),
                                        _QuickAmountChip(
                                          label: '100%',
                                          amount: remainingCents,
                                          isActive:
                                              paymentAmount() == remainingCents,
                                          onTap: () {
                                            amountController.text =
                                                (remainingCents / 100)
                                                    .toStringAsFixed(0);
                                            amountController.selection =
                                                TextSelection.fromPosition(
                                                  TextPosition(
                                                    offset: amountController
                                                        .text
                                                        .length,
                                                  ),
                                                );
                                            setSheetState(() {});
                                          },
                                          isDark: isDark,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: kSpacing24),
                                    const Text(
                                      'MEMO',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: kSpacing8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF1C1C1E)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.08,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.06,
                                                ),
                                        ),
                                      ),
                                      child: TextField(
                                        controller: descriptionController,
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Add a note (optional)',
                                          hintStyle: TextStyle(
                                            color: isDark
                                                ? Colors.white30
                                                : Colors.black26,
                                          ),
                                          prefixIcon: Icon(
                                            PesaFlowIcons.edit,
                                            size: 20,
                                            color: isDark
                                                ? Colors.white38
                                                : Colors.black26,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: kSpacing16,
                                                vertical: kSpacing14,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: kSpacing20),
                                    Container(
                                      padding: const EdgeInsets.all(kSpacing12),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF609F8A,
                                        ).withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF609F8A,
                                          ).withValues(alpha: 0.15),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            PesaFlowIcons.info,
                                            size: 16,
                                            color: const Color(
                                              0xFF609F8A,
                                            ).withValues(alpha: 0.8),
                                          ),
                                          const SizedBox(width: kSpacing8),
                                          Expanded(
                                            child: Text(
                                              'This records the payment without deducting from any wallet account. Use this for cash or external payments.',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: const Color(
                                                  0xFF609F8A,
                                                ).withValues(alpha: 0.8),
                                                height: 1.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: kSpacing24),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 54,
                                        child: ElevatedButton(
                                          onPressed: canSubmit && !sheetIsProcessing
                                              ? () async {
                                                  final desc =
                                                      descriptionController.text
                                                          .trim();
                                                  setSheetState(() {
                                                    sheetIsProcessing = true;
                                                  });
                                                  final success =
                                                      await _processOfflinePayment(
                                                    context: context,
                                                    ref: ref,
                                                    loan: loan,
                                                    amount: paymentAmount(),
                                                    description: desc.isNotEmpty
                                                        ? desc
                                                        : 'Offline loan payment',
                                                  );
                                                  if (success) {
                                                    if (sheetContext.mounted) {
                                                      Navigator.of(
                                                        sheetContext,
                                                      ).pop();
                                                    }
                                                  } else {
                                                    setSheetState(() {
                                                      sheetIsProcessing = false;
                                                    });
                                                  }
                                                }
                                              : null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF609F8A,
                                            ),
                                            foregroundColor: Colors.white,
                                            disabledBackgroundColor: isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.05,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.05,
                                                  ),
                                            disabledForegroundColor: isDark
                                                ? Colors.white24
                                                : Colors.black26,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(
                                                16,
                                              ),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: kSpacing14,
                                            ),
                                          ),
                                          child: sheetIsProcessing
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : Text(
                                                  paymentAmount() <= 0
                                                      ? 'Enter an amount'
                                                      : 'Record ${CurrencyFormatter.formatCents(paymentAmount())}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
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
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _processOfflinePayment({
    required BuildContext context,
    required WidgetRef ref,
    required Loan loan,
    required int amount,
    required String description,
  }) async {
    try {
      final activeTrackerId =
          await ref
              .read(settingsRepositoryProvider)
              .getSetting('active_tracker_id') ??
          'default_personal';
      final categories = await ref
          .read(categoryRepositoryProvider)
          .getAllCategories();
      final expenseCat = categories.firstWhere(
        (c) => c.type == 'expense',
        orElse: () => categories.first,
      );

      final txn = Transaction(
        id: const Uuid().v4(),
        accountId: null,
        categoryId: expenseCat.id,
        trackerId: activeTrackerId,
        loanId: loan.id,
        amount: amount,
        type: 'expense',
        description: description,
        source: 'manual',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref
          .read(transactionRepositoryNoAlertsProvider)
          .createTransactionNoBalanceAdjustment(txn);
      await ref.read(loanRepositoryProvider).applyPayment(loan.id, amount);

      HapticFeedback.mediumImpact();
      return true;
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
      return false;
    }
  }

  Widget _buildTransactionTile(Transaction tx, ThemeData theme, bool isDark) {
    final isCredit = tx.type == 'income';
    final amountColor = isCredit
        ? const Color(0xFF609F8A)
        : const Color(0xFFE53935);
    return Container(
      margin: const EdgeInsets.only(bottom: kSpacing8),
      padding: const EdgeInsets.all(kSpacing12),
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
            padding: const EdgeInsets.all(kSpacing8),
            decoration: BoxDecoration(
              color: amountColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: amountColor,
              size: 16,
            ),
          ),
          const SizedBox(width: kSpacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tx.description.isNotEmpty
                            ? tx.description
                            : (tx.type == 'income'
                                  ? 'Payment Received'
                                  : 'Payment Sent'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (tx.accountId == null) ...[
                      const SizedBox(width: kSpacing6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kSpacing6,
                          vertical: kSpacing2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Offline',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: kSpacing2),
                Text(
                  _formatDate(tx.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
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
      padding: const EdgeInsets.symmetric(
        vertical: kSpacing4,
        horizontal: kSpacing4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _copyableInfoRow(
    BuildContext context,
    String label,
    String value,
    bool isDark,
  ) {
    if (value == 'N/A' || value.isEmpty) {
      return _infoRow(label, value, isDark);
    }
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied $label to clipboard'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            width: 250,
          ),
        );
      },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: kSpacing4,
          horizontal: kSpacing4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: kSpacing4),
                Icon(
                  Icons.copy_rounded,
                  size: 12,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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

class _QuickAmountChip extends StatelessWidget {
  final String label;
  final int amount;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDark;

  const _QuickAmountChip({
    required this.label,
    required this.amount,
    required this.isActive,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: kSpacing10),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF609F8A).withValues(alpha: 0.15)
                : isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF609F8A).withValues(alpha: 0.5)
                  : isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? const Color(0xFF609F8A)
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
              const SizedBox(height: kSpacing2),
              Text(
                CurrencyFormatter.formatCents(amount),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
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

  _TimelineEvent({
    required this.title,
    required this.subtitle,
    this.date,
    this.isCompleted = false,
    this.isLast = false,
    this.isWarning = false,
  });
}
