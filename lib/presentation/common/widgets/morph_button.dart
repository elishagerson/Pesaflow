import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:pesaflow/core/theme/app_shapes.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/motion/haptic_pattern.dart';
import 'package:pesaflow/presentation/common/widgets/motion/motion_aware.dart';

/// The app's primary action.
///
/// Two things separate it from a coloured `ElevatedButton`:
///
///  * **It morphs, it doesn't just shrink.** On press-down the outline travels
///    from a full-width pill to a chamfered squircle; on release it springs
///    back. Scale is *not* used at all here — a scale reads as "the element got
///    smaller", a morph reads as "the element absorbed the press". One gesture,
///    one animation, no layering.
///  * **It carries the brand gradient and a brand-tinted shadow**, so the single
///    loud accent in the app lands on the single most important action.
///
/// Use at most one per screen. If two actions feel equally important, one of
/// them should be a [MorphButtonVariant.outline] instead.
class MorphButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;

  /// Stretch to the available width. Turn off inside a `Row` to size to the
  /// label.
  final bool expand;

  /// Fill treatment.
  final MorphButtonVariant variant;

  /// Semantic label when [child] is not itself descriptive.
  final String? semanticLabel;

  const MorphButton({
    super.key,
    this.onPressed,
    required this.child,
    this.icon,
    this.expand = true,
    this.variant = MorphButtonVariant.solid,
    this.semanticLabel,
  });

  @override
  State<MorphButton> createState() => _MorphButtonState();
}

enum MorphButtonVariant {
  /// Brand gradient fill, brand-tinted shadow. The one per screen.
  solid,

  /// Brand container fill. For a second, weaker affirmative action.
  tonal,

  /// Hairline border, brand text. For a peer action.
  outline,
}

class _MorphButtonState extends State<MorphButton>
    with SingleTickerProviderStateMixin, MotionAwareMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: MotionTokens.durationFast,
      value: 0,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _down() {
    if (widget.onPressed == null) return;
    if (shouldAnimate) {
      _press.animateTo(1, duration: MotionTokens.durationFast);
    } else {
      _press.value = 1;
    }
  }

  void _up() {
    if (widget.onPressed == null) return;
    // Snap back with real spring physics, and floor the start value so a
    // sub-50ms tap still shows the shape breathing back out.
    final start = _press.value < 0.35 ? 0.35 : _press.value;
    _press.value = start;
    if (shouldAnimate) {
      _press.animateWith(
        SpringSimulation(MotionTokens.springSnappy, start, 0, 0),
      );
    } else {
      _press.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = context.appColors;
    final enabled = widget.onPressed != null;

    final Color fg;
    final Color? bg;
    final Gradient? gradient;
    final BorderSide? side;

    switch (widget.variant) {
      case MorphButtonVariant.solid:
        gradient = LinearGradient(
          colors: [appColors.brandGradientFrom, appColors.brandGradientTo],
        );
        bg = null;
        fg = appColors.brandOnColor;
        side = null;
      case MorphButtonVariant.tonal:
        gradient = null;
        bg = appColors.brandContainer;
        fg = appColors.brandOnContainer;
        side = null;
      case MorphButtonVariant.outline:
        gradient = null;
        bg = null;
        fg = enabled ? appColors.brandColor : appColors.textLow;
        side = BorderSide(
          color: enabled ? appColors.hairlineStrong : appColors.hairline,
        );
    }

    return Semantics(
      label: widget.semanticLabel,
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _down(),
        onTapUp: (_) {
          _up();
          triggerHaptic(HapticType.selection);
          widget.onPressed?.call();
        },
        onTapCancel: _up,
        child: AnimatedBuilder(
          animation: _press,
          builder: (context, child) {
            return CustomPaint(
              painter: _MorphButtonPainter(
                t: _press.value,
                radius: AppTheme.radiusButton,
                gradient: gradient,
                background: bg,
                side: side,
                shadowColor:
                    widget.variant == MorphButtonVariant.solid && enabled
                    ? appColors.brandGlow.withValues(
                        alpha: 0.34 * (1 - _press.value * 0.6),
                      )
                    : null,
                enabled: enabled,
              ),
              child: child,
            );
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kSpacing24,
                vertical: kSpacing14,
              ),
              child: Row(
                mainAxisSize: widget.expand
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 18, color: fg),
                    const SizedBox(width: kSpacing10),
                  ],
                  Flexible(
                    child: DefaultTextStyle.merge(
                      style: theme.textTheme.titleMedium!.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                      ),
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MorphButtonPainter extends CustomPainter {
  final double t;
  final double radius;
  final Gradient? gradient;
  final Color? background;
  final BorderSide? side;
  final Color? shadowColor;
  final bool enabled;

  const _MorphButtonPainter({
    required this.t,
    required this.radius,
    required this.gradient,
    required this.background,
    required this.side,
    required this.shadowColor,
    required this.enabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Pressed, the pill contracts its corners into the poster cut. The
    // chamfer grows from nothing so the transition starts as a pure pill and
    // the silhouette change is what the eye reads.
    final cut = math.min(size.height * 0.34, radius * 0.9) * t;
    final path = appShapePath(
      rect: rect,
      radius: radius * (1 - t * 0.14),
      topLeft: t > 0.02 ? AppCorner.chamfer : AppCorner.rounded,
      bottomRight: t > 0.02 ? AppCorner.chamfer : AppCorner.rounded,
      chamfer: cut,
    );

    if (shadowColor != null) {
      canvas.drawShadow(path, shadowColor!, 10 * (1 - t * 0.4), true);
    }

    if (gradient != null) {
      canvas.drawPath(path, Paint()..shader = gradient!.createShader(rect));
    } else if (background != null) {
      canvas.drawPath(path, Paint()..color = background!);
    }
    if (side != null && side!.style != BorderStyle.none) {
      canvas.drawPath(path, side!.toPaint());
    }

    // Press feedback is a dim on the surface only — the label stays at full
    // strength so the text never loses legibility at the exact moment the user
    // is reading it.
    if (t > 0.01 && enabled) {
      canvas.drawPath(
        path,
        Paint()..color = const Color(0xFF000000).withValues(alpha: t * 0.10),
      );
    }
    if (!enabled) {
      canvas.drawPath(
        path,
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.26),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MorphButtonPainter old) =>
      old.t != t ||
      old.radius != radius ||
      old.gradient != gradient ||
      old.background != background ||
      old.side != side ||
      old.shadowColor != shadowColor ||
      old.enabled != enabled;
}
