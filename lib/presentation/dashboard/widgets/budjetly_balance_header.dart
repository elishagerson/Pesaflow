import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/pesa_surface.dart';

class BudjetlyBalanceHeader extends StatefulWidget {
  final int balance;
  final String label;
  final int income;
  final int expense;
  final VoidCallback? onAccountTap;

  /// Optional block rendered under the cash-flow row, inside the same card.
  ///
  /// The hero strip uses this to hang its side-by-side cells off the balance
  /// card rather than laying a second card next to it. Putting them in separate
  /// cards is what made the dashboard read as a carousel of competing widgets;
  /// one card with hairline-divided cells reads as a single instrument.
  final Widget? footer;

  /// Extra height reserved for [footer] when the card needs to grow for it.
  final double footerHeight;

  const BudjetlyBalanceHeader({
    super.key,
    required this.balance,
    required this.label,
    required this.income,
    required this.expense,
    this.onAccountTap,
    this.footer,
    this.footerHeight = 0,
  });

  /// The plate's cut, in one place. The shape and the padding that has to clear
  /// it are the same decision, so they read the same number rather than two
  /// literals that can drift apart and leave content tucked under the diagonal.
  /// Corner radius. Deliberately small: the hero runs edge to edge, so the
  /// rounding only shows at the screen's own corners, where a large radius
  /// would carve visible bites out of the left and right edges instead of
  /// softening them.
  static const double radius = AppTheme.radiusHero;

  @override
  State<BudjetlyBalanceHeader> createState() => _BudjetlyBalanceHeaderState();
}

