import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// Named material thicknesses, mirroring visionOS/iOS glass materials.
enum GlassMaterial {
  /// Nav bars, tab bars — most translucent.
  thin,

  /// Sheets, dialogs, palettes — the default.
  regular,

  /// Content-bearing surfaces needing max legibility.
  thick,
}

/// Apple "Liquid Glass"-style frosted surface.
///
/// Layer composition (bottom → top):
/// 1. `BackdropFilter` blur — the frosted body
/// 2. Tint wash — visionOS "material" base (lightens dark mode, milks light mode)
/// 3. Vibrancy wash — soft-light gradient that enriches blurred content
/// 4. Static film grain — breaks up banding, adds physical realism
/// 5. Lens rim — gradient stroke + corner catchlights + inner counter-shadow
///    (the signature "glass pane edge" read)
/// 6. Pointer-parallax specular — [GlassMaterial] desktop sheen following the
///    cursor (macOS behaviour); inert on touch and under reduced motion
///
/// Performance contract (AGENTS.md): one-shot entrance fade, then fully inert
/// unless the pointer moves inside [enableParallax] surfaces. Never wrap
/// scrollable list items.
class LiquidGlassOverlay extends StatefulWidget {
  final Widget child;

  /// Explicit tint override. When null, derived from brightness + [material].
  final Color? tintColor;

  /// Scales overall effect strength (entrance fade target).
  final double intensity;

  /// Preset selecting blur sigma + tint density. Ignored when
  /// [blurSigma]/[tintColor] are set explicitly.
  final GlassMaterial material;

  final double? blurSigma;
  final bool showTopHighlight;
  final bool showInnerBorder;

  /// macOS-style cursor-following specular highlight.
  final bool enableParallax;

  /// Seed for deterministic grain pattern. Each instance should use a
  /// different value to avoid identical noise across overlapping overlays.
  final int grainSeed;

  const LiquidGlassOverlay({
    super.key,
    required this.child,
    this.tintColor,
    this.intensity = 1.0,
    this.material = GlassMaterial.regular,
    this.blurSigma,
    this.showTopHighlight = true,
    this.showInnerBorder = true,
    this.enableParallax = false,
    this.grainSeed = 0x61F7,
  });

  @override
  State<LiquidGlassOverlay> createState() => _LiquidGlassOverlayState();
}

class _LiquidGlassOverlayState extends State<LiquidGlassOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  final ValueNotifier<Offset?> _pointer = ValueNotifier(null);
  bool _entranceStarted = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceStarted) return;
    _entranceStarted = true;

    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reducedMotion) {
      _entrance.value = 1.0;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _entrance.forward();
      });
    }
  }

  @override
  void dispose() {
    _pointer.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    // Material presets (visionOS .thin/.regular/.thick analogues).
    final (presetBlur, tintDark, tintLight) = switch (widget.material) {
      GlassMaterial.thin => (18.0, 0.07, 0.55),
      GlassMaterial.regular => (26.0, 0.11, 0.72),
      GlassMaterial.thick => (34.0, 0.16, 0.84),
    };

    final sigma = widget.blurSigma ?? presetBlur;
    final baseTint =
        widget.tintColor ??
        (isDark
            ? Color.fromRGBO(255, 255, 255, tintDark)
            : const Color(0xFFFAFAFE).withValues(alpha: tintLight));

    Widget content = widget.child;

    if (widget.enableParallax && !reducedMotion) {
      content = MouseRegion(
        onHover: (e) => _pointer.value = e.localPosition,
        onExit: (_) => _pointer.value = null,
        child: content,
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _entrance,
        builder: (context, child) {
          final e = Curves.easeOutCubic.transform(_entrance.value);
          final k = e * widget.intensity;
          if (k <= 0.01) return child!;

          return Stack(
            children: [
              // ── 1+2. Frosted blur + tint wash ──
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: sigma * k,
                        sigmaY: sigma * k,
                        tileMode: TileMode.mirror,
                      ),
                      child: Container(
                        color: baseTint.withValues(alpha: baseTint.a * k),
                      ),
                    ),
                  ),
                ),
              ),

              // ── 3-6. Vibrancy, grain, lens rim, parallax sheen ──
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _LiquidGlassPainter(
                      k: k,
                      isDark: isDark,
                      showTopHighlight: widget.showTopHighlight,
                      showInnerBorder: widget.showInnerBorder,
                      grainSeed: widget.grainSeed,
                      pointer: widget.enableParallax && !reducedMotion
                          ? _pointer
                          : null,
                    ),
                  ),
                ),
              ),

              Opacity(opacity: e.clamp(0.0, 1.0), child: child!),
            ],
          );
        },
        child: content,
      ),
    );
  }
}

