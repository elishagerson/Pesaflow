import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/domain/analytics/insight_generator.dart';

class InsightCard extends StatelessWidget {
  final Insight insight;

  const InsightCard({super.key, required this.insight});

  IconData _icon() {
    return switch (insight.icon) {
      'trending_up' => Icons.trending_up_rounded,
      'trending_down' => Icons.trending_down_rounded,
      'savings' => Icons.savings_rounded,
      'arrow_upward' => Icons.arrow_upward_rounded,
      'arrow_downward' => Icons.arrow_downward_rounded,
      'account_balance_wallet' => Icons.account_balance_wallet_rounded,
      'category' => Icons.category_rounded,
      _ => Icons.lightbulb_outline_rounded,
    };
  }

  Color _color(ThemeData theme) {
    return switch (insight.severity) {
      InsightSeverity.positive => const Color(0xFF34C759),
      InsightSeverity.neutral => theme.colorScheme.primary,
      InsightSeverity.warning => const Color(0xFFFF9F0A),
      InsightSeverity.critical => const Color(0xFFFF453A),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = _color(theme);

    return Semantics(
      container: true,
      label: 'Insight: ${insight.title}',
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(kSpacing16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(kSpacing6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_icon(), size: 18, color: color),
                ),
                const SizedBox(width: kSpacing8),
                Expanded(
                  child: Text(insight.title,
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: kSpacing8),
            Text(insight.message,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
