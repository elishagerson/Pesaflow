import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';

enum AmountType { income, expense, transfer, neutral }

class AmountText extends StatelessWidget {
  final int amountInCents;
  final AmountType type;
  final TextStyle? style;
  final bool showDecimals;

  const AmountText({
    required this.amountInCents,
    this.type = AmountType.neutral,
    this.style,
    this.showDecimals = false,
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
    final TextStyle customMonospaceStyle = AppTheme.getMonospaceStyle(baseStyle).copyWith(
      color: resolveColor(),
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

    return Text(
      displayString,
      style: customMonospaceStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
