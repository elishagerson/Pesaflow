import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/spacing.dart';

/// A bottom sheet route with physics-based spring animation and drag-to-dismiss.
///
/// Features:
/// - Native [PopupRoute] with smooth 320ms cubic entrance and crisp 220ms cubic exit
/// - Automatic exit transition on programmatic pop, barrier tap, and back button
/// - Drag-to-dismiss with velocity-based fling decision
/// - Physical spring snap-back via [SpringSimulation]
/// - Reduced motion support
///
/// Call [showSpringSheet] instead of `showModalBottomSheet`.
Future<T?> showSpringSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext) builder,
  Color? backgroundColor,
  bool useSafeArea = true,
  bool isScrollControlled = false,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    SpringSheetRoute<T>(
      builder: builder,
      backgroundColor: backgroundColor,
      useSafeArea: useSafeArea,
      isScrollControlled: isScrollControlled,
    ),
  );
}

class SpringSheetRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;
  final Color? backgroundColor;
  final bool useSafeArea;
  final bool isScrollControlled;

  SpringSheetRoute({
    required this.builder,
    this.backgroundColor,
    this.useSafeArea = true,
    this.isScrollControlled = false,
    super.settings,
  });

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: 0.45);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _SpringSheetHost(
      builder: builder(context),
      backgroundColor: backgroundColor,
      useSafeArea: useSafeArea,
      isScrollControlled: isScrollControlled,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (context.isReducedMotion) {
      return FadeTransition(opacity: animation, child: child);
    }
    return _SpringSheetAnimatedTransition(animation: animation, child: child);
  }
}

class _SpringSheetAnimatedTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _SpringSheetAnimatedTransition({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final isReverse = animation.status == AnimationStatus.reverse;
        final t = isReverse
            ? Curves.easeInCubic.transform(animation.value)
            : Curves.easeOutCubic.transform(animation.value);

        // Slide up smoothly from completely off-screen at bottom, slide down on exit
        final scale = 0.98 + (0.02 * t);
        final opacity = isReverse
            ? t.clamp(0.0, 1.0)
            : (t * 2.5).clamp(0.0, 1.0);

        return FractionalTranslation(
          translation: Offset(0, (1.0 - t).clamp(0.0, 1.0)),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.bottomCenter,
            child: Opacity(opacity: opacity, child: child),
          ),
        );
      },
      child: child,
    );
  }
}

class _SpringSheetHost extends StatefulWidget {
  final Widget builder;
  final Color? backgroundColor;
  final bool useSafeArea;
  final bool isScrollControlled;

  const _SpringSheetHost({
    required this.builder,
    this.backgroundColor,
    this.useSafeArea = true,
    this.isScrollControlled = false,
  });

  @override
  State<_SpringSheetHost> createState() => _SpringSheetHostState();
}

class _SpringSheetHostState extends State<_SpringSheetHost>
    with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  double _dragOffset = 0.0;
  double _sheetHeight = 0.0;
  late final AnimationController _snapController;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(vsync: this)
      ..addListener(() {
        if (_snapController.isAnimating) {
          setState(() => _dragOffset = _snapController.value);
        }
      });
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    _isDragging = true;
    _snapController.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, _sheetHeight);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;
    final velocity = details.velocity.pixelsPerSecond.dy;
    final fraction = _sheetHeight > 0 ? _dragOffset / _sheetHeight : 0.0;

    // Fast upward flick -> snap back to open
    if (velocity < MotionTokens.sheetSnapUpVelocity) {
      _snapBack();
      return;
    }

    // Fast downward fling -> dismiss
    if (velocity > MotionTokens.sheetDismissVelocity ||
        fraction > MotionTokens.sheetDismissFraction) {
      Navigator.of(context).pop();
      return;
    }

    _snapBack();
  }

  void _snapBack() {
    if (context.isReducedMotion) {
      setState(() => _dragOffset = 0.0);
      return;
    }
    // Physical spring settle-back — same spring preset as TactileSpringContainer
    // for a consistent tactile feel across drag and tap interactions.
    _snapController.value = _dragOffset;
    _snapController.animateWith(
      SpringSimulation(MotionTokens.springSnappy, _dragOffset, 0.0, 0.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = widget.backgroundColor ?? theme.colorScheme.surface;
    final bottomInset = widget.useSafeArea
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;

    return PopScope(
      canPop: true,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxH = widget.isScrollControlled
                ? MediaQuery.sizeOf(context).height * 0.92
                : MediaQuery.sizeOf(context).height * 0.55;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: _onDragStart,
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              child: Transform.translate(
                offset: Offset(0, _dragOffset),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppTheme.radiusDialog),
                    topRight: Radius.circular(AppTheme.radiusDialog),
                  ),
                  child: Material(
                    color: bgColor,
                    elevation: 16,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppTheme.radiusDialog),
                      topRight: Radius.circular(AppTheme.radiusDialog),
                    ),
                    child: Container(
                      width: double.infinity,
                      constraints: BoxConstraints(maxHeight: maxH),
                      child: _MeasureSize(
                        onSizeChanged: (size) {
                          _sheetHeight = size.height;
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Tactile handle bar
                            _HandleBar(dragOffset: _dragOffset),
                            // Sheet content
                            Flexible(
                              child: Padding(
                                padding: EdgeInsets.only(bottom: bottomInset),
                                child: widget.builder,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Thin rounded handle bar at the top of the sheet.
class _HandleBar extends StatelessWidget {
  final double dragOffset;

  const _HandleBar({required this.dragOffset});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Opacity increases as user drags — visual cue that dismiss is possible
    final dragOpacity = (dragOffset / 100).clamp(0.0, 0.3);

    return Padding(
      padding: const EdgeInsets.only(top: kSpacing8, bottom: kSpacing4),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(
              alpha: 0.25 + dragOpacity,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// Reports its child's size after layout via a callback.
class _MeasureSize extends StatefulWidget {
  final ValueChanged<Size> onSizeChanged;
  final Widget child;

  const _MeasureSize({required this.onSizeChanged, required this.child});

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  final _key = GlobalKey();
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final newSize = box.size;
    if (newSize != _lastSize) {
      _lastSize = newSize;
      widget.onSizeChanged(newSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    return SizedBox(key: _key, child: widget.child);
  }
}
