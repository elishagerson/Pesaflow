import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/state/insight_provider.dart';
import 'package:pesaflow/presentation/common/widgets/interactive_3d_card.dart';

class InsightCard extends StatelessWidget {
  final InsightData data;

  const InsightCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = data.color;

    return Semantics(
      container: true,
      label: 'Insight: ${data.title}',
      child: Interactive3DCard(
        borderRadius: 16.0,
        shadowColor: color,
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(kSpacing16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
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
                  child: Icon(data.icon, size: 18, color: color),
                ),
                const SizedBox(width: kSpacing8),
                Expanded(
                  child: Text(data.title,
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: kSpacing8),
            Text(data.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );
}
}
