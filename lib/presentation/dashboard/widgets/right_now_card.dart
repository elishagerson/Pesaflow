import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class RightNowCard extends ConsumerWidget {
  const RightNowCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    final dueAsync = ref.watch(dueRecurringTransactionsProvider);
    final reviewAsync = ref.watch(reviewQueueStreamProvider);
    final budgetsAsync = ref.watch(budgetProgressProvider);

    final dueItems = dueAsync.maybeWhen(
      data: (items) => items.where((r) => r.type == 'expense').toList(),
      orElse: () => [],
    );

    final reviewCount = reviewAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    final budgets = budgetsAsync.value ?? [];
    final overBudgetItems = budgets.where((b) => b.remaining < 0).toList();

    final hasItems =
        dueItems.isNotEmpty || reviewCount > 0 || overBudgetItems.isNotEmpty;
    if (!hasItems) return const SizedBox.shrink();

    final List<_RightNowItem> items = [];

    for (final budget in overBudgetItems) {
      items.add(
        _RightNowItem(
          icon: PesaFlowIcons.expense,
          iconColor: theme.colorScheme.error,
          title: '${budget.budget.name} is over budget',
          subtitle:
              'Over by ${CurrencyFormatter.formatCents(budget.remaining.abs())}',
          actionLabel: 'Adjust',
          onTap: () => context.push('/budgets'),
        ),
      );
    }

    if (reviewCount > 0) {
      items.add(
        _RightNowItem(
          icon: PesaFlowIcons.sms,
          iconColor: context.appColors.transferColor,
          title: '$reviewCount SMS to review',
          subtitle: 'Tap to categorize incoming transactions',
          actionLabel: 'Review',
          onTap: () => context.push('/sms-review'),
        ),
      );
    }

    for (final due in dueItems.take(3)) {
      items.add(
        _RightNowItem(
          icon: PesaFlowIcons.subscriptions,
          iconColor: context.appColors.expenseColor,
          title: due.description ?? 'Recurring payment',
          subtitle: '${CurrencyFormatter.formatCents(due.amount)} due today',
          actionLabel: 'Pay',
          onTap: () => context.push('/recurring'),
        ),
      );
    }

    return GlassCard(
      accentColor: theme.colorScheme.error,
      accentGlow: true,
      elevation: CardElevation.low,
      padding: const EdgeInsets.all(kSpacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(
                    AppTheme.squircleRadius(6),
                  ),
                ),
              ),
              const SizedBox(width: kSpacing8),
              Text(
                'NEEDS ATTENTION',
                style: context.ts(
                  11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: theme.colorScheme.error,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  '${items.length}',
                  style: context.ts(
                    10,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing12),
          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Column(
              children: [
                TactileSpringContainer(
                  onTap: item.onTap,
                  selectedColor: theme.colorScheme.onSurface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: kSpacing8),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: item.iconColor.withValues(
                              alpha: context.isDark ? 0.16 : 0.09,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppTheme.squircleRadius(34),
                            ),
                            border: Border.all(
                              color: item.iconColor.withValues(
                                alpha: context.isDark ? 0.28 : 0.16,
                              ),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            item.icon,
                            size: 16,
                            color: item.iconColor,
                          ),
                        ),
                        const SizedBox(width: kSpacing12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: context.ts(
                                  13,
                                  fontWeight: FontWeight.w600,
                                  color: onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle,
                                style: context.ts(
                                  11,
                                  color: onSurface.withValues(alpha: 0.5),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: kSpacing8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpacing8,
                            vertical: kSpacing4,
                          ),
                          decoration: BoxDecoration(
                            color: item.iconColor.withValues(
                              alpha: context.isDark ? 0.16 : 0.08,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusPill,
                            ),
                            border: Border.all(
                              color: item.iconColor.withValues(
                                alpha: context.isDark ? 0.30 : 0.18,
                              ),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            item.actionLabel.toUpperCase(),
                            style: context.ts(
                              10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: item.iconColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (idx < items.length - 1)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: onSurface.withValues(alpha: 0.06),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _RightNowItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  const _RightNowItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });
}
