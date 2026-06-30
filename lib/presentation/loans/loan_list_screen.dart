import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/core/utils/app_illustrations.dart';
import 'package:pesaflow/presentation/common/widgets/empty_state.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/premium_fab.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_list.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';

class LoanListScreen extends ConsumerWidget {
  const LoanListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeLoansAsync = ref.watch(activeLoansStreamProvider);
    final paidLoansAsync = ref.watch(paidLoansStreamProvider);
    final totalOutstandingAsync = ref.watch(totalOutstandingLoanProvider);
    final recentLoanCountAsync = ref.watch(recentLoanActivityProvider);

    return Scaffold(
      appBar: const IosNavBar(title: 'Loans', largeTitle: true),
      floatingActionButton: PremiumExtendedFab(
        onPressed: () => context.push('/loans/add'),
        label: 'Add Loan',
      ),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([
          ref.refresh(activeLoansStreamProvider.future),
          ref.refresh(paidLoansStreamProvider.future),
        ]),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            kSpacing16,
            kSpacing16,
            kSpacing16,
            kSpacing80,
          ),
          child: Column(
            children: [
              // Outstanding header
              totalOutstandingAsync.when(
                data: (total) => total > 0
                    ? _buildOutstandingHeader(context, total, isDark, ref)
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),

              // Loan burden warning
              recentLoanCountAsync.when(
                data: (count) => count >= 3
                    ? _buildLoanBurdenWarning(context, count, isDark)
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),

              // Active Loans section
              activeLoansAsync.when(
                data: (activeLoans) {
                  final paidData = paidLoansAsync.asData?.value;
                  if (activeLoans.isEmpty &&
                      (paidData == null || paidData.isEmpty)) {
                    return _buildEmptyState(theme, isDark);
                  }
                  if (activeLoans.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        context,
                        'Active Loans',
                        '${activeLoans.length} loan${activeLoans.length == 1 ? '' : 's'}',
                        Colors.redAccent,
                      ),
                      const SizedBox(height: 4),
                      StaggeredList(
                        itemCount: activeLoans.length,
                        itemBuilder: (context, index) => _buildLoanTile(
                          context,
                          activeLoans[index],
                          theme,
                          isDark,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: kSpacing4,
                    vertical: kSpacing8,
                  ),
                  child: Column(
                    children: [
                      SkeletonCard(height: 110),
                      SizedBox(height: 8),
                      SkeletonCard(height: 110),
                      SizedBox(height: 8),
                      SkeletonCard(height: 110),
                      SizedBox(height: 8),
                      SkeletonCard(height: 110),
                    ],
                  ),
                ),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),

              // Paid Loans section
              paidLoansAsync.when(
                data: (paidLoans) {
                  if (paidLoans.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        context,
                        'Paid Loans',
                        '${paidLoans.length} paid',
                        const Color(0xFF609F8A),
                      ),
                      const SizedBox(height: 4),
                      StaggeredList(
                        itemCount: paidLoans.length,
                        itemBuilder: (context, index) => _buildPaidLoanTile(
                          context,
                          paidLoans[index],
                          theme,
                          isDark,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String subtitle,
    Color accent,
  ) {
    return Padding(
      padding: EdgeInsets.only(
        left: kSpacing4,
        bottom: kSpacing8,
        top: kSpacing4,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(width: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanBurdenWarning(BuildContext context, int count, bool isDark) {
    return GlassCard(
      frosted: false,
      elevation: CardElevation.none,
      padding: const EdgeInsets.all(kSpacing14),
      accentColor: const Color(0xFFFF6B35),
      margin: const EdgeInsets.only(bottom: kSpacing12),
      backgroundGradient: LinearGradient(
        colors: [
          const Color(0xFFFF6B35).withValues(alpha: 0.12),
          const Color(0xFFFF6B35).withValues(alpha: 0.03),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(kSpacing8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.speed_rounded,
              color: Color(0xFFFF6B35),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'High Loan Activity',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count active loans taken in the last 3 months. Consider slowing down.',
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
    );
  }

  Widget _buildOutstandingHeader(
    BuildContext context,
    int total,
    bool isDark,
    WidgetRef ref,
  ) {
    final netWorth = ref.watch(netWorthProvider);
    final debtRatio = netWorth > 0 ? total / netWorth : 999.0;
    final severityColor = debtRatio > 1.0
        ? const Color(0xFFE53935)
        : debtRatio > 0.5
        ? const Color(0xFFFF6B35)
        : const Color(0xFFFF9F0A);

    return GlassCard(
      frosted: false,
      elevation: CardElevation.none,
      padding: const EdgeInsets.all(kSpacing16),
      accentColor: severityColor,
      margin: const EdgeInsets.only(bottom: kSpacing12),
      backgroundGradient: LinearGradient(
        colors: [
          severityColor.withValues(alpha: 0.15),
          severityColor.withValues(alpha: 0.03),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(kSpacing10),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PesaFlowIcons.warning,
                  color: severityColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Outstanding',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.formatCents(total),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 6,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: debtRatio.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: severityColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return EmptyState(
      icon: PesaFlowIcons.loans,
      title: 'No Loans Yet',
      subtitle:
          'Add a loan manually or wait for loan\ndisbursements from M-Pesa to appear.',
      illustration: PesaFlowIllustration.emptyLoans(),
    );
  }

  Widget _buildLoanTile(
    BuildContext context,
    Loan loan,
    ThemeData theme,
    bool isDark,
  ) {
    final ratio = loan.amount > 0 ? loan.remaining / loan.amount : 1.0;
    final progressColor = ratio > 0.5
        ? const Color(0xFFE53935)
        : const Color(0xFFFF9F0A);

    return Hero(
      tag: 'loan-${loan.id}',
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: kSpacing10),
        borderRadius: AppTheme.radiusCard,
        elevation: CardElevation.low,
        accentColor: progressColor,
        onTap: () => context.push('/loans/${loan.id}'),
        child: Padding(
          padding: const EdgeInsets.all(kSpacing14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(kSpacing8),
                    decoration: BoxDecoration(
                      color: progressColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PesaFlowIcons.income,
                      color: progressColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loan.description ?? loan.sender ?? 'Loan',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: progressColor,
                          ),
                        ),
                        if (loan.dueAt != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            loan.dueAt!.isBefore(DateTime.now())
                                ? 'OVERDUE'
                                : 'Due ${loan.dueAt!.day}/${loan.dueAt!.month}/${loan.dueAt!.year}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: loan.dueAt!.isBefore(DateTime.now())
                                  ? const Color(0xFFE53935)
                                  : Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.formatCents(loan.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${CurrencyFormatter.formatCents(loan.remaining)} left',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  backgroundColor: progressColor.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaidLoanTile(
    BuildContext context,
    Loan loan,
    ThemeData theme,
    bool isDark,
  ) {
    return Hero(
      tag: 'loan-${loan.id}',
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: kSpacing10),
        borderRadius: AppTheme.radiusCard,
        elevation: CardElevation.low,
        accentColor: const Color(0xFF609F8A),
        onTap: () => context.push('/loans/${loan.id}'),
        child: Padding(
          padding: const EdgeInsets.all(kSpacing14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(kSpacing8),
                decoration: BoxDecoration(
                  color: const Color(0xFF609F8A).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PesaFlowIcons.success,
                  color: Color(0xFF609F8A),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.description ?? loan.sender ?? 'Loan',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Paid ${loan.paidAt != null ? 'on ${loan.paidAt!.day}/${loan.paidAt!.month}/${loan.paidAt!.year}' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyFormatter.formatCents(loan.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
