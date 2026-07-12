import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

class LoanOverviewSection extends ConsumerWidget {
  const LoanOverviewSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeLoansAsync = ref.watch(activeLoansStreamProvider);
    final netWorth = ref.watch(netWorthProvider);
    final recentLoanCountAsync = ref.watch(recentLoanActivityProvider);
    final paidLoansCountAsync = ref.watch(paidLoansCountProvider);

    return activeLoansAsync.when(
      data: (activeLoans) {
        if (activeLoans.isEmpty) {
          return Column(
            children: [
              TactileSpringContainer(
                onTap: () => context.go('/loans'),
                child: GlassCard(
                  elevation: CardElevation.low,
                  padding: const EdgeInsets.all(kSpacing20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(kSpacing10),
                        decoration: BoxDecoration(
                          color: context.appColors.incomeColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          PesaFlowIcons.success,
                          color: context.appColors.incomeColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: kSpacing14),
                      Expanded(
                        child: Text(
                          'No active debt. Keep it that way.',
                          style: context.ts(13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: context.appColors.textMedium,
                      ),
                    ],
                  ),
                ),
              ),
              paidLoansCountAsync.when(
                data: (paidCount) => paidCount > 0
                    ? Padding(
                        padding: const EdgeInsets.only(top: kSpacing8),
                        child: TactileSpringContainer(
                          onTap: () => context.go('/loans'),
                          child: GlassCard(
    
                            elevation: CardElevation.low,
                            padding: const EdgeInsets.all(kSpacing12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 16,
                                  color: context.appColors.incomeColor,
                                ),
                                const SizedBox(width: kSpacing8),
                                Text(
                                  '$paidCount loan${paidCount == 1 ? '' : 's'} paid off',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: context.appColors.textMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          );
        }

        final totalOutstanding = activeLoans.fold<int>(
          0,
          (sum, l) => sum + l.remaining,
        );
        final debtRatio = netWorth > 0 ? totalOutstanding / netWorth : 999.0;
        final severityLevel = debtRatio > 1.0
            ? 'CRITICAL'
            : debtRatio > 0.5
            ? 'HIGH'
            : debtRatio > 0.2
            ? 'MODERATE'
            : 'LOW';
        final severityColor = debtRatio > 1.0
            ? context.appColors.expenseColor
            : debtRatio > 0.5
            ? context.appColors.transferColor
            : debtRatio > 0.2
            ? context.appColors.transferColor
            : context.appColors.incomeColor;

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(kSpacing16),
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
                  color: severityColor.withValues(alpha: 0.25),
                  width: 0.5,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(kSpacing10),
                        decoration: BoxDecoration(
                          color: severityColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          debtRatio > 0.5
                              ? PesaFlowIcons.warning
                              : PesaFlowIcons.income,
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
                              CurrencyFormatter.formatCents(totalOutstanding),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: kSpacing2),
                            Text(
                              '$severityLevel DEBT BURDEN',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: severityColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kSpacing10,
                          vertical: kSpacing4,
                        ),
                        decoration: BoxDecoration(
                          color: severityColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '${activeLoans.length} loan${activeLoans.length == 1 ? '' : 's'}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: severityColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpacing14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: kSpacing8,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: severityColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: (debtRatio.clamp(0.0, 1.0)),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        severityColor,
                                        severityColor.withValues(alpha: 0.6),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: kSpacing8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(debtRatio * 100).round()}% of net worth',
                        style: context.ts(10, fontWeight: FontWeight.w700, color: severityColor),
                      ),
                      Text(
                        netWorth > 0
                            ? 'Net worth: ${CurrencyFormatter.formatCents(netWorth)}'
                            : 'Net worth: ${CurrencyFormatter.formatCents(netWorth)}',
                        style: context.ts(10, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: kSpacing8),
            recentLoanCountAsync.when(
              data: (count) => count >= 3
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: kSpacing8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(kSpacing12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              context.appColors.transferColor.withValues(alpha: 0.1),
                              context.appColors.transferColor.withValues(alpha: 0.02),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusCard,
                          ),
                          border: Border.all(
                            color: context.appColors.transferColor.withValues(alpha: 0.2),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(kSpacing6),
                              decoration: BoxDecoration(
                                color: context.appColors.transferColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.speed_rounded,
                                color: context.appColors.transferColor,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: kSpacing10),
                            Expanded(
                              child: Text(
                                '$count active loans in 3 months — consider reducing new borrowing',
                                style: context.ts(11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            ...activeLoans.take(2).map((loan) {
              final ratio = loan.amount > 0
                  ? loan.remaining / loan.amount
                  : 1.0;
              final loanSeverity = ratio > 0.7
                  ? context.appColors.expenseColor
                  : ratio > 0.4
                  ? context.appColors.transferColor
                  : context.appColors.incomeColor;
              return TactileSpringContainer(
                onTap: () => context.go('/loans/${loan.id}'),
                child: GlassCard(
                  elevation: CardElevation.low,
                  margin: const EdgeInsets.only(bottom: kSpacing8),
                  padding: const EdgeInsets.all(kSpacing14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(kSpacing6),
                            decoration: BoxDecoration(
                              color: loanSeverity.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              ratio > 0.5
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              color: loanSeverity,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: kSpacing10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  loan.description ?? 'Loan',
                                  style: context.ts(13, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${(ratio * 100).round()}% unpaid',
                                  style: context.ts(10, fontWeight: FontWeight.w700, color: loanSeverity),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatCents(loan.remaining),
                            style: context.ts(14, fontWeight: FontWeight.w900, color: loanSeverity),
                          ),
                        ],
                      ),
                      const SizedBox(height: kSpacing10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: kSpacing6,
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: loanSeverity.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: ratio.clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            loanSeverity,
                                            loanSeverity.withValues(alpha: 0.5),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
