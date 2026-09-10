import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/theme/app_colors_theme.dart';

/// A card that shows what's financially due today.
/// Inspired by PocketCal's "red line for right now" pattern.
/// Shows: recurring payments due, budget alerts, savings goals on track.
class RightNowCard extends ConsumerWidget {
  const RightNowCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appColors = context.appColors;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    final dueAsync = ref.watch(dueRecurringTransactionsProvider);
    final budgetsAsync = ref.watch(budgetProgressProvider);
    final savingsAsync = ref.watch(savingsGoalsStreamProvider);

    final items = <_RightNowItem>[];

    // Recurring transactions due today
    dueAsync.whenData((due) {
      for (final tx in due) {
        final txDate = DateTime(
          tx.nextDate.year,
          tx.nextDate.month,
          tx.nextDate.day,
        );
        if (!txDate.isAfter(todayStart)) {
          items.add(
            _RightNowItem(
              icon: PesaFlowIcons.subscriptions,
              iconColor: appColors.expenseColor,
              name: tx.description ?? 'Recurring payment',
              amount: tx.amount,
              type: _ItemType.recurring,
            ),
          );
        }
      }
    });

    // Budget periods expiring today
    budgetsAsync.whenData((budgets) {
      for (final bp in budgets) {
        final periodEnd = bp.currentPeriod?.periodEnd;
        if (periodEnd == null) continue;
        final endDay = DateTime(
          periodEnd.year,
          periodEnd.month,
          periodEnd.day,
        );
        if (endDay == todayStart) {
          final remaining = bp.remaining;
          items.add(
            _RightNowItem(
              icon: remaining < 0
                  ? PesaFlowIcons.warning
                  : PesaFlowIcons.budgets,
              iconColor: remaining < 0
                  ? appColors.expenseColor
                  : appColors.warningColor,
              name: bp.budget.name,
              subtitle: remaining < 0
                  ? 'Over budget'
                  : '${CurrencyFormatter.formatCents(remaining)} left',
              amount: null,
              type: _ItemType.budget,
            ),
          );
        }
      }
    });

    // Savings goals due today (target date is today)
    savingsAsync.whenData((goals) {
      for (final goal in goals) {
        if (goal.isCompleted) continue;
        final targetDay = DateTime(
          goal.targetDate.year,
          goal.targetDate.month,
          goal.targetDate.day,
        );
        if (targetDay == todayStart) {
          final pct = goal.targetAmount > 0
              ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
              : 0.0;
          items.add(
            _RightNowItem(
              icon: PesaFlowIcons.savings,
              iconColor: appColors.transferColor,
              name: goal.name,
              subtitle: '${(pct * 100).round()}% saved',
              amount: null,
              type: _ItemType.savings,
            ),
          );
        }
      }
    });

    if (items.isEmpty) {
      return _AllClearCard(appColors: appColors, theme: theme);
    }

    final visible = items.take(3).toList();
    final overflow = items.length - 3;

    return GlassCard(
      borderRadius: AppTheme.radiusCard,
      elevation: CardElevation.low,
      padding: const EdgeInsets.all(kSpacing14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: appColors.expenseColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: kSpacing8),
              Text(
                'RIGHT NOW',
                style: context.ts(
                  11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: appColors.expenseColor,
                ),
              ),
              const Spacer(),
              Text(
                '${items.length} item${items.length == 1 ? '' : 's'}',
                style: context.ts(
                  10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing12),
          ...visible.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: kSpacing8),
              child: TactileSpringContainer(
                onTap: () {
                  PesaHaptics.light();
                  _navigateToItem(context, item.type);
                },
                selectedColor: theme.colorScheme.onSurface,
                child: _DueItemRow(item: item),
              ),
            ),
          ),
          if (overflow > 0)
            Padding(
              padding: const EdgeInsets.only(top: kSpacing2),
              child: Text(
                '+$overflow more',
                style: context.ts(
                  10,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToItem(BuildContext context, _ItemType type) {
    switch (type) {
      case _ItemType.recurring:
        context.push('/recurring');
      case _ItemType.budget:
        context.push('/budgets');
      case _ItemType.savings:
        context.push('/savings-goals');
    }
  }
}

class _AllClearCard extends StatelessWidget {
  final AppColorsTheme appColors;
  final ThemeData theme;

  const _AllClearCard({required this.appColors, required this.theme});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: AppTheme.radiusCard,
      elevation: CardElevation.low,
      padding: const EdgeInsets.all(kSpacing14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(kSpacing8),
            decoration: BoxDecoration(
              color: appColors.incomeColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              PesaFlowIcons.success,
              size: 16,
              color: appColors.incomeColor,
            ),
          ),
          const SizedBox(width: kSpacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All clear today',
                  style: context.ts(
                    13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: kSpacing2),
                Text(
                  'Nothing due right now',
                  style: context.ts(
                    11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DueItemRow extends StatelessWidget {
  final _RightNowItem item;

  const _DueItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: item.iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusCompact),
          ),
          alignment: Alignment.center,
          child: Icon(item.icon, size: 16, color: item.iconColor),
        ),
        const SizedBox(width: kSpacing10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.ts(
                  13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (item.subtitle != null) ...[
                const SizedBox(height: kSpacing2),
                Text(
                  item.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.ts(
                    10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (item.amount != null)
          AmountText(
            amountInCents: item.amount!,
            type: AmountType.expense,
            style: context.ts(12, fontWeight: FontWeight.w700),
          ),
        const SizedBox(width: kSpacing8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpacing8,
            vertical: kSpacing2,
          ),
          decoration: BoxDecoration(
            color: context.appColors.expenseColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          child: Text(
            'Due today',
            style: context.ts(
              9,
              fontWeight: FontWeight.w700,
              color: context.appColors.expenseColor,
            ),
          ),
        ),
      ],
    );
  }
}

enum _ItemType { recurring, budget, savings }

class _RightNowItem {
  final IconData icon;
  final Color iconColor;
  final String name;
  final String? subtitle;
  final int? amount;
  final _ItemType type;

  const _RightNowItem({
    required this.icon,
    required this.iconColor,
    required this.name,
    this.subtitle,
    this.amount,
    required this.type,
  });
}
