import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

/// A page route that uses Hero for smooth list→detail card transitions.
/// The hero tag should be unique per item (e.g., 'budget_budget.id').
///
/// [page] is the destination screen widget.
/// [heroTag] must match the Hero tag on the source card in the list.
/// [barrierColor] controls the scrim behind the route during flight.
class HeroCardRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final String heroTag;

  HeroCardRoute({required this.page, required this.heroTag, super.settings})
    : super(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final isReverse = animation.status == AnimationStatus.reverse;
          final curve = isReverse ? Curves.easeInCubic : Curves.easeOutCubic;
          final curvedAnim = CurvedAnimation(parent: animation, curve: curve);

          return FadeTransition(
            opacity: curvedAnim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(curvedAnim),
              child: child,
            ),
          );
        },
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.45),
      );
}

/// Push a [HeroCardRoute] for smooth card→detail transitions, or a simple
/// fade when the device has reduced motion enabled.
Future<T?> pushHeroCard<T>(BuildContext context, Widget page, String heroTag) {
  if (context.isReducedMotion) {
    return Navigator.of(context).push<T>(
      PageRouteBuilder(
        settings: RouteSettings(name: heroTag),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
        barrierDismissible: true,
        barrierColor: Colors.black45,
      ),
    );
  }
  return Navigator.of(
    context,
  ).push<T>(HeroCardRoute<T>(page: page, heroTag: heroTag));
}
