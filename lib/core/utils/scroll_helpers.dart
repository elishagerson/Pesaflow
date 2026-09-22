import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

/// Extension on [ScrollController] to uniformly handle smooth scroll-to-top
/// requests with route visibility checks and reduced motion support.
extension ScrollToTopExtension on ScrollController {
  void scrollToTop(BuildContext context) {
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    if (!hasClients) return;
    if (offset <= 0) return;
    if (context.isReducedMotion) {
      jumpTo(0);
    } else {
      animateTo(
        0,
        duration: MotionTokens.durationNormal,
        curve: Curves.easeOutCubic,
      );
    }
  }
}
