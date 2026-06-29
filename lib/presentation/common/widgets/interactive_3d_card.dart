import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A premium, state-of-the-art interactive container that provides a 3D perspective
/// tilt effect, dynamic shadow translation, and a shifting light reflection sheen
/// when touched or dragged.
class Interactive3DCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final Color shadowColor;
  final double maxTiltX;
  final double maxTiltY;
  final double glareOpacity;
  final VoidCallback? onTap;

  const Interactive3DCard({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.shadowColor = Colors.black,
    this.maxTiltX = 0.15,
    this.maxTiltY = 0.15,
    this.glareOpacity = 0.15,
    this.onTap,
  });

  @override
  State<Interactive3DCard> createState() => _Interactive3DCardState();
}

class _Interactive3DCardState extends State<Interactive3DCard> {
  double _tiltX = 0.0;
  double _tiltY = 0.0;
  bool _isPressed = false;
  bool _hasTriggeredHaptic = false;

  @override
  void initState() {
    super.initState();
    // Glance auto-tilt sway animation: briefly tilt and release to show off the 3D effect
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _tiltX = 0.35;
        _tiltY = -0.2;
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          _tiltX = -0.3;
          _tiltY = 0.35;
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          _resetTilt();
        });
      });
    });
  }

  void _updateTilt(Offset localPosition, double width, double height) {
    if (width <= 0 || height <= 0) return;

    // Normalize coordinates to [-1.0, 1.0] relative to the center of the widget
    final dx = ((localPosition.dx / width) * 2.0 - 1.0).clamp(-1.0, 1.0);
    final dy = ((localPosition.dy / height) * 2.0 - 1.0).clamp(-1.0, 1.0);

    // Trigger tilt haptic click if absolute tilt exceeds 80% range (0.8 magnitude)
    final magnitude = Offset(dx, dy).distance;
    if (magnitude > 0.8) {
      if (!_hasTriggeredHaptic) {
        HapticFeedback.selectionClick();
        _hasTriggeredHaptic = true;
      }
    } else {
      _hasTriggeredHaptic = false;
    }

    setState(() {
      _tiltX = dx;
      _tiltY = dy;
      _isPressed = true;
    });
  }

  void _resetTilt() {
    setState(() {
      _tiltX = 0.0;
      _tiltY = 0.0;
      _isPressed = false;
      _hasTriggeredHaptic = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Listener(
          onPointerDown: (event) =>
              _updateTilt(event.localPosition, width, height),
          onPointerMove: (event) =>
              _updateTilt(event.localPosition, width, height),
          onPointerUp: (_) => _resetTilt(),
          onPointerCancel: (_) => _resetTilt(),
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: TweenAnimationBuilder<Offset>(
              tween: Tween<Offset>(
                begin: Offset.zero,
                end: _isPressed ? Offset(_tiltX, _tiltY) : Offset.zero,
              ),
              duration: Duration(milliseconds: _isPressed ? 80 : 500),
              curve: _isPressed ? Curves.easeOutQuad : Curves.elasticOut,
              builder: (context, tilt, child) {
                // Perspective transformation matrix
                final matrix = Matrix4.identity()
                  ..setEntry(3, 2, 0.0012) // Depth perspective
                  ..rotateX(
                    -tilt.dy * widget.maxTiltY,
                  ) // Rotation around X axis
                  ..rotateY(
                    tilt.dx * widget.maxTiltX,
                  ); // Rotation around Y axis

                if (_isPressed) {
                  matrix.scaleByDouble(1.02, 1.02, 1.02, 1.0); // Lift effect
                }

                // Dynamic shadow translation: moves opposite to the tilt direction
                final shadowOffset = Offset(
                  -tilt.dx * 8.0,
                  8.0 - tilt.dy * 8.0,
                );
                final shadowBlur = _isPressed ? 24.0 : 12.0;
                final shadowSpread = _isPressed ? 2.0 : 0.0;
                final shadowAlpha = _isPressed ? 0.22 : 0.12;

                // Reflective glare intensity based on current tilt magnitude
                final magnitude = tilt.distance.clamp(0.0, 1.5);
                final glareAlpha = (magnitude * widget.glareOpacity).clamp(
                  0.0,
                  1.0,
                );

                return Transform(
                  transform: matrix,
                  alignment: FractionalOffset.center,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      boxShadow: [
                        BoxShadow(
                          color: widget.shadowColor.withValues(
                            alpha: shadowAlpha,
                          ),
                          blurRadius: shadowBlur,
                          spreadRadius: shadowSpread,
                          offset: shadowOffset,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      child: Stack(
                        children: [
                          widget.child,

                          // Shiny glare overlay sheet
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    widget.borderRadius,
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment(
                                      tilt.dx - 1.5,
                                      tilt.dy - 1.5,
                                    ),
                                    end: Alignment(
                                      tilt.dx + 1.5,
                                      tilt.dy + 1.5,
                                    ),
                                    colors: [
                                      Colors.white.withValues(
                                        alpha: glareAlpha * 1.3,
                                      ),
                                      Colors.white.withValues(alpha: 0.0),
                                      Colors.white.withValues(
                                        alpha: glareAlpha * 0.4,
                                      ),
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
