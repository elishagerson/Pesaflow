import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/state/insight_provider.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';

class MorphingInsightCard extends StatefulWidget {
  final InsightData data;
  final int index;
  final bool? expanded;
  final VoidCallback? onTap;

  const MorphingInsightCard({
    super.key,
    required this.data,
    this.index = 0,
    this.expanded,
    this.onTap,
  });

  @override
  State<MorphingInsightCard> createState() => _MorphingInsightCardState();
}

class _MorphingInsightCardState extends State<MorphingInsightCard>
    with TickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  late AnimationController _counterController;

  @override
  void initState() {
    super.initState();
    _expanded = widget.expanded ?? false;
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    if (_expanded) {
      _expandController.value = 1.0;
    }

    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.index * 80), () {
      if (mounted) _counterController.forward();
    });
  }

  @override
  void didUpdateWidget(covariant MorphingInsightCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != null && widget.expanded != oldWidget.expanded) {
      _expanded = widget.expanded!;
      if (_expanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    _counterController.dispose();
    super.dispose();
  }

  Severity _computeSeverity() {
    final s = widget.data.subtitle.toLowerCase();
    if (s.contains('higher') || s.contains('up ') || s.contains('increased')) {
      return Severity.warning;
    }
    if (s.contains('lower') || s.contains('down ') || s.contains('decreased')) {
      return Severity.good;
    }
    return Severity.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.data.color;
    final severity = _computeSeverity();

    return TactileSpringContainer(
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!();
        } else {
          setState(() => _expanded = !_expanded);
          if (_expanded) {
            _expandController.forward();
          } else {
            _expandController.reverse();
          }
        }
      },
      child: AnimatedBuilder(
        animation: _expandAnimation,
        builder: (context, _) {
          final glowOpacity = 0.08 + _expandAnimation.value * 0.12;

          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: kSpacing12),
            decoration: BoxDecoration(
              color: context.appColors.surfaceHigh,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              border: Border.all(
                color: color.withValues(
                  alpha: 0.2 + _expandAnimation.value * 0.2,
                ),
                width: 0.5 + _expandAnimation.value * 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: glowOpacity),
                  blurRadius: 12 + _expandAnimation.value * 16,
                  spreadRadius: _expandAnimation.value * 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              child: Stack(
                children: [
                  // Severity gradient bar at top
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 3 + _expandAnimation.value * 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _severityGradient(severity),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(kSpacing16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(kSpacing6),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSmall,
                                ),
                              ),
                              child: PulseIcon(
                                icon: widget.data.icon,
                                color: color,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: kSpacing8),
                            Expanded(
                              child: Text(
                                widget.data.title,
                                style: context.ts(
                                  14,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Severity badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _severityColor(
                                  severity,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _severityIcon(severity),
                                    size: 10,
                                    color: _severityColor(severity),
                                  ),
                                  const SizedBox(width: kSpacing4),
                                  Text(
                                    _severityLabel(severity),
                                    style: context.ts(
                                      9,
                                      fontWeight: FontWeight.w700,
                                      color: _severityColor(severity),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: kSpacing8),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.data.subtitle,
                                style: context.ts(
                                  13,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                                maxLines: _expanded ? 5 : 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_expanded)
                                FadeTransition(
                                  opacity: _expandAnimation,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      top: kSpacing8,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Divider(height: 1),
                                        const SizedBox(height: kSpacing8),
                                        _buildDetailRow(
                                          PesaFlowIcons.income,
                                          'Category trend',
                                          'Based on your spending in this category',
                                        ),
                                        const SizedBox(height: kSpacing4),
                                        _buildDetailRow(
                                          PesaFlowIcons.calendar,
                                          'Time period',
                                          'This month vs last month',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: kSpacing6),
        Text(
          label,
          style: context.ts(
            11,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(width: kSpacing8),
        Expanded(
          child: Text(
            value,
            style: context.ts(
              11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  List<Color> _severityGradient(Severity s) {
    switch (s) {
      case Severity.good:
        return [context.appColors.incomeColor, AppTheme.incomeColorDark];
      case Severity.warning:
        return [context.appColors.expenseColor, AppTheme.expenseColorDark];
      case Severity.neutral:
        return [AppTheme.transferColor, AppTheme.transferColorDark];
    }
  }

  Color _severityColor(Severity s) {
    switch (s) {
      case Severity.good:
        return context.appColors.incomeColor;
      case Severity.warning:
        return context.appColors.expenseColor;
      case Severity.neutral:
        return AppTheme.transferColor;
    }
  }

  IconData _severityIcon(Severity s) {
    switch (s) {
      case Severity.good:
        return PesaFlowIcons.arrowDown;
      case Severity.warning:
        return PesaFlowIcons.arrowUp;
      case Severity.neutral:
        return PesaFlowIcons.remove;
    }
  }

  String _severityLabel(Severity s) {
    switch (s) {
      case Severity.good:
        return 'GOOD';
      case Severity.warning:
        return 'UP';
      case Severity.neutral:
        return 'FLAT';
    }
  }
}

enum Severity { good, warning, neutral }

class PulseIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const PulseIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 18,
  });

  @override
  State<PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<PulseIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulse = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      if (!context.isReducedMotion) {
        _controller.repeat(reverse: true);
      } else {
        _controller.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.isReducedMotion) {
      return Icon(widget.icon, size: widget.size, color: widget.color);
    }
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Transform.scale(scale: _pulse.value, child: child);
      },
      child: Icon(widget.icon, size: widget.size, color: widget.color),
    );
  }
}
