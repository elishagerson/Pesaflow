import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';

class ActiveParserBadge extends StatelessWidget {
  final ThemeData theme;
  final bool isDark;
  final String label;

  const ActiveParserBadge({
    super.key,
    required this.theme,
    required this.isDark,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpacing8,
        vertical: kSpacing4,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x0AFFFFFF) : const Color(0x0A000000),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? const Color(0x10FFFFFF) : const Color(0x10000000),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PesaFlowIcons.success, size: 10, color: const Color(0xFF609F8A)),
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
  final ThemeData theme;
  final bool isDark;
  final int pendingReviewCount;

  const SmsReviewCard({
    super.key,
    required this.theme,
    required this.isDark,
    required this.pendingReviewCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(kSpacing16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceHighDark : AppTheme.bgLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: isDark ? const Color(0x12FFFFFF) : const Color(0x0F000000),
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
                    Icons.message_rounded,
                    size: 14,
                    color: const Color(0xFF609F8A),
                  ),
                  const SizedBox(width: kSpacing6),
                  Text(
                    'SMS AUTO-TRACKING',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
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
                      ? const Color(0xFFFF9F0A).withValues(alpha: 0.12)
                      : (isDark ? Colors.white10 : Colors.black12),
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
                        ? const Color(0xFFFF9F0A)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing10),
          Text(
            'Review parsed mobile money & bank transactions from your SMS.',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 11,
              height: 1.3,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: kSpacing14),
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: isDark ? const Color(0x12FFFFFF) : const Color(0x0F000000),
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
                    ActiveParserBadge(theme: theme, isDark: isDark, label: 'M-Pesa'),
                    ActiveParserBadge(theme: theme, isDark: isDark, label: 'Tigo'),
                    ActiveParserBadge(theme: theme, isDark: isDark, label: 'Airtel'),
                    ActiveParserBadge(theme: theme, isDark: isDark, label: 'Selcom'),
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
                    color: isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Let's go",
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: kSpacing2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 12,
                        color: isDark ? Colors.white : Colors.black,
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
