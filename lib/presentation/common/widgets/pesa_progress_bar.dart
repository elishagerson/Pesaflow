import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/motion/motion_aware.dart';

/// The app's progress primitive.
///
/// A determinate bar whose leading edge ripples and whose tip carries a bright
/// node, instead of a flat Material `LinearProgressIndicator`. Progress is the
/// emotional core of a finance app — budget consumed, goal funded, loan paid
/// off — so it gets the app's signature treatment rather than the default one.
///
/// Two cost controls, both important:
///
///  * **The wave is opt-in.** List rows and dense tables pass `wave: false` and
///    get a plain static bar with no ticker at all. Only the two or three
///    hero bars on screen run the animation.
///  * **The ticker parks when the value is settled and the bar is off-screen.**
///    `TickerMode` (and therefore page changes inside the indexed-stack shell)
///    mutes it automatically, and reduced-motion skips it entirely. The bar is
///    never a permanent frame-budget tax.
class PesaProgressBar extends StatefulWidget {
  /// Progress in the range 0..1. Values outside are clamped.
  final double value;

  /// Fill colour. Defaults to the brand accent.
  final Color? color;

  /// Track colour. Defaults to a quiet surface step above the background.
  final Color? trackColor;

  /// Bar thickness in logical pixels.
  final double height;

  /// Peak displacement of the leading-edge ripple, in logical pixels.
  ///
  /// Ignored when [wave] is `false`. Clamped to `height / 2 - 1` so the ripple
  /// can never break out of the bar's own silhouette.
  final double amplitude;

  /// Ripple travel speed, in cycles per second.
  final double waveSpeed;

  /// Whether the leading edge ripples. `true` for hero bars, `false` for rows.
  final bool wave;

  /// Draw a terminal node at the far end of the track, marking 100%.
  final bool showEndStop;

  /// Semantic value announced by screen readers, e.g. `62% of budget used`.
  final String? semanticsLabel;

  const PesaProgressBar({
    super.key,
    required this.value,
    this.color,
    this.trackColor,
    this.height = 8,
    this.amplitude = 2.0,
    this.waveSpeed = 0.55,
    this.wave = true,
    this.showEndStop = true,
    this.semanticsLabel,
  });

  @override
  State<PesaProgressBar> createState() => _PesaProgressBarState();
}

