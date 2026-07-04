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
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: _ShimmerEffect(child: _buildContent()),
    );
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final barHeight = (constraints.maxHeight - 16) / 6.5;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: kSpacing16, vertical: kSpacing8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _pulseBar(width: 120, height: barHeight * 1.5, theme: theme),
              SizedBox(height: barHeight),
              _pulseBar(width: double.infinity, height: barHeight, theme: theme),
              SizedBox(height: barHeight),
              _pulseBar(width: 180, height: barHeight, theme: theme),
            ],
          ),
        );
      },
    );
  }

  Widget _pulseBar({double width = 80, double height = 12, required ThemeData theme}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.10),
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
    return _ShimmerEffect(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.55),
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
    final theme = Theme.of(context);
    final shimmerColor = theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.30);
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, child) {
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              shimmerColor,
              Colors.transparent,
            ],
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

/// Wraps content and ensures skeleton loading is shown
/// for at least [minimumDuration] to prevent flicker.
class SkeletonLoader extends StatefulWidget {
  final bool isLoading;
  final Widget skeleton;
  final Widget child;
  final Duration minimumDuration;

  const SkeletonLoader({
    super.key,
    required this.isLoading,
    required this.skeleton,
    required this.child,
    this.minimumDuration = const Duration(milliseconds: 300),
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader> {
  bool _showSkeleton = true;

  @override
  void didUpdateWidget(SkeletonLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading) {
      _showSkeleton = true;
    } else if (!widget.isLoading && oldWidget.isLoading && _showSkeleton) {
      Future.delayed(widget.minimumDuration, () {
        if (mounted && !widget.isLoading) {
          setState(() => _showSkeleton = false);
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _showSkeleton = widget.isLoading;
  }

  @override
  Widget build(BuildContext context) {
    return _showSkeleton ? widget.skeleton : widget.child;
  }
}
