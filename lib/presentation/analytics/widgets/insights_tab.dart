import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/presentation/common/widgets/empty_state.dart';
import 'package:pesaflow/presentation/common/widgets/error_state.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/domain/analytics/insight_generator.dart';

class InsightsTab extends StatelessWidget {
  final ThemeData theme;
  final WidgetRef ref;
  const InsightsTab({super.key, required this.theme, required this.ref});

  IconData _getInsightIcon(String iconName) {
    switch (iconName) {
      case 'trending_up':
        return PesaFlowIcons.income;
      case 'trending_down':
        return PesaFlowIcons.expense;
      case 'savings':
        return PesaFlowIcons.savings;
      case 'arrow_upward':
        return PesaFlowIcons.arrowUp;
      case 'arrow_downward':
        return PesaFlowIcons.arrowDown;
      case 'account_balance_wallet':
        return PesaFlowIcons.wallet;
      case 'category':
        return PesaFlowIcons.category;
      default:
        return PesaFlowIcons.lightbulb;
    }
  }

  Color _getSeverityColor(BuildContext context, InsightSeverity severity) {
    switch (severity) {
      case InsightSeverity.positive:
        return context.appColors.incomeColor;
      case InsightSeverity.warning:
        return context.appColors.transferColor;
      case InsightSeverity.critical:
        return context.appColors.expenseColor;
      case InsightSeverity.neutral:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final insightsAsync = ref.watch(insightsProvider);
    return insightsAsync.when(
      data: (insights) {
        if (insights.isEmpty) {
          return const EmptyState(
            icon: PesaFlowIcons.lightbulb,
            title: 'No Insights Yet',
            subtitle:
                'Insights will appear after you have transactions recorded.',
          );
        }
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            kSpacing16,
            kSpacing16,
            kSpacing16,
            IosTabBar.navBarHeight + kSpacing32,
          ),
          itemCount: insights.length,
          itemBuilder: (context, index) {
            final insight = insights[index];
            final color = _getSeverityColor(context, insight.severity);

            return StaggeredFadeSlide(
              index: index,
              child: GlassCard(
                margin: const EdgeInsets.only(bottom: kSpacing14),
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
                          padding: const EdgeInsets.all(kSpacing18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(kSpacing10),
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
                              const SizedBox(width: kSpacing14),
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
                                    const SizedBox(height: kSpacing6),
                                    Text(
                                      insight.message,
                                      style: context.ts(
                                        12,
                                        color: theme
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: 0.85),
                                        height: 1.4,
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
      error: (e, _) => ErrorState(
        title: 'Failed to load analytics',
        message: e.toString(),
        onRetry: () {
          ref.invalidate(insightsProvider);
        },
      ),
    );
  }
}
