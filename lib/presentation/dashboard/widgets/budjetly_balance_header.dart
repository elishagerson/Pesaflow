import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/core/utils/spacing.dart';

class BudjetlyBalanceHeader extends StatelessWidget {
  final int balance;
  final String label;

  const BudjetlyBalanceHeader({
    super.key,
    required this.balance,
    this.label = 'Total Balance',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: context.ts(
            12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: appColors.textMedium,
          ),
        ),
        const SizedBox(height: kSpacing4),
        AmountText(
          amountInCents: balance,
          style: context.ts(
            44,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: kSpacing24),
      ],
    );
  }
}
