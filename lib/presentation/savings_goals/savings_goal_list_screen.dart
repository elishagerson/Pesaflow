import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:fl_chart/fl_chart.dart';

class SavingsGoalListScreen extends ConsumerWidget {
  const SavingsGoalListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final savingsGoalsAsync = ref.watch(savingsGoalsStreamProvider);
    final totalSaved = ref.watch(savingsGoalsTotalSavedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Goals'),
        centerTitle: true,
      ),
      body: savingsGoalsAsync.when(
        data: (goals) {
          if (goals.isEmpty) {
            return _buildEmptyState(context, isDark);
          }

          int totalTarget = 0;
          for (final goal in goals) {
            totalTarget += goal.targetAmount;
          }
          final overallPct =
              totalTarget > 0 ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0.0;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(savingsGoalsStreamProvider);
              ref.invalidate(savingsGoalsTotalSavedProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(kSpacing16),
              children: [
                _buildSummaryCard(
                    context, isDark, totalSaved, totalTarget, overallPct),
                const SizedBox(height: kSpacing20),
                Text(
                  'ACTIVE GOALS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.4),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: kSpacing12),
                ...goals.asMap().entries.map((entry) =>
                    _buildGoalCard(context, ref, entry.value, entry.key, isDark, theme)),
              ],
            ),
          );
        },
        loading: () =>
            const Center(child: CupertinoActivityIndicator()),
        error: (err, _) =>
            Center(child: Text('Error loading savings goals: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/savings-goals/add'),
        icon: const Icon(PesaFlowIcons.add, size: 20),
        label: const Text('New Goal'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kSpacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(kSpacing24),
              decoration: BoxDecoration(
                color: AppTheme.transferColorDark.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                PesaFlowIcons.savings,
                size: 48,
                color: AppTheme.transferColorDark,
              ),
            ),
            const SizedBox(height: kSpacing24),
            const Text(
              'No Savings Goals Yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: kSpacing8),
            Text(
              'Set a savings target and track your progress.\nEvery journey starts with a goal.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: kSpacing24),
            TactileSpringContainer(
              onTap: () => context.push('/savings-goals/add'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: kSpacing28, vertical: kSpacing14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.transferColorDark,
                      AppTheme.transferColorDark.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'Set Your First Goal',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      BuildContext context, bool isDark, int totalSaved, int totalTarget, double overallPct) {
    return GlassCard(
      padding: const EdgeInsets.all(kSpacing20),
      borderRadius: AppTheme.radiusCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(kSpacing10),
                decoration: BoxDecoration(
                  color: AppTheme.transferColorDark.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(PesaFlowIcons.income,
                    color: AppTheme.transferColorDark, size: 20),
              ),
              const SizedBox(width: kSpacing12),
              Text(
                'TOTAL SAVED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing16),
          Text(
            CurrencyFormatter.formatCents(totalSaved),
            style: TextStyle(
              fontSize: 28,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: kSpacing4),
          Text(
            'Combined target: ${CurrencyFormatter.formatCents(totalTarget)}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: kSpacing12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: overallPct,
              backgroundColor: AppTheme.transferColorDark.withValues(alpha: 0.12),
              color: AppTheme.transferColorDark,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: kSpacing6),
          Text(
            '${(overallPct * 100).round()}% of combined target achieved',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, WidgetRef ref,
      dynamic goal, int index, bool isDark, ThemeData theme) {
    final goalColor = hexToColor(goal.color);
    final goalPct = goal.targetAmount > 0
        ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final diff = goal.targetDate.difference(DateTime.now()).inDays;
    final daysLeft = diff < 0 ? 0 : diff;

    return StaggeredFadeSlide(
      index: index,
      child: TactileSpringContainer(
        onTap: () => context.push('/savings-goals/${goal.id}'),
        child: Hero(
          tag: 'goal-${goal.id}',
          child: Container(
          margin: const EdgeInsets.only(bottom: kSpacing12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            color: isDark
                ? goalColor.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.65),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: goalColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(kSpacing16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              height: 48,
                              width: 48,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  PieChart(PieChartData(
                                    startDegreeOffset: -90,
                                    sectionsSpace: 0,
                                    centerSpaceRadius: 16,
                                    sections: [
                                      PieChartSectionData(
                                        value: goalPct * 100,
                                        color: goalColor,
                                        radius: 4,
                                        showTitle: false,
                                      ),
                                      PieChartSectionData(
                                        value: (1.0 - goalPct) * 100,
                                        color: goalColor.withValues(alpha: 0.12),
                                        radius: 4,
                                        showTitle: false,
                                      ),
                                    ],
                                  )),
                                  Icon(
                                    getGoalIcon(goal.icon),
                                    color: goalColor,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: kSpacing14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    goal.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: kSpacing2),
                                  Text(
                                    'by ${goal.targetDate.day}/${goal.targetDate.month}/${goal.targetDate.year}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (goal.isCompleted)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: kSpacing8, vertical: kSpacing4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.transferColorDark
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'COMPLETED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.transferColorDark,
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    '$daysLeft days remaining',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                                const SizedBox(height: kSpacing4),
                                GestureDetector(
                                  onTap: () => context.push(
                                      '/savings-goals/${goal.id}/edit'),
                                  child: Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: kSpacing14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              CurrencyFormatter.formatCents(goal.currentAmount),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Target: ${CurrencyFormatter.formatCents(goal.targetAmount)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: kSpacing8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: goalPct,
                            backgroundColor:
                                goalColor.withValues(alpha: 0.12),
                            color: goalColor,
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: kSpacing4),
                        Text(
                          '${(goalPct * 100).round()}% completed',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}

