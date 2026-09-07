import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';

enum ToastType { success, error, info }

class CustomToast {
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        type: type,
        onDismiss: () {
          overlayEntry.remove();
        },
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    );

    overlayState.insert(overlayEntry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
    required this.duration,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _timerController;
  Timer? _timer;
  bool _initialized = false;
  double _swipeOffset = 0.0;
  bool _isSwiping = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: MotionTokens.durationSheet,
    );

    // Timer progress ring
    _timerController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _timer = Timer(widget.duration, () {
      _dismiss();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    if (context.isReducedMotion) {
      _entryController.value = 1.0;
      _timerController.forward();
      return;
    }

    // Physics-based spring simulation for premium entry feel
    final spring = SpringSimulation(
      MotionTokens.springBouncy,
      0.0,
      1.0,
      0.0,
    );
    _entryController.animateWith(spring);
    _timerController.forward();
  }

  void _dismiss() {
    if (!mounted) return;
    _timer?.cancel();
    if (context.isReducedMotion) {
      widget.onDismiss();
      return;
    }
    _entryController
        .animateTo(
          0.0,
          duration: MotionTokens.durationExit,
          curve: Curves.easeInCubic,
        )
        .then((_) {
          widget.onDismiss();
        });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    _isSwiping = true;
    setState(() {
      _swipeOffset += details.delta.dx;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isSwiping) return;
    _isSwiping = false;
    final velocity = details.velocity.pixelsPerSecond.dx.abs();
    if (_swipeOffset.abs() > 60 || velocity > 400) {
      // Swipe to dismiss
      _timer?.cancel();
      widget.onDismiss();
    } else {
      // Snap back
      setState(() => _swipeOffset = 0.0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _entryController.dispose();
    _timerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final IconData icon = switch (widget.type) {
      ToastType.success => PesaFlowIcons.success,
      ToastType.error => PesaFlowIcons.error,
      ToastType.info => PesaFlowIcons.info,
    };

    final Color brandColor = switch (widget.type) {
      ToastType.success => context.appColors.incomeColor,
      ToastType.error => context.appColors.expenseColor,
      ToastType.info => theme.colorScheme.primary,
    };

    return Positioned(
      bottom: MediaQuery.paddingOf(context).bottom + kSpacing32,
      left: kSpacing24,
      right: kSpacing24,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: _entryController,
          builder: (context, child) {
            final t = _entryController.value;
            final translateY = (1.0 - t) * 64.0;
            final scale = 0.85 + (0.15 * t);
            final opacity = t.clamp(0.0, 1.0);

            return Transform.translate(
              offset: Offset(_swipeOffset, translateY),
              child: Opacity(
                opacity: (opacity - (_swipeOffset.abs() / 200))
                    .clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: child,
                ),
              ),
            );
          },
          child: GestureDetector(
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    AppTheme.radiusPill,
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kSpacing20,
                        vertical: kSpacing12,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh
                            .withValues(
                              alpha: theme.brightness == Brightness.dark
                                  ? 0.70
                                  : 0.85,
                            ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusPill,
                        ),
                        border: Border.all(
                          color: brandColor.withValues(alpha: 0.15),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: brandColor.withValues(alpha: 0.08),
                            blurRadius: 24,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon with timer ring
                          _TimerRingIcon(
                            icon: icon,
                            brandColor: brandColor,
                            progress: _timerController,
                          ),
                          const SizedBox(width: kSpacing10),
                          Flexible(
                            child: Text(
                              widget.message,
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                          if (widget.actionLabel != null &&
                              widget.onAction != null) ...[
                            const SizedBox(width: kSpacing8),
                            Container(
                              height: 24,
                              width: 1,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.1),
                            ),
                            const SizedBox(width: kSpacing4),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: kSpacing12,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                widget.onAction!();
                                _dismiss();
                              },
                              child: Text(
                                widget.actionLabel!.toUpperCase(),
                                style: context.ts(
                                  12,
                                  fontWeight: FontWeight.bold,
                                  color: brandColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ), // Container
                  ), // BackdropFilter
                ), // ClipRRect
              ), // Material
            ), // Center
          ), // GestureDetector
        ),
      ),
    );
  }
}

/// Icon with a circular timer ring that "empties" as time passes.
class _TimerRingIcon extends StatelessWidget {
  final IconData icon;
  final Color brandColor;
  final Animation<double> progress;

  const _TimerRingIcon({
    required this.icon,
    required this.brandColor,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Timer ring
          AnimatedBuilder(
            animation: progress,
            builder: (context, _) {
              return SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  value: 1.0 - progress.value,
                  strokeWidth: 1.5,
                  backgroundColor: brandColor.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation(
                    brandColor.withValues(alpha: 0.3),
                  ),
                ),
              );
            },
          ),
          // Icon
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: brandColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: brandColor,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }
}