class _LiquidGlassPainter extends CustomPainter {
  final double k;
  final bool isDark;
  final bool showTopHighlight;
  final bool showInnerBorder;
  final int grainSeed;
  final ValueNotifier<Offset?>? pointer;

  _LiquidGlassPainter({
    required this.k,
    required this.isDark,
    required this.showTopHighlight,
    required this.showInnerBorder,
    required this.grainSeed,
    this.pointer,
  }) : super(repaint: pointer);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || k < 0.05) return;
    final rect = Offset.zero & size;
    final cornerR = math.min(24.0, math.min(size.width, size.height) / 2);

    _paintVibrancy(canvas, rect);
    _paintGrain(canvas, size);
    if (showTopHighlight) _paintTopHighlight(canvas, size);
    if (showInnerBorder) _paintLensRim(canvas, rect, cornerR);
    _paintParallaxSheen(canvas, size);
  }

  /// Soft-light wash that makes blurred colours pop (iOS "vibrancy").
  void _paintVibrancy(Canvas canvas, Rect rect) {
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.softLight
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFEAF0FF).withValues(alpha: 0.10 * k),
            Colors.transparent,
            const Color(0xFF101418).withValues(alpha: 0.05 * k),
          ],
        ).createShader(rect),
    );
  }

  /// Deterministic micro-speckle; kills gradient banding on large panes.
  void _paintGrain(Canvas canvas, Size size) {
    if (k < 0.2) return;
    final count = math.min(360, (size.width * size.height / 1100).round());
    final rng = math.Random(grainSeed);
    final dot = Paint()..strokeWidth = 0.8;
    for (var i = 0; i < count; i++) {
      final p = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height,
      );
      final light = rng.nextBool();
      dot.color = (light ? Colors.white : Colors.black).withValues(
        alpha: (light ? 0.020 : 0.014) * k,
      );
      canvas.drawCircle(p, 0.6, dot);
    }
  }

  void _paintTopHighlight(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, 0.75),
      Offset(size.width, 0.75),
      Paint()
        ..strokeWidth = 1.5
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.40 * k),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, 2)),
    );
  }

  /// The signature Liquid-Glass rim: bright refractive edge (top-left lit),
  /// faint inner counter-shadow (bottom-right), and two corner catchlights.
  void _paintLensRim(Canvas canvas, Rect rect, double cornerR) {
    final outer = RRect.fromRectAndRadius(
      rect.deflate(0.75),
      Radius.circular(cornerR - 0.75),
    );

    // Primary rim — refracted light gradient.
    canvas.drawRRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: (isDark ? 0.38 : 0.62) * k),
            Colors.white.withValues(alpha: 0.05 * k),
            Colors.white.withValues(alpha: (isDark ? 0.16 : 0.34) * k),
          ],
        ).createShader(rect),
    );

    // Inner counter-shadow — sells physical thickness.
    final inner = RRect.fromRectAndRadius(
      rect.deflate(2.2),
      Radius.circular(math.max(0, cornerR - 2.2)),
    );
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5)
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: (isDark ? 0.22 : 0.08) * k),
          ],
        ).createShader(rect),
    );

    // Corner catchlights — brightest points where curvature faces the light.
    void catchlight(Offset c, double startAngle, double alpha) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: cornerR - 1.4),
        startAngle,
        math.pi / 2.4,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: alpha * k),
      );
    }

    catchlight(Offset(cornerR, cornerR), math.pi, 0.60);
    catchlight(Offset(rect.width - cornerR, rect.height - cornerR), 0, 0.32);
  }

  /// Cursor-tracking specular pool (macOS/visionOS desktop feel).
  void _paintParallaxSheen(Canvas canvas, Size size) {
    final p = pointer?.value;
    if (p == null || k < 0.3) return;

    final center = Alignment(
      (p.dx / size.width).clamp(-0.2, 1.2) * 2 - 1,
      (p.dy / size.height).clamp(-0.2, 1.2) * 2 - 1,
    );

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: center,
          radius: 0.9,
          colors: [
            Colors.white.withValues(alpha: 0.09 * k),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_LiquidGlassPainter oldDelegate) =>
      oldDelegate.k != k ||
      oldDelegate.isDark != isDark ||
      oldDelegate.showTopHighlight != showTopHighlight ||
      oldDelegate.showInnerBorder != showInnerBorder;
}

/// Ready-made visionOS sheet container: clip radius + regular glass + padding.
class VisionOSSheet extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final GlassMaterial material;
  final bool enableParallax;

  const VisionOSSheet({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.padding,
    this.material = GlassMaterial.regular,
    this.enableParallax = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: LiquidGlassOverlay(
        material: material,
        enableParallax: enableParallax,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}
