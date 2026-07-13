import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';

enum ToastType { success, error, info }

class CustomToast {
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        type: type,
        onDismiss: () {
          overlayEntry.remove();
        },
        duration: duration,
      ),
    );

    overlayState.insert(overlayEntry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;
  final Duration duration;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Physics-based spring simulation for premium entry feel
    final spring = SpringDescription(
      mass: 0.6,      // lightweight
      stiffness: 180, // snappy
      damping: 14,    // smooth bounce
    );
    final simulation = SpringSimulation(spring, 0.0, 1.0, 0.0);
    _controller.animateWith(simulation);

    _timer = Timer(widget.duration, () {
      _dismiss();
    });
  }

  void _dismiss() {
    if (mounted) {
      // Snappy slide-out transition
      _controller.animateTo(0.0, duration: const Duration(milliseconds: 250), curve: Curves.easeInCubic).then((_) {
        widget.onDismiss();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final IconData icon = switch (widget.type) {
      ToastType.success => PesaFlowIcons.success,
      ToastType.error => PesaFlowIcons.error,
      ToastType.info => PesaFlowIcons.info,
    };

    final Color brandColor = switch (widget.type) {
      ToastType.success => context.appColors.incomeColor,
      ToastType.error => context.appColors.expenseColor,
      ToastType.info => theme.colorScheme.primary,
    };

    return Positioned(
      bottom: MediaQuery.paddingOf(context).bottom + kSpacing32,
      left: kSpacing24,
      right: kSpacing24,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            // Spring-based translate & scale curves
            final translateY = (1.0 - t) * 64.0;
            final scale = 0.85 + (0.15 * t);
            final opacity = t.clamp(0.0, 1.0);

            return Transform.translate(
              offset: Offset(0.0, translateY),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Center(
                    child: Material(
                      color: Colors.transparent,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: kSpacing20,
                              vertical: kSpacing12,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHigh.withValues(
                                alpha: theme.brightness == Brightness.dark ? 0.70 : 0.85,
                              ),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: brandColor.withValues(alpha: 0.15),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: brandColor.withValues(alpha: 0.08),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Snappy spring-scaled icon reveal
                                Transform.scale(
                                  scale: t.clamp(0.0, 1.0),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: brandColor.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      icon,
                                      color: brandColor,
                                      size: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: kSpacing10),
                                Flexible(
                                  child: Text(
                                    widget.message,
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
