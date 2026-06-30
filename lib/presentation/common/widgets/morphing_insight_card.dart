import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/state/insight_provider.dart';

class MorphingInsightCard extends StatefulWidget {
  final InsightData data;
  final int index;

  const MorphingInsightCard({
    super.key,
    required this.data,
    this.index = 0,
  });

  @override
  State<MorphingInsightCard> createState() => _MorphingInsightCardState();
}

class _MorphingInsightCardState extends State<MorphingInsightCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  late AnimationController _counterController;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.index * 80), () {
      if (mounted) _counterController.forward();
    });
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

  String _extractAmount(String s) {
    final re = RegExp(r'Tsh\s[\d,]+');
    final match = re.firstMatch(s);
    return match?.group(0) ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = widget.data.color;
    final severity = _computeSeverity();

    return GestureDetector(
      onTap: () {
        setState(() => _expanded = !_expanded);
        if (_expanded) {
          _expandController.forward();
        } else {
          _expandController.reverse();
        }
      },
      child: AnimatedBuilder(
        animation: _expandAnimation,
        builder: (context, _) {
          final expandedHeight = 120.0 + _expandAnimation.value * 60;
          final glowOpacity = 0.08 + _expandAnimation.value * 0.12;

          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: kSpacing12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withValues(alpha: 0.2 + _expandAnimation.value * 0.2),
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
              borderRadius: BorderRadius.circular(16),
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
                          colors: _severityGradient(severity, isDark),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(kSpacing16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(kSpacing6),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
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
                                style: theme.textTheme.labelLarge?.copyWith(
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
                                color: _severityColor(severity).withValues(
                                  alpha: 0.12,
                                ),
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
                                  const SizedBox(width: 3),
                                  Text(
                                    _severityLabel(severity),
                                    style: TextStyle(
                                      fontSize: 9,
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
                        Text(
                          widget.data.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                          maxLines: _expanded ? 5 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Expanded detail area
                        if (_expanded)
                          Padding(
                            padding: const EdgeInsets.only(top: kSpacing8),
                            child: AnimatedOpacity(
                              opacity: _expandAnimation.value,
                              duration: Duration.zero,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(height: 1),
                                  const SizedBox(height: kSpacing8),
                                  _buildDetailRow(
                                    Icons.trending_up_rounded,
                                    'Category trend',
                                    'Based on your spending in this category',
                                    isDark,
                                  ),
                                  const SizedBox(height: kSpacing4),
                                  _buildDetailRow(
                                    Icons.calendar_month_rounded,
                                    'Time period',
                                    'This month vs last month',
                                    isDark,
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
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    bool isDark,
  ) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: kSpacing6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  List<Color> _severityGradient(Severity s, bool isDark) {
    switch (s) {
      case Severity.good:
        return [const Color(0xFF10B981), const Color(0xFF34D399)];
      case Severity.warning:
        return [const Color(0xFFF59E0B), const Color(0xFFFBBF24)];
      case Severity.neutral:
        return [const Color(0xFF6366F1), const Color(0xFF818CF8)];
    }
  }

  Color _severityColor(Severity s) {
    switch (s) {
      case Severity.good:
        return const Color(0xFF10B981);
      case Severity.warning:
        return const Color(0xFFF59E0B);
      case Severity.neutral:
        return const Color(0xFF6366F1);
    }
  }

  IconData _severityIcon(Severity s) {
    switch (s) {
      case Severity.good:
        return Icons.arrow_downward_rounded;
      case Severity.warning:
        return Icons.arrow_upward_rounded;
      case Severity.neutral:
        return Icons.remove_rounded;
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
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
      animation: _pulse,
      builder: (context, _) {
        return Transform.scale(
          scale: _pulse.value,
          child: Icon(widget.icon, size: widget.size, color: widget.color),
        );
      },
    );
  }
}
