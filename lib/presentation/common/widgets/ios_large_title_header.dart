import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

class IosLargeTitleHeader extends StatelessWidget {
  final String title;
  final ScrollController scrollController;
  final List<Widget>? actions;

  const IosLargeTitleHeader({
    super.key,
    required this.title,
    required this.scrollController,
    this.actions,
  });

  static const double _collapseThreshold = 60;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = context.isReducedMotion;

    return AnimatedBuilder(
      animation: scrollController,
      builder: (context, child) {
        final offset = scrollController.hasClients
            ? scrollController.offset.clamp(0.0, _collapseThreshold + 10)
            : 0.0;
        final t = (offset / _collapseThreshold).clamp(0.0, 1.0);
        final effectiveT = reducedMotion ? (t > 0.5 ? 1.0 : 0.0) : t;

        return _LargeTitleHeaderRender(
          title: title,
          actions: actions,
          t: effectiveT,
        );
      },
    );
  }
}

class _LargeTitleHeaderRender extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final double t;

  const _LargeTitleHeaderRender({
    required this.title,
    this.actions,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final currentHeight = ui.lerpDouble(90, 56, t)!;
    final fontSize = ui.lerpDouble(28, 17, t)!;
    final largeOpacity = 1.0 - t;
    final smallOpacity = t;

    return SizedBox(
      height: currentHeight,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Opacity(
                        opacity: smallOpacity,
                        child: Text(
                          title,
                          style: context.ts(17, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  // ignore: use_null_aware_elements
                  if (actions != null) ...actions!,
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            bottom: 0,
            right: actions != null ? 0 : 20,
            child: SizedBox(
              height: 34,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Opacity(
                  opacity: largeOpacity,
                  child: Text(
                    title,
                    style: context.ts(
                      fontSize,
                      fontWeight:
                          t < 0.3 ? FontWeight.w700 : FontWeight.w600,
                      letterSpacing: -0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
