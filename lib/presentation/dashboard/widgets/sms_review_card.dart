import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/theme/app_colors_theme.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

class ActiveParserBadge extends StatelessWidget {
  final String label;

  const ActiveParserBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpacing8,
        vertical: kSpacing4,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PesaFlowIcons.success,
            size: 10,
            color: context.appColors.incomeColor,
          ),
          const SizedBox(width: kSpacing4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class SmsReviewCard extends StatelessWidget {
  final int pendingReviewCount;

  const SmsReviewCard({super.key, required this.pendingReviewCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColorsTheme>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(kSpacing16),
      decoration: BoxDecoration(
        color: appColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    PesaFlowIcons.message,
                    size: 14,
                    color: context.appColors.incomeColor,
                  ),
                  const SizedBox(width: kSpacing6),
                  Text(
                    'SMS AUTO-TRACKING',
                    style: context.ts(
                      10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacing8,
                  vertical: kSpacing4,
                ),
                decoration: BoxDecoration(
                  color: pendingReviewCount > 0
                      ? context.appColors.transferColor.withValues(alpha: 0.12)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  pendingReviewCount > 0
                      ? '$pendingReviewCount PENDING'
                      : '0 PENDING',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: pendingReviewCount > 0
                        ? context.appColors.transferColor
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing10),
          Text(
            'Review parsed mobile money & bank transactions from your SMS.',
            style: context.ts(
              11,
              height: 1.3,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: kSpacing14),
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          ),
          const SizedBox(height: kSpacing10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    const ActiveParserBadge(label: 'M-Pesa'),
                    const ActiveParserBadge(label: 'Tigo'),
                    const ActiveParserBadge(label: 'Airtel'),
                    const ActiveParserBadge(label: 'Selcom'),
                  ],
                ),
              ),
              const SizedBox(width: kSpacing8),
              TactileSpringContainer(
                onTap: () => context.push('/sms-review'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpacing12,
                    vertical: kSpacing6,
                  ),
                  decoration: BoxDecoration(
                    color: appColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Let's go",
                        style: context.ts(
                          11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: kSpacing2),
                      Icon(
                        PesaFlowIcons.chevronRight,
                        size: 12,
                        color: theme.colorScheme.onSurface,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
