import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';

class EmptyState extends StatefulWidget {
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
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with TickerProviderStateMixin {
  // Entrance: spring scale from 0.8 → 1.0
  late AnimationController _entranceController;
  late Animation<double> _entranceScale;

  // Idle breathing: slow scale oscillation 1.0 → 1.02 → 1.0
  late AnimationController _breathController;
  late Animation<double> _breathScale;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _entranceScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutBack,
      ),
    );

    // Breathing: subtle scale oscillation, 3s full cycle
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _breathScale = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(
        parent: _breathController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    if (context.isReducedMotion) {
      _entranceController.value = 1.0;
      // No breathing animation
    } else {
      // Entrance spring — starts after first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _entranceController.forward().then((_) {
          // Begin breathing after entrance completes
          if (mounted) {
            _breathController.repeat(reverse: true);
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final illustration = widget.illustration ??
        Semantics(
          excludeSemantics: true,
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: theme.colorScheme.primary.withValues(alpha: 0.4),
          ),
        );

    final animatedIllustration = context.isReducedMotion
        ? illustration
        : AnimatedBuilder(
            animation: Listenable.merge([_entranceController, _breathController]),
            builder: (context, child) {
              // Combine entrance scale and breath scale
              final combinedScale = _entranceScale.value * _breathScale.value;
              return Transform.scale(
                scale: combinedScale,
                child: child,
              );
            },
            child: illustration,
          );

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.isCompactView ? 24 : 48,
          vertical: 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AnimatedEntranceWrapper(
              entranceController: _entranceController,
              child: animatedIllustration,
            ),
            SizedBox(height: context.isCompactView ? 16 : 24),
            _DelayedFadeIn(
              delay: const Duration(milliseconds: 300),
              child: Semantics(
                header: true,
                child: Text(
                  widget.title,
                  style: context.ts(
                    16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
            if (widget.subtitle != null) ...[
              SizedBox(height: context.isCompactView ? 8 : 12),
              _DelayedFadeIn(
                delay: const Duration(milliseconds: 500),
                child: Text(
                  widget.subtitle!,
                  style: context.ts(
                    13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (widget.action != null) ...[
              SizedBox(height: context.isCompactView ? 20 : 28),
              _DelayedFadeIn(
                delay: const Duration(milliseconds: 700),
                child: widget.action!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Wraps the illustration with a fade-in tied to the entrance controller.
/// The illustration fades in from 0 opacity as it springs to scale 1.0.
class _AnimatedEntranceWrapper extends StatelessWidget {
  final AnimationController entranceController;
  final Widget child;

  const _AnimatedEntranceWrapper({
    required this.entranceController,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: entranceController,
      builder: (context, child) {
        final opacity = entranceController.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: child,
        );
      },
      child: child,
    );
  }
}

/// Fades in text after a configurable delay.
/// On reduced motion, appears instantly.
class _DelayedFadeIn extends StatefulWidget {
  final Duration delay;
  final Widget child;

  const _DelayedFadeIn({
    required this.delay,
    required this.child,
  });

  @override
  State<_DelayedFadeIn> createState() => _DelayedFadeInState();
}

class _DelayedFadeInState extends State<_DelayedFadeIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (context.isReducedMotion) {
      _controller.value = 1.0;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: widget.child,
    );
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
              style: context.ts(
                16,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const Spacer(),
          if (actionLabel != null && onAction != null)
            Semantics(
              button: true,
              child: TactileSpringContainer(
                onTap: onAction,
                child: Padding(
                  padding: const EdgeInsets.all(kSpacing8),
                  child: Text(
                    actionLabel!,
                    style: context.ts(
                      13,
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
