import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
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
          ? MotionTokens.durationFast
          : const Duration(milliseconds: 260),
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
          return FadeTransition(opacity: anim1, child: dialog);
        }
        final isReverse = anim1.status == AnimationStatus.reverse;
        final curve = isReverse ? Curves.easeInCubic : Curves.easeOutCubic;
        final scaleValue = Tween<double>(
          begin: isReverse ? 0.95 : 0.92,
          end: 1.0,
        ).animate(CurvedAnimation(parent: anim1, curve: curve));
        return ScaleTransition(
          scale: scaleValue,
          child: FadeTransition(
            opacity: CurvedAnimation(parent: anim1, curve: curve),
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
          ? MotionTokens.durationFast
          : const Duration(milliseconds: 260),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, _) {
        if (reduced) {
          return FadeTransition(opacity: anim1, child: child);
        }
        final isReverse = anim1.status == AnimationStatus.reverse;
        final curve = isReverse ? Curves.easeInCubic : Curves.easeOutCubic;
        final scaleValue = Tween<double>(
          begin: isReverse ? 0.95 : 0.92,
          end: 1.0,
        ).animate(CurvedAnimation(parent: anim1, curve: curve));
        return ScaleTransition(
          scale: scaleValue,
          child: FadeTransition(
            opacity: CurvedAnimation(parent: anim1, curve: curve),
            child: child,
          ),
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
      child: GlassCard(
        frosted: true,
        borderRadius: 28.0,
        backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.9),
        hasBorder: true,
        elevation: CardElevation.medium,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
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
                        style: context.ts(
                          22,
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
                    style: context.ts(
                      15,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    child: content,
                  ),
                ),
              ),
              // Actions — with staggered appearance
              if (actions != null && actions!.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 24.0),
                  child: _StaggeredActions(actions: actions!),
                ),
              ] else ...[
                const SizedBox(height: kSpacing24),
              ],
            ],
          ),
        ), // Container
      ), // GlassCard
    ); // Dialog
  }
}

/// Staggers action button appearances with 40ms delay each.
class _StaggeredActions extends StatefulWidget {
  final List<Widget> actions;

  const _StaggeredActions({required this.actions});

  @override
  State<_StaggeredActions> createState() => _StaggeredActionsState();
}

class _StaggeredActionsState extends State<_StaggeredActions>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200 + (widget.actions.length * 40)),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      if (context.isReducedMotion) {
        _controller.value = 1.0;
      } else {
        // Delay slightly after dialog entrance completes
        Future.delayed(MotionTokens.durationExit, () {
          if (mounted) _controller.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: List.generate(widget.actions.length, (i) {
            // Each action fades in with 40ms stagger
            final start = (i * 40) / (200 + widget.actions.length * 40);
            final end = start + 0.5;
            final t = Interval(
              start.clamp(0.0, 1.0),
              end.clamp(0.0, 1.0),
              curve: Curves.easeOut,
            ).transform(_controller.value);
            return Padding(
              padding: EdgeInsets.only(left: i > 0 ? kSpacing12 : 0),
              child: Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 4 * (1 - t)),
                  child: widget.actions[i],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
