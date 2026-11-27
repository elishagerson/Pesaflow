import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/empty_state.dart';
import 'package:pesaflow/presentation/common/widgets/pesa_surface.dart';
import 'package:pesaflow/presentation/recurring/utils/recurring_schedule_helpers.dart';

/// Payday overview matching the Payday snapshot:
/// - Header ("Payday" + schedule cadence)
/// - Countdown calendar card ("X days to payday" + 3-week calendar strip)
/// - Next paydays timeline card (next 3 projected occurrences)
/// - Safe-to-spend card ("<amount> to last X days")
class PaydayView extends StatelessWidget {
  final List<RecurringTransaction> allRecurring;
  final int currentBalanceCents;
  final int billsDueBeforePaydayCents;

  const PaydayView({
    super.key,
    required this.allRecurring,
    required this.currentBalanceCents,
    required this.billsDueBeforePaydayCents,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final activeIncomes = allRecurring
        .where((r) => r.type == 'income' && r.status == 'active')
        .toList();

    if (activeIncomes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          kSpacing16,
          kSpacing24,
          kSpacing16,
          kSpacing16,
        ),
        child: EmptyState(
          icon: PesaFlowIcons.income,
          title: 'No Payday Schedule',
          subtitle:
              'Add your salary or recurring income stream to track your countdown to payday and upcoming bills.',
          action: FilledButton.icon(
            onPressed: () {
              PesaHaptics.medium();
              context.push('/recurring/add', extra: {'type': 'income'});
            },
            icon: const Icon(PesaFlowIcons.add, size: 18),
            label: const Text('Add Payday Income'),
          ),
        ),
      );
    }

    final now = dateOnly(DateTime.now());
    final nextPayday = nextPaydayFor(allRecurring, now: now);
    final upcomingPaydays = projectUpcomingPaydays(
      allRecurring,
      count: 3,
      now: now,
    );
    final subtitle = paydayScheduleSubtitle(activeIncomes);
    final daysToPayday =
        nextPayday != null ? nextPayday.difference(now).inDays : 0;

