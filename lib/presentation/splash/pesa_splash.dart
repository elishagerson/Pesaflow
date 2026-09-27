import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/spacing.dart';

/// The cold-start moment.
///
/// Five beats, in order, and no beat is decorative:
///
///  1. **Draw.** A thin ring of the brand accent draws itself in a single
///     stroke — the app's "O" mark: a track, with a slash across it.
///  2. **Bloom.** The ring's stroke becomes light. A radial glow expands from
///     it until it fills the frame.
///  3. **Settle.** The mark scales and rotates into place on a real spring, so
///     it arrives rather than appears.
///  4. **Commit.** The canvas flips from pure black to the brand field. The
///     wordmark locks in.
///  5. **Hand off.** [onComplete] fires; the caller fades this out.
///
/// Every stage is driven from one controller, so the whole thing is a single
/// timeline rather than a pile of overlapping animations, and reduced-motion
/// collapses it to an instant, opaque brand field.
class PesaSplash extends StatefulWidget {
  final VoidCallback onComplete;

  const PesaSplash({super.key, required this.onComplete});

  @override
  State<PesaSplash> createState() => _PesaSplashState();
}

class _PesaSplashState extends State<PesaSplash>
    with SingleTickerProviderStateMixin {
  static const Duration _total = Duration(milliseconds: 1560);

  late final AnimationController _c;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _total);
    if (context.isReducedMotion) {
      _c.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onComplete();
  }

  /// Fraction of [total] at which [onComplete] fires. Exposed so the caller can
  /// start its own fade-out at exactly this point.
  static const double handoffAt = 0.86;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final brand = appColors.brandGradientFrom;
    final brandHi = appColors.brandGradientTo;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;

        if (!_done && t >= handoffAt) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
        }

        // Beat 1 — the stroke draws over the first fifth of the timeline.
        final draw = Curves.easeOutCubic.transform(
          (_seg(t, 0.0, 0.20)).clamp(0.0, 1.0),
        );
        // Beat 2 — the glow blooms, overlapping the end of the draw.
        final bloom = Curves.easeOutCubic.transform(
          (_seg(t, 0.12, 0.48)).clamp(0.0, 1.0),
        );
        // Beat 3 — the mark settles on a spring curve after the bloom peaks.
        final settleIn = Curves.easeOutBack.transform(
          (_seg(t, 0.26, 0.66)).clamp(0.0, 1.0),
        );
        // Beat 4 — black commits to the brand field.
        final commit = Curves.easeInOutCubic.transform(
          (_seg(t, 0.52, 0.80)).clamp(0.0, 1.0),
        );
        // Beat 5 — the wordmark.
        final wordIn = Curves.easeOutCubic.transform(
          (_seg(t, 0.44, 0.78)).clamp(0.0, 1.0),
        );

        final bg = Color.lerp(const Color(0xFF000000), brand, commit)!;
        final wordColor = Color.lerp(
          Colors.white,
          appColors.brandOnColor,
          commit,
        )!;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: commit > 0.5
              ? SystemUiOverlayStyle.light.copyWith(
                  statusBarColor: Colors.transparent,
                )
              : SystemUiOverlayStyle.light.copyWith(
                  statusBarColor: Colors.transparent,
                ),
          child: ColoredBox(
            color: bg,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Beat 2 — the glow. Sized far beyond the frame so its soft
                // falloff never shows an edge.
                IgnorePointer(
                  child: Opacity(
                    opacity: bloom,
                    child: CustomPaint(
                      painter: _BloomPainter(
                        progress: bloom,
                        color: Color.lerp(brand, brandHi, bloom)!,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Beat 1 + 3 — the mark.
                      SizedBox(
                        width: 108,
                        height: 108,
                        child: CustomPaint(
                          painter: _MarkPainter(
                            draw: draw,
                            settle: settleIn,
                            color: Color.lerp(brandHi, Colors.white, commit)!,
                            glow: bloom,
                          ),
                        ),
                      ),
                      SizedBox(height: kSpacing20),
                      // Beat 5 — the wordmark, in the poster cut.
                      Opacity(
                        opacity: wordIn,
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1 - wordIn)),
                          child: Text(
                            'PESAFLOW',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppTheme.fontPoster,
                              fontSize: 34,
                              height: 1.0,
                              letterSpacing: 3,
                              color: wordColor,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: kSpacing6),
                      Opacity(
                        opacity: wordIn * 0.7,
                        child: Text(
                          'EVERY SHILLING, TRACKED',
                          style: TextStyle(
                            fontFamily: AppTheme.fontText,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.4,
                            color: wordColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Normalised progress through [from]..[to] within the whole timeline.
  static double _seg(double t, double from, double to) =>
      ((t - from) / (to - from)).clamp(0.0, 1.0);
}

/// The mark: a ring drawn in one stroke, with a slash across it.
///
/// The ring is a loop of money and a track; the slash is the stroke of a
/// transaction cutting across it. Drawn tilted so it reads as motion rather
/// than as a static letter.
class _MarkPainter extends CustomPainter {
  final double draw;
  final double settle;
  final Color color;
  final double glow;

  const _MarkPainter({
    required this.draw,
    required this.settle,
    required this.color,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (draw <= 0) return;
    final center = size.center(Offset.zero);
    final base = size.width * 0.34;
    // Beat 3 — the mark grows and untwists as it settles.
    final scale = 0.72 + 0.28 * settle;
    final radius = base * scale;
    final tilt = (1 - settle) * 0.55;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tilt);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..color = color.withValues(alpha: 0.30 * glow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color;

    final rect = Rect.fromCircle(center: Offset.zero, radius: radius);
    final start = -math.pi * 0.5;

    // Beat 1 — a single sweep, not a wipe. The head of the stroke is rounded
    // so it reads as being drawn rather than revealed.
    if (glow > 0.01) {
      canvas.drawArc(rect, start, math.pi * 2 * draw, false, glowPaint);
    }
    canvas.drawArc(rect, start, math.pi * 2 * draw, false, stroke);

    // The slash fades in only once the ring is most of the way round, so the
    // two never overlap into a blob.
    final slashIn = ((draw - 0.7) / 0.3).clamp(0.0, 1.0);
    if (slashIn > 0) {
      canvas.drawLine(
        Offset(-radius * 0.66, radius * 0.66),
        Offset(radius * 0.66, -radius * 0.66),
        stroke
          ..strokeWidth = 5
          ..color = color.withValues(alpha: slashIn),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) =>
      old.draw != draw ||
      old.settle != settle ||
      old.color != color ||
      old.glow != glow;
}

/// The expanding radial light.
class _BloomPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _BloomPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = size.center(Offset.zero);
    final maxRadius = size.longestSide * 0.9;
    final radius = maxRadius * Curves.easeOutCubic.transform(progress);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.42),
            color.withValues(alpha: 0.20),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(covariant _BloomPainter old) =>
      old.progress != progress || old.color != color;
}
