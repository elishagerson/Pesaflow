import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

/// Flat grouped-list container.
///
/// Intentionally NOT frosted: this wraps per-day/per-item groups inside
/// long scrolling ListViews, where `BackdropFilter` would run per group and
/// blow the frame budget (AGENTS.md: blur reserved for overlays/sheets).
class GlassListContainer extends StatelessWidget {
  final Widget child;

  const GlassListContainer({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: appColors.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: appColors.scaffoldLine,
          width: 0.5,
        ),
      ),
      child: child,
    );
  }
}
