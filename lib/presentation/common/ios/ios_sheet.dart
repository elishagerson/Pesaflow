import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/app_theme.dart';

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
        child: child,
        initialChildSize: initialChildSize,
        maxChildSize: maxChildSize,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      maxChildSize: maxChildSize,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xF01C1C1E) : const Color(0xF0F2F2F7),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[600] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: RawScrollbar(
                  controller: scrollController,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
