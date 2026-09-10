import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/app_colors_theme.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/utils/spacing.dart';

class AmountSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;
  final String currency;
  final Color? accentColor;

  const AmountSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.step = 100,
    required this.onChanged,
    this.currency = 'TSh',
    this.accentColor,
  });

  @override
  State<AmountSlider> createState() => _AmountSliderState();
}

class _AmountSliderState extends State<AmountSlider> {
  double _previousValue = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
  }

  @override
  void didUpdateWidget(AmountSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
    }
  }

  void _fireHaptics(double oldValue, double newValue) {
    final oldStep = (oldValue / widget.step).round();
    final newStep = (newValue / widget.step).round();
    if (oldStep == newStep) return;

    final oldThousands = (oldValue / 10000).floor();
    final newThousands = (newValue / 10000).floor();
    if (oldThousands != newThousands) {
      PesaHaptics.medium();
    } else {
      PesaHaptics.selection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = context.appColors;
    final isDark = context.isDark;
    final accent = widget.accentColor ?? theme.colorScheme.primary;
    final reducedMotion = context.isReducedMotion;

    final clampedValue = widget.value.clamp(widget.min, widget.max);

    return Container(
      padding: const EdgeInsets.all(kSpacing20),
      decoration: BoxDecoration(
        color: appColors.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusHero),
        border: Border.all(
          color: appColors.cardBorder.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: appColors.shadowSubtle,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AmountDisplay(
            value: clampedValue,
            previousValue: _previousValue,
            currency: widget.currency,
            accentColor: accent,
            reducedMotion: reducedMotion,
          ),
          const SizedBox(height: kSpacing20),
          _SliderTrack(
            value: clampedValue,
            min: widget.min,
            max: widget.max,
            step: widget.step,
            accentColor: accent,
            isDark: isDark,
            isDragging: _isDragging,
            onChanged: (v) {
              final snapped = (v / widget.step).round() * widget.step;
              final clamped = snapped.clamp(widget.min, widget.max);
              _fireHaptics(widget.value, clamped);
              widget.onChanged(clamped.toDouble());
            },
            onDragStart: () => setState(() => _isDragging = true),
            onDragEnd: () => setState(() => _isDragging = false),
          ),
          const SizedBox(height: kSpacing8),
          _StepLabels(
            min: widget.min,
            max: widget.max,
            step: widget.step,
            accentColor: accent,
          ),
        ],
      ),
    );
  }
}

// ── Animated Amount Display ──────────────────────────────────────────────

class _AmountDisplay extends StatelessWidget {
  final double value;
  final double previousValue;
  final String currency;
  final Color accentColor;
  final bool reducedMotion;

  const _AmountDisplay({
    required this.value,
    required this.previousValue,
    required this.currency,
    required this.accentColor,
    required this.reducedMotion,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final amountStr = _formatAmount(value);
    final currencyStr = currency.isNotEmpty ? '$currency ' : '';

    if (reducedMotion) {
      return _buildStaticAmount(context, currencyStr, amountStr, appColors);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) {
        final isNew = child.key == ValueKey(amountStr);
        return isNew
            ? FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, 0.15),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                  child: child,
                ),
              )
            : child;
      },
      child: Row(
        key: ValueKey(amountStr),
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            currencyStr,
            style: context
                .ts(14, fontWeight: FontWeight.w500)
                .copyWith(color: appColors.textLow),
          ),
          const SizedBox(width: kSpacing4),
          _SlidingDigits(
            value: amountStr,
            accentColor: accentColor,
            reducedMotion: reducedMotion,
          ),
        ],
      ),
    );
  }

  Widget _buildStaticAmount(
    BuildContext context,
    String currencyStr,
    String amountStr,
    AppColorsTheme appColors,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          currencyStr,
          style: context
              .ts(14, fontWeight: FontWeight.w500)
              .copyWith(color: appColors.textLow),
        ),
        const SizedBox(width: kSpacing4),
        Text(
          amountStr,
          style: context
              .ts(32, fontWeight: FontWeight.w700)
              .copyWith(
                color: accentColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
      ],
    );
  }

  String _formatAmount(double value) {
    final absVal = value.abs();
    final formatted = absVal >= 10000
        ? _commaFormat(absVal.round())
        : absVal >= 1000
        ? _commaFormat(absVal.round())
        : absVal.toInt().toString();
    return formatted;
  }

  String _commaFormat(int value) {
    final str = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return buf.toString();
  }
}

