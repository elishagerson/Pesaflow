import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'tactile_spring_container.dart';

import 'package:pesaflow/core/utils/spacing.dart';

class PremiumFab extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? accentColor;

  const PremiumFab({super.key, this.onPressed, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accentColor ?? theme.colorScheme.primary;

    return TactileSpringContainer(
      onTap: onPressed,
      scaleFactor: 0.92,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: color.withValues(alpha: 0.175),
              blurRadius: 32,
              spreadRadius: -4,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Icon(
          PesaFlowIcons.add,
          color: theme.colorScheme.onPrimary,
          size: 28,
        ),
      ),
    );
  }
}

class PremiumExtendedFab extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData icon;
  final Color? accentColor;

  const PremiumExtendedFab({
    super.key,
    this.onPressed,
    required this.label,
    this.icon = PesaFlowIcons.add,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accentColor ?? theme.colorScheme.primary;

    return TactileSpringContainer(
      onTap: onPressed,
      scaleFactor: 0.95,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: kSpacing20,
          vertical: kSpacing12,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: color.withValues(alpha: 0.175),
              blurRadius: 32,
              spreadRadius: -4,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: theme.colorScheme.onPrimary, size: 20),
            const SizedBox(width: kSpacing8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