class _PesaProgressBarState extends State<PesaProgressBar>
    with TickerProviderStateMixin, MotionAwareMixin {
  late final AnimationController _wave;
  late final AnimationController _spring;

  /// The value actually on screen. Chases [PesaProgressBar.value] on a spring,
  /// so a balance update glides rather than jumping.
  double _shown = 0;

  @override
  void initState() {
    super.initState();

    _wave = AnimationController(vsync: this, duration: const Duration(days: 1));
    _spring = AnimationController(
      vsync: this,
      duration: MotionTokens.durationLongProgress,
      value: widget.value.clamp(0.0, 1.0),
    );
    _shown = widget.value.clamp(0.0, 1.0);

    // Registered once, not per update: the wave has to park the instant the
    // spring settles, and a status listener is the only hook that fires then.
    _spring.addStatusListener((_) => _syncWave());
    _syncWave();
  }

  @override
  void didUpdateWidget(covariant PesaProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.value.clamp(0.0, 1.0);
    if (next != _shown) {
      final from = _spring.value;
      _spring.value = from;
      if (shouldAnimate) {
        springAnimate(_spring, MotionTokens.springSnappy, from, next);
      } else {
        _spring.value = next;
      }
      // Track the target, not the rendered value: Semantics should announce the
      // number the bar is heading to, and `_shown` is read outside the
      // AnimatedBuilder, so it has to be state that actually changes.
      if (mounted) setState(() => _shown = next);
    }
    if (oldWidget.wave != widget.wave) _syncWave();
  }

  @override
  void dispose() {
    _wave.dispose();
    _spring.dispose();
    super.dispose();
  }

  /// The wave only exists to make the leading edge feel alive, so it runs only
  /// while the value is actually in motion. A bar sitting at its final value
  /// with a static leading edge costs nothing; the same bar with a repeating
  /// ticker repaints every frame forever, which is a real cost on a list of
  /// rows.
  bool get _waving => widget.wave && shouldAnimate && !_spring.isCompleted;

  void _syncWave() {
    if (_waving) {
      if (!_wave.isAnimating) _wave.repeat();
    } else {
      _wave.stop();
      _wave.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final fill = widget.color ?? appColors.brandColor;
    final track = widget.trackColor ?? appColors.surfaceContainerHighest;
    return Semantics(
      label: widget.semanticsLabel,
      value: '${(_shown * 100).round()}%',
      child: ExcludeSemantics(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: AnimatedBuilder(
            animation: Listenable.merge([_wave, _spring]),
            builder: (context, _) {
              return CustomPaint(
                painter: _ProgressPainter(
                  value: _spring.value,
                  phase: _waving
                      ? _wave.value * widget.waveSpeed * 2 * math.pi
                      : 0,
                  color: fill,
                  trackColor: track,
                  endStopColor: fill,
                  amplitude: widget.wave
                      ? widget.amplitude.clamp(
                          0.0,
                          math.max(0.0, widget.height / 2 - 1),
                        )
                      : 0,
                  showEndStop: widget.showEndStop,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  final double value;
  final double phase;
  final Color color;
  final Color trackColor;
  final Color endStopColor;
  final double amplitude;
  final bool showEndStop;

  const _ProgressPainter({
    required this.value,
    required this.phase,
    required this.color,
    required this.trackColor,
    required this.endStopColor,
    required this.amplitude,
    required this.showEndStop,
  });

  /// Wavelength of the ripple. Short enough to read as energy, long enough
  /// that the leading edge never looks like a sawtooth.
  static const double _wavelength = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(r, Paint()..color = trackColor);

    final clamped = value.clamp(0.0, 1.0);
    if (clamped <= 0) {
      if (showEndStop) _paintEndStop(canvas, size);
      return;
    }

    final fillWidth = size.width * clamped;
    if (fillWidth <= 0.5) {
      if (showEndStop) _paintEndStop(canvas, size);
      return;
    }

    final mid = size.height / 2;
    final track = Path()..addRRect(r);
    canvas.save();
    canvas.clipPath(track);

    // The ripple ramps in from zero at the start of the fill to full at the
    // leading edge, so the body of the bar stays calm and readable while the
    // tip carries the motion.
    final fill = Path()..moveTo(0, mid);
    const steps = 48;
    for (var i = 0; i <= steps; i++) {
      final x = fillWidth * (i / steps);
      final ramp = (i / steps);
      final a = amplitude * ramp;
      final y = mid - math.sin(phase + (x / _wavelength) * 2 * math.pi) * a;
      fill.lineTo(x, y);
    }
    for (var i = steps; i >= 0; i--) {
      final x = fillWidth * (i / steps);
      final ramp = (i / steps);
      final a = amplitude * ramp;
      final y = mid + math.sin(phase + (x / _wavelength) * 2 * math.pi) * a;
      fill.lineTo(x, y);
    }
    fill.close();
    canvas.drawPath(fill, Paint()..color = color);

    // Cap the ripple so the tip keeps a clean round silhouette instead of a
    // ragged sine edge.
    canvas.drawCircle(Offset(fillWidth, mid), mid, Paint()..color = color);
    canvas.restore();

    if (showEndStop) _paintEndStop(canvas, size);
  }

  void _paintEndStop(Canvas canvas, Size size) {
    final r = math.min(3.0, size.height / 2);
    final center = Offset(size.width - r, size.height / 2);
    canvas.drawCircle(
      center,
      r,
      Paint()..color = endStopColor.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter old) =>
      old.value != value ||
      old.phase != phase ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.amplitude != amplitude ||
      old.showEndStop != showEndStop;
}

/// A thin, always-static variant for list rows and table cells.
///
/// Same geometry family, zero tickers, zero `AnimationController` — safe to
/// put in a `ListView.builder` at any length.
class StaticProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final Color? trackColor;
  final double height;
  final String? semanticsLabel;

  const StaticProgressBar({
    super.key,
    required this.value,
    this.color,
    this.trackColor,
    this.height = 6,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    return Semantics(
      label: semanticsLabel,
      value: '${(value.clamp(0.0, 1.0) * 100).round()}%',
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _StaticProgressPainter(
              value: value.clamp(0.0, 1.0),
              color: color ?? appColors.brandColor,
              trackColor: trackColor ?? appColors.surfaceContainerHighest,
            ),
          ),
        ),
      ),
    );
  }
}

class _StaticProgressPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color trackColor;

  const _StaticProgressPainter({
    required this.value,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, r),
      Paint()..color = trackColor,
    );
    if (value <= 0) return;
    final w = size.width * value;
    // Below one full cap-diameter the bar is drawn as a dot so a 2% budget
    // still registers as "something happened" instead of a rounded sliver.
    if (w < size.height) {
      canvas.drawCircle(
        Offset(size.height / 2, size.height / 2),
        size.height / 2,
        Paint()..color = color,
      );
      return;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, size.height), r),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _StaticProgressPainter old) =>
      old.value != value || old.color != color || old.trackColor != trackColor;
}

/// Radius helper so callers don't hard-code 4 for a 8px bar.
double progressBarRadius(double height) => height / 2;
