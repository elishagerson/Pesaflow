import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/track_ring.dart';
import 'package:pesaflow/presentation/dashboard/widgets/dashboard_balance_header.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

/// Dashboard hero: one full-width card with the balance, the next bill, and the
/// remaining budget in hairline-divided cells.
///
/// The cells share a single surface so the three numbers read as one financial
/// position. There is no pager, dot rail, or per-cell card chrome.
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

    // The hero answers "can I spend today?" first. Net worth is still here,
    // but one tier down in the footer next to the next bill.
    final isOver = remainingBudget < 0;
    final fraction = budgetPct.clamp(0.0, 1.0);
    final tone = isOver
        ? Theme.of(context).colorScheme.error
        : remainingBudget == 0
        ? context.appColors.textMedium
        : context.appColors.brandColor;

    return DashboardBalanceHeader(
      balance: remainingBudget,
      label: 'SAFE TO SPEND',
      heroBadge: TrackRing(
        value: fraction,
        size: 52,
        thickness: 4,
        color: tone,
        trackColor: context.appColors.hairlineStrong,
        semanticsLabel: budgetTotal > 0
            ? '${(fraction * 100).round()} percent of budget used'
            : 'No budget limit set',
      ),
      income: income,
      expense: expense,
      footerHeight: 80,
      footer: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The two cells split the width evenly. Expanded rather than a
          // measured fraction so a long countdown string cannot steal width
          // from its neighbour.
          Expanded(
            child: _NextUpCell(
              label: event?.label,
              countdown: event == null
                  ? null
                  : _countdown(
                      event.date,
                      Localizations.localeOf(context).toLanguageTag(),
                    ),
            ),
          ),
          const _CellDivider(),
          Expanded(
            child: _NetWorthCell(amount: balance, label: label),
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
String _countdown(DateTime date, String locale) {
  final now = DateTime.now();
  final days = date.difference(now).inDays;
  final hours = date.difference(now).inHours % 24;
  if (days <= 0) return 'TODAY ${hours}H';
  if (days == 1) return 'TOMORROW';
  if (days < 7) return '$days DAYS';
  return '${date.day} ${DateFormat('MMM', locale).format(date).toUpperCase()}';
}

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
                  style: context
                      .ts(
                        30,
                        tabular: true,
                        color: isEmpty
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface,
                      )
                      .copyWith(fontFamily: AppTheme.fontDisplay),
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

/// Net worth used to own the hero. It now sits in the footer: useful context,
/// but not the answer to "am I okay today?".
class _NetWorthCell extends StatelessWidget {
  final int amount;
  final String label;

  const _NetWorthCell({required this.amount, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNegative = amount < 0;

    return Semantics(
      label: 'Net worth ${CurrencyFormatter.formatCents(amount)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.trim().isEmpty
                ? 'NET WORTH'
                : 'NET WORTH · ${label.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.appTypography.eyebrow.copyWith(
              color: context.appColors.textMedium,
            ),
          ),
          const SizedBox(height: kSpacing6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                CurrencyFormatter.formatCents(amount),
                maxLines: 1,
                // Two tiers below the 76px hero: this is context, not the
                // answer. Peer scale with the "Next up" countdown.
                style: context
                    .ts(
                      30,
                      tabular: true,
                      color: isNegative
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface,
                    )
                    .copyWith(fontFamily: AppTheme.fontDisplay),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
