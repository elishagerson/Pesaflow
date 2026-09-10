import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

/// A bottom sheet route with physics-based spring animation and drag-to-dismiss.
///
/// Features:
/// - Spring-driven scale + slide entrance (not linear)
/// - Drag-to-dismiss with velocity-based decision
/// - Handle bar indicator with animated opacity
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
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
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
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  bool _initialized = false;
  bool _isDragging = false;
  double _dragOffset = 0.0;
  double _sheetHeight = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MotionTokens.durationSheet,
    );
    _animation = _controller.drive(Tween<double>(begin: 0, end: 1));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      if (context.isReducedMotion) {
        _controller.value = 1.0;
      } else {
        final spring = SpringSimulation(MotionTokens.springGentle, 0, 1, 0);
        _controller.animateWith(spring);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    _isDragging = true;
    _dragOffset = 0.0;
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

    // Velocity-based direction detection (takes priority over position)
    if (velocity < MotionTokens.sheetSnapUpVelocity) {
      _snapTo(0.0);
      return;
    }
    if (velocity > MotionTokens.sheetDismissVelocity) {
      _dismiss();
      return;
    }

    // Position-based snap zones (slow drag / low velocity)
    if (fraction > MotionTokens.sheetDismissFraction) {
      _dismiss();
    } else if (fraction > MotionTokens.sheetHalfOpenFractionLower) {
      final peekOffset =
          _sheetHeight * (1.0 - MotionTokens.sheetHalfOpenVisibleFraction);
      _snapTo(peekOffset);
    } else {
      _snapTo(0.0);
    }
  }

  void _snapTo(double targetOffset) {
    if (context.isReducedMotion) {
      setState(() => _dragOffset = targetOffset);
      return;
    }
    final startOffset = _dragOffset;
    final delta = targetOffset - startOffset;
    late final AnimationController snapController;
    snapController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 400),
        )..addListener(() {
          setState(() {
            _dragOffset = startOffset + delta * snapController.value;
          });
        });
    snapController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        snapController.dispose();
      }
    });

    final simulation = SpringSimulation(
      MotionTokens.springSnappy,
      0.0,
      1.0,
      0.0,
    );
    snapController.animateWith(simulation);
  }

  void _dismiss() {
    if (context.isReducedMotion) {
      Navigator.of(context).pop();
      return;
    }
    _controller
        .animateTo(
          0.0,
          duration: MotionTokens.durationExit,
          curve: Curves.easeInCubic,
        )
        .then((_) {
          if (mounted) Navigator.of(context).pop();
        });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = widget.backgroundColor ?? theme.colorScheme.surface;
    final bottomInset = widget.useSafeArea
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;
    final dragFraction = _sheetHeight > 0
        ? (_dragOffset / _sheetHeight).clamp(0.0, 1.0)
        : 0.0;

    return Stack(
      children: [
        // Animated scrim — fades as user drags down
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _dismiss(),
          child: AnimatedBuilder(
            animation: _animation,
            builder: (_, _) {
              final baseAlpha = 0.45 * _animation.value;
              final scrimAlpha = (baseAlpha * (1.0 - dragFraction)).clamp(
                0.0,
                1.0,
              );
              return Container(
                color: Colors.black.withValues(alpha: scrimAlpha),
              );
            },
          ),
        ),
        // Sheet content
        AnimatedBuilder(
          animation: _animation,
          builder: (_, child) {
            final t = _animation.value;
            final scale = 1.0 - (0.08 * (1 - t));
            final translateY = (1 - t) * 60 + _dragOffset;
            final opacity = (0.5 + (0.5 * t)).clamp(0.0, 1.0);

            return Transform.translate(
              offset: Offset(0, translateY),
              child: FadeTransition(
                opacity: AlwaysStoppedAnimation(opacity),
                child: Transform.scale(scale: scale, child: child),
              ),
            );
          },
          child: GestureDetector(
            onVerticalDragStart: _onDragStart,
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxH = widget.isScrollControlled
                      ? MediaQuery.sizeOf(context).height * 0.9
                      : MediaQuery.sizeOf(context).height * 0.5;
                  return ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    child: Material(
                      color: bgColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
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
                              // Handle bar
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
                  );
                },
              ),
            ),
          ),
        ),
      ],
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
      padding: const EdgeInsets.only(top: 8, bottom: 4),
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
