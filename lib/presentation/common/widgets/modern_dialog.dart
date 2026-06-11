import 'dart:ui';
import 'package:flutter/material.dart';

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
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curve,
          child: FadeTransition(
            opacity: anim1,
            child: ModernDialog(
              title: title,
              content: content,
              actions: actions,
              titleIcon: titleIcon,
              iconColor: iconColor,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xE6161618) : const Color(0xE6FFFFFF),
              borderRadius: BorderRadius.circular(28.0),
              border: Border.all(
                color: isDark ? const Color(0x1AFFFFFF) : const Color(0x1F000000),
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
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (iconColor ?? theme.colorScheme.primary).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            titleIcon,
                            color: iconColor ?? theme.colorScheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: DefaultTextStyle(
                          style: (theme.textTheme.titleLarge ?? theme.textTheme.titleMedium!).copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
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
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: DefaultTextStyle(
                      style: (theme.textTheme.bodyMedium ?? theme.textTheme.bodySmall!).copyWith(
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
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
                          padding: const EdgeInsets.only(left: 12.0),
                          child: act,
                        );
                      }).toList(),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 24.0),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
