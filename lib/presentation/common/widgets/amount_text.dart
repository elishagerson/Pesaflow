import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

enum AmountType { income, expense, transfer, neutral }

class AmountText extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Resolve color based on type and dark/light settings
    Color resolveColor() {
      switch (type) {
        case AmountType.income:
          return context.appColors.incomeColor;
        case AmountType.expense:
          return context.appColors.expenseColor;
        case AmountType.transfer:
          return context.appColors.transferColor;
        case AmountType.neutral:
          return theme.colorScheme.onSurface;
      }
    }

    final TextStyle baseStyle =
        style ?? theme.textTheme.bodyMedium ?? const TextStyle();
    final TextStyle customStyle = useMonospace
        ? AppTheme.getMonospaceStyle(baseStyle).copyWith(color: resolveColor())
        : baseStyle.copyWith(
            color: resolveColor(),
            fontWeight: baseStyle.fontWeight ?? FontWeight.w900,
          );

    final globalShowDecimals =
        ref.watch(currencyShowDecimalsProvider).value ?? false;
    final finalShowDecimals = showDecimals || globalShowDecimals;

    // Build the string representation: Prepend +/- signs for visually dynamic grids
    String displayString = CurrencyFormatter.formatCents(
      amountInCents,
      showDecimals: finalShowDecimals,
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
