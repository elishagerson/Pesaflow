import 'package:flutter/material.dart';

/// Crossfades between a skeleton loader and the actual content.
///
/// Adds a subtle scale transition (0.99 → 1.0) alongside the fade
/// for a "content materializing" effect instead of a flat crossfade.
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
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        // Skeleton fades out flat; content fades in with subtle scale
        final isContent = child.key != const ValueKey('skeleton');
        if (isContent) {
          final scaleAnimation = Tween<double>(
            begin: 0.99,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ));
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: scaleAnimation, child: child),
          );
        }
        return FadeTransition(opacity: animation, child: child);
      },
      child: isLoading
          ? KeyedSubtree(key: const ValueKey('skeleton'), child: skeleton)
          : KeyedSubtree(key: const ValueKey('content'), child: child),
    );
  }
}
