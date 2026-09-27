import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/pesa_surface.dart';
import 'package:pesaflow/presentation/common/widgets/track_ring.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/dashboard/widgets/budjetly_balance_header.dart';

/// The dashboard's hero strip: a snap-paged carousel of full-bleed cards, the
/// way a widget-gallery home screen presents its content.
///
/// Why a carousel at all: the dashboard already had a fixed vertical stack, and
/// everything down it competed for the same attention as the balance. Paging
/// makes exactly one card loud at a time and turns the rest into a browsable
/// row, so the surface area grows without the scroll growing.
class DashboardHeroCarousel extends ConsumerStatefulWidget {
  final int balance;
  final String label;
  final int income;
  final int expense;
  final int remainingBudget;
  final double budgetPct;
  final int budgetTotal;

  const DashboardHeroCarousel({
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
  ConsumerState<DashboardHeroCarousel> createState() =>
      _DashboardHeroCarouselState();
}

class _DashboardHeroCarouselState extends ConsumerState<DashboardHeroCarousel> {
  late final PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    // `initialPage: 0` with a viewport fraction below 1 is what makes the
    // neighbouring card peek in from the right — the "there is more here"
    // signal that a dot indicator alone can't carry.
    _controller = PageController(viewportFraction: 0.885);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _pageCount => 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 232,
          child: PageView.builder(
            controller: _controller,
            itemCount: _pageCount,
            onPageChanged: (i) {
              PesaHaptics.selection();
              setState(() => _page = i);
            },
            itemBuilder: (context, i) => Padding(
              padding: EdgeInsets.only(
                right: i == _pageCount - 1 ? 0 : kSpacing12,
              ),
              child: switch (i) {
                0 => BudjetlyBalanceHeader(
                  balance: widget.balance,
                  label: widget.label,
                  income: widget.income,
                  expense: widget.expense,
                ),
                1 => const _NextUpCard(),
                _ => _SafeToSpendCard(
                  remaining: widget.remainingBudget,
                  pct: widget.budgetPct,
                  total: widget.budgetTotal,
                ),
              },
            ),
          ),
        ),
        const SizedBox(height: kSpacing14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kSpacing4),
          child: Row(
            children: [
              for (var i = 0; i < _pageCount; i++)
                _Segment(
                  active: i == _page,
                  onTap: () {
                    PesaHaptics.selection();
                    _controller.animateToPage(
                      i,
                      duration: MotionTokens.durationNormal,
                      curve: Curves.easeOutCubic,
                    );
                  },
                ),
              const Spacer(),
              Text(
                switch (_page) {
                  0 => 'Balance',
                  1 => 'Next up',
                  _ => 'Safe to spend',
                },
                style: context.appTypography.labelMicro.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _Segment({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: kSpacing6, top: kSpacing8),
        child: AnimatedContainer(
          duration: MotionTokens.durationExit,
          curve: Curves.easeOutCubic,
          width: active ? 26 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? context.appColors.brandColor
                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
        ),
      ),
    );
  }
}

/// "NEXT UP" — the single most important future date in the app, counted down.
/// Box Box puts a session countdown on its home screen; the financial
/// equivalent is the next bill or loan landing, so that is what this leads with.
class _NextUpCard extends ConsumerWidget {
  const _NextUpCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    final events =
        <({String label, int amount, DateTime date, IconData icon})>[];

    final recs = ref.watch(recurringTransactionsStreamProvider).value ?? [];
    for (final r in recs) {
      if (r.status != 'active' || r.type != 'expense') continue;
      if (r.nextDate.isBefore(now)) continue;
      events.add((
        label: r.description ?? 'Recurring payment',
        amount: r.amount,
        date: r.nextDate,
        icon: PesaFlowIcons.subscriptions,
      ));
    }

    if (events.isEmpty) {
      return PesaSurface.chamferSurface(
        glow: 0.14,
        padding: const EdgeInsets.all(kSpacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Next up',
              style: context.appTypography.eyebrow.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: kSpacing10),
            Text(
              'All clear',
              style: context.appTypography.posterLarge.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: kSpacing6),
            Text(
              'Nothing due in the schedule. Add a recurring bill to see it here.',
              style: context.ts(12, color: context.appColors.textMedium),
            ),
          ],
        ),
      );
    }

    events.sort((a, b) => a.date.compareTo(b.date));
    final next = events.first;
    final days = next.date.difference(now).inDays;
    final hours = next.date.difference(now).inHours % 24;
    final countdown = switch (days) {
      0 => 'TODAY ${hours}H',
      1 => 'TOMORROW',
      < 7 => '$days DAYS',
      _ => '${next.date.day} ${_month(next.date.month)}',
    };

    return PesaSurface.chamferSurface(
      onTap: () => context.push('/recurring'),
      semanticLabel: 'Next up: ${next.label}, $countdown',
      glow: 0.3,
      padding: const EdgeInsets.all(kSpacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Next up',
                style: context.appTypography.eyebrow.copyWith(
                  color: context.appColors.brandColor,
                ),
              ),
              Icon(
                next.icon,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: kSpacing10),
          Text(
            countdown,
            style: context.appTypography.posterLarge.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: kSpacing4),
          Text(
            next.label,
            style: context.ts(
              14,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            children: [
              Icon(
                PesaFlowIcons.wallet,
                size: 14,
                color: context.appColors.textMedium,
              ),
              const SizedBox(width: kSpacing6),
              Text(
                CurrencyFormatter.formatCents(next.amount),
                style: context.ts(
                  15,
                  fontWeight: FontWeight.w800,
                  color: context.appColors.textMedium,
                ),
              ),
              const Spacer(),
              if (events.length > 1)
                Text(
                  '+${events.length - 1} more',
                  style: context.appTypography.labelMicro.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _month(int m) => const [
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
}

/// "SAFE TO SPEND" — the month's remaining allowance as a tilted ring, mirroring
/// Box Box's signature ring gauge.
class _SafeToSpendCard extends StatelessWidget {
  final int remaining;
  final double pct;
  final int total;

  const _SafeToSpendCard({
    required this.remaining,
    required this.pct,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTight = remaining <= 0;

    return PesaSurface.chamferSurface(
      onTap: () => context.push('/budgets'),
      semanticLabel: 'Safe to spend $remaining',
      glow: isTight ? 0.08 : 0.24,
      padding: const EdgeInsets.all(kSpacing20),
      child: Row(
        children: [
          TrackRing(
            value: pct,
            size: 96,
            thickness: 9,
            color: isTight
                ? theme.colorScheme.error
                : context.appColors.brandColor,
            trackColor: context.appColors.hairlineStrong,
            child: Icon(
              isTight ? PesaFlowIcons.warning : PesaFlowIcons.wallet,
              size: 22,
              color: isTight
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: kSpacing16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Safe to spend',
                  style: context.appTypography.eyebrow.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: kSpacing6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyFormatter.formatCents(remaining.abs()),
                    style: context.appTypography.poster.copyWith(
                      color: isTight
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: kSpacing4),
                Text(
                  isTight
                      ? 'Over budget by this much'
                      : 'of ${CurrencyFormatter.formatCents(total)} this month',
                  style: context.ts(12, color: context.appColors.textMedium),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
