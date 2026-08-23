import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/daos/budget_dao.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';

class CategoryBudgetCard extends StatelessWidget {
  final BudgetWithProgress budgetProgress;
  final VoidCallback? onTap;

  const CategoryBudgetCard({
    super.key,
    required this.budgetProgress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = context.appColors;

    final pct = budgetProgress.percentage;
    final allocated =
        budgetProgress.currentPeriod?.allocated ?? budgetProgress.budget.amount;
    final isOverBudget = pct > 1.0;

    // Choose color based on budget progress
    final Color progressColor = isOverBudget
        ? appColors.expenseColor
        : (pct > 0.85 ? Colors.orange : appColors.incomeColor);

    return TactileSpringContainer(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(kSpacing14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  getCategoryIcon(budgetProgress.category.icon),
                  color: hexToColor(budgetProgress.category.color),
                  size: 28,
                ),
                Text(
                  '${(pct * 100).toInt()}%',
                  style: context.ts(
                    11,
                    fontWeight: FontWeight.w700,
                    color: isOverBudget
                        ? appColors.expenseColor
                        : appColors.textMedium,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  budgetProgress.category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.ts(
                    13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: kSpacing4),
                Text(
                  '${CurrencyFormatter.formatCents(budgetProgress.spentInPeriod)} / ${CurrencyFormatter.formatCents(allocated)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.ts(
                    11,
                    fontWeight: FontWeight.w500,
                    color: appColors.textLow,
                  ),
                ),
                const SizedBox(height: kSpacing10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: theme.colorScheme.onSurface.withValues(
                      alpha: 0.05,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