class _BudjetlyBalanceHeaderState extends State<BudjetlyBalanceHeader>
    with TickerProviderStateMixin {
  bool _isHidden = false;

  // Animated balance (odometer)
  late final List<AnimationController> _digitControllers;
  late final List<Animation<double>> _digitAnimations;
  bool _isInitialBuild = true;

  // Gradient shimmer
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAnimation;

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
    if (balance < 0) {
      final absFormatted = CurrencyFormatter.formatCents(balance.abs());
      return ['-', ...absFormatted.split('')];
    }
    return CurrencyFormatter.formatCents(balance).split('');
  }

  @override
  void didUpdateWidget(covariant BudjetlyBalanceHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.balance != widget.balance) {
      _initDigitAnimations();
      if (!_isInitialBuild && !context.isReducedMotion) {
        _startShimmer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNegative = widget.balance < 0;
    final textColor = isNegative
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;

    return PesaSurface.bleed(
      radius: BudjetlyBalanceHeader.radius,
      // With the hairline and the shadow gone, the gradient is the only thing
      // giving the surface a top and a bottom. It stays in the slate family so
      // it does not compete with the numbers.
      background: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isNegative
            ? [
                theme.colorScheme.errorContainer.withValues(alpha: 0.55),
                theme.colorScheme.surfaceContainerHigh,
              ]
            : [
                theme.colorScheme.surfaceContainerHighest,
                theme.colorScheme.surfaceContainer,
              ],
        stops: const [0.0, 1.0],
      ),
      // Uniform inset. There is no cut to clear any more, so the content does
      // not have to lean away from one edge.
      padding: const EdgeInsets.fromLTRB(
        kSpacing20,
        kSpacing20,
        kSpacing20,
        kSpacing20,
      ),
      // A screen reader should meet one labelled region rather than a pile of
      // unrelated text nodes.
      semanticLabel: 'Account balance and monthly cash flow',
      child: Stack(
        children: [
          // Ambient gradient shimmer sweep (neutral, non-distracting)
          if (!context.isReducedMotion)
            AnimatedBuilder(
              animation: _shimmerAnimation,
              builder: (context, _) {
                final t = _shimmerAnimation.value;
                return Positioned.fill(
                  child: IgnorePointer(
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
                );
              },
            ),
          // Card content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Label + Status (if negative) + Eye toggle
              //
              // Flat on purpose: the account label is `Expanded` and every
              // other child is fixed width, so the row provably divides the
              // space it was given. Nesting the label inside a
              // `MainAxisSize.min` Row looks equivalent and is not — the inner
              // row hands its child an unbounded width, so a long workspace
              // name shoves the privacy toggle clean off the card.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isNegative
                          ? theme.colorScheme.error
                          : context.appColors.brandColor,
                      borderRadius: BorderRadius.circular(AppTheme.squircleRadius(8)),
                    ),
                  ),
                  const SizedBox(width: kSpacing8),
                  Expanded(
                    child: Text(
                      widget.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.appTypography.eyebrow.copyWith(
                        color: isNegative
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (isNegative) ...[
                    const SizedBox(width: kSpacing8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withValues(alpha: 0.12),
                        // A 4px plate rather than a pill: the poster language
                        // in this app is all straight edges, and a fully round
                        // chip is the one shape that reads as soft.
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: theme.colorScheme.error.withValues(
                            alpha: 0.35,
                          ),
                        ),
                      ),
                      child: Text(
                        'DEFICIT',
                        style: context.appTypography.labelMicro.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  // The eye is the most-repeated control on this screen, and
                  // an 18px icon in 6px of padding is a 30dp target — below the
                  // 48dp minimum and below the WCAG 2.5.8 threshold. The mark
                  // stays small on purpose; only the target grows.
                  Semantics(
                    button: true,
                    label: _isHidden ? 'Show balance' : 'Hide balance',
                    child: InkWell(
                      onTap: () {
                        PesaHaptics.light();
                        setState(() {
                          _isHidden = !_isHidden;
                        });
                      },
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(kSpacing6),
                            child: Icon(
                              _isHidden
                                  ? PesaFlowIcons.visibilityOff
                                  : PesaFlowIcons.visibility,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.55,
                              ),
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: kSpacing12),

              // Center: Balance reflecting reality
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _isHidden
                    ? Text(
                        '••••••',
                        style: context.appTypography.posterHero.copyWith(
                          color: textColor,
                        ),
                      )
                    : context.isReducedMotion
                    ? Text(
                        isNegative
                            ? '- ${CurrencyFormatter.formatCents(widget.balance.abs())}'
                            : CurrencyFormatter.formatCents(widget.balance),
                        style: context.appTypography.posterHero.copyWith(
                          color: textColor,
                        ),
                      )
                    : _buildAnimatedDigits(theme, textColor),
              ),
              const SizedBox(height: kSpacing18),

              Divider(
                height: 1,
                thickness: 0.8,
                color: context.appColors.hairline,
              ),
              const SizedBox(height: kSpacing14),

              // Bottom: Monthly Cash Flow (Income vs Spent)
              Row(
                children: [
                  // Total In
                  Expanded(
                    child: _buildCashFlowLeg(
                      label: 'INCOME',
                      value: _isHidden
                          ? '••••'
                          : CurrencyFormatter.formatCents(widget.income),
                      accent: context.appColors.incomeColor,
                      icon: PesaFlowIcons.arrowDown,
                      isNegative: false,
                    ),
                  ),
                  // Vertical divider
                  Container(
                    width: 1,
                    height: 28,
                    color: context.appColors.hairline,
                    margin: const EdgeInsets.symmetric(horizontal: kSpacing12),
                  ),
                  // Total Out
                  Expanded(
                    child: _buildCashFlowLeg(
                      label: 'SPENT',
                      value: _isHidden
                          ? '••••'
                          : CurrencyFormatter.formatCents(widget.expense),
                      accent: context.appColors.expenseColor,
                      icon: PesaFlowIcons.arrowUp,
                      isNegative: isNegative,
                    ),
                  ),
                ],
              ),
              if (widget.footer != null) ...[
                const SizedBox(height: kSpacing14),
                Divider(
                  height: 1,
                  thickness: 0.8,
                  color: context.appColors.hairline,
                ),
                SizedBox(height: kSpacing14),
                SizedBox(height: widget.footerHeight, child: widget.footer),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// One leg of the cash-flow split. Extracted because both legs were
  /// byte-identical apart from three values, and the duplicated copy is what
  /// let the two drift apart in the first place.
  Widget _buildCashFlowLeg({
    required String label,
    required String value,
    required Color accent,
    required IconData icon,
    required bool isNegative,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.squircleRadius(28)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 14, color: accent),
        ),
        const SizedBox(width: kSpacing10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.appTypography.labelMicro.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: context.ts(
                  13,
                  fontWeight: FontWeight.w700,
                  color: isNegative
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedDigits(ThemeData theme, Color textColor) {
    return AnimatedBuilder(
      animation: Listenable.merge(_digitControllers),
      builder: (context, _) {
        final chars = _formatBalanceDigits(widget.balance);
        int digitIdx = 0;
        final baseStyle = context.appTypography.posterHero.copyWith(
          color: textColor,
        );

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