// ── Sliding Digit Animation ─────────────────────────────────────────────

class _SlidingDigits extends StatefulWidget {
  final String value;
  final Color accentColor;
  final bool reducedMotion;

  const _SlidingDigits({
    required this.value,
    required this.accentColor,
    required this.reducedMotion,
  });

  @override
  State<_SlidingDigits> createState() => _SlidingDigitsState();
}

class _SlidingDigitsState extends State<_SlidingDigits> {
  String _previousValue = '';

  @override
  void didUpdateWidget(_SlidingDigits oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentChars = widget.value.split('');
    final previousChars = _previousValue.isNotEmpty
        ? _previousValue.split('')
        : List<String>.filled(currentChars.length, '');

    // Pad shorter list to match lengths
    while (previousChars.length < currentChars.length) {
      previousChars.insert(0, '');
    }

    final displayChars = math.max(currentChars.length, previousChars.length);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: List.generate(displayChars, (i) {
        final current = i < currentChars.length ? currentChars[i] : '';
        final previous = i < previousChars.length ? previousChars[i] : '';

        final isComma = current == ',';

        if (isComma) {
          return Text(
            ',',
            style: context
                .ts(32, fontWeight: FontWeight.w700)
                .copyWith(
                  color: widget.accentColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          );
        }

        if (widget.reducedMotion || previous == current) {
          return Text(
            current,
            style: context
                .ts(32, fontWeight: FontWeight.w700)
                .copyWith(
                  color: widget.accentColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          );
        }

        return _DigitTransition(
          key: ValueKey('$i-$current'),
          digit: current,
          accentColor: widget.accentColor,
        );
      }),
    );
  }
}

class _DigitTransition extends StatefulWidget {
  final String digit;
  final Color accentColor;

  const _DigitTransition({
    required this.digit,
    required this.accentColor,
    super.key,
  });

  @override
  State<_DigitTransition> createState() => _DigitTransitionState();
}

class _DigitTransitionState extends State<_DigitTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(_DigitTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.digit != widget.digit) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final eased = Curves.easeOutCubic.transform(_controller.value);
        final slideOffset = (1.0 - eased) * 16.0;
        return Opacity(
          opacity: _controller.value,
          child: Transform.translate(
            offset: Offset(0, slideOffset),
            child: Text(
              widget.digit,
              style: context
                  .ts(32, fontWeight: FontWeight.w700)
                  .copyWith(
                    color: widget.accentColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ),
        );
      },
    );
  }
}

// ── Custom Slider Track & Thumb ─────────────────────────────────────────

