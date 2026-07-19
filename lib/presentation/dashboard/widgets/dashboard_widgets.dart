import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';

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
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kSpacing16),
        child: Row(
          children: [
            _SummaryNavCard(
              icon: PesaFlowIcons.budgets,
              metric: budgets.isNotEmpty
                  ? '${budgets.length} budgets'
                  : 'No budgets',
              label: '${(overallPct * 100).toStringAsFixed(0)}% spent',
              color: trackerColor,
              onTap: () => context.go('/budgets'),
            ),
            if (savingsGoals.isNotEmpty)
              _SummaryNavCard(
                icon: PesaFlowIcons.target,
                metric:
                    '${savingsGoals.length} goal${savingsGoals.length == 1 ? '' : 's'}',
                label: 'Emergency vault',
                color: context.appColors.incomeColor,
                onTap: () => context.go('/savings-goals'),
              ),
            _SummaryNavCard(
              icon: PesaFlowIcons.calendar,
              metric: dueCount > 0
                  ? '$dueCount due'
                  : '$activeRecurringCount active',
              label: 'Recurring',
              color: context.appColors.transferColor,
              onTap: () => context.go('/recurring'),
            ),
            _SummaryNavCard(
              icon: PesaFlowIcons.creditScore,
              metric: 'Loans',
              label: 'Debt overview',
              color: context.appColors.transferColor,
              onTap: () => context.go('/loans'),
            ),
            if (pendingReviewCount > 0)
              _SummaryNavCard(
                icon: PesaFlowIcons.message,
                metric: '$pendingReviewCount pending',
                label: 'SMS review',
                color: theme.colorScheme.primary,
                onTap: () => context.go('/sms-review'),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryNavCard extends StatelessWidget {
  final IconData icon;
  final String metric;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SummaryNavCard({
    required this.icon,
    required this.metric,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: kSpacing12),
      child: TactileSpringContainer(
        onTap: onTap,
        child: Container(
          width: 130,
          height: 96,
          padding: const EdgeInsets.all(kSpacing12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.10),
                theme.colorScheme.surfaceContainerHigh,
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(
              color: color.withValues(alpha: 0.18),
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                padding: const EdgeInsets.all(kSpacing6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    metric,
                    style: context.ts(
                      12,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: kSpacing2),
                  Text(
                    label,
                    style: context.ts(
                      10,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
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
