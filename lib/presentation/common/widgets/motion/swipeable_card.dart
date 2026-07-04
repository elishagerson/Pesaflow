import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

class SwipeableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final double swipeThreshold;

  const SwipeableCard({
    super.key,
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.swipeThreshold = 120.0,
  });

  @override
  State<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Alignment _dragAlignment = Alignment.center;
  late AlignmentTween _alignmentTween;
  double _rotation = 0.0;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addListener(() {
      setState(() {
        _dragAlignment = _alignmentTween.evaluate(_controller);
        _rotation = _dragAlignment.x * 0.05;
        _scale = 1.0 - (_dragAlignment.x.abs() * 0.05).clamp(0.0, 0.1);
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _runSpringAnimation(Offset pixelsPerSecond, Size size) {
    _alignmentTween = AlignmentTween(
      begin: _dragAlignment,
      end: Alignment.center,
    );

    final unitsPerSecondX = pixelsPerSecond.dx / size.width;
    final unitsPerSecondY = pixelsPerSecond.dy / size.height;
    final unitsPerSecond = Offset(unitsPerSecondX, unitsPerSecondY);

    const spring = SpringDescription(
      maxLimit: 1,
      mass: 1,
      stiffness: 220,
      damping: 18,
    );

    final simulation = SpringSimulation(spring, 0, 1, -unitsPerSecond.distance);
    _controller.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return GestureDetector(
      onPanDown: (details) {
        _controller.stop();
      },
      onPanUpdate: (details) {
        setState(() {
          _dragAlignment += Alignment(
            details.delta.dx / (size.width / 2),
            details.delta.dy / (size.height / 2),
          );
          _rotation = _dragAlignment.x * 0.05;
          _scale = 1.0 - (_dragAlignment.x.abs() * 0.05).clamp(0.0, 0.1);
        });
      },
      onPanEnd: (details) {
        final dragDistance = _dragAlignment.x * (size.width / 2);

        if (dragDistance.abs() > widget.swipeThreshold) {
          HapticFeedback.mediumImpact();
          if (dragDistance > 0) {
            widget.onSwipeRight?.call();
          } else {
            widget.onSwipeLeft?.call();
          }
        } else {
          _runSpringAnimation(details.velocity.pixelsPerSecond, size);
        }
      },
      child: Transform.translate(
        offset: Offset(
          _dragAlignment.x * (size.width / 2),
          _dragAlignment.y * (size.height / 4),
        ),
        child: Transform.rotate(
          angle: _rotation,
          child: Transform.scale(
            scale: _scale,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
