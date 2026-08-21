import 'package:flutter/material.dart';
import 'package:pesaflow/presentation/common/widgets/liquid_glass.dart';

class GlassListContainer extends StatelessWidget {
  final Widget child;

  const GlassListContainer({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: onSurface.withValues(alpha: 0.05),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: LiquidGlassOverlay(
          speedFactor: 1.2,
          accentColor: onSurface.withValues(alpha: 0.8),
          child: child,
        ),
      ),
    );
  }
}
