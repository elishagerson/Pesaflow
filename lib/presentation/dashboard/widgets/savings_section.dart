import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';
import 'package:fl_chart/fl_chart.dart';

class SavingsSection extends ConsumerWidget {
  const SavingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final savingsGoalsAsync = ref.watch(savingsGoalsStreamProvider);

    return savingsGoalsAsync.when(
      data: (goals) {
        if (goals.isEmpty) return const SizedBox.shrink();

        final goal = goals.first;
        final goalColor = hexToColor(goal.color);
        final mutedGoalColor = desaturateColor(goalColor);
        final pct = goal.targetAmount > 0
            ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
            : 0.0;
        final percentInt = (pct * 100).round();

        return TactileSpringContainer(
          onTap: () {
            HapticFeedback.mediumImpact();
            context.push('/savings-goals/${goal.id}');
          },
          child: GlassCard(
            frosted: false,
            elevation: CardElevation.low,
            padding: const EdgeInsets.all(kSpacing16),
            child: Row(
              children: [
                Semantics(
                  label:
                      'Savings goal progress: ${(pct * 100).round()}% completed.',
                  excludeSemantics: true,
                  child: SizedBox(
                    height: 52,
                    width: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            startDegreeOffset: -90,
                            sectionsSpace: 0,
                            centerSpaceRadius: 18,
                            sections: [
                              PieChartSectionData(
                                value: pct * 100,
                                color: mutedGoalColor,
                                radius: 4,
                                showTitle: false,
                              ),
                              PieChartSectionData(
                                value: (1.0 - pct) * 100,
                                color: mutedGoalColor.withValues(alpha: 0.12),
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
                              : PesaFlowIcons.savings,
                          color: goalColor,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: kSpacing16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: kSpacing4),
                      Text(
                        'Saved ${CurrencyFormatter.formatCents(goal.currentAmount)} of ${CurrencyFormatter.formatCents(goal.targetAmount)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$percentInt%',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: goalColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: kSpacing2),
                    Text(
                      'Completed',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: kSpacing16),
        child: SkeletonCard(height: 100),
      ),
      error: (_, _) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: kSpacing16),
        child: SkeletonCard(height: 100),
      ),
    );
  }
}

class SavingsReminder extends ConsumerWidget {
  const SavingsReminder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final daysSinceLastSaveAsync = ref.watch(daysSinceLastSaveProvider);

    return daysSinceLastSaveAsync.when(
      data: (days) {
        if (days < 0) return const SizedBox.shrink();
        if (days < 5) return const SizedBox.shrink();

        final (icon, message, color) = days >= 14
            ? (
                PesaFlowIcons.warning,
                'It\'s been $days days since you saved — set aside some money today!',
                Colors.orange,
              )
            : days >= 7
            ? (
                PesaFlowIcons.savings,
                'It\'s been $days days since your last deposit — consider saving today.',
                AppTheme.transferColorDark,
              )
            : (
                PesaFlowIcons.success,
                'Last saved $days days ago.',
                AppTheme.transferColorDark,
              );

        return Container(
          padding: const EdgeInsets.all(kSpacing14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(
              color: color.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: kSpacing12),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.7)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.87),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: kSpacing16),
        child: SkeletonCard(height: 80),
      ),
      error: (_, _) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: kSpacing16),
        child: SkeletonCard(height: 80),
      ),
    );
  }
}
