import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/core/utils/spacing.dart';

class BudjetlyBalanceHeader extends StatelessWidget {
  final int balance;
  final String label;
  final int remainingBudget;

  const BudjetlyBalanceHeader({
    super.key,
    required this.balance,
    this.label = 'Total Balance',
    this.remainingBudget = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(kSpacing24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Subtle background texture/shape
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -60,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: context.ts(
                  13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: kSpacing8),
              AmountText(
                amountInCents: balance,
                style: context.ts(
                  42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: kSpacing24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_balance_wallet, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          remainingBudget > 0
                              ? 'Remaining Budget: ${CurrencyFormatter.formatCents(remainingBudget)}'
                              : 'No Remaining Budget',
                          style: context.ts(12, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.trending_up_rounded,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 32,
                  )
                ],
              )
            ],
          ),
        ],
      ),
    );
  }
}
