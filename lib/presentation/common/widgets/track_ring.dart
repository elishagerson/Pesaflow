import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/motion/motion_aware.dart';

/// A circular progress gauge built on the tilted-ring motif.
///
/// The ring is rotated so the sweep starts at the lower-left and climbs to the
/// top — the same "wheel with a marker" reading as a speedometer or a tyre
/// with a wheel-gun across it, rather than the flat 12-o'clock start of a
/// stock `CircularProgressIndicator`.
///
/// It also carries a **slash**: a chord across the unfilled part of the ring
/// that rotates to point at the current value. That single mark turns an
/// anonymous donut into a gauge you can read at a glance, and it is the one
/// piece of shape language in the app that is unmistakably ours.
///
/// Cost control: a single `SpringSimulation` drives the value. There is no
/// perpetual ticker — the ring paints only while the value is settling.
class TrackRing extends StatefulWidget {
  /// Progress in the range 0..1.
  final double value;

  /// Ring thickness in logical pixels.
  final double thickness;

  /// Track (unfilled) colour. Defaults to a quiet surface step.
  final Color? trackColor;

  /// Fill colour. Defaults to the brand accent.
  final Color? color;

  /// Colour of the rotating slash and the tip node. Defaults to [color].
  final Color? markerColor;

  /// Overall diameter. Omit to let the ring size itself from [child].
  final double? size;

  /// Draw the slash marker. Turn off for dense or decorative uses.
  final bool showMarker;

  /// Centre content, typically a `Text` or an icon.
  final Widget? child;

  /// Accessible description, e.g. `62 percent of monthly budget used`.
  final String? semanticsLabel;

  const TrackRing({
    super.key,
    required this.value,
    this.thickness = 8,
    this.trackColor,
    this.color,
    this.markerColor,
    this.size,
    this.showMarker = true,
    this.child,
    this.semanticsLabel,
  });

  @override
  State<TrackRing> createState() => _TrackRingState();
}

class _TrackRingState extends State<TrackRing>
    with TickerProviderStateMixin, MotionAwareMixin {
  late final AnimationController _spring;

  /// The announced target, tracked separately from [_spring] because the
  /// Semantics wrapper sits *outside* the AnimatedBuilder that reads
  /// `_spring.value` — without this, a screen reader hears the pre-animation
  /// value until the next unrelated rebuild.
  double _announced = 0;

  @override
  void initState() {
    super.initState();
    _spring = AnimationController(
      vsync: this,
      duration: MotionTokens.durationLongProgress,
      value: widget.value.clamp(0.0, 1.0),
    );
    _announced = _spring.value;
  }

  @override
  void didUpdateWidget(covariant TrackRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.value.clamp(0.0, 1.0);
    if (next != _spring.value) {
      final from = _spring.value;
      _spring.value = from;
      if (shouldAnimate) {
        springAnimate(_spring, MotionTokens.springSnappy, from, next);
      } else {
        _spring.value = next;
      }
      if (mounted) setState(() => _announced = next);
    }
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final fill = widget.color ?? appColors.brandColor;
    final track = widget.trackColor ?? appColors.surfaceContainerHighest;
    final diameter = widget.size ?? (widget.thickness * 8);

    return Semantics(
      label: widget.semanticsLabel,
      value: '${(_announced * 100).round()}%',
      child: ExcludeSemantics(
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: AnimatedBuilder(
            animation: _spring,
            builder: (context, _) => CustomPaint(
              painter: _TrackRingPainter(
                value: _spring.value,
                thickness: widget.thickness,
                color: fill,
                trackColor: track,
                markerColor: widget.markerColor ?? fill,
                showMarker: widget.showMarker,
              ),
              child: widget.child == null
                  ? null
                  : Center(
                      child: Padding(
                        padding: EdgeInsets.all(widget.thickness + kRingPad),
                        child: widget.child,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Breathing room between the ring stroke and whatever sits in the middle.
const double kRingPad = 6;

class _TrackRingPainter extends CustomPainter {
  final double value;
  final double thickness;
  final Color color;
  final Color trackColor;
  final Color markerColor;
  final bool showMarker;

  const _TrackRingPainter({
    required this.value,
    required this.thickness,
    required this.color,
    required this.trackColor,
    required this.markerColor,
    required this.showMarker,
  });

  /// Sweep start, in radians. 135° puts the origin at the lower-left and
  /// sends the fill clockwise over the top — a gauge, not a pie chart.
  static const double _startAngle = math.pi * 0.75;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - thickness) / 2;
    if (radius <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      _startAngle,
      math.pi * 2,
      false,
      stroke..color = trackColor,
    );

    final clamped = value.clamp(0.0, 1.0);
    final sweep = math.pi * 2 * clamped;

    if (clamped > 0) {
      canvas.drawArc(rect, _startAngle, sweep, false, stroke..color = color);
    }

    if (!showMarker) return;

    // The tip node sits exactly at the leading end of the fill.
    if (clamped > 0.001) {
      final tipAngle = _startAngle + sweep;
      final tip = Offset(
        center.dx + radius * math.cos(tipAngle),
        center.dy + radius * math.sin(tipAngle),
      );
      canvas.drawCircle(tip, thickness * 0.5, Paint()..color = color);
      canvas.drawCircle(
        tip,
        thickness * 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, thickness * 0.2)
          ..color = markerColor,
      );
    }

    // The slash: a chord through the ring at the current angle, cut into the
    // track only. Reads as a needle without occluding the number behind it.
    final needleAngle = _startAngle + math.pi * 2 * clamped;
    final inner = radius - thickness * 0.9;
    final outer = radius + thickness * 0.9;
    canvas.drawLine(
      Offset(
        center.dx + inner * math.cos(needleAngle),
        center.dy + inner * math.sin(needleAngle),
      ),
      Offset(
        center.dx + outer * math.cos(needleAngle),
        center.dy + outer * math.sin(needleAngle),
      ),
      Paint()
        ..strokeWidth = math.max(1.5, thickness * 0.22)
        ..strokeCap = StrokeCap.round
        ..color = markerColor.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _TrackRingPainter old) =>
      old.value != value ||
      old.thickness != thickness ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.markerColor != markerColor ||
      old.showMarker != showMarker;
}
