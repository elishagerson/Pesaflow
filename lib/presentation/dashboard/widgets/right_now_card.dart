import 'package:flutter/material.dart';
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
          onTap: () => context.push('/recurring'),
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(kSpacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(kSpacing6),
                decoration: BoxDecoration(
                  color: context.appColors.expenseColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  PesaFlowIcons.bolt,
                  size: 16,
                  color: context.appColors.expenseColor,
                ),
              ),
              const SizedBox(width: kSpacing10),
              Text(
                'RIGHT NOW',
                style: context.ts(
                  12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: onSurface.withValues(alpha: 0.55),
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
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: item.iconColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
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
                        Icon(
                          PesaFlowIcons.chevronRight,
                          size: 14,
                          color: onSurface.withValues(alpha: 0.2),
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
  final VoidCallback onTap;

  const _RightNowItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
