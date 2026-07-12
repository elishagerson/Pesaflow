import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/utils/date_formatter.dart';
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
import 'package:pesaflow/core/utils/context_extensions.dart';

class LoanListScreen extends ConsumerWidget {
  const LoanListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeLoansAsync = ref.watch(activeLoansStreamProvider);
    final paidLoansAsync = ref.watch(paidLoansStreamProvider);
    final totalOutstandingAsync = ref.watch(totalOutstandingLoanProvider);
    final recentLoanCountAsync = ref.watch(recentLoanActivityProvider);
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      appBar: IosNavBar(title: 'Loans', largeTitle: true, canPop: canPop),
      floatingActionButton: PremiumExtendedFab(
        onPressed: () => context.push('/loans/add'),
        label: 'Add Loan',
      ),
      body: RefreshIndicator(
        color: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.surface,
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
                    ? _buildOutstandingHeader(context, total, ref)
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),

              // Loan burden warning
              recentLoanCountAsync.when(
                data: (count) => count >= 3
                    ? _buildLoanBurdenWarning(context, count)
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
                    return _buildEmptyState(theme);
                  }
                  if (activeLoans.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        context,
                        'Active Loans',
                        '${activeLoans.length} loan${activeLoans.length == 1 ? '' : 's'}',
                        context.appColors.expenseColor,
                      ),
                      const SizedBox(height: kSpacing4),
                      StaggeredList(
                        itemCount: activeLoans.length,
                        itemBuilder: (context, index) =>
                            _buildLoanTile(context, activeLoans[index], theme),
                      ),
                      const SizedBox(height: kSpacing20),
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
                      SizedBox(height: kSpacing8),
                      SkeletonCard(height: 110),
                      SizedBox(height: kSpacing8),
                      SkeletonCard(height: 110),
                      SizedBox(height: kSpacing8),
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
                        context.appColors.incomeColor,
                      ),
                      const SizedBox(height: kSpacing4),
                      StaggeredList(
                        itemCount: paidLoans.length,
                        itemBuilder: (context, index) => _buildPaidLoanTile(
                          context,
                          paidLoans[index],
                          theme,
                        ),
                      ),
                      const SizedBox(height: kSpacing20),
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
          const SizedBox(width: kSpacing10),
          Text(title, style: context.ts(15, fontWeight: FontWeight.w800)),
          const SizedBox(width: kSpacing8),
          Text(
            subtitle,
            style: context.ts(11, fontWeight: FontWeight.w600, color: accent),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanBurdenWarning(BuildContext context, int count) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return GlassCard(
      elevation: CardElevation.none,
      padding: const EdgeInsets.all(kSpacing14),
      accentColor: context.appColors.transferColor,
      margin: const EdgeInsets.only(bottom: kSpacing12),
      backgroundGradient: LinearGradient(
        colors: [
          context.appColors.transferColor.withValues(alpha: 0.12),
          context.appColors.transferColor.withValues(alpha: 0.03),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(kSpacing8),
            decoration: BoxDecoration(
              color: context.appColors.transferColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.speed_rounded,
              color: context.appColors.transferColor,
              size: 20,
            ),
          ),
          const SizedBox(width: kSpacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'High Loan Activity',
                  style: context.ts(
                    13,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: kSpacing2),
                Text(
                  '$count active loans taken in the last 3 months. Consider slowing down.',
                  style: context.ts(
                    11,
                    color: onSurface.withValues(alpha: 0.6),
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
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final netWorth = ref.watch(netWorthProvider);
    final debtRatio = netWorth > 0 ? total / netWorth : 999.0;
    final severityColor = debtRatio > 1.0
        ? context.appColors.expenseColor
        : debtRatio > 0.5
        ? context.appColors.transferColor
        : context.appColors.transferColor;

    return GlassCard(
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
              const SizedBox(width: kSpacing14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Outstanding',
                      style: context.ts(12, fontWeight: FontWeight.w600, color: onSurface.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: kSpacing2),
                    Text(
                      CurrencyFormatter.formatCents(total),
                      style: context.ts(22, fontWeight: FontWeight.w900, color: onSurface),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing10),
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

  Widget _buildEmptyState(ThemeData theme) {
    return EmptyState(
      icon: PesaFlowIcons.loans,
      title: 'No Loans Yet',
      subtitle:
          'Add a loan manually or wait for loan\ndisbursements from M-Pesa to appear.',
      illustration: PesaFlowIllustration.emptyLoans(),
    );
  }

  Widget _buildLoanTile(BuildContext context, Loan loan, ThemeData theme) {
    final onSurface = theme.colorScheme.onSurface;
    final ratio = loan.amount > 0 ? loan.remaining / loan.amount : 1.0;
    final progressColor = ratio > 0.5
        ? context.appColors.expenseColor
        : context.appColors.transferColor;

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
                  const SizedBox(width: kSpacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loan.description ?? loan.sender ?? 'Loan',
                          style: Theme.of(context).textTheme.titleSmall!
                              .copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: kSpacing2),
                        Text(
                          'Active',
                          style: Theme.of(context).textTheme.labelSmall!
                              .copyWith(
                                fontWeight: FontWeight.w700,
                                color: progressColor,
                              ),
                        ),
                        if (loan.dueAt != null) ...[
                          const SizedBox(height: kSpacing2),
                          Text(
                            loan.dueAt!.isBefore(DateTime.now())
                                ? 'Overdue by ${DateTime.now().difference(loan.dueAt!).inDays} days'
                                : 'Due ${DateFormatter.relative(loan.dueAt!)}',
                            style: Theme.of(context)
                                .extension<AppTypographyTheme>()!
                                .labelMicro
                                .copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: loan.dueAt!.isBefore(DateTime.now())
                                      ? context.appColors.expenseColor
                                      : context.appColors.textMedium,
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
                        style: context.ts(14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: kSpacing2),
                      Text(
                        '${CurrencyFormatter.formatCents(loan.remaining)} left',
                        style: context.ts(11, color: onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: kSpacing12),
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

  Widget _buildPaidLoanTile(BuildContext context, Loan loan, ThemeData theme) {
    return Hero(
      tag: 'loan-${loan.id}',
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: kSpacing10),
        borderRadius: AppTheme.radiusCard,
        elevation: CardElevation.low,
        accentColor: context.appColors.incomeColor,
        onTap: () => context.push('/loans/${loan.id}'),
        child: Padding(
          padding: const EdgeInsets.all(kSpacing14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(kSpacing8),
                decoration: BoxDecoration(
                  color: context.appColors.incomeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PesaFlowIcons.success,
                  color: context.appColors.incomeColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: kSpacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.description ?? loan.sender ?? 'Loan',
                      style: context.ts(14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: kSpacing2),
                    Text(
                      'Paid ${loan.paidAt != null ? DateFormatter.relative(loan.paidAt!) : ''}',
                      style: context.ts(11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyFormatter.formatCents(loan.amount),
                style: context.ts(14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
