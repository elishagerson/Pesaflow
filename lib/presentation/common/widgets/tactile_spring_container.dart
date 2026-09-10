import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/presentation/common/widgets/motion/haptic_pattern.dart';
import 'package:pesaflow/presentation/common/widgets/motion/motion_aware.dart';

/// A press-interactive container with physics-based spring scale + opacity dim.
///
/// Provides PocketCal-level tactile feel:
/// - Press-down: quick ease to [scaleFactor] + subtle opacity dim
/// - Release: spring-back to 1.0 (haptic fires on release, confirming action)
/// - Reduced motion: instant state changes, no spring physics
class TactileSpringContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;

  /// Optional haptic type to fire on tap-up (not tap-down).
  /// PocketCal pattern: haptic confirms the action, not the intent.
  final HapticType? haptic;

  /// Optional semantic label for accessibility (VoiceOver / TalkBack).
  final String? semanticLabel;

  /// Whether this widget should be announced as a button by screen readers.
  /// Defaults to `true` when [onTap] is non-null.
  final bool? semanticButton;

  /// Optional background color shown instantly on press-down (Apple-style selection tint).
  /// When non-null, the container gets this background color at [selectedOpacity] opacity on touch.
  final Color? selectedColor;

  /// Opacity of the selection highlight. Defaults to 0.08 (Apple's default).
  final double selectedOpacity;

  const TactileSpringContainer({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = MotionTokens.scalePress,
    this.haptic,
    this.semanticLabel,
    this.semanticButton,
    this.selectedColor,
    this.selectedOpacity = 0.08,
  });

  @override
  State<TactileSpringContainer> createState() => _TactileSpringContainerState();
}

class _TactileSpringContainerState extends State<TactileSpringContainer>
    with SingleTickerProviderStateMixin, MotionAwareMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(_controller);
    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: MotionTokens.opacityPress,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pressDown() {
    if (widget.onTap == null) return;
    setState(() => _isPressed = true);
    tweenAnimate(_controller, 1.0, duration: MotionTokens.durationFast);
  }

  void _springBack() {
    if (widget.onTap == null) return;
    setState(() => _isPressed = false);
    springAnimate(
      _controller,
      MotionTokens.springSnappy,
      _controller.value,
      0.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasButton = widget.semanticButton ?? (widget.onTap != null);
    final core = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _pressDown(),
      onTapUp: (_) {
        if (widget.haptic != null) triggerHaptic(widget.haptic!);
        _springBack();
        widget.onTap?.call();
      },
      onTapCancel: () => _springBack(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                color: _isPressed && widget.selectedColor != null
                    ? widget.selectedColor!.withValues(
                        alpha: widget.selectedOpacity,
                      )
                    : null,
                child: child,
              ),
            ),
          );
        },
        child: widget.child,
      ),
    );

    if (widget.semanticLabel == null && !hasButton) return core;
    return Semantics(
      label: widget.semanticLabel,
      button: hasButton,
      enabled: widget.onTap != null,
      child: core,
    );
  }
}
