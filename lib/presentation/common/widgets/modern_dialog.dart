import 'package:flutter/material.dart';
import 'package:pesaflow/presentation/common/widgets/liquid_glass.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

class ModernDialog extends StatelessWidget {
  final Widget title;
  final Widget content;
  final List<Widget>? actions;
  final IconData? titleIcon;
  final Color? iconColor;

  const ModernDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.titleIcon,
    this.iconColor,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget title,
    required Widget content,
    List<Widget>? actions,
    IconData? titleIcon,
    Color? iconColor,
    bool barrierDismissible = true,
  }) {
    final reduced = context.isReducedMotion;
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: reduced
          ? const Duration(milliseconds: 100)
          : const Duration(milliseconds: 320),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final dialog = ModernDialog(
          title: title,
          content: content,
          actions: actions,
          titleIcon: titleIcon,
          iconColor: iconColor,
        );
        if (reduced) {
          return FadeTransition(
            opacity: anim1,
            child: dialog,
          );
        }
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curve,
          child: FadeTransition(
            opacity: anim1,
            child: dialog,
          ),
        );
      },
    );
  }

  static Future<T?> showCustom<T>({
    required BuildContext context,
    required Widget child,
    bool barrierDismissible = true,
  }) {
    final reduced = context.isReducedMotion;
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: reduced
          ? const Duration(milliseconds: 100)
          : const Duration(milliseconds: 320),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, childWidget) {
        if (reduced) {
          return FadeTransition(opacity: anim1, child: child);
        }
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curve,
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: kSpacing24,
        vertical: kSpacing24,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.0),
        child: LiquidGlassOverlay(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(28.0),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.11),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 16.0),
                  child: Row(
                    children: [
                      if (titleIcon != null) ...[
                        Container(
                          padding: const EdgeInsets.all(kSpacing10),
                          decoration: BoxDecoration(
                            color: (iconColor ?? theme.colorScheme.primary)
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            titleIcon,
                            color: iconColor ?? theme.colorScheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: kSpacing14),
                      ],
                      Expanded(
                        child: DefaultTextStyle(
                          style:
                              (theme.textTheme.titleLarge ??
                                      theme.textTheme.titleMedium!)
                                  .copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                          child: title,
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: kSpacing24),
                    child: DefaultTextStyle(
                      style:
                          (theme.textTheme.bodyMedium ??
                                  theme.textTheme.bodySmall!)
                              .copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                      child: content,
                    ),
                  ),
                ),
                // Actions
                if (actions != null && actions!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions!.map((act) {
                        return Padding(
                          padding: const EdgeInsets.only(left: kSpacing12),
                          child: act,
                        );
                      }).toList(),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: kSpacing24),
                ],
              ],
            ),
          ), // Container
        ), // LiquidGlassOverlay
      ), // ClipRRect
    );
  }
}
