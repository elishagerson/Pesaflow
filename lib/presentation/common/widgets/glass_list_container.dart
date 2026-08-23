import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/liquid_glass.dart';

class GlassListContainer extends StatelessWidget {
  final Widget child;

  const GlassListContainer({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: appColors.scaffoldLine,
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: LiquidGlassOverlay(
          intensity: 0.85,
          child: child,
        ),
      ),
    );
  }
}
