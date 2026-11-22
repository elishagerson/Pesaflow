import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/theme/app_colors_theme.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/error_state.dart';
import 'package:pesaflow/presentation/common/widgets/empty_state.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/motion/haptic_pattern.dart';
import 'package:pesaflow/presentation/common/widgets/motion/skeleton_crossfade.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';
import 'package:pesaflow/presentation/state/spending_heatmap_provider.dart';

class SpendingHeatmapCard extends ConsumerStatefulWidget {
  const SpendingHeatmapCard({super.key});

  @override
  ConsumerState<SpendingHeatmapCard> createState() =>
      _SpendingHeatmapCardState();
}

class _SpendingHeatmapCardState extends ConsumerState<SpendingHeatmapCard> {
  final ScrollController _scrollController = ScrollController();
  DateTime? _selectedDate;
  int? _selectedAmount;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _getCellColor(
    BuildContext context,
    int amount,
    int maxExpense,
    AppColorsTheme appColors,
  ) {
    if (amount == 0) {
      return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06);
    }
    if (maxExpense <= 0) {
      return appColors.expenseColor.withValues(alpha: 0.15);
    }
    final ratio = amount / maxExpense;
    if (ratio <= 0.25) {
      return appColors.expenseColor.withValues(alpha: 0.25);
    } else if (ratio <= 0.50) {
      return appColors.expenseColor.withValues(alpha: 0.50);
    } else if (ratio <= 0.75) {
      return appColors.expenseColor.withValues(alpha: 0.75);
    } else {
      return appColors.expenseColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final heatmapAsync = ref.watch(spendingHeatmapProvider);
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColorsTheme>()!;

    return SkeletonCrossfade(
      isLoading: heatmapAsync is AsyncLoading && !heatmapAsync.hasValue,
      skeleton: const Padding(
        padding: EdgeInsets.symmetric(horizontal: kSpacing16),
        child: SkeletonCard(height: 180),
      ),
      child: heatmapAsync.when(
        data: (data) {
          if (data.totalExpenditure == 0) {
            return const Padding(
              padding: EdgeInsets.all(kSpacing16),
              child: EmptyState(
                icon: PesaFlowIcons.analytics,
                title: 'No spending yet',
                subtitle:
                    'Log expenses to see your spending pattern over time.',
              ),
            );
          }
          // Align columns. We display exactly 20 columns (weeks).
          // We start on the Sunday before the calculated start date
          final startDayOfWeek = data.startDate.weekday;
          final daysToSubtract = startDayOfWeek == 7 ? 0 : startDayOfWeek;
          final gridStartDate = data.startDate.subtract(
            Duration(days: daysToSubtract),
          );

          final weeks = <List<DateTime>>[];
          for (int w = 0; w < 20; w++) {
            final weekDays = <DateTime>[];
            for (int d = 0; d < 7; d++) {
              weekDays.add(gridStartDate.add(Duration(days: w * 7 + d)));
            }
            weeks.add(weekDays);
          }

          return GlassCard(
            padding: const EdgeInsets.all(kSpacing16),
            borderRadius: AppTheme.radiusCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'SPENDING ACTIVITY',
                        style: context.ts(
                          11,
                          color: appColors.textMedium,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: kSpacing8),
                    Flexible(
                      child: Text(
                        'Last 20 Weeks',
                        textAlign: TextAlign.end,
                        style: context.ts(11, color: appColors.textMedium),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: kSpacing8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        'Total Spent: ',
                        style: context.ts(13, color: appColors.textMedium),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      flex: 2,
                      child: AmountText(
                        amountInCents: data.totalExpenditure,
                        animate: true,
                        style: context.ts(
                          20,
                          color: appColors.expenseColor,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: kSpacing16),
                // Scrollable grid of blocks with a fixed weekday gutter.
                SizedBox(
                  height: 144,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Weekday initials (Sun -> Sat) aligned with the 7 rows.
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Month-label header height (16) + gap (6).
                          const SizedBox(height: 22),
                          ...List.generate(7, (d) {
                            return SizedBox(
                              width: 18,
                              height: 17,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'][d],
                                  style: context.ts(
                                    8,
                                    color: appColors.textMedium,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(width: kSpacing4),
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          itemCount: weeks.length,
                          itemBuilder: (context, wIndex) {
                            final week = weeks[wIndex];

                            // Label the week that CONTAINS the 1st of a month,
                            // not merely one that starts in a new month — a
                            // Sunday-aligned week can straddle two months.
                            final hasFirstOfMonth = week.any((d) => d.day == 1);
                            final monthLabel = DateFormat('MMM').format(
                              hasFirstOfMonth
                                  ? week.firstWhere((d) => d.day == 1)
                                  : week.first,
                            );
                            final showMonthLabel =
                                wIndex == 0 || hasFirstOfMonth;

                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Month label header
                                  SizedBox(
                                    width: 13,
                                    height: 16,
                                    child: showMonthLabel
                                        ? OverflowBox(
                                            maxWidth: 40,
                                            alignment: Alignment.bottomLeft,
                                            child: Text(
                                              monthLabel,
                                              style: context.ts(
                                                9,
                                                color: appColors.textMedium,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              softWrap: false,
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                  const SizedBox(height: kSpacing6),
                                  ...week.map((date) {
                                    final dateStr =
                                        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                                    final amount =
                                        data.dailyExpenses[dateStr] ?? 0;
                                    final cellColor = _getCellColor(
                                      context,
                                      amount,
                                      data.maxExpense,
                                      appColors,
                                    );
                                    final isSelected =
                                        _selectedDate != null &&
                                        _selectedDate!.year == date.year &&
                                        _selectedDate!.month == date.month &&
                                        _selectedDate!.day == date.day;

                                    return Tooltip(
                                      message:
                                          '${DateFormat('d MMM').format(date)}: ${CurrencyFormatter.formatCents(amount)}',
                                      child: Semantics(
                                        label:
                                            '$dateStr, spent ${CurrencyFormatter.formatCents(amount)}',
                                        button: true,
                                        child: GestureDetector(
                                          onTap: () {
                                            triggerHaptic(HapticType.selection);
                                            setState(() {
                                              if (isSelected) {
                                                _selectedDate = null;
                                                _selectedAmount = null;
                                              } else {
                                                _selectedDate = date;
                                                _selectedAmount = amount;
                                              }
                                            });
                                          },
                                          child: AnimatedContainer(
                                            duration: MotionTokens.durationExit,
                                            curve: Curves.easeOutCubic,
                                            width: isSelected ? 15 : 13,
                                            height: isSelected ? 15 : 13,
                                            margin: EdgeInsets.symmetric(
                                              vertical: isSelected ? 1.0 : 2.0,
                                              horizontal:
                                                  isSelected ? 0.0 : 1.0,
                                            ),
                                            decoration: BoxDecoration(
                                              color: cellColor,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                isSelected ? 4 : 3,
                                              ),
                                              border: Border.all(
                                                color: isSelected
                                                    ? theme.colorScheme.onPrimary
                                                    : Colors.transparent,
                                                width: isSelected ? 1.5 : 0.0,
                                              ),
                                              boxShadow: isSelected
                                                  ? [
                                                      BoxShadow(
                                                        color: cellColor
                                                            .withValues(
                                                          alpha: 0.4,
                                                        ),
                                                        blurRadius: 6,
                                                        spreadRadius: 1,
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: kSpacing8),
                // Legend and details row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Legend
                    Row(
                      children: [
                        Text(
                          'Less',
                          style: context.ts(
                            10,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: kSpacing4),
                        ...List.generate(5, (i) {
                          final val = data.maxExpense <= 0
                              ? 0
                              : (data.maxExpense * (i / 4)).round();
                          return Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(
                              color: _getCellColor(
                                context,
                                val,
                                data.maxExpense <= 0 ? 1 : data.maxExpense,
                                appColors,
                              ),
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                          );
                        }),
                        const SizedBox(width: kSpacing4),
                        Text(
                          'More',
                          style: context.ts(
                            10,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Selected date detail
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AnimatedSwitcher(
                          duration: MotionTokens.durationMicro,
                          child: _selectedDate != null
                              ? Text(
                                  '${DateFormat('d MMM').format(_selectedDate!)}: ${CurrencyFormatter.formatCents(_selectedAmount ?? 0)}',
                                  style: context.ts(
                                    11,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  key: ValueKey(_selectedDate),
                                )
                              : Text(
                                  'Tap cell for details',
                                  style: context.ts(
                                    10,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.35),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (e, _) => ErrorState(
          title: 'Could not load heatmap',
          message: '$e',
          onRetry: () => ref.invalidate(spendingHeatmapProvider),
        ),
      ),
    );
  }
}
