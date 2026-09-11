import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/core/utils/haptics.dart';

/// A 2x2 executive financial hub grid replacing scattered carousels.
class FinancialHubGrid extends StatelessWidget {
  final List<dynamic> budgets;
  final double overallPct;
  final List<dynamic> savingsGoals;
  final int activeRecurringCount;
  final int dueCount;
  final int pendingReviewCount;
  final Color trackerColor;

  const FinancialHubGrid({
    super.key,
    required this.budgets,
    required this.overallPct,
    required this.savingsGoals,
    required this.activeRecurringCount,
    required this.dueCount,
    required this.pendingReviewCount,
    required this.trackerColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final budgetMetric = budgets.isNotEmpty
        ? '${(overallPct * 100).toStringAsFixed(0)}% spent'
        : 'Not set';
    final budgetSub = budgets.isNotEmpty
        ? '${budgets.length} active'
        : 'Set monthly budget';

    final savingsMetric = savingsGoals.isNotEmpty
        ? '${savingsGoals.length} goal${savingsGoals.length == 1 ? '' : 's'}'
        : '0 goals';
    final savingsSub = savingsGoals.isNotEmpty
        ? 'Vault & Targets'
        : 'Start saving';

    final recurringMetric = dueCount > 0
        ? '$dueCount due today'
        : '$activeRecurringCount active';
    final recurringSub = dueCount > 0
        ? 'Payment pending'
        : 'Subscriptions';
    final recurringColor = dueCount > 0
        ? theme.colorScheme.error
        : context.appColors.transferColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kSpacing4),
          child: Text(
            'FINANCIAL OVERVIEW',
            style: context.ts(
              11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: kSpacing12),
        Row(
          children: [
            Expanded(
              child: _HubCard(
                icon: PesaFlowIcons.budgets,
                title: 'Budgets',
                metric: budgetMetric,
                subtitle: budgetSub,
                color: trackerColor,
                progress: budgets.isNotEmpty ? overallPct : null,
                onTap: () => context.go('/budgets'),
              ),
            ),
            const SizedBox(width: kSpacing12),
            Expanded(
              child: _HubCard(
                icon: PesaFlowIcons.target,
                title: 'Savings',
                metric: savingsMetric,
                subtitle: savingsSub,
                color: context.appColors.incomeColor,
                onTap: () => context.go('/savings-goals'),
              ),
            ),
          ],
        ),
        const SizedBox(height: kSpacing12),
        Row(
          children: [
            Expanded(
              child: _HubCard(
                icon: PesaFlowIcons.calendar,
                title: 'Recurring',
                metric: recurringMetric,
                subtitle: recurringSub,
                color: recurringColor,
                badgeCount: dueCount > 0 ? dueCount : null,
                onTap: () => context.go('/recurring'),
              ),
            ),
            const SizedBox(width: kSpacing12),
            Expanded(
              child: _HubCard(
                icon: PesaFlowIcons.creditScore,
                title: 'Loans & Debt',
                metric: 'Liabilities',
                subtitle: 'Track payables',
                color: context.appColors.transferColor,
                onTap: () => context.go('/loans'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String metric;
  final String subtitle;
  final Color color;
  final double? progress;
  final int? badgeCount;
  final VoidCallback onTap;

  const _HubCard({
    required this.icon,
    required this.title,
    required this.metric,
    required this.subtitle,
    required this.color,
    this.progress,
    this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TactileSpringContainer(
      onTap: () {
        PesaHaptics.light();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(kSpacing14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: context.appColors.shadowSubtle,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 16, color: color),
                ),
                if (badgeCount != null && badgeCount! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: context.ts(
                        10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onError,
                      ),
                    ),
                  )
                else
                  Icon(
                    PesaFlowIcons.chevronRight,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
              ],
            ),
            const SizedBox(height: kSpacing12),
            Text(
              metric,
              style: context.ts(
                14,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: kSpacing2),
            Text(
              subtitle,
              style: context.ts(
                11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (progress != null) ...[
              const SizedBox(height: kSpacing8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                child: LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress! > 1.0 ? theme.colorScheme.error : color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Kept for backward compatibility.
class SummaryNavCardRow extends StatelessWidget {
  final List<dynamic> budgets;
  final double overallPct;
  final List<dynamic> savingsGoals;
  final int activeRecurringCount;
  final int dueCount;
  final int pendingReviewCount;
  final Color trackerColor;

  const SummaryNavCardRow({
    super.key,
    required this.budgets,
    required this.overallPct,
    required this.savingsGoals,
    required this.activeRecurringCount,
    required this.dueCount,
    required this.pendingReviewCount,
    required this.trackerColor,
  });

  @override
  Widget build(BuildContext context) {
    return FinancialHubGrid(
      budgets: budgets,
      overallPct: overallPct,
      savingsGoals: savingsGoals,
      activeRecurringCount: activeRecurringCount,
      dueCount: dueCount,
      pendingReviewCount: pendingReviewCount,
      trackerColor: trackerColor,
    );
  }
}

class CollapsibleSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Widget? action;
  final Widget child;

  const CollapsibleSection({
    super.key,
    required this.title,
    required this.icon,
    this.action,
    required this.child,
  });

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: kSpacing8,
                    right: kSpacing8,
                    top: kSpacing6,
                    bottom: kSpacing6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            widget.icon,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: kSpacing8),
                          Text(
                            widget.title,
                            style: context.ts(16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: kSpacing6),
                          AnimatedRotation(
                            turns: _isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              PesaFlowIcons.chevronDown,
                              size: 20,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.action != null) ...[
              const SizedBox(width: kSpacing8),
              widget.action!,
            ],
          ],
        ),
        const SizedBox(height: kSpacing8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kSpacing8),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _isExpanded
                ? widget.child
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ),
      ],
    );
  }
}
