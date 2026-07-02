import 'package:flutter/material.dart';

class ShimmerCard extends StatefulWidget {
  final double height;
  final double width;
  final double borderRadius;
  final List<double> barHeights;
  final List<double> barWidths;
  final Widget? leading;
  final Widget? trailing;

  const ShimmerCard({
    super.key,
    this.height = 100,
    this.width = double.infinity,
    this.borderRadius = 20,
    this.barHeights = const [14, 10, 10],
    this.barWidths = const [120, double.infinity, 180],
    this.leading,
    this.trailing,
  });

  @override
  State<ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<ShimmerCard>
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
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark
        ? theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5)
        : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.6);

    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: _ShimmerEffect(
        animation: _animation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.barHeights.length, (i) {
                    final widths = widget.barWidths;
                    final w = i < widths.length ? widths[i] : double.infinity;
                    final h = i < widget.barHeights.length
                        ? widget.barHeights[i]
                        : 10.0;
                    return Padding(
                      padding: EdgeInsets.only(top: i > 0 ? h * 0.6 : 0),
                      child: _pulseBar(width: w, height: h),
                    );
                  }),
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 12),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _pulseBar({double width = 80, double height = 12}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

class ShimmerCircle extends StatelessWidget {
  final double size;
  const ShimmerCircle({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5)
            : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
      ),
    );
  }
}

class _ShimmerEffect extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  const _ShimmerEffect({required this.child, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) {
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [
              Colors.transparent,
              Colors.white24,
              Colors.transparent,
            ],
            stops: [
              animation.value - 0.3,
              animation.value,
              animation.value + 0.3,
            ],
          ).createShader(bounds),
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: child,
    );
  }
}
