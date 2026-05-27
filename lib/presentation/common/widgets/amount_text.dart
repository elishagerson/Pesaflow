import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';

enum AmountType { income, expense, transfer, neutral }

class AmountText extends StatelessWidget {
  final int amountInCents;
  final AmountType type;
  final TextStyle? style;
  final bool showDecimals;
  final bool useMonospace;

  const AmountText({
    required this.amountInCents,
    this.type = AmountType.neutral,
    this.style,
    this.showDecimals = false,
    this.useMonospace = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Resolve color based on type and dark/light settings
    Color resolveColor() {
      switch (type) {
        case AmountType.income:
          return isDark ? AppTheme.incomeColorDark : AppTheme.incomeColor;
        case AmountType.expense:
          return isDark ? AppTheme.expenseColorDark : AppTheme.expenseColor;
        case AmountType.transfer:
          return isDark ? AppTheme.transferColorDark : AppTheme.transferColor;
        case AmountType.neutral:
        default:
          return isDark ? Colors.white : Colors.black;
      }
    }

    final TextStyle baseStyle = style ?? theme.textTheme.bodyMedium ?? const TextStyle();
    final TextStyle customStyle = useMonospace
        ? AppTheme.getMonospaceStyle(baseStyle).copyWith(
            color: resolveColor(),
          )
        : baseStyle.copyWith(
            color: resolveColor(),
            fontWeight: baseStyle.fontWeight ?? FontWeight.w900,
          );

    // Build the string representation: Prepend +/- signs for visually dynamic grids
    String displayString = CurrencyFormatter.formatCents(
      amountInCents,
      showDecimals: showDecimals,
    );

    if (type == AmountType.income) {
      displayString = '+ $displayString';
    } else if (type == AmountType.expense) {
      displayString = '- $displayString';
    }

    if (useMonospace) {
      displayString = '$displayString\u200A';
    }

    return Padding(
      padding: const EdgeInsets.only(right: 2.0),
      child: Text(
        displayString,
        style: customStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
