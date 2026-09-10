import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/presentation/settings/settings_screen.dart';

class BudjetlyBalanceHeader extends StatefulWidget {
  final int balance;
  final String label;
  final int income;
  final int expense;

  const BudjetlyBalanceHeader({
    super.key,
    required this.balance,
    required this.label,
    required this.income,
    required this.expense,
  });

  @override
  State<BudjetlyBalanceHeader> createState() => _BudjetlyBalanceHeaderState();
}

class _BudjetlyBalanceHeaderState extends State<BudjetlyBalanceHeader>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;
  bool _isHidden = false;
  bool _firedMidFlipHaptic = false;

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
    _controller = AnimationController(
      vsync: this,
      duration: MotionTokens.durationSheet,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
    _animation.addListener(_checkMidFlipHaptic);

    // Digit odometer controllers — one per possible character in formatted string
    _digitControllers = List.generate(20, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 800 + (9 - (i % 10)) * 40),
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

    // Shimmer sweep — slow, continuous cycle
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
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

  void _checkMidFlipHaptic() {
    final angle = _animation.value * pi;
    if (!_firedMidFlipHaptic && angle >= pi / 2) {
      _firedMidFlipHaptic = true;
      PesaHaptics.light();
    }
  }

  @override
  void dispose() {
    _animation.removeListener(_checkMidFlipHaptic);
    _controller.dispose();
    for (final c in _digitControllers) {
      c.dispose();
    }
    _shimmerController.dispose();
    _highlightController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    PesaHaptics.light();
    _isFront = !_isFront;
    _firedMidFlipHaptic = false;
    if (context.isReducedMotion) {
      _controller.value = _isFront ? 0.0 : 1.0;
      return;
    }
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _initDigitAnimations({bool forceInitial = false}) {
    if (context.isReducedMotion) return;
    final digits = _balanceDigits(widget.balance);
    for (var i = 0; i < digits.length && i < _digitControllers.length; i++) {
      final d = digits[i];
      if (forceInitial && !_isInitialBuild) {
        _digitControllers[i].value = d / 9.0;
      }
      Future.delayed(Duration(milliseconds: 60 + i * 80), () {
        if (mounted) {
          _digitControllers[i].animateTo(
            d / 9.0,
            duration: Duration(milliseconds: 800 + (9 - d) * 40),
          );
        }
      });
    }
    _isInitialBuild = false;
    _startShimmer();
  }

  void _startShimmer() {
    if (context.isReducedMotion) return;
    if (!_shimmerController.isAnimating) {
      _shimmerController.repeat(reverse: true);
    }
  }

  /// Digit characters from the balance, skipping currency symbol and separators.
  List<int> _balanceDigits(int balance) {
    final text = CurrencyFormatter.formatCents(balance.abs());
    return text
        .split('')
        .where((c) => RegExp(r'^\d$').hasMatch(c))
        .map(int.parse)
        .toList();
  }

  /// Formatted balance split into characters for per-character rendering.
  List<String> _formatBalanceDigits(int balance) {
    final text = CurrencyFormatter.formatCents(balance.abs());
    return text.split('');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Balance details. Tap to flip between balance and account totals.',
      child: GestureDetector(
        onTap: _toggleFlip,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final angle = _animation.value * pi;
            final transform = Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(angle);

            // If rotated past 90 degrees (pi/2), show back side
            final isBackVisible = angle >= pi / 2;

            return Transform(
              transform: transform,
              alignment: Alignment.center,
              child: isBackVisible
                  ? Transform(
                      // Un-mirror the back side content
                      transform: Matrix4.identity()..rotateX(pi),
                      alignment: Alignment.center,
                      child: _buildCardSide(context, isFront: false),
                    )
                  : _buildCardSide(context, isFront: true),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCardSide(BuildContext context, {required bool isFront}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark
        ? const Color(0xFF1C1C1E)
        : theme.colorScheme.surface;

    return ClipPath(
      clipper: _TicketClipper(cutoutRadius: 12, cutoutOffset: 135),
      child: AnimatedBuilder(
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
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Color.lerp(
                cardColor,
                highlightTint,
                highlightValue > 0 ? 1.0 : 0.0,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusDialog),
              boxShadow: [
                BoxShadow(
                  color: context.appColors.shadowMedium,
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Gradient depth shimmer — subtle light sweep
                if (_isFront && !context.isReducedMotion)
                  AnimatedBuilder(
                    animation: _shimmerAnimation,
                    builder: (context, _) {
                      final t = _shimmerAnimation.value;
                      return Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(-1.0 + t * 2, -0.5),
                                end: Alignment(-0.2 + t * 2, 0.5),
                                colors: [
                                  Colors.transparent,
                                  context.appColors.textLow.withValues(
                                    alpha: 0.04,
                                  ),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                // Content
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Section
                    Container(
                      height: 135,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: isFront
                          ? _buildFrontTop(context)
                          : _buildBackTop(context),
                    ),

                    // Dashed Divider
                    Row(
                      children: [
                        const SizedBox(width: 12),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Flex(
                                direction: Axis.horizontal,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                mainAxisSize: MainAxisSize.max,
                                children: List.generate(
                                  (constraints.constrainWidth() / 8).floor(),
                                  (index) => Container(
                                    width: 4,
                                    height: 1,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),

                    // Bottom Section
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: isFront
                          ? _buildBottomButtons(context)
                          : _buildBottomButtons(context),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void didUpdateWidget(covariant BudjetlyBalanceHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.balance != widget.balance) {
      _previousBalance = oldWidget.balance;
      _initDigitAnimations();
      // Flash highlight for balance changes (skip initial load)
      if (!_isInitialBuild && !context.isReducedMotion) {
        _highlightController.forward(from: 0.0);
      }
    }
  }

  Widget _buildFrontTop(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.label,
                style: context.ts(
                  16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _isHidden
                          ? Text(
                              '••••••',
                              style: context.ts(
                                40,
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -1.0,
                              ),
                            )
                          : context.isReducedMotion
                          ? Text(
                              CurrencyFormatter.formatCents(widget.balance),
                              style: context.ts(
                                40,
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -1.0,
                              ),
                            )
                          : AnimatedBuilder(
                              animation: Listenable.merge([
                                ..._digitControllers,
                                _highlightAnimation,
                              ]),
                              builder: (context, _) {
                                final chars = _formatBalanceDigits(
                                  widget.balance,
                                );
                                int digitIdx = 0;
                                final baseStyle = context.ts(
                                  40,
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.onSurface,
                                  letterSpacing: -1.0,
                                );

                                // Balance-change highlight flash color
                                Color textColor = theme.colorScheme.onSurface;
                                if (_highlightAnimation.value > 0) {
                                  final isIncome =
                                      widget.balance >= _previousBalance;
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
                                          final isDigit = RegExp(
                                            r'^\d$',
                                          ).hasMatch(char);
                                          final idx = isDigit ? digitIdx++ : -1;
                                          if (!isDigit) {
                                            return Text(
                                              char,
                                              style: baseStyle.copyWith(
                                                color: textColor,
                                              ),
                                            );
                                          }
                                          final animCtrl =
                                              idx < _digitControllers.length
                                              ? _digitControllers[idx]
                                              : null;
                                          final animVal =
                                              idx < _digitAnimations.length
                                              ? _digitAnimations[idx]
                                              : null;
                                          final isAnimating =
                                              animCtrl?.isAnimating ?? false;
                                          final isComplete =
                                              animCtrl?.isCompleted ?? false;
                                          if (!isAnimating && isComplete) {
                                            return Text(
                                              char,
                                              style: baseStyle.copyWith(
                                                color: textColor,
                                              ),
                                            );
                                          }
                                          return AnimatedBuilder(
                                            animation: animVal!,
                                            builder: (context, _) {
                                              final spinDigit =
                                                  (animVal.value * 9).round();
                                              return SizedBox(
                                                width: 28,
                                                child: ClipRect(
                                                  child: SlideTransition(
                                                    position: Tween<Offset>(
                                                      begin: Offset(
                                                        0,
                                                        (spinDigit == 0 &&
                                                                isAnimating)
                                                            ? -1
                                                            : 0,
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
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: _isHidden ? 'Show balance' : 'Hide balance',
          onPressed: () {
            setState(() {
              _isHidden = !_isHidden;
            });
          },
          icon: Icon(
            _isHidden ? PesaFlowIcons.visibilityOff : PesaFlowIcons.visibility,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildBackTop(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Details',
          style: context.ts(
            16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: context.appColors.incomeColor.withValues(
                          alpha: 0.12,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        PesaFlowIcons.arrowDown,
                        size: 10,
                        color: context.appColors.incomeColor,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Total In',
                      style: context.ts(
                        13,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.formatCents(widget.income),
                  style: context.ts(
                    18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: context.appColors.expenseColor.withValues(
                          alpha: 0.12,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        PesaFlowIcons.arrowUp,
                        size: 10,
                        color: context.appColors.expenseColor,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Total Out',
                      style: context.ts(
                        13,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.formatCents(widget.expense),
                  style: context.ts(
                    18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: TactileSpringContainer(
            onTap: () {
              context.push('/transactions/add');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PesaFlowIcons.add,
                    color: theme.colorScheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Add Transaction',
                        style: context.ts(
                          14,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Consumer(
            builder: (context, ref, _) {
              return TactileSpringContainer(
                onTap: () {
                  SettingsScreen.showAccountsManager(context, ref);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.4,
                      ),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PesaFlowIcons.wallet,
                        color: theme.colorScheme.onSurface,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Accounts',
                            style: context.ts(
                              14,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TicketClipper extends CustomClipper<Path> {
  final double cutoutRadius;
  final double cutoutOffset;

  _TicketClipper({required this.cutoutRadius, required this.cutoutOffset});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();

    // Left cutout
    final leftCutout = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(0, cutoutOffset), radius: cutoutRadius),
        -pi / 2,
        pi,
      );

    // Right cutout
    final rightCutout = Path()
      ..addArc(
        Rect.fromCircle(
          center: Offset(size.width, cutoutOffset),
          radius: cutoutRadius,
        ),
        pi / 2,
        pi,
      );

    return Path.combine(
      PathOperation.difference,
      Path.combine(PathOperation.difference, path, leftCutout),
      rightCutout,
    );
  }

  @override
  bool shouldReclip(_TicketClipper oldClipper) =>
      oldClipper.cutoutRadius != cutoutRadius ||
      oldClipper.cutoutOffset != cutoutOffset;
}
