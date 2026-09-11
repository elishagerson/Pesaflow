import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';

class BudjetlyBalanceHeader extends StatefulWidget {
  final int balance;
  final String label;
  final int income;
  final int expense;
  final VoidCallback? onAccountTap;

  const BudjetlyBalanceHeader({
    super.key,
    required this.balance,
    required this.label,
    required this.income,
    required this.expense,
    this.onAccountTap,
  });

  @override
  State<BudjetlyBalanceHeader> createState() => _BudjetlyBalanceHeaderState();
}

class _BudjetlyBalanceHeaderState extends State<BudjetlyBalanceHeader>
    with TickerProviderStateMixin {
  bool _isHidden = false;

  // Animated balance (odometer)
  late final List<AnimationController> _digitControllers;
  late final List<Animation<double>> _digitAnimations;
  int _previousBalance = 0;
  bool _isInitialBuild = true;

  // Gradient shimmer
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAnimation;

  // Balance-change color highlight
  late final AnimationController _highlightController;
  late final Animation<double> _highlightAnimation;

  @override
  void initState() {
    super.initState();

    // Digit odometer controllers
    _digitControllers = List.generate(20, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 700 + (9 - (i % 10)) * 35),
      );
    });
    _digitAnimations = List.generate(20, (i) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _digitControllers[i],
          curve: Curves.easeOutCubic,
        ),
      );
    });

    // Shimmer sweep — single forward sweep on change
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _shimmerAnimation = Tween<double>(begin: -0.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // Balance-change highlight flash
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _highlightAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _highlightController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _previousBalance = widget.balance;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDigitAnimations(forceInitial: true);
    });
  }

  @override
  void dispose() {
    for (final c in _digitControllers) {
      c.dispose();
    }
    _shimmerController.dispose();
    _highlightController.dispose();
    super.dispose();
  }

  void _initDigitAnimations({bool forceInitial = false}) {
    if (context.isReducedMotion) return;
    final digits = _balanceDigits(widget.balance);
    for (var i = 0; i < digits.length && i < _digitControllers.length; i++) {
      final d = digits[i];
      if (forceInitial && !_isInitialBuild) {
        _digitControllers[i].value = d / 9.0;
      }
      Future.delayed(Duration(milliseconds: 50 + i * 60), () {
        if (mounted) {
          _digitControllers[i].animateTo(
            d / 9.0,
            duration: Duration(milliseconds: 650 + (9 - d) * 35),
          );
        }
      });
    }
    _isInitialBuild = false;
    _startShimmer();
  }

  void _startShimmer() {
    if (context.isReducedMotion) return;
    _shimmerController.forward(from: 0.0);
  }

  List<int> _balanceDigits(int balance) {
    final text = CurrencyFormatter.formatCents(balance.abs());
    return text
        .split('')
        .where((c) => RegExp(r'^\d$').hasMatch(c))
        .map(int.parse)
        .toList();
  }

  List<String> _formatBalanceDigits(int balance) {
    final text = CurrencyFormatter.formatCents(balance.abs());
    return text.split('');
  }

  @override
  void didUpdateWidget(covariant BudjetlyBalanceHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.balance != widget.balance) {
      _previousBalance = oldWidget.balance;
      _initDigitAnimations();
      if (!_isInitialBuild && !context.isReducedMotion) {
        _highlightController.forward(from: 0.0);
        _startShimmer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _highlightAnimation,
      builder: (context, _) {
        final highlightValue = _highlightAnimation.value;
        final Color highlightTint;
        if (highlightValue > 0) {
          final isIncome = widget.balance >= _previousBalance;
          final baseColor = isIncome
              ? context.appColors.incomeColor
              : context.appColors.expenseColor;
          highlightTint = baseColor.withValues(alpha: highlightValue * 0.12);
        } else {
          highlightTint = Colors.transparent;
        }

        final baseBgColor = theme.colorScheme.surfaceContainerHigh;
        final cardColor = Color.lerp(
          baseBgColor,
          highlightTint,
          highlightValue > 0 ? 1.0 : 0.0,
        )!;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusDialog),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: context.appColors.shadowMedium,
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Ambient gradient shimmer sweep
              if (!context.isReducedMotion)
                AnimatedBuilder(
                  animation: _shimmerAnimation,
                  builder: (context, _) {
                    final t = _shimmerAnimation.value;
                    return Positioned.fill(
                      child: IgnorePointer(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radiusDialog),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(-1.0 + t * 2, -0.6),
                                end: Alignment(-0.2 + t * 2, 0.6),
                                colors: [
                                  Colors.transparent,
                                  context.appColors.textLow.withValues(alpha: 0.035),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              // Card content
              Padding(
                padding: const EdgeInsets.all(kSpacing20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Label + Eye toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: kSpacing8),
                            Text(
                              widget.label.toUpperCase(),
                              style: context.ts(
                                11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            PesaHaptics.light();
                            setState(() {
                              _isHidden = !_isHidden;
                            });
                          },
                          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                          child: Padding(
                            padding: const EdgeInsets.all(kSpacing6),
                            child: Icon(
                              _isHidden
                                  ? PesaFlowIcons.visibilityOff
                                  : PesaFlowIcons.visibility,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: kSpacing12),

                    // Center: Total Balance
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _isHidden
                          ? Text(
                              '••••••',
                              style: context.ts(
                                34,
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -0.8,
                              ),
                            )
                          : context.isReducedMotion
                          ? Text(
                              CurrencyFormatter.formatCents(widget.balance),
                              style: context.ts(
                                34,
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -0.8,
                              ),
                            )
                          : _buildAnimatedDigits(theme),
                    ),
                    const SizedBox(height: kSpacing18),

                    // Divider
                    Divider(
                      height: 1,
                      thickness: 0.8,
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.22),
                    ),
                    const SizedBox(height: kSpacing14),

                    // Bottom: Monthly Cash Flow (Income vs Spent)
                    Row(
                      children: [
                        // Total In
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: context.appColors.incomeColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  PesaFlowIcons.arrowDown,
                                  size: 14,
                                  color: context.appColors.incomeColor,
                                ),
                              ),
                              const SizedBox(width: kSpacing10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Income',
                                      style: context.ts(
                                        11,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      _isHidden
                                          ? '••••'
                                          : CurrencyFormatter.formatCents(widget.income),
                                      style: context.ts(
                                        13,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Vertical divider
                        Container(
                          width: 1,
                          height: 28,
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.22),
                          margin: const EdgeInsets.symmetric(horizontal: kSpacing12),
                        ),
                        // Total Out
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: context.appColors.expenseColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  PesaFlowIcons.arrowUp,
                                  size: 14,
                                  color: context.appColors.expenseColor,
                                ),
                              ),
                              const SizedBox(width: kSpacing10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Spent',
                                      style: context.ts(
                                        11,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      _isHidden
                                          ? '••••'
                                          : CurrencyFormatter.formatCents(widget.expense),
                                      style: context.ts(
                                        13,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnimatedDigits(ThemeData theme) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ..._digitControllers,
        _highlightAnimation,
      ]),
      builder: (context, _) {
        final chars = _formatBalanceDigits(widget.balance);
        int digitIdx = 0;
        final baseStyle = context.ts(
          34,
          fontWeight: FontWeight.w900,
          color: theme.colorScheme.onSurface,
          letterSpacing: -0.8,
        );

        Color textColor = theme.colorScheme.onSurface;
        if (_highlightAnimation.value > 0) {
          final isIncome = widget.balance >= _previousBalance;
          final flashColor = isIncome
              ? context.appColors.incomeColor
              : context.appColors.expenseColor;
          textColor = Color.lerp(
            theme.colorScheme.onSurface,
            flashColor,
            _highlightAnimation.value,
          )!;
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final char in chars)
              Builder(
                builder: (context) {
                  final isDigit = RegExp(r'^\d$').hasMatch(char);
                  final idx = isDigit ? digitIdx++ : -1;
                  if (!isDigit) {
                    return Text(
                      char,
                      style: baseStyle.copyWith(color: textColor),
                    );
                  }
                  final animCtrl = idx < _digitControllers.length
                      ? _digitControllers[idx]
                      : null;
                  final animVal = idx < _digitAnimations.length
                      ? _digitAnimations[idx]
                      : null;
                  final isAnimating = animCtrl?.isAnimating ?? false;
                  final isComplete = animCtrl?.isCompleted ?? false;
                  if (!isAnimating && isComplete) {
                    return Text(
                      char,
                      style: baseStyle.copyWith(color: textColor),
                    );
                  }
                  return AnimatedBuilder(
                    animation: animVal!,
                    builder: (context, _) {
                      final spinDigit = (animVal.value * 9).round();
                      return SizedBox(
                        width: 24,
                        child: ClipRect(
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(
                                0,
                                (spinDigit == 0 && isAnimating) ? -1 : 0,
                              ),
                              end: Offset.zero,
                            ).animate(animVal),
                            child: Text(
                              '$spinDigit',
                              style: baseStyle.copyWith(
                                color: textColor,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
