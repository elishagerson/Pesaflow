import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final double iconSize;
  final Widget? illustration;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.iconSize = 64,
    this.illustration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.isCompactView ? 24 : 48,
          vertical: 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AnimatedEmptyIllustration(
              child:
                  illustration ??
                  Semantics(
                    excludeSemantics: true,
                    child: Icon(
                      icon,
                      size: iconSize,
                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                    ),
                  ),
            ),
            SizedBox(height: context.isCompactView ? 16 : 24),
            Semantics(
              header: true,
              child: Text(
                title,
                style: context.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: context.isCompactView ? 8 : 12),
              Text(
                subtitle!,
                style: context.bodySmall.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              SizedBox(height: context.isCompactView ? 20 : 28),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _AnimatedEmptyIllustration extends StatefulWidget {
  final Widget child;

  const _AnimatedEmptyIllustration({required this.child});

  @override
  State<_AnimatedEmptyIllustration> createState() =>
      _AnimatedEmptyIllustrationState();
}

class _AnimatedEmptyIllustrationState extends State<_AnimatedEmptyIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuad),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _animation, child: widget.child);
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding:
          padding ??
          EdgeInsets.symmetric(horizontal: context.spacing, vertical: 8),
      child: Row(
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: context.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const Spacer(),
          if (actionLabel != null && onAction != null)
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: onAction,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    actionLabel!,
                    style: context.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
