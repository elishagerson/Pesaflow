import 'package:flutter/material.dart';

class SkeletonCard extends StatelessWidget {
  final double height;
  final double width;
  final double borderRadius;

  const SkeletonCard({
    super.key,
    this.height = 100,
    this.width = double.infinity,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5)
            : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: _ShimmerEffect(child: _buildContent()),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pulseBar(width: 120, height: 14),
          const SizedBox(height: 12),
          _pulseBar(width: double.infinity, height: 10),
          const SizedBox(height: 8),
          _pulseBar(width: 180, height: 10),
        ],
      ),
    );
  }

  Widget _pulseBar({double width = 80, double height = 12}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class SkeletonRing extends StatelessWidget {
  final double size;

  const SkeletonRing({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return _ShimmerEffect(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5)
              : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _ShimmerEffect extends StatefulWidget {
  final Widget child;
  const _ShimmerEffect({required this.child});

  @override
  State<_ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<_ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, child) {
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [Colors.transparent, Colors.white24, Colors.transparent],
            stops: [
              _animation.value - 0.3,
              _animation.value,
              _animation.value + 0.3,
            ],
          ).createShader(bounds),
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
