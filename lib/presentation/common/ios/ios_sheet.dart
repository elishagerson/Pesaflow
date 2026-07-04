import 'package:flutter/material.dart';

import 'package:pesaflow/core/utils/spacing.dart';

class IosBottomSheet extends StatelessWidget {
  final Widget child;
  final double initialChildSize;
  final double maxChildSize;

  const IosBottomSheet({
    super.key,
    required this.child,
    this.initialChildSize = 0.5,
    this.maxChildSize = 0.9,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    double initialChildSize = 0.5,
    double maxChildSize = 0.9,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => IosBottomSheet(
        initialChildSize: initialChildSize,
        maxChildSize: maxChildSize,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      maxChildSize: maxChildSize,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                const SizedBox(height: kSpacing8),
                Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.175),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                const SizedBox(height: kSpacing10),
                Expanded(
                  child: RawScrollbar(
                    controller: scrollController,
                    child: SingleChildScrollView(
                      controller: scrollController,
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: kSpacing20,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
