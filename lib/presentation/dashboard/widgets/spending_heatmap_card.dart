import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/theme/app_colors_theme.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/motion/haptic_pattern.dart';
import 'package:pesaflow/presentation/common/widgets/motion/skeleton_crossfade.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';
import 'package:pesaflow/presentation/state/spending_heatmap_provider.dart';

class SpendingHeatmapCard extends ConsumerStatefulWidget {
  const SpendingHeatmapCard({super.key});

  @override
  ConsumerState<SpendingHeatmapCard> createState() => _SpendingHeatmapCardState();
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

  Color _getCellColor(BuildContext context, int amount, int maxExpense, AppColorsTheme appColors) {
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
          // Align columns. We display exactly 20 columns (weeks).
          // We start on the Sunday before the calculated start date
          final startDayOfWeek = data.startDate.weekday;
          final daysToSubtract = startDayOfWeek == 7 ? 0 : startDayOfWeek;
          final gridStartDate = data.startDate.subtract(Duration(days: daysToSubtract));

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
                    Text(
                      'SPENDING ACTIVITY',
                      style: context.ts(
                        11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Last 20 Weeks',
                      style: context.ts(
                        11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: kSpacing8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'Total Spent: ',
                      style: context.ts(
                        13,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    AmountText(
                      amountInCents: data.totalExpenditure,
                      style: context.ts(
                        20,
                        color: appColors.expenseColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: kSpacing16),
                // Scrollable Grid of blocks
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: weeks.length,
                    itemBuilder: (context, wIndex) {
                      final week = weeks[wIndex];

                      // Calculate month label visibility
                      bool showMonthLabel = false;
                      String monthLabel = '';
                      if (wIndex == 0) {
                        showMonthLabel = true;
                        monthLabel = DateFormat('MMM').format(week.first);
                      } else {
                        final prevWeek = weeks[wIndex - 1];
                        if (week.first.month != prevWeek.first.month) {
                          showMonthLabel = true;
                          monthLabel = DateFormat('MMM').format(week.first);
                        }
                      }

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
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
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
                              final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                              final amount = data.dailyExpenses[dateStr] ?? 0;
                              final cellColor = _getCellColor(context, amount, data.maxExpense, appColors);
                              final isSelected = _selectedDate != null &&
                                  _selectedDate!.year == date.year &&
                                  _selectedDate!.month == date.month &&
                                  _selectedDate!.day == date.day;

                              return GestureDetector(
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
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutCubic,
                                  width: isSelected ? 15 : 13,
                                  height: isSelected ? 15 : 13,
                                  margin: EdgeInsets.symmetric(
                                    vertical: isSelected ? 1.0 : 2.0,
                                    horizontal: isSelected ? 0.0 : 1.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cellColor,
                                    borderRadius: BorderRadius.circular(isSelected ? 4 : 3),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: isSelected ? 1.5 : 0.0,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: cellColor.withValues(alpha: 0.4),
                                              blurRadius: 6,
                                              spreadRadius: 1,
                                            )
                                          ]
                                        : null,
                                  ),
                            }),
                          ],
                        ),
                      );
                    },
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
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 4),
                        ...[0, 100, 200, 300, 400].map((val) {
                          return Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(
                              color: _getCellColor(context, val, 400, appColors),
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                          );
                        }),
                        const SizedBox(width: 4),
                        Text(
                          'More',
                          style: context.ts(
                            10,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    // Selected date detail
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          child: _selectedDate != null
                              ? Text(
                                  '${DateFormat('d MMM').format(_selectedDate!)}: ${CurrencyFormatter.formatCents(_selectedAmount ?? 0)}',
                                  style: context.ts(
                                    11,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  key: ValueKey(_selectedDate),
                                )
                              : Text(
                                  'Tap cell for details',
                                  style: context.ts(
                                    10,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
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
        error: (e, _) => Text('Error loading heatmap: $e'),
      ),
    );
  }
}
