import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/analytics_dao.dart';
import 'package:pesaflow/domain/analytics/insight_generator.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/budgets/widgets/savings_goal_detail_sheet.dart';
import 'package:pesaflow/presentation/budgets/widgets/savings_goal_form_sheet.dart';
import 'package:flutter/services.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // iOS-style nav header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Analytics',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
              // iOS-style sliding capsule control
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F0F10) : const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: isDark ? const Color(0x10FFFFFF) : Colors.transparent,
                      width: 0.5,
                    ),
                  ),
                  child: TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicatorPadding: const EdgeInsets.all(2),
                    indicator: BoxDecoration(
                      color: isDark ? const Color(0xFF242426) : Colors.white,
                      borderRadius: BorderRadius.circular(7),
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 1,
                                offset: const Offset(0, 1),
                              ),
                            ],
                    ),
                    labelColor: isDark ? Colors.white : Colors.black,
                    unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
                    labelStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
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
                    _OverviewTab(theme: theme, ref: ref, hexToColor: _hexToColor),
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

class _OverviewTab extends StatelessWidget {
  final ThemeData theme;
  final WidgetRef ref;
  final Color Function(String) hexToColor;
  const _OverviewTab({required this.theme, required this.ref, required this.hexToColor});

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
              final savingsRate = income > 0 ? ((net / income) * 100).round() : 0;
              final isDark = theme.brightness == Brightness.dark;
              final incomeColorVal = isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF);
              final expenseColorVal = isDark ? const Color(0xFFFF453A) : const Color(0xFFE11D48);

              return GlassCard(
                padding: const EdgeInsets.all(20),
                frosted: false,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('THIS MONTH', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Income', style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[500], fontSize: 12)),
                      AmountText(amountInCents: income, style: TextStyle(color: incomeColorVal, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.3)),
                    ])),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('Expense', style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[500], fontSize: 12)),
                      AmountText(amountInCents: expense, style: TextStyle(color: expenseColorVal, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.3)),
                    ])),
                  ]),
                  const SizedBox(height: 12),
                  Divider(height: 0.5, thickness: 0.5, color: isDark ? const Color(0x12FFFFFF) : const Color(0x0F000000)),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(net >= 0 ? 'Net Savings' : 'Net Deficit', style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500)),
                    AmountText(amountInCents: net.abs(), type: net >= 0 ? AmountType.income : AmountType.expense, style: TextStyle(color: net >= 0 ? incomeColorVal : expenseColorVal, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: -0.2)),
                  ]),
                  const SizedBox(height: 4),
                  Text('Savings rate: $savingsRate%', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 11)),
                ]),
              );
            },
            loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 20),

          // Savings Goal Bento Box
          ref.watch(savingsGoalsStreamProvider).when(
            data: (goals) {
              final isDark = theme.brightness == Brightness.dark;

              if (goals.isNotEmpty) {
                return SizedBox(
                  height: 125,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: goals.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final goal = goals[index];
                      final goalColor = hexToColor(goal.color);
                      final goalPct = goal.targetAmount > 0 
                          ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
                          : 0.0;
                      final percentInt = (goalPct * 100).round();

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => SavingsGoalDetailSheet(goal: goal),
                          );
                        },
                        child: SizedBox(
                          width: 250,
                          child: GlassCard(
                            padding: const EdgeInsets.all(16),
                            frosted: false,
                            child: Row(
                            children: [
                              SizedBox(
                                height: 56,
                                width: 56,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    PieChart(PieChartData(
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
                                          value: (1.0 - goalPct) * 100,
                                          color: goalColor.withOpacity(0.12),
                                          radius: 4,
                                          showTitle: false,
                                        ),
                                      ],
                                    )),
                                    Icon(
                                      goal.icon == 'savings' 
                                          ? Icons.savings_rounded 
                                          : goal.icon == 'laptop' 
                                              ? Icons.laptop_chromebook_rounded 
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
                                                                  : Icons.savings_rounded,
                                      color: goalColor,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      goal.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                                      style: const TextStyle(color: Colors.grey, fontSize: 10),
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
                        ? Colors.white.withOpacity(0.04) 
                        : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    border: Border.all(
                      color: isDark 
                          ? Colors.white.withOpacity(0.08) 
                          : Colors.black.withOpacity(0.06),
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
                              color: const Color(0xFF30D158).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.savings_rounded, color: Color(0xFF30D158), size: 20),
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
                              builder: (context) => const SavingsGoalFormSheet(),
                            );
                          },
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Set Monthly Savings Goal',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
            loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            error: (_, __) => const SizedBox(),
          ),
          const SizedBox(height: 24),

          // Category Donut
          Text('Top Spending Categories', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          categoriesAsync.when(
            data: (cats) {
              if (cats.isEmpty) return const Center(child: Text('No spending data yet', style: TextStyle(color: Colors.grey)));
              final total = cats.fold<int>(0, (s, c) => s + c.amount);
              final colors = [theme.colorScheme.primary, const Color(0xFFF59E0B), const Color(0xFF3B82F6), const Color(0xFF8B5CF6), const Color(0xFFEF4444)];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 140,
                    width: 140,
                    child: PieChart(PieChartData(
                      sectionsSpace: 2, centerSpaceRadius: 40,
                      sections: List.generate(cats.length, (i) => PieChartSectionData(
                        value: cats[i].amount.toDouble(), color: i < colors.length ? colors[i] : hexToColor(cats[i].categoryColor),
                        radius: 20, showTitle: false,
                      )),
                    )),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(cats.length, (i) {
                        final cat = cats[i];
                        final color = i < colors.length ? colors[i] : hexToColor(cat.categoryColor);
                        final pct = total > 0 ? (cat.amount / total * 100).round() : 0;
                        final double pctFactor = total > 0 ? (cat.amount / total) : 0.0;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
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
                              const SizedBox(height: 6),
                              // Curved progress track
                              ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: Container(
                                  height: 5,
                                  width: double.infinity,
                                  color: Colors.white.withOpacity(0.06),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: pctFactor,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius: BorderRadius.circular(100),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              );
            },
            loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
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

  @override
  Widget build(BuildContext context) {
    final snapshotsAsync = ref.watch(monthlySnapshotsProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Income & Expense Trends', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Curved trend waves over the last 12 months', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          snapshotsAsync.when(
            data: (snapshots) {
              if (snapshots.isEmpty) {
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
              final reversed = snapshots.reversed.toList();
              
              // Build points for Income (Green) and Expense (Red)
              final incomeSpots = List.generate(reversed.length, (i) {
                return FlSpot(i.toDouble(), reversed[i].totalIncome / 100.0);
              });
              final expenseSpots = List.generate(reversed.length, (i) {
                return FlSpot(i.toDouble(), reversed[i].totalExpense / 100.0);
              });

              // Find maximum for clean scaling
              double maxVal = 1000.0;
              for (final s in reversed) {
                final inc = s.totalIncome / 100.0;
                final exp = s.totalExpense / 100.0;
                if (inc > maxVal) maxVal = inc;
                if (exp > maxVal) maxVal = exp;
              }

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x15FFFFFF), width: 0.5),
                ),
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
                                    ? const Color(0xFF1B1B1D).withOpacity(0.95)
                                    : Colors.white.withOpacity(0.95);
                              },
                              tooltipBorderRadius: BorderRadius.circular(12),
                              tooltipBorder: BorderSide(
                                color: theme.brightness == Brightness.dark ? const Color(0x22FFFFFF) : const Color(0x0D000000),
                                width: 1,
                              ),
                              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                                return touchedSpots.map((spot) {
                                  final isIncome = spot.barIndex == 0;
                                  return LineTooltipItem(
                                    '${isIncome ? "Income" : "Expense"}\nTsh ${NumberFormat('#,###').format(spot.y.round() * 100)}',
                                    TextStyle(
                                      color: isIncome
                                          ? const Color(0xFF00E5FF)
                                          : const Color(0xFFFF453A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                            getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                              return spotIndexes.map((spotIndex) {
                                return TouchedSpotIndicatorData(
                                  FlLine(
                                    color: barData.color?.withOpacity(0.3) ?? Colors.grey,
                                    strokeWidth: 2,
                                    dashArray: [4, 4],
                                  ),
                                  FlDotData(
                                    show: true,
                                    getDotPainter: (spot, percent, barData, index) {
                                      return FlDotCirclePainter(
                                        radius: 6,
                                        color: barData.color ?? Colors.grey,
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
                            horizontalInterval: maxVal > 0 ? maxVal / 4 : 1000,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.white.withOpacity(0.04),
                              strokeWidth: 1,
                              dashArray: [5, 5],
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                getTitlesWidget: (val, _) {
                                  final idx = val.toInt();
                                  if (idx < 0 || idx >= reversed.length) return const SizedBox();
                                  final ym = reversed[idx].yearMonth;
                                  final monthNum = ym.substring(5);
                                  final monthLabels = {
                                    '01': 'Jan', '02': 'Feb', '03': 'Mar', '04': 'Apr',
                                    '05': 'May', '06': 'Jun', '07': 'Jul', '08': 'Aug',
                                    '09': 'Sep', '10': 'Oct', '11': 'Nov', '12': 'Dec',
                                  };
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      monthLabels[monthNum] ?? monthNum,
                                      style: TextStyle(color: Colors.grey[500], fontSize: 10),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: (reversed.length - 1).toDouble(),
                          minY: 0,
                          maxY: maxVal * 1.15,
                          lineBarsData: [
                            // Green Income line
                            LineChartBarData(
                              spots: incomeSpots,
                              isCurved: true,
                              color: const Color(0xFF00E5FF),
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF00E5FF).withOpacity(0.12),
                                    const Color(0xFF00E5FF).withOpacity(0.0),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                            // Red Expense line
                            LineChartBarData(
                              spots: expenseSpots,
                              isCurved: true,
                              color: const Color(0xFFFF453A),
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFFF453A).withOpacity(0.12),
                                    const Color(0xFFFF453A).withOpacity(0.0),
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
              );
            },
            loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 20),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF00E5FF), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('Income', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(width: 24),
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFF453A), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('Expense', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
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
      case 'trending_up': return Icons.trending_up_rounded;
      case 'trending_down': return Icons.trending_down_rounded;
      case 'savings': return Icons.savings_rounded;
      case 'arrow_upward': return Icons.arrow_upward_rounded;
      case 'arrow_downward': return Icons.arrow_downward_rounded;
      case 'account_balance_wallet': return Icons.account_balance_wallet_rounded;
      case 'category': return Icons.category_rounded;
      default: return Icons.lightbulb_rounded;
    }
  }

  Color _getSeverityColor(InsightSeverity severity) {
    switch (severity) {
      case InsightSeverity.positive: return AppTheme.incomeColor;
      case InsightSeverity.warning: return Colors.orange;
      case InsightSeverity.critical: return AppTheme.expenseColor;
      case InsightSeverity.neutral: return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final insightsAsync = ref.watch(insightsProvider);
    return insightsAsync.when(
      data: (insights) {
        if (insights.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.lightbulb_outline_rounded, size: 48, color: Colors.grey), SizedBox(height: 16), Text('No insights yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), SizedBox(height: 8), Text('Insights will appear after you have transactions recorded.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))])));
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: insights.length,
          itemBuilder: (context, index) {
            final insight = insights[index];
            final color = _getSeverityColor(insight.severity);
            final gradient = LinearGradient(
              colors: [
                color.withOpacity(0.08),
                color.withOpacity(0.01),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            );

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withOpacity(0.25),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left colored accent border strip
                      Container(
                        width: 5,
                        color: color,
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
                                  color: color.withOpacity(0.12),
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
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      insight.message,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.85),
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
