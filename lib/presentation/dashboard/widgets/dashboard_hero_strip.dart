import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/track_ring.dart';
import 'package:pesaflow/presentation/dashboard/widgets/budjetly_balance_header.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

/// The dashboard hero: one full-width card whose metrics sit **side by side** in
/// hairline-divided cells.
///
/// This replaces a snap-paged carousel. The carousel was the wrong read of the
/// reference: in a Formula Widgets home screen the widgets sit next to each
/// other inside a single continuous card, and they do not present as individual
/// cards at all. Paging them made one thing loud at a time, which is the
/// opposite of the point — the balance, what is due, and what is left to spend
/// are one reading of the same financial position, and a reader should be able
/// to take all three in without a gesture.
///
/// So: no `PageController`, no dot rail, no peeking neighbour, no per-cell card
/// chrome. One outline, one subtle gradient, cells separated by a 1px hairline
/// that is a divider rather than a border.
class DashboardHeroStrip extends ConsumerWidget {
  final int balance;
  final String label;
  final int income;
  final int expense;
  final int remainingBudget;
  final double budgetPct;
  final int budgetTotal;

  const DashboardHeroStrip({
    super.key,
    required this.balance,
    required this.label,
    required this.income,
    required this.expense,
    required this.remainingBudget,
    required this.budgetPct,
    required this.budgetTotal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(recurringTransactionsStreamProvider).value;
    final event = _nextEvent(upcoming);

    return BudjetlyBalanceHeader(
      balance: balance,
      label: label,
      income: income,
      expense: expense,
      footerHeight: 80,
      footer: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The two cells split the width evenly. Expanded rather than a
          // measured fraction so a long countdown string cannot steal width
          // from the ring beside it.
          Expanded(
            child: _NextUpCell(
              label: event?.label,
              countdown: event == null ? null : _countdown(event.date),
            ),
          ),
          const _CellDivider(),
          Expanded(
            child: _SafeToSpendCell(
              remaining: remainingBudget,
              pct: budgetPct,
              total: budgetTotal,
            ),
          ),
        ],
      ),
    );
  }

  /// The soonest active expense that has not landed yet.
  ({String label, DateTime date})? _nextEvent(
    List<RecurringTransaction>? recurring,
  ) {
    if (recurring == null) return null;
    final now = DateTime.now();
    ({String label, DateTime date})? soonest;
    for (final r in recurring) {
      if (r.status != 'active' || r.type != 'expense') continue;
      if (r.nextDate.isBefore(now)) continue;
      if (soonest == null || r.nextDate.isBefore(soonest.date)) {
        soonest = (
          label: r.description ?? 'Recurring payment',
          date: r.nextDate,
        );
      }
    }
    return soonest;
  }
}

/// Human count-down, matching the language a person would use out loud rather
/// than dumping a date on them.
String _countdown(DateTime date) {
  final now = DateTime.now();
  final days = date.difference(now).inDays;
  final hours = date.difference(now).inHours % 24;
  if (days <= 0) return 'TODAY ${hours}H';
  if (days == 1) return 'TOMORROW';
  if (days < 7) return '$days DAYS';
  return '${date.day} ${_month(date.month)}';
}

String _month(int m) => const [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
][m - 1];

/// 1px vertical rule between two cells. A divider, not a border: it should read
/// as a fold in one continuous surface, so it takes the hairline token and has
/// no padding of its own.
class _CellDivider extends StatelessWidget {
  const _CellDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    margin: const EdgeInsets.symmetric(horizontal: kSpacing14),
    color: context.appColors.hairline,
  );
}

class _NextUpCell extends StatelessWidget {
  final String? label;
  final String? countdown;

  const _NextUpCell({this.label, this.countdown});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = countdown == null;

    return Semantics(
      label: isEmpty ? 'Next up: nothing due' : 'Next up: $label, $countdown',
      button: !isEmpty,
      child: InkWell(
        onTap: isEmpty ? null : () => context.push('/recurring'),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'NEXT UP',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.appTypography.eyebrow.copyWith(
                      color: isEmpty
                          ? theme.colorScheme.onSurfaceVariant
                          : context.appColors.brandColor,
                    ),
                  ),
                ),
                if (!isEmpty)
                  Icon(
                    PesaFlowIcons.chevronRight,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
            const SizedBox(height: kSpacing6),
            // `poster`, not `posterLarge`: 64px condensed wraps to three lines
            // in a half-width cell and the last line falls out of the card.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  isEmpty ? 'All clear' : countdown!,
                  maxLines: 1,
                  style: context.appTypography.poster.copyWith(
                    fontSize: 30,
                    color: isEmpty
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            if (label != null) ...[
              const SizedBox(height: kSpacing2),
              Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.ts(12, color: context.appColors.textMedium),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SafeToSpendCell extends StatelessWidget {
  final int remaining;
  final double pct;
  final int total;

  const _SafeToSpendCell({
    required this.remaining,
    required this.pct,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Over budget is a fact, not an error state: it gets the error colour, but
    // the cell keeps the same shape and weight as every other cell.
    final isOver = remaining < 0;
    final fraction = (total <= 0 ? 0.0 : 1.0 - (remaining / total)).clamp(
      0.0,
      1.0,
    );
    final tone = isOver
        ? theme.colorScheme.error
        : remaining == 0
        ? context.appColors.textMedium
        : context.appColors.brandColor;

    return Semantics(
      label: isOver
          ? 'Over budget by ${CurrencyFormatter.formatCents(remaining.abs())}'
          : 'Safe to spend ${CurrencyFormatter.formatCents(remaining)}',
      button: true,
      child: InkWell(
        onTap: () => context.push('/budgets'),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrackRing(
              value: fraction,
              size: 44,
              thickness: 3.5,
              color: tone,
              trackColor: context.appColors.hairlineStrong,
            ),
            const SizedBox(width: kSpacing10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SAFE TO SPEND',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.appTypography.eyebrow.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: kSpacing4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      isOver
                          ? '- ${CurrencyFormatter.formatCents(remaining.abs())}'
                          : CurrencyFormatter.formatCents(remaining),
                      maxLines: 1,
                      // Same poster scale as the countdown beside it. The two
                      // footer cells are peers, so their values share a size;
                      // only the hero balance is allowed to break the scale.
                      style: context.appTypography.poster.copyWith(
                        fontSize: 30,
                        color: tone,
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
}
