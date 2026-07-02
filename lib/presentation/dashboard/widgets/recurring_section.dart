import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/frequency_helpers.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class _CycleChip extends StatelessWidget {
  final String text;

  const _CycleChip({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpacing8,
        vertical: kSpacing4,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class RecurringSection extends ConsumerWidget {
  const RecurringSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final recsAsync = ref.watch(recurringTransactionsStreamProvider);
    final dueAsync = ref.watch(dueRecurringTransactionsProvider);
    final totals = ref.watch(recurringTotalsProvider);
    final upcoming = ref.watch(upcomingRecurringExpensesProvider);

    return recsAsync.when(
      data: (recs) {
        final expenses = recs.where((r) => r.type == 'expense').toList();
        if (expenses.isEmpty) {
          return TactileSpringContainer(
            onTap: () => context.push('/recurring'),
            child: GlassCard(
              frosted: false,
              borderRadius: AppTheme.radiusCard,
              elevation: CardElevation.low,
              padding: const EdgeInsets.all(kSpacing20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(kSpacing12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PesaFlowIcons.subscriptions,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: kSpacing16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Track recurring expenses',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: kSpacing4),
                        Text(
                          'Log recurring payments like streaming, utility bills, or memberships to get ahead of renewals.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final due = dueAsync.asData?.value ?? [];
        final active = expenses.where((s) => s.status == 'active').toList();
        final categories =
            ref.read(categoriesFutureProvider).asData?.value ?? [];

        Color? catColor(String? catId) {
          if (catId == null) return null;
          final cat = categories.where((c) => c.id == catId).firstOrNull;
          return cat != null ? hexToColor(cat.color) : null;
        }

        final upcomingIds = upcoming.map((s) => s.id).toSet();
        final remaining = active
            .where((s) => !upcomingIds.contains(s.id))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (totals.monthly > 0)
              GlassCard(
                borderRadius: AppTheme.radiusCard,
                elevation: CardElevation.medium,
                padding: const EdgeInsets.all(kSpacing16),
                margin: const EdgeInsets.only(bottom: kSpacing12),
                child: Column(
                  children: [
                    Text(
                      '${CurrencyFormatter.formatCents(totals.monthly)}/mo',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: kSpacing8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CycleChip(
                          text: '${_fmtShort(totals.daily)}/day',
                        ),
                        const SizedBox(width: kSpacing8),
                        _CycleChip(
                          text: '${_fmtShort(totals.weekly)}/wk',
                        ),
                        const SizedBox(width: kSpacing8),
                        _CycleChip(
                          text: '${_fmtShort(totals.yearly)}/yr',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            if (upcoming.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: kSpacing8),
                child: Row(
                  children: [
                    Icon(
                      PesaFlowIcons.calendar,
                      size: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    const SizedBox(width: kSpacing6),
                    Text(
                      'UPCOMING RENEWALS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...upcoming
                  .take(3)
                  .map(
                    (sub) => Padding(
                      padding: const EdgeInsets.only(bottom: kSpacing6),
                      child: GlassCard(
                        borderRadius: AppTheme.radiusCard,
                        elevation: CardElevation.low,
                        padding: const EdgeInsets.symmetric(
                          horizontal: kSpacing14,
                          vertical: kSpacing10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: due.any((d) => d.id == sub.id)
                                    ? const Color(0xFFFF6B35)
                                    : (catColor(sub.categoryId) ??
                                          const Color(0xFF609F8A)),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: kSpacing10),
                            Expanded(
                              child: Text(
                                sub.description ?? 'Recurring Expense',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _formatDate(sub.nextDate),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(width: kSpacing8),
                            AmountText(
                              amountInCents: sub.amount,
                              type: AmountType.expense,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: kSpacing4),
            ],

            ...remaining
                .take(3)
                .map(
                  (sub) => Padding(
                    padding: const EdgeInsets.only(bottom: kSpacing8),
                    child: GlassCard(
                      borderRadius: AppTheme.radiusCard,
                      elevation: CardElevation.low,
                      padding: const EdgeInsets.symmetric(
                        horizontal: kSpacing14,
                        vertical: kSpacing12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(kSpacing8),
                            decoration: BoxDecoration(
                              color: desaturateColor(
                                catColor(sub.categoryId) ??
                                    const Color(0xFF609F8A),
                              ).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              PesaFlowIcons.subscriptions,
                              size: 14,
                              color:
                                  catColor(sub.categoryId) ??
                                  const Color(0xFF609F8A),
                            ),
                          ),
                          const SizedBox(width: kSpacing12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (catColor(sub.categoryId) != null) ...[
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: catColor(sub.categoryId),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: kSpacing6),
                                    ],
                                    Expanded(
                                      child: Text(
                                        sub.description ?? 'Recurring Expense',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: kSpacing2),
                                Text(
                                  frequencyLabel(
                                    sub.frequency,
                                    sub.intervalValue,
                                  ),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AmountText(
                            amountInCents: sub.amount,
                            type: AmountType.expense,
                            useMonospace: true,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

String _formatDate(DateTime dt) {
  return '${dt.day}/${dt.month}';
}

String _fmtShort(int cents) {
  if (cents <= 0) return '0';
  final raw = CurrencyFormatter.formatCents(cents);
  return raw.startsWith('Tsh ') ? raw.substring(4) : raw;
}
