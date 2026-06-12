import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class StaggeredFadeSlide extends StatefulWidget {
  final int index;
  final Widget child;
  final double offset;

  const StaggeredFadeSlide({
    super.key,
    required this.index,
    required this.child,
    this.offset = 20,
  });

  @override
  State<StaggeredFadeSlide> createState() => _StaggeredFadeSlideState();
}

class _StaggeredFadeSlideState extends State<StaggeredFadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _fade = Tween<double>(begin: 0, end: 1).animate(_controller);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offset / 60),
      end: Offset.zero,
    ).animate(_controller);

    Future.delayed(Duration(milliseconds: widget.index * 40), () {
      if (mounted) {
        const spring = SpringDescription(
          mass: 1.0,
          stiffness: 180.0,
          damping: 19.0,
        );
        _controller.animateWith(SpringSimulation(spring, 0.0, 1.0, 0.0));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
