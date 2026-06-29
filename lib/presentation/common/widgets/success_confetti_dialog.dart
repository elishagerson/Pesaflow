import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';

class SuccessConfettiDialog extends StatefulWidget {
  final String goalName;
  final int targetAmount;

  const SuccessConfettiDialog({
    required this.goalName,
    required this.targetAmount,
    super.key,
  });

  @override
  State<SuccessConfettiDialog> createState() => _SuccessConfettiDialogState();
}

class _SuccessConfettiDialogState extends State<SuccessConfettiDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _tickerController;
  final List<_ConfettiParticle> _particles = [];
  final Random _rand = Random();

  final List<Color> _colors = [
    const Color(0xFFFF2D55), // Red
    const Color(0xFFFF9500), // Orange
    const Color(0xFFFFCC00), // Yellow
    const Color(0xFF34C759), // Green
    const Color(0xFF007AFF), // Blue
    const Color(0xFF5856D6), // Purple
    const Color(0xFFAF52DE), // Violet
  ];

  @override
  void initState() {
    super.initState();

    // Ticker running at 60 FPS
    _tickerController =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..addListener(() {
            _updateParticles();
          });

    // Generate initial batch of particles
    _spawnParticles(120);
    _tickerController.forward();
  }

  void _spawnParticles(int count) {
    for (int i = 0; i < count; i++) {
      _particles.add(
        _ConfettiParticle(
          x:
              _rand.nextDouble() *
              400, // will be scaled to screen width in painter
          y: -_rand.nextDouble() * 300 - 20, // start above viewport
          size: _rand.nextDouble() * 10 + 6,
          color: _colors[_rand.nextInt(_colors.length)],
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
        p.x +=
            p.vx +
            sin(_tickerController.value * 2 * pi + p.size) * 0.5; // wind sway
        p.rotation += p.rotationSpeed;

        // Reset particle to top if it goes off bottom
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
    _tickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Fullscreen CustomPainter Canvas for Confetti particles
        IgnorePointer(
          child: CustomPaint(
            size: Size(size.width, size.height),
            painter: _ConfettiPainter(particles: _particles, rand: _rand),
          ),
        ),

        // Beautiful glassmorphic dialog card content
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1C1C1E).withValues(alpha: 0.92)
                      : Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Celebration Crown / Trophy Icon
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFCC00).withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFFCC00).withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFFFCC00),
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Celebration Swahili & English Headers
                    const Text(
                      'Hongera sana!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Goal Achieved!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF609F8A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Completed Details text
                    Text(
                      'You have successfully completed your savings goal for:',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.goalName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.formatCents(widget.targetAmount),
                      style: const TextStyle(
                        fontSize: 22,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF609F8A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // Bouncing tactile confirmation button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: TactileSpringContainer(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF609F8A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Hooray!',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfettiParticle {
  double x;
  double y;
  double size;
  Color color;
  double vx;
  double vy;
  double rotation;
  double rotationSpeed;
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
  final Random rand;

  _ConfettiPainter({required this.particles, required this.rand});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      paint.color = p.color;

      // Scale simulated coordinates (0..400) to actual canvas size
      final drawX = (p.x / 400) * size.width;
      final drawY = p.y;

      canvas.save();
      canvas.translate(drawX, drawY);
      canvas.rotate(p.rotation);

      if (p.isStreamer) {
        // Draw streamer (thin ribbon)
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size * 0.3,
            height: p.size * 2,
          ),
          paint,
        );
      } else {
        // Draw square / squircle
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
