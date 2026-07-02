import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiOverlay extends StatefulWidget {
  final Widget child;
  final bool show;
  final int particleCount;
  final List<Color> colors;
  final Duration duration;

  const ConfettiOverlay({
    super.key,
    required this.child,
    this.show = true,
    this.particleCount = 80,
    this.colors = _defaultColors,
    this.duration = const Duration(seconds: 4),
  });

  static const List<Color> _defaultColors = [
    Color(0xFFFF2D55),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF007AFF),
    Color(0xFF5856D6),
    Color(0xFFAF52DE),
  ];

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ConfettiParticle> _particles = [];
  final Random _rand = Random();

  @override
  void initState() {
    super.initState();
    if (widget.show) {
      _startConfetti();
    }
  }

  void _startConfetti() {
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addListener(_updateParticles)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _particles.clear());
        }
      });
    _spawnParticles(widget.particleCount);
    _controller.forward();
  }

  @override
  void didUpdateWidget(ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      _particles.clear();
      _startConfetti();
    }
  }

  void _spawnParticles(int count) {
    for (int i = 0; i < count; i++) {
      _particles.add(
        _ConfettiParticle(
          x: _rand.nextDouble() * 400,
          y: -_rand.nextDouble() * 300 - 20,
          size: _rand.nextDouble() * 10 + 6,
          color: widget.colors[_rand.nextInt(widget.colors.length)],
          vx: (_rand.nextDouble() - 0.5) * 4,
          vy: _rand.nextDouble() * 5 + 3,
          rotation: _rand.nextDouble() * 2 * pi,
          rotationSpeed: (_rand.nextDouble() - 0.5) * 0.2,
          isStreamer: _rand.nextBool(),
        ),
      );
    }
  }

  void _updateParticles() {
    if (!mounted) return;
    setState(() {
      for (final p in _particles) {
        p.y += p.vy;
        p.x += p.vx + sin(_controller.value * 2 * pi + p.size) * 0.5;
        p.rotation += p.rotationSpeed;
        if (p.y > 800) {
          p.y = -20;
          p.x = _rand.nextDouble() * 400;
          p.vy = _rand.nextDouble() * 5 + 3;
        }
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
    return Stack(
      children: [
        widget.child,
        if (_particles.isNotEmpty)
          IgnorePointer(
            child: CustomPaint(
              size: Size.infinite,
              painter: _ConfettiPainter(particles: _particles),
            ),
          ),
      ],
    );
  }
}

class _ConfettiParticle {
  double x, y, size, vx, vy, rotation, rotationSpeed;
  Color color;
  bool isStreamer;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
    required this.isStreamer,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;

  _ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      paint.color = p.color;
      final drawX = (p.x / 400) * size.width;
      final drawY = p.y;
      canvas.save();
      canvas.translate(drawX, drawY);
      canvas.rotate(p.rotation);
      if (p.isStreamer) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size * 0.3,
            height: p.size * 2,
          ),
          paint,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
