import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';

class ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kSpacing24),
        child: GlassCard(
          padding: const EdgeInsets.all(kSpacing24),
          borderRadius: AppTheme.radiusCard,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(kSpacing16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PesaFlowIcons.error,
                  size: 40,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: kSpacing20),
              Text(
                title,
                style: context.ts(16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: kSpacing8),
              Text(
                message,
                style: context.ts(15, color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: kSpacing20),
                TactileSpringContainer(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: kSpacing24,
                      vertical: kSpacing12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'Retry',
                      style: context.ts(14, fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimary),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