class _SliderTrack extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final Color accentColor;
  final bool isDark;
  final bool isDragging;
  final ValueChanged<double> onChanged;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  const _SliderTrack({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.accentColor,
    required this.isDark,
    required this.isDragging,
    required this.onChanged,
    required this.onDragStart,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final range = max - min;
    final normalized = range > 0 ? (value - min) / range : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final thumbRadius = isDragging ? 12.0 : 10.0;
        final thumbX = normalized * trackWidth;

        return GestureDetector(
          onHorizontalDragStart: (details) {
            onDragStart();
            _handleDrag(details.localPosition.dx, trackWidth);
          },
          onHorizontalDragUpdate: (details) {
            _handleDrag(details.localPosition.dx, trackWidth);
          },
          onHorizontalDragEnd: (_) => onDragEnd(),
          onTapDown: (details) {
            onDragStart();
            _handleDrag(details.localPosition.dx, trackWidth);
          },
          onTapUp: (_) => onDragEnd(),
          child: SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Track background
                Positioned(
                  left: 0,
                  right: 0,
                  top: 14,
                  bottom: 14,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(kSpacing4),
                    ),
                  ),
                ),
                // Track fill
                Positioned(
                  left: 0,
                  top: 14,
                  bottom: 14,
                  width: math.max(0, thumbX),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.7),
                          accentColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(kSpacing4),
                    ),
                  ),
                ),
                // Step tick marks
                ..._buildTickMarks(trackWidth, context),
                // Thumb
                Positioned(
                  left: thumbX - thumbRadius,
                  top: 20 - thumbRadius,
                  child: _GlassThumb(
                    radius: thumbRadius,
                    isDragging: isDragging,
                    accentColor: accentColor,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleDrag(double dx, double trackWidth) {
    final normalized = (dx / trackWidth).clamp(0.0, 1.0);
    final range = max - min;
    final rawValue = min + (normalized * range);
    final snapped = (rawValue / step).round() * step;
    final clamped = snapped.clamp(min, max);
    onChanged(clamped.toDouble());
  }

  List<Widget> _buildTickMarks(double trackWidth, BuildContext context) {
    final appColors = context.appColors;
    final range = max - min;
    if (range <= 0) return [];

    final ticks = <Widget>[];
    final tickInterval = _calculateTickInterval();
    var tick = (min / tickInterval).ceil() * tickInterval;

    while (tick <= max) {
      final normalized = (tick - min) / range;
      final x = normalized * trackWidth;
      final isMajor = tick % 10000 == 0;

      ticks.add(
        Positioned(
          left: x - 0.5,
          top: 0,
          bottom: 0,
          child: Container(
            width: 1,
            color: isMajor
                ? appColors.textLow.withValues(alpha: 0.4)
                : appColors.textLow.withValues(alpha: 0.15),
          ),
        ),
      );

      tick += tickInterval;
    }

    return ticks;
  }

  double _calculateTickInterval() {
    final range = max - min;
    if (range <= 500) return step > 0 ? step : 100;
    if (range <= 5000) return 500;
    if (range <= 50000) return 1000;
    if (range <= 200000) return 5000;
    return 10000;
  }
}

// ── Glassmorphic Thumb ──────────────────────────────────────────────────

class _GlassThumb extends StatelessWidget {
  final double radius;
  final bool isDragging;
  final Color accentColor;
  final bool isDark;

  const _GlassThumb({
    required this.radius,
    required this.isDragging,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark
                ? Colors.white.withValues(alpha: isDragging ? 0.30 : 0.22)
                : Colors.white.withValues(alpha: isDragging ? 0.95 : 0.90),
            isDark
                ? Colors.white.withValues(alpha: isDragging ? 0.15 : 0.10)
                : Colors.white.withValues(alpha: isDragging ? 0.80 : 0.70),
          ],
        ),
        border: Border.all(
          color: isDragging
              ? accentColor.withValues(alpha: 0.6)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.20)
                    : Colors.white.withValues(alpha: 0.50)),
          width: isDragging ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDragging ? 0.35 : 0.15),
            blurRadius: isDragging ? 12 : 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: radius * 0.7,
          height: radius * 0.7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDragging
                ? accentColor.withValues(alpha: 0.8)
                : accentColor.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

// ── Step Labels ─────────────────────────────────────────────────────────

class _StepLabels extends StatelessWidget {
  final double min;
  final double max;
  final double step;
  final Color accentColor;

  const _StepLabels({
    required this.min,
    required this.max,
    required this.step,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _formatCompact(min),
          style: context.ts(10).copyWith(color: appColors.textLow),
        ),
        Text(
          _formatCompact(max),
          style: context.ts(10).copyWith(color: appColors.textLow),
        ),
      ],
    );
  }

  String _formatCompact(double value) {
    final absVal = value.abs();
    if (absVal >= 1000000) {
      return '${(absVal / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    }
    if (absVal >= 1000) {
      return '${(absVal / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    }
    return absVal.toInt().toString();
  }
}
