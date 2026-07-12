import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// A bottom sheet route with physics-based spring animation.
///
/// Replaces the default linear slide with a spring-driven scale + slide
/// for a premium feel. Call [showSpringSheet] instead of `showModalBottomSheet`.
Future<T?> showSpringSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext) builder,
  Color? backgroundColor,
  bool useSafeArea = true,
  bool isScrollControlled = false,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: Duration.zero,
    pageBuilder: (ctx, anim, secAnim) => _SpringSheetContent(
      builder: builder(ctx),
      backgroundColor: backgroundColor,
      useSafeArea: useSafeArea,
      isScrollControlled: isScrollControlled,
    ),
  );
}

class _SpringSheetContent extends StatefulWidget {
  final Widget builder;
  final Color? backgroundColor;
  final bool useSafeArea;
  final bool isScrollControlled;

  const _SpringSheetContent({
    required this.builder,
    this.backgroundColor,
    this.useSafeArea = true,
    this.isScrollControlled = false,
  });

  @override
  State<_SpringSheetContent> createState() => _SpringSheetContentState();
}

class _SpringSheetContentState extends State<_SpringSheetContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    final spring = SpringSimulation(
      SpringDescription(mass: 0.8, stiffness: 300, damping: 18),
      0,
      1,
      0,
    );
    _animation = _controller.drive(Tween<double>(begin: 0, end: 1));

    _controller.animateWith(spring);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = widget.backgroundColor ?? theme.colorScheme.surface;
    final bottomInset = widget.useSafeArea ? MediaQuery.of(context).viewInsets.bottom : 0.0;

    return AnimatedBuilder(
      animation: _animation,
      builder: (_, child) {
        final t = _animation.value;
        final scale = 1.0 - (0.08 * (1 - t));
        final translateY = (1 - t) * 60;
        final opacity = 0.5 + (0.5 * t);

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: widget.isScrollControlled
                  ? MediaQuery.of(context).size.height * 0.9
                  : MediaQuery.of(context).size.height * 0.5,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: widget.builder,
            ),
          ),
        ),
      ),
    );
  }
}
