import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/pesa_surface.dart';

class DashboardBalanceHeader extends StatefulWidget {
  final int balance;
  final String label;
  final int income;
  final int expense;
  final VoidCallback? onAccountTap;

  /// Optional block rendered under the cash-flow row, inside the same card.
  final Widget? footer;

  /// Extra height reserved for [footer] when the card needs to grow for it.
  final double footerHeight;

  const DashboardBalanceHeader({
    super.key,
    required this.balance,
    required this.label,
    required this.income,
    required this.expense,
    this.onAccountTap,
    this.footer,
    this.footerHeight = 0,
  });

  /// Small on purpose: the hero runs edge to edge, so a large radius would cut
  /// visible bites out of the left and right edges.
  static const double radius = AppTheme.radiusHero;

  @override
  State<DashboardBalanceHeader> createState() => _DashboardBalanceHeaderState();
}

class _DashboardBalanceHeaderState extends State<DashboardBalanceHeader> {
  bool _isHidden = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DashboardBalanceHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Balance renders instantly; no odometer/shimmer to trigger.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNegative = widget.balance < 0;
    final textColor = isNegative
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;

    return PesaSurface.bleed(
      radius: DashboardBalanceHeader.radius,
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
          // Ambient glow behind the balance number
          Positioned(
            left: 10,
            top: 36,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isNegative
                                  ? theme.colorScheme.error
                                  : context.appColors.brandColor)
                              .withValues(
                                alpha: context.appColors.badgeBorderAlpha,
                              ),
                      blurRadius: 55,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
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
                      borderRadius: BorderRadius.circular(
                        AppTheme.squircleRadius(8),
                      ),
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
                    : Text(
                        isNegative
                            ? '- ${CurrencyFormatter.formatCents(widget.balance.abs())}'
                            : CurrencyFormatter.formatCents(widget.balance),
                        style: context.appTypography.posterHero.copyWith(
                          color: textColor,
                        ),
                      ),
              ),
              const SizedBox(height: kSpacing18),

              // Gradient hairline divider
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.appColors.hairline.withValues(alpha: 0.15),
                      context.appColors.hairline,
                      context.appColors.hairline.withValues(alpha: 0.15),
                    ],
                  ),
                ),
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
                  // Vertical gradient divider
                  Container(
                    width: 1,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          context.appColors.hairline.withValues(alpha: 0.1),
                          context.appColors.hairline,
                          context.appColors.hairline.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
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
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.appColors.hairline.withValues(alpha: 0.15),
                        context.appColors.hairline,
                        context.appColors.hairline.withValues(alpha: 0.15),
                      ],
                    ),
                  ),
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
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: context.appColors.badgeFillAlpha),
            borderRadius: BorderRadius.circular(AppTheme.squircleRadius(32)),
            border: Border.all(
              color: accent.withValues(
                alpha: context.appColors.badgeBorderAlpha,
              ),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 15, color: accent),
        ),
        const SizedBox(width: kSpacing10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.ts(
                  10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.8,
                  ),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: context.ts(
                  14,
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
}
