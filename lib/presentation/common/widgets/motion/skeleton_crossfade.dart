import 'package:flutter/material.dart';

/// Crossfades between a skeleton loader and the actual content.
///
/// Use in place of a hard cut between `asyncValue.when(loading: ...)` branches.
class SkeletonCrossfade extends StatelessWidget {
  final bool isLoading;
  final Widget skeleton;
  final Widget child;

  const SkeletonCrossfade({
    required this.isLoading,
    required this.skeleton,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: isLoading ? skeleton : child,
    );
  }
}
