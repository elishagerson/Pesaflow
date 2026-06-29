import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/domain/analytics/insight_generator.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/budgets/widgets/savings_goal_detail_sheet.dart';
import 'package:pesaflow/presentation/budgets/widgets/savings_goal_form_sheet.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/analytics_repository.dart';
import 'package:flutter/services.dart';

enum TrendRange { days, weeks, months }

class TrendDataPoint {
  final String label;
  final double income;
  final double expense;

  TrendDataPoint({
    required this.label,
    required this.income,
    required this.expense,
  });
}

class TrendRangeNotifier extends Notifier<TrendRange> {
  @override
  TrendRange build() => TrendRange.days;

  @override
  set state(TrendRange value) => super.state = value;
}

final trendRangeProvider = NotifierProvider<TrendRangeNotifier, TrendRange>(() {
  return TrendRangeNotifier();
});

final trendPointsProvider = FutureProvider<List<TrendDataPoint>>((ref) async {
  final range = ref.watch(trendRangeProvider);
  final analyticsRepo = ref.watch(analyticsRepositoryProvider);
  final now = DateTime.now();

  switch (range) {
    case TrendRange.days:
      final daysCount = 14;
      final startDate = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: daysCount - 1));
      final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final snapshots = await analyticsRepo.getDailySnapshots(
        startDate,
        endDate,
      );
      final Map<String, DailySnapshot> snapshotMap = {
        for (final s in snapshots) s.date: s,
      };

      final List<TrendDataPoint> points = [];
      for (int i = 0; i < daysCount; i++) {
        final date = startDate.add(Duration(days: i));
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final snapshot = snapshotMap[dateStr];

        final label = DateFormat('dd/MM').format(date);
        points.add(
          TrendDataPoint(
            label: label,
            income: (snapshot?.totalIncome ?? 0) / 100.0,
            expense: (snapshot?.totalExpense ?? 0) / 100.0,
          ),
        );
      }
      return points;

    case TrendRange.weeks:
      final weeksCount = 8;
      final totalDays = weeksCount * 7;
      final startDate = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: totalDays - 1));
      final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final snapshots = await analyticsRepo.getDailySnapshots(
        startDate,
        endDate,
      );

      final List<TrendDataPoint> points = [];
      for (int w = 0; w < weeksCount; w++) {
        final weekStart = startDate.add(Duration(days: w * 7));
        final weekEnd = weekStart.add(
          const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
        );

        double weekIncome = 0;
        double weekExpense = 0;

        for (final s in snapshots) {
          final sDate = DateTime.parse(s.date);
          if (sDate.isAfter(weekStart.subtract(const Duration(seconds: 1))) &&
              sDate.isBefore(weekEnd.add(const Duration(seconds: 1)))) {
            weekIncome += s.totalIncome / 100.0;
            weekExpense += s.totalExpense / 100.0;
          }
        }

        final label = 'W${w + 1}\n(${DateFormat('d/M').format(weekStart)})';
        points.add(
          TrendDataPoint(
            label: label,
            income: weekIncome,
            expense: weekExpense,
          ),
        );
      }
      return points;

    case TrendRange.months:
      final snapshots = await analyticsRepo.getMonthlySnapshots(6);
      final reversed = snapshots.reversed.toList();

      final monthLabels = {
        '01': 'Jan',
        '02': 'Feb',
        '03': 'Mar',
        '04': 'Apr',
        '05': 'May',
        '06': 'Jun',
        '07': 'Jul',
        '08': 'Aug',
        '09': 'Sep',
        '10': 'Oct',
        '11': 'Nov',
        '12': 'Dec',
      };

      return reversed.map((s) {
        final ym = s.yearMonth;
        final monthNum = ym.substring(5);
        final label = monthLabels[monthNum] ?? monthNum;
        return TrendDataPoint(
          label: label,
          income: s.totalIncome / 100.0,
          expense: s.totalExpense / 100.0,
        );
      }).toList();
  }
});

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: const IosNavBar(title: 'Analytics', largeTitle: true),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              // iOS-style sliding capsule control
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xE60F1013)
                        : const Color(0xE6E5E5EA),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: isDark
                          ? const Color(0x1AFFFFFF)
                          : const Color(0x1F000000),
                      width: 0.5,
                    ),
                  ),
                  child: TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicatorPadding: EdgeInsets.zero,
                    indicator: BoxDecoration(
                      color: isDark ? AppTheme.surfaceHighDark : Colors.white,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 1,
                                offset: const Offset(0, 1),
                              ),
                            ],
                    ),
                    labelColor: isDark ? Colors.white : Colors.black,
                    unselectedLabelColor: isDark
                        ? Colors.grey[600]
                        : Colors.grey[500],
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Trends'),
                      Tab(text: 'Insights'),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _OverviewTab(
                      theme: theme,
                      ref: ref,
                      hexToColor: hexToColor,
                    ),
                    _TrendsTab(theme: theme, ref: ref),
                    _InsightsTab(theme: theme, ref: ref),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Gradient _getCategoryNeonGradient(Color baseColor) {
  final hsl = HSLColor.fromColor(baseColor);
  final brighter = hsl
      .withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0))
      .withSaturation((hsl.saturation + 0.1).clamp(0.0, 1.0))
      .toColor();
  return LinearGradient(
    colors: [brighter, baseColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class _OverviewTab extends StatelessWidget {
  final ThemeData theme;
  final WidgetRef ref;
  final Color Function(String) hexToColor;
  const _OverviewTab({
    required this.theme,
    required this.ref,
    required this.hexToColor,
  });

  @override
  Widget build(BuildContext context) {
    final totalsAsync = ref.watch(monthlyTotalsProvider);
    final categoriesAsync = ref.watch(topCategoriesProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Monthly Summary
          totalsAsync.when(
            data: (totals) {
              final income = totals['income'] ?? 0;
              final expense = totals['expense'] ?? 0;
              final net = income - expense;
              final savingsRate = income > 0
                  ? ((net / income) * 100).round()
                  : 0;
              final isDark = theme.brightness == Brightness.dark;
              final incomeColorVal = const Color(0xFF609F8A);
              final expenseColorVal = isDark
                  ? const Color(0xFFFF453A)
                  : const Color(0xFFE11D48);

              return StaggeredFadeSlide(
                index: 0,
                child: GlassCard(
                  padding: const EdgeInsets.all(20),
                  frosted: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'THIS MONTH',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Income',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey[500]
                                        : Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                                AmountText(
                                  amountInCents: income,
                                  style: TextStyle(
                                    color: incomeColorVal,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Expense',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey[500]
                                        : Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                                AmountText(
                                  amountInCents: expense,
                                  style: TextStyle(
                                    color: expenseColorVal,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(
                        height: 0.5,
                        thickness: 0.5,
                        color: isDark
                            ? const Color(0x12FFFFFF)
                            : const Color(0x0F000000),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            net >= 0 ? 'Net Savings' : 'Net Deficit',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[700],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          AmountText(
                            amountInCents: net.abs(),
                            type: net >= 0
                                ? AmountType.income
                                : AmountType.expense,
                            style: TextStyle(
                              color: net >= 0
                                  ? incomeColorVal
                                  : expenseColorVal,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Savings rate: $savingsRate%',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 20),

          // Savings Goal Bento Box
          ref
              .watch(savingsGoalsStreamProvider)
              .when(
                data: (goals) {
                  final isDark = theme.brightness == Brightness.dark;

                  if (goals.isNotEmpty) {
                    return SizedBox(
                      height: 125,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: goals.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final goal = goals[index];
                          final goalColor = hexToColor(goal.color);
                          final goalPct = goal.targetAmount > 0
                              ? (goal.currentAmount / goal.targetAmount).clamp(
                                  0.0,
                                  1.0,
                                )
                              : 0.0;
                          final percentInt = (goalPct * 100).round();

                          return StaggeredFadeSlide(
                            index: index,
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) =>
                                      SavingsGoalDetailSheet(goal: goal),
                                );
                              },
                              child: SizedBox(
                                width: 250,
                                child: GlassCard(
                                  padding: const EdgeInsets.all(16),
                                  frosted: true,
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        height: 56,
                                        width: 56,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            PieChart(
                                              PieChartData(
                                                startDegreeOffset: -90,
                                                sectionsSpace: 0,
                                                centerSpaceRadius: 20,
                                                sections: [
                                                  PieChartSectionData(
                                                    value: goalPct * 100,
                                                    color: goalColor,
                                                    radius: 4,
                                                    showTitle: false,
                                                  ),
                                                  PieChartSectionData(
                                                    value:
                                                        (1.0 - goalPct) * 100,
                                                    color: goalColor.withValues(
                                                      alpha: 0.12,
                                                    ),
                                                    radius: 4,
                                                    showTitle: false,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              goal.icon == 'savings'
                                                  ? PesaFlowIcons.savings
                                                  : goal.icon == 'laptop'
                                                  ? Icons
                                                        .laptop_chromebook_rounded
                                                  : goal.icon == 'flight'
                                                  ? Icons.flight_takeoff_rounded
                                                  : goal.icon == 'home'
                                                  ? Icons.home_rounded
                                                  : goal.icon == 'car'
                                                  ? Icons.directions_car_rounded
                                                  : goal.icon == 'school'
                                                  ? Icons.school_rounded
                                                  : goal.icon == 'heart'
                                                  ? Icons.favorite_rounded
                                                  : PesaFlowIcons.savings,
                                              color: goalColor,
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              goal.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$percentInt% Completed',
                                              style: TextStyle(
                                                color: goalColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Saved ${CurrencyFormatter.formatCents(goal.currentAmount)}',
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 10,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  } else {
                    final totals = totalsAsync.value ?? {};
                    final income = totals['income'] ?? 0;
                    final expense = totals['expense'] ?? 0;
                    final netSavings = income - expense;

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusCard,
                        ),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.transferColorDark.withValues(
                                    alpha: 0.12,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  PesaFlowIcons.savings,
                                  color: AppTheme.transferColorDark,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'SET A SAVINGS GOAL',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            netSavings > 0
                                ? 'You\'ve saved Tsh ${NumberFormat('#,###').format(netSavings ~/ 100)} this month! Let\'s build a target habit.'
                                : 'Set a visual savings goal target to build a structured emergency safety vault.',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) =>
                                      const SavingsGoalFormSheet(),
                                );
                              },
                              icon: const Icon(PesaFlowIcons.add, size: 16),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Set Monthly Savings Goal',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                },
                loading: () => const SizedBox(
                  height: 100,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, _) => const SizedBox(),
              ),
          const SizedBox(height: 24),

          // Category Donut inside a beautiful GlassCard
          GlassCard(
            padding: const EdgeInsets.all(20),
            frosted: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOP SPENDING CATEGORIES',
                  style: TextStyle(
                    color: theme.brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                categoriesAsync.when(
                  data: (cats) {
                    if (cats.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No spending data yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    }
                    final total = cats.fold<int>(0, (s, c) => s + c.amount);
                    final colors = [
                      theme.colorScheme.primary,
                      const Color(0xFFF59E0B),
                      const Color(0xFF3B82F6),
                      const Color(0xFF8B5CF6),
                      const Color(0xFFEF4444),
                    ];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        StaggeredFadeSlide(
                          index: 1,
                          child: SizedBox(
                            height: 120,
                            width: 120,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 36,
                                sections: List.generate(cats.length, (i) {
                                  final cat = cats[i];
                                  final color = i < colors.length
                                      ? colors[i]
                                      : hexToColor(cat.categoryColor);
                                  return PieChartSectionData(
                                    value: cat.amount.toDouble(),
                                    gradient: _getCategoryNeonGradient(color),
                                    radius: 18,
                                    showTitle: false,
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List.generate(cats.length, (i) {
                              final cat = cats[i];
                              final color = i < colors.length
                                  ? colors[i]
                                  : hexToColor(cat.categoryColor);
                              final pct = total > 0
                                  ? (cat.amount / total * 100).round()
                                  : 0;
                              final double pctFactor = total > 0
                                  ? (cat.amount / total)
                                  : 0.0;

                              return StaggeredFadeSlide(
                                index: i,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 10.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 10,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      _getCategoryNeonGradient(
                                                        color,
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                cat.categoryName,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '$pct%',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Curved progress track
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                        child: Container(
                                          height: 5,
                                          width: double.infinity,
                                          color: Colors.white.withValues(
                                            alpha: 0.06,
                                          ),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: FractionallySizedBox(
                                              widthFactor: pctFactor,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      _getCategoryNeonGradient(
                                                        color,
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        100,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const SizedBox(
                    height: 120,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (e, _) => Text('Error: $e'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendsTab extends StatelessWidget {
  final ThemeData theme;
  final WidgetRef ref;
  const _TrendsTab({required this.theme, required this.ref});

  Widget _buildRangeButton(TrendRange range, String label, TrendRange current) {
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = range == current;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(trendRangeProvider.notifier).state = range;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? theme.colorScheme.onPrimary
                : (isDark ? Colors.white70 : Colors.black54),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentRange = ref.watch(trendRangeProvider);
    final trendPointsAsync = ref.watch(trendPointsProvider);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StaggeredFadeSlide(
            index: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Income & Expense Trends',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentRange == TrendRange.days
                            ? 'Curved trend waves over the last 14 days'
                            : (currentRange == TrendRange.weeks
                                  ? 'Curved trend waves over the last 8 weeks'
                                  : 'Curved trend waves over the last 6 months'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.04),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildRangeButton(TrendRange.days, 'Days', currentRange),
                      _buildRangeButton(
                        TrendRange.weeks,
                        'Weeks',
                        currentRange,
                      ),
                      _buildRangeButton(
                        TrendRange.months,
                        'Months',
                        currentRange,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          trendPointsAsync.when(
            data: (points) {
              if (points.isEmpty) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                    child: Text(
                      'No data yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              final incomeSpots = List.generate(points.length, (i) {
                return FlSpot(i.toDouble(), points[i].income);
              });
              final expenseSpots = List.generate(points.length, (i) {
                return FlSpot(i.toDouble(), points[i].expense);
              });

              double maxVal = 1000.0;
              for (final p in points) {
                if (p.income > maxVal) maxVal = p.income;
                if (p.expense > maxVal) maxVal = p.expense;
              }

              return StaggeredFadeSlide(
                index: 1,
                child: GlassCard(
                  padding: const EdgeInsets.all(20),
                  frosted: true,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 240,
                        child: LineChart(
                          LineChartData(
                            lineTouchData: LineTouchData(
                              handleBuiltInTouches: true,
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (touchedSpot) {
                                  return theme.brightness == Brightness.dark
                                      ? const Color(
                                          0xFF1B1B1D,
                                        ).withValues(alpha: 0.95)
                                      : Colors.white.withValues(alpha: 0.95);
                                },
                                tooltipBorderRadius: BorderRadius.circular(12),
                                tooltipBorder: BorderSide(
                                  color: theme.brightness == Brightness.dark
                                      ? const Color(0x22FFFFFF)
                                      : const Color(0x0D000000),
                                  width: 1,
                                ),
                                getTooltipItems: (List<LineBarSpot> touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    final isIncome = spot.barIndex == 0;
                                    return LineTooltipItem(
                                      '${isIncome ? "Income" : "Expense"}\nTsh ${NumberFormat('#,###').format(spot.y.round() * 100)}',
                                      TextStyle(
                                        color: isIncome
                                            ? const Color(0xFF609F8A)
                                            : const Color(0xFFFF453A),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                              getTouchedSpotIndicator:
                                  (
                                    LineChartBarData barData,
                                    List<int> spotIndexes,
                                  ) {
                                    return spotIndexes.map((spotIndex) {
                                      return TouchedSpotIndicatorData(
                                        FlLine(
                                          color:
                                              (barData.gradient?.colors.first ??
                                                      Colors.grey)
                                                  .withValues(alpha: 0.3),
                                          strokeWidth: 2,
                                          dashArray: [4, 4],
                                        ),
                                        FlDotData(
                                          show: true,
                                          getDotPainter:
                                              (spot, percent, barData, index) {
                                                return FlDotCirclePainter(
                                                  radius: 6,
                                                  color:
                                                      barData
                                                          .gradient
                                                          ?.colors
                                                          .first ??
                                                      Colors.grey,
                                                  strokeWidth: 2,
                                                  strokeColor: Colors.white,
                                                );
                                              },
                                        ),
                                      );
                                    }).toList();
                                  },
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: maxVal > 0
                                  ? maxVal / 4
                                  : 1000,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: Colors.white.withValues(alpha: 0.04),
                                strokeWidth: 1,
                                dashArray: [5, 5],
                              ),
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  getTitlesWidget: (val, _) {
                                    final idx = val.toInt();
                                    if (idx < 0 || idx >= points.length) {
                                      return const SizedBox();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        points[idx].label,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 9,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            minX: 0,
                            maxX: (points.length - 1).toDouble(),
                            minY: 0,
                            maxY: maxVal * 1.15,
                            lineBarsData: [
                              LineChartBarData(
                                spots: incomeSpots,
                                isCurved: true,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF609F8A),
                                    Color(0xFF609F8A),
                                  ],
                                ),
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(
                                        0xFF609F8A,
                                      ).withValues(alpha: 0.24),
                                      const Color(
                                        0xFF609F8A,
                                      ).withValues(alpha: 0.0),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                              LineChartBarData(
                                spots: expenseSpots,
                                isCurved: true,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF453A),
                                    Color(0xFFE11D48),
                                  ],
                                ),
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(
                                        0xFFFF453A,
                                      ).withValues(alpha: 0.24),
                                      const Color(
                                        0xFFFF453A,
                                      ).withValues(alpha: 0.0),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 20),
          StaggeredFadeSlide(
            index: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF609F8A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Income',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 24),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF453A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Expense',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
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

class _InsightsTab extends StatelessWidget {
  final ThemeData theme;
  final WidgetRef ref;
  const _InsightsTab({required this.theme, required this.ref});

  IconData _getInsightIcon(String iconName) {
    switch (iconName) {
      case 'trending_up':
        return PesaFlowIcons.income;
      case 'trending_down':
        return PesaFlowIcons.expense;
      case 'savings':
        return PesaFlowIcons.savings;
      case 'arrow_upward':
        return Icons.arrow_upward_rounded;
      case 'arrow_downward':
        return Icons.arrow_downward_rounded;
      case 'account_balance_wallet':
        return PesaFlowIcons.wallet;
      case 'category':
        return Icons.category_rounded;
      default:
        return Icons.lightbulb_rounded;
    }
  }

  Color _getSeverityColor(InsightSeverity severity) {
    switch (severity) {
      case InsightSeverity.positive:
        return AppTheme.incomeColor;
      case InsightSeverity.warning:
        return Colors.orange;
      case InsightSeverity.critical:
        return AppTheme.expenseColor;
      case InsightSeverity.neutral:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final insightsAsync = ref.watch(insightsProvider);
    return insightsAsync.when(
      data: (insights) {
        if (insights.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 48,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No insights yet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Insights will appear after you have transactions recorded.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: insights.length,
          itemBuilder: (context, index) {
            final insight = insights[index];
            final color = _getSeverityColor(insight.severity);

            return StaggeredFadeSlide(
              index: index,
              child: GlassCard(
                margin: const EdgeInsets.only(bottom: 14),
                frosted: true,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left colored accent border strip with glowing shadow
                      Container(
                        width: 5,
                        decoration: BoxDecoration(
                          color: color,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      // Content Row
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getInsightIcon(insight.icon),
                                  color: color,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      insight.title,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: -0.2,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      insight.message,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withValues(alpha: 0.85),
                                            height: 1.4,
                                            fontSize: 12,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
