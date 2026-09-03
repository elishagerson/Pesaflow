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
import 'package:pesaflow/presentation/common/widgets/premium_fab.dart';
import 'package:pesaflow/presentation/common/widgets/glass_list_container.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/floating_top_bar.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/empty_state.dart';
import 'package:pesaflow/core/utils/app_illustrations.dart';
import 'package:pesaflow/presentation/common/widgets/motion/skeleton_crossfade.dart';

class SavingsGoalListScreen extends ConsumerWidget {
  const SavingsGoalListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final savingsGoalsAsync = ref.watch(savingsGoalsStreamProvider);
    final totalSaved = ref.watch(savingsGoalsTotalSavedProvider);

    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            const FloatingTopBar(title: 'Savings Goals'),
            Expanded(
              child: SkeletonCrossfade(
                isLoading:
                    savingsGoalsAsync is AsyncLoading &&
                    !savingsGoalsAsync.hasValue,
                skeleton: const Padding(
                  padding: EdgeInsets.all(kSpacing16),
                  child: Column(
                    children: [
                      SkeletonCard(height: 130),
                      SizedBox(height: kSpacing12),
                      SkeletonCard(height: 130),
                      SizedBox(height: kSpacing12),
                      SkeletonCard(height: 130),
                      SizedBox(height: kSpacing12),
                      SkeletonCard(height: 130),
                    ],
                  ),
                ),
                child: savingsGoalsAsync.when(
                  data: (goals) {
                    if (goals.isEmpty) {
                      return _buildEmptyState(context, theme);
                    }

                    int totalTarget = 0;
                    for (final goal in goals) {
                      totalTarget += goal.targetAmount;
                    }
                    final overallPct = totalTarget > 0
                        ? (totalSaved / totalTarget).clamp(0.0, 1.0)
                        : 0.0;

                    return RefreshIndicator(
                      color: theme.colorScheme.primary,
                      backgroundColor: theme.colorScheme.surfaceContainerHigh,
                      onRefresh: () async {
                        ref.invalidate(savingsGoalsStreamProvider);
                        ref.invalidate(savingsGoalsTotalSavedProvider);
                      },
                      child: SingleChildScrollView(
                        key: const PageStorageKey('savings_goal_list'),
                        padding: const EdgeInsets.all(kSpacing16),
                        child: Column(
                          children: [
                            _buildSummaryCard(
                              context,
                              theme,
                              totalSaved,
                              totalTarget,
                              overallPct,
                            ),
                            const SizedBox(height: kSpacing20),
                            Text(
                              'ACTIVE GOALS',
                              style: context.ts(
                                13,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: kSpacing12),
                            GlassListContainer(
                              child: Column(
                                children: goals
                                    .asMap()
                                    .entries
                                    .map(
                                      (entry) => _buildGoalCard(
                                        context,
                                        ref,
                                        entry.value,
                                        theme,
                                        entry.key,
                                        goals.length,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (err, _) =>
                      Center(child: Text('Error loading savings goals: $err')),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: PremiumExtendedFab(
        onPressed: () => context.push('/savings-goals/add'),
        label: 'New Goal',
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return EmptyState(
      icon: PesaFlowIcons.savings,
      title: 'No Savings Goals Yet',
      subtitle:
          'Set a savings target and track your progress.\nEvery journey starts with a goal.',
      illustration: PesaFlowIllustration.emptyGoals(),
      action: TactileSpringContainer(
        onTap: () => context.push('/savings-goals/add'),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpacing28,
            vertical: kSpacing14,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          child: Text(
            'Set Your First Goal',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    ThemeData theme,
    int totalSaved,
    int totalTarget,
    double overallPct,
  ) {
    final onSurface = theme.colorScheme.onSurface;
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
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PesaFlowIcons.income,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: kSpacing12),
              Text(
                'TOTAL SAVED',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: onSurface.withValues(alpha: 0.6),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing16),
          Text(
            CurrencyFormatter.formatCents(totalSaved),
            style: context.ts(28, color: onSurface),
          ),
          const SizedBox(height: kSpacing4),
          Text(
            'Combined target: ${CurrencyFormatter.formatCents(totalTarget)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: kSpacing12),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            tween: Tween<double>(begin: 0, end: overallPct),
            builder: (context, value, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.12,
                  ),
                  color: theme.colorScheme.primary,
                  minHeight: 8,
                ),
              );
            },
          ),
          const SizedBox(height: kSpacing6),
          Text(
            '${(overallPct * 100).round()}% of combined target achieved',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(
    BuildContext context,
    WidgetRef ref,
    dynamic goal,
    ThemeData theme,
    int index,
    int totalCount,
  ) {
    final goalColor = hexToColor(goal.color);
    final mutedGoalColor = desaturateColor(goalColor);
    final goalPct = goal.targetAmount > 0
        ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final diff = goal.targetDate.difference(DateTime.now()).inDays;
    final daysLeft = diff < 0 ? 0 : diff;

    return TactileSpringContainer(
      onTap: () => context.push('/savings-goals/${goal.id}'),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 12, bottom: 12),
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: mutedGoalColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 12,
                      right: kSpacing16,
                      top: kSpacing20,
                      bottom: kSpacing20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Semantics(
                              label:
                                  'Savings goal progress: ${(goalPct * 100).round()}% completed.',
                              excludeSemantics: true,
                              child: SizedBox(
                                height: 48,
                                width: 48,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    PieChart(
                                      PieChartData(
                                        startDegreeOffset: -90,
                                        sectionsSpace: 0,
                                        centerSpaceRadius: 16,
                                        sections: [
                                          PieChartSectionData(
                                            value: goalPct * 100,
                                            color: mutedGoalColor,
                                            radius: 4,
                                            showTitle: false,
                                          ),
                                          PieChartSectionData(
                                            value: (1.0 - goalPct) * 100,
                                            color: mutedGoalColor.withValues(
                                              alpha: 0.12,
                                            ),
                                            radius: 4,
                                            showTitle: false,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      getGoalIcon(goal.icon),
                                      color: goalColor,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: kSpacing14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    goal.name,
                                    style: theme.textTheme.titleSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: kSpacing2),
                                  Text(
                                    'by ${goal.targetDate.day}/${goal.targetDate.month}/${goal.targetDate.year}',
                                    style: context.appTypography.labelMicro
                                        .copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
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
                                      horizontal: kSpacing8,
                                      vertical: kSpacing4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusInput,
                                      ),
                                    ),
                                    child: Text(
                                      'COMPLETED',
                                      style: context.ts(
                                        9,
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    '$daysLeft days remaining',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                const SizedBox(height: kSpacing4),
                                GestureDetector(
                                  onTap: () => context.push(
                                    '/savings-goals/${goal.id}/edit',
                                  ),
                                  child: Text(
                                    'Edit',
                                    style: theme.textTheme.labelSmall?.copyWith(
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
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              'Target: ${CurrencyFormatter.formatCents(goal.targetAmount)}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: kSpacing8),
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          tween: Tween<double>(begin: 0, end: goalPct),
                          builder: (context, value, child) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: value,
                                backgroundColor: goalColor.withValues(
                                  alpha: 0.12,
                                ),
                                color: goalColor,
                                minHeight: 6,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: kSpacing4),
                        Text(
                          '${(goalPct * 100).round()}% completed',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (index < totalCount - 1)
            Divider(
              height: 1,
              thickness: 0.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              indent: 4 + 16,
            ),
        ],
      ),
    );
  }
}
