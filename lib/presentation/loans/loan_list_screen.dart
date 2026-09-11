import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/utils/date_formatter.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/core/utils/app_illustrations.dart';
import 'package:pesaflow/presentation/common/widgets/empty_state.dart';
import 'package:pesaflow/presentation/common/widgets/glass_list_container.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/error_state.dart';
import 'package:pesaflow/presentation/common/widgets/floating_top_bar.dart';
import 'package:pesaflow/presentation/common/widgets/premium_fab.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_entrance.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';

class LoanListScreen extends ConsumerStatefulWidget {
  const LoanListScreen({super.key});

  @override
  ConsumerState<LoanListScreen> createState() => _LoanListScreenState();
}

class _LoanListScreenState extends ConsumerState<LoanListScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    ref.listen(scrollToTopProvider, (_, _) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: MotionTokens.durationNormal,
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeLoansAsync = ref.watch(activeLoansStreamProvider);
    final paidLoansAsync = ref.watch(paidLoansStreamProvider);
    final totalOutstandingAsync = ref.watch(totalOutstandingLoanProvider);
    final recentLoanCountAsync = ref.watch(recentLoanActivityProvider);

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: kSpacing80),
        child: PremiumExtendedFab(
          label: 'New Loan',
          onPressed: () {
            PesaHaptics.medium();
            context.push('/loans/add');
          },
        ),
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: RefreshIndicator(
          color: theme.colorScheme.primary,
          backgroundColor: theme.colorScheme.surface,
          onRefresh: () => Future.wait([
            ref.refresh(activeLoansStreamProvider.future),
            ref.refresh(paidLoansStreamProvider.future),
          ]),
          child: SingleChildScrollView(
            controller: _scrollController,
            key: const PageStorageKey('loan_list'),
            padding: const EdgeInsets.fromLTRB(
              kSpacing16,
              kSpacing8,
              kSpacing16,
              kSpacing80,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Floating Top Bar ──
                const FloatingTopBar(title: 'Loans', padding: EdgeInsets.zero),
                const SizedBox(height: 16),
                ...StaggeredEntrance(
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
                        if (activeLoans.isEmpty) {
                          return const SizedBox.shrink();
                        }
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
                            GlassListContainer(
                              child: Column(
                                children: activeLoans
                                    .asMap()
                                    .entries
                                    .map(
                                      (entry) => _buildLoanTile(
                                        context,
                                        entry.value,
                                        theme,
                                        entry.key,
                                        activeLoans.length,
                                      ),
                                    )
                                    .toList(),
                              ),
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
                      error: (e, _) => ErrorState(
                        title: 'Failed to load loans',
                        message: e.toString(),
                        onRetry: () {
                          ref.invalidate(activeLoansStreamProvider);
                        },
                      ),
                    ),

                    // Paid Loans section
                    paidLoansAsync.when(
                      data: (paidLoans) {
                        if (paidLoans.isEmpty) {
                          return const SizedBox.shrink();
                        }
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
                            GlassListContainer(
                              child: Column(
                                children: paidLoans
                                    .asMap()
                                    .entries
                                    .map(
                                      (entry) => _buildPaidLoanTile(
                                        context,
                                        entry.value,
                                        theme,
                                        entry.key,
                                        paidLoans.length,
                                      ),
                                    )
                                    .toList(),
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
                ).children,
              ],
            ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: kSpacing12),
      padding: const EdgeInsets.symmetric(
        horizontal: kSpacing16,
        vertical: kSpacing12,
      ),
      decoration: BoxDecoration(
        color: context.appColors.warningColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: context.appColors.warningColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            PesaFlowIcons.warning,
            color: context.appColors.warningColor,
            size: 18,
          ),
          const SizedBox(width: kSpacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'High Loan Frequency',
                  style: context.ts(
                    12,
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count active loans taken in the last 3 months. Consider slowing down.',
                  style: context.ts(
                    11,
                    color: onSurface.withValues(alpha: 0.65),
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
    final isCritical = debtRatio > 1.0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: kSpacing16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusDialog),
        border: Border.all(
          color: isCritical
              ? context.appColors.expenseColor.withValues(alpha: 0.35)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: context.appColors.shadowMedium,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(kSpacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(kSpacing6),
                    decoration: BoxDecoration(
                      color: context.appColors.expenseColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PesaFlowIcons.loans,
                      size: 15,
                      color: context.appColors.expenseColor,
                    ),
                  ),
                  const SizedBox(width: kSpacing8),
                  Text(
                    'TOTAL OUTSTANDING LIABILITIES',
                    style: context.ts(
                      11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacing8,
                  vertical: kSpacing4,
                ),
                decoration: BoxDecoration(
                  color: context.appColors.expenseColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  border: Border.all(
                    color: context.appColors.expenseColor.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PesaFlowIcons.error,
                      size: 11,
                      color: context.appColors.expenseColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ACTIVE DEBT',
                      style: context.ts(
                        10,
                        fontWeight: FontWeight.w800,
                        color: context.appColors.expenseColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing16),
          AmountText(
            amountInCents: total,
            animate: true,
            style: context.ts(
              28,
              fontWeight: FontWeight.w900,
              color: onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            debtRatio <= 1.0
                ? '${(debtRatio * 100).round()}% of estimated liquid assets'
                : 'Exceeds current liquid balance',
            style: context.ts(
              11,
              fontWeight: FontWeight.w500,
              color: onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: kSpacing14),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: LinearProgressIndicator(
              value: debtRatio.clamp(0.0, 1.0),
              backgroundColor: onSurface.withValues(alpha: 0.06),
              color: isCritical
                  ? context.appColors.expenseColor
                  : (debtRatio > 0.5
                      ? context.appColors.warningColor
                      : context.appColors.transferColor),
              minHeight: 6,
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

  Widget _buildLoanTile(
    BuildContext context,
    Loan loan,
    ThemeData theme,
    int index,
    int totalCount,
  ) {
    final onSurface = theme.colorScheme.onSurface;
    final ratio = loan.amount > 0 ? loan.remaining / loan.amount : 1.0;
    final progressColor = ratio > 0.5
        ? context.appColors.expenseColor
        : context.appColors.transferColor;

    return Hero(
      tag: 'loan-${loan.id}',
      child: TactileSpringContainer(
        onTap: () {
          PesaHaptics.light();
          context.push('/loans/${loan.id}');
        },
        selectedColor: theme.colorScheme.onSurface,
        child: Column(
          children: [
            Padding(
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
                              style: context.ts(14, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: kSpacing4),
                            Row(
                              children: [
                                if (loan.category != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: kSpacing8,
                                      vertical: kSpacing2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusSmall,
                                      ),
                                    ),
                                    child: Text(
                                      loan.category!,
                                      style: context.ts(
                                        11,
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: kSpacing6),
                                ],
                                Text(
                                  'Active',
                                   style: context.ts(11, fontWeight: FontWeight.w700, color: progressColor),
                                ),
                              ],
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
                                      color:
                                          loan.dueAt!.isBefore(DateTime.now())
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
                            style: context.ts(
                              11,
                              color: onSurface.withValues(alpha: 0.6),
                            ),
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
            if (index < totalCount - 1)
              Divider(
                height: 1,
                thickness: 0.5,
                color: onSurface.withValues(alpha: 0.05),
                indent: 14 + 34 + 12,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaidLoanTile(
    BuildContext context,
    Loan loan,
    ThemeData theme,
    int index,
    int totalCount,
  ) {
    return Hero(
      tag: 'loan-${loan.id}',
      child: TactileSpringContainer(
        onTap: () {
          PesaHaptics.light();
          context.push('/loans/${loan.id}');
        },
        selectedColor: theme.colorScheme.onSurface,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(kSpacing14),
              child: Row(
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
                        const SizedBox(height: kSpacing4),
                        Row(
                          children: [
                            if (loan.category != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: kSpacing8,
                                  vertical: kSpacing2,
                                ),
                                decoration: BoxDecoration(
                                  color: context.appColors.incomeColor
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSmall,
                                  ),
                                ),
                                child: Text(
                                  loan.category!,
                                  style: context.ts(
                                    11,
                                    color: context.appColors.incomeColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: kSpacing6),
                            ],
                            Text(
                              'Paid ${loan.paidAt != null ? DateFormatter.relative(loan.paidAt!) : ''}',
                              style: context.ts(
                                11,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
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
            if (index < totalCount - 1)
              Divider(
                height: 1,
                thickness: 0.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                indent: 14 + 34 + 12,
              ),
          ],
        ),
      ),
    );
  }
}
