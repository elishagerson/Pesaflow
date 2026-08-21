import 'package:flutter/material.dart';

import 'package:pesaflow/presentation/common/widgets/liquid_glass.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';

class GlassTransactionCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  const GlassTransactionCard({
    super.key,
    required this.child,
    required this.onTap,
    this.margin = const EdgeInsets.symmetric(vertical: 6.0),
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Padding(
      padding: margin,
      child: TactileSpringContainer(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: onSurface.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: onSurface.withValues(alpha: 0.05),
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LiquidGlassOverlay(
              speedFactor: 1.2,
              accentColor: onSurface.withValues(alpha: 0.8),
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