    final remainingAfterBills =
        (currentBalanceCents - billsDueBeforePaydayCents).clamp(0, 1 << 62);
    final effectiveDays = daysToPayday > 0 ? daysToPayday : 1;
    final dailyAllowanceCents = remainingAfterBills ~/ effectiveDays;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kSpacing16,
        kSpacing12,
        kSpacing16,
        kSpacing8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: kSpacing12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payday',
                  style: context.ts(
                    24,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  subtitle,
                  style: context.ts(
                    16,
                    fontWeight: FontWeight.w500,
                    color: context.appColors.textMedium,
                  ),
                ),
              ],
            ),
          ),

          // Card 1: Countdown Calendar
          _CountdownCalendarCard(
            today: now,
            nextPayday: nextPayday,
            daysToPayday: daysToPayday,
            projectedDates: upcomingPaydays.map((p) => p.date).toSet(),
          ),
          const SizedBox(height: kSpacing12),

          // Card 2: Next Paydays Timeline
          if (upcomingPaydays.isNotEmpty) ...[
            _NextPaydaysCard(
              today: now,
              occurrences: upcomingPaydays,
            ),
            const SizedBox(height: kSpacing12),
          ],

          // Card 3: "<amount> to last X days"
          PesaSurface.bleed(
            fill: theme.colorScheme.surfaceContainerHigh,
            radius: AppTheme.radiusDialog,
            padding: const EdgeInsets.all(kSpacing20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        spacing: kSpacing6,
                        children: [
                          AmountText(
                            amountInCents: remainingAfterBills,
                            animate: true,
                            style: context.ts(
                              22,
                              fontWeight: FontWeight.w800,
                              color: onSurface,
                            ),
                          ),
                          Text(
                            daysToPayday == 0
                                ? 'available today'
                                : daysToPayday == 1
                                    ? 'to last 1 day'
                                    : 'to last $daysToPayday days',
                            style: context.ts(
                              13,
                              fontWeight: FontWeight.w500,
                              color: context.appColors.textMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: kSpacing4),
                      Text(
                        '${CurrencyFormatter.formatCompact(dailyAllowanceCents)}/day safe to spend after upcoming bills',
                        style: context.ts(
                          11,
                          fontWeight: FontWeight.w500,
                          color: context.appColors.textMedium,
                        ),
                      ),
                    ],
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

class _CountdownCalendarCard extends StatelessWidget {
  final DateTime today;
  final DateTime? nextPayday;
  final int daysToPayday;
  final Set<DateTime> projectedDates;

  const _CountdownCalendarCard({
    required this.today,
    required this.nextPayday,
    required this.daysToPayday,
    required this.projectedDates,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final incomeColor = context.appColors.incomeColor;

    // Anchor 3-week grid starting from the Monday of last week (so today sits
    // cleanly in the middle/upper rows and upcoming payday is visible).
    final currentWeekMonday = today.subtract(Duration(days: today.weekday - 1));
    final gridStart = currentWeekMonday.subtract(const Duration(days: 7));
    final days = List<DateTime>.generate(
      21,
      (i) => gridStart.add(Duration(days: i)),
    );

    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return PesaSurface.bleed(
      fill: theme.colorScheme.surfaceContainerHigh,
      radius: AppTheme.radiusDialog,
      padding: const EdgeInsets.all(kSpacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Headline: "6 days to payday"
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                daysToPayday == 0
                    ? 'Payday'
                    : daysToPayday == 1
                        ? '1 day'
                        : '$daysToPayday days',
                style: context.ts(
                  30,
                  fontWeight: FontWeight.w900,
                  color: onSurface,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(width: kSpacing8),
              Text(
                daysToPayday == 0 ? 'is today!' : 'to payday',
                style: context.ts(
                  14,
                  fontWeight: FontWeight.w500,
                  color: context.appColors.textMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing16),

          // Weekday header
          Row(
            children: weekdays
                .map(
                  (w) => Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: context.ts(
                          11,
                          fontWeight: FontWeight.w600,
                          color: context.appColors.textMedium,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: kSpacing8),

          // 3 rows x 7 columns
          for (int row = 0; row < 3; row++) ...[
            if (row > 0) const SizedBox(height: kSpacing6),
            Row(
              children: List.generate(7, (col) {
                final d = days[row * 7 + col];
                final isToday = d == today;
                final isPayday = projectedDates.contains(d);
                final isCountdown = nextPayday != null &&
                    d.isAfter(today) &&
                    d.isBefore(nextPayday!);
                final isPast = d.isBefore(today);

                Color? bgColor;
                BoxBorder? border;
                Color textColor = onSurface;
                FontWeight fontWeight = FontWeight.w600;

                if (isPayday) {
                  bgColor = incomeColor;
                  textColor = Colors.white;
                  fontWeight = FontWeight.w800;
                } else if (isToday) {
                  border = Border.all(color: onSurface, width: 1.5);
                  fontWeight = FontWeight.w800;
                } else if (isCountdown) {
                  bgColor = incomeColor.withValues(alpha: 0.22);
                  fontWeight = FontWeight.w700;
                } else if (isPast) {
                  textColor = onSurface.withValues(alpha: 0.32);
                  fontWeight = FontWeight.w500;
                } else {
                  textColor = onSurface.withValues(alpha: 0.45);
                  fontWeight = FontWeight.w500;
                }

                return Expanded(
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: bgColor,
                        border: border,
                        borderRadius: BorderRadius.circular(
                          AppTheme.squircleRadius(12),
                        ),
                      ),
                      child: Text(
                        '${d.day}',
                        style: context.ts(
                          13,
                          fontWeight: fontWeight,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

class _NextPaydaysCard extends StatelessWidget {
  final DateTime today;
  final List<PaydayOccurrence> occurrences;

  const _NextPaydaysCard({
    required this.today,
    required this.occurrences,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final incomeColor = context.appColors.incomeColor;
    final dateFmt = DateFormat('EEE d MMM');

    return PesaSurface.bleed(
      fill: theme.colorScheme.surfaceContainerHigh,
      radius: AppTheme.radiusDialog,
      padding: const EdgeInsets.all(kSpacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Next paydays',
            style: context.ts(
              13,
              fontWeight: FontWeight.w600,
              color: context.appColors.textMedium,
            ),
          ),
          const SizedBox(height: kSpacing16),
          for (int i = 0; i < occurrences.length; i++) ...[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Timeline dot + vertical line
                  SizedBox(
                    width: 20,
                    child: Column(
                      children: [
                        const SizedBox(height: kSpacing4),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: i == 0
                                ? incomeColor
                                : onSurface.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (i < occurrences.length - 1)
                          Expanded(
                            child: Container(
                              width: 1.5,
                              margin: const EdgeInsets.symmetric(
                                vertical: kSpacing4,
                              ),
                              color: context.appColors.hairline,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: kSpacing12),
                  // Date + relative label
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: i < occurrences.length - 1 ? kSpacing16 : 0,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateFmt.format(occurrences[i].date),
                                  style: context.ts(
                                    14,
                                    fontWeight: FontWeight.w700,
                                    color: onSurface,
                                  ),
                                ),
                                const SizedBox(height: kSpacing2),
                                Text(
                                  relativeDayLabel(
                                    occurrences[i].date,
                                    now: today,
                                  ),
                                  style: context.ts(
                                    12,
                                    fontWeight: FontWeight.w500,
                                    color: context.appColors.textMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '+ ${CurrencyFormatter.formatCents(occurrences[i].source.amount)}',
                            style: context.ts(
                              14,
                              fontWeight: FontWeight.w700,
                              color: i == 0 ? incomeColor : onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
