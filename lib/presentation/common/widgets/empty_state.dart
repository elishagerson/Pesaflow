import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final double iconSize;
  final Widget? illustration;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.iconSize = 64,
    this.illustration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final illustration =
        illustration ??
        Semantics(
          excludeSemantics: true,
          child: Icon(
            icon,
            size: iconSize,
            color: theme.colorScheme.primary.withValues(alpha: 0.4),
          ),
        );

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.isCompactView ? kSpacing24 : kSpacing48,
          vertical: kSpacing32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            illustration,
            SizedBox(height: context.isCompactView ? kSpacing16 : kSpacing24),
            Semantics(
              header: true,
              child: Text(
                title,
                style: context.ts(
                  16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: context.isCompactView ? kSpacing8 : kSpacing12),
              Text(
                subtitle!,
                style: context.ts(
                  13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              SizedBox(height: context.isCompactView ? kSpacing20 : kSpacing28),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: context.spacing,
            vertical: kSpacing8,
          ),
      child: Row(
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: context.ts(
                16,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const Spacer(),
          if (actionLabel != null && onAction != null)
            Semantics(
              button: true,
              child: TactileSpringContainer(
                onTap: onAction,
                child: Padding(
                  padding: const EdgeInsets.all(kSpacing8),
                  child: Text(
                    actionLabel!,
                    style: context.ts(
                      13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}