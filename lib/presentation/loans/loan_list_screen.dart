import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/premium_fab.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

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
      appBar: AppBar(
        title: const Text('Loans'),
        centerTitle: true,
      ),
      floatingActionButton: PremiumExtendedFab(
        onPressed: () => context.push('/loans/add'),
        label: 'Add Loan',
      ),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([
          ref.refresh(activeLoansStreamProvider.future),
          ref.refresh(paidLoansStreamProvider.future),
        ]),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            // Outstanding header
            totalOutstandingAsync.when(
              data: (total) => total > 0
                  ? StaggeredFadeSlide(index: 0, child: _buildOutstandingHeader(context, total, isDark, ref))
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            // Loan burden warning
            recentLoanCountAsync.when(
              data: (count) => count >= 3
                  ? StaggeredFadeSlide(
                      index: 1,
                      child: _buildLoanBurdenWarning(context, count, isDark),
                    )
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            // Active Loans section
            activeLoansAsync.when(
              data: (activeLoans) {
                if (activeLoans.isEmpty && paidLoansAsync.asData?.value.isEmpty == true) {
                  return StaggeredFadeSlide(index: 1, child: _buildEmptyState(theme, isDark));
                }
                if (activeLoans.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StaggeredFadeSlide(
                      index: 2,
                      child: _buildSectionHeader(
                        context,
                        'Active Loans',
                        '${activeLoans.length} loan${activeLoans.length == 1 ? '' : 's'}',
                        Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...activeLoans.asMap().entries.map((e) => StaggeredFadeSlide(
                      index: e.key + 3,
                      child: _buildLoanTile(context, e.value, theme, isDark),
                    )),
                    const SizedBox(height: 20),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),

            // Paid Loans section
            paidLoansAsync.when(
              data: (paidLoans) {
                if (paidLoans.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StaggeredFadeSlide(
                      index: 99,
                      child: _buildSectionHeader(
                        context,
                        'Paid Loans',
                        '${paidLoans.length} paid',
                        const Color(0xFF609F8A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...paidLoans.asMap().entries.map((e) => StaggeredFadeSlide(
                      index: 100 + e.key,
                      child: _buildPaidLoanTile(context, e.value, theme, isDark),
                    )),
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
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, String subtitle, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
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
            style: TextStyle(fontSize: 11, color: accent, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanBurdenWarning(BuildContext context, int count, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B35).withValues(alpha: 0.12),
            const Color(0xFFFF6B35).withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: const Color(0xFFFF6B35).withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.speed_rounded, color: Color(0xFFFF6B35), size: 20),
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

  Widget _buildOutstandingHeader(BuildContext context, int total, bool isDark, WidgetRef ref) {
    final netWorth = ref.watch(netWorthProvider);
    final debtRatio = netWorth > 0 ? total / netWorth : 999.0;
    final severityColor = debtRatio > 1.0
        ? const Color(0xFFE53935)
        : debtRatio > 0.5
            ? const Color(0xFFFF6B35)
            : const Color(0xFFFF9F0A);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            severityColor.withValues(alpha: 0.15),
            severityColor.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: severityColor.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_rounded, color: severityColor, size: 22),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_rounded,
                color: theme.colorScheme.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Loans Yet',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a loan manually or wait for loan\ndisbursements from M-Pesa to appear.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanTile(BuildContext context, Loan loan, ThemeData theme, bool isDark) {
    final ratio = loan.amount > 0 ? loan.remaining / loan.amount : 1.0;
    final progressColor = ratio > 0.5 ? const Color(0xFFE53935) : const Color(0xFFFF9F0A);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      borderRadius: AppTheme.radiusCard,
      elevation: CardElevation.low,
      accentColor: progressColor,
      onTap: () => context.push('/loans/${loan.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: progressColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.trending_up_rounded,
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
    );
  }

  Widget _buildPaidLoanTile(BuildContext context, Loan loan, ThemeData theme, bool isDark) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      borderRadius: AppTheme.radiusCard,
      elevation: CardElevation.low,
      accentColor: const Color(0xFF609F8A),
      onTap: () => context.push('/loans/${loan.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF609F8A).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
