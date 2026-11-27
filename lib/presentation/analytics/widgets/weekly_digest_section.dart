import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/pesa_surface.dart';
import 'package:pesaflow/presentation/recurring/utils/recurring_schedule_helpers.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

/// Weekly & behavioral digest cards for the Analytics Overview tab:
/// - Time-aware greeting ("here's your week")
/// - Safe to spend + daily pace until payday
/// - Proportional allocation bar ("Where your X goes": Bills / Savings / Safe to spend)
/// - Segmented primary savings goal progress
/// - Spending behavior digest (30d daily burn vs. safe pace, savings rate, top category)
class WeeklyDigestSection extends ConsumerWidget {
  const WeeklyDigestSection({super.key});

  String _greetingForHour(int hour) {
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final incomeColor = context.appColors.incomeColor;
    final warningColor = context.appColors.warningColor;

    final now = DateTime.now();
    final today = dateOnly(now);

    final currentBalance = ref.watch(netWorthProvider);
    final recurring =
        ref.watch(recurringTransactionsStreamProvider).asData?.value ?? [];
    final goals = ref.watch(savingsGoalsStreamProvider).asData?.value ?? [];
    final dailyBurn30d =
        ref.watch(thirtyDayDailyBurnRateProvider).asData?.value ?? 0;
    final monthlyTotals =
        ref.watch(monthlyTotalsProvider).asData?.value ?? {};
    final topCategories =
        ref.watch(topCategoriesProvider).asData?.value ?? [];

    final nextPayday = nextPaydayFor(recurring, now: today);
    final classified = classifyUpcomingBills(
      recurring,
      nextPayday: nextPayday,
      now: today,
    );

    final billsCents = classified.toPayTotalCents;
    final activeGoals = goals.where((g) => !g.isCompleted).toList();
    final primaryGoal = activeGoals.isNotEmpty
        ? activeGoals.first
        : (goals.isNotEmpty ? goals.first : null);

    // Reserve goals progress or monthly savings toward goals if available.
    final goalsSavedCents = activeGoals.fold<int>(
      0,
      (sum, g) => sum + g.currentAmount,
    );

    final daysUntilPayday = nextPayday != null
        ? nextPayday.difference(today).inDays.clamp(1, 365)
        : 7;

    // Safe to spend = current balance minus upcoming bills before payday.
    final safeToSpendCents = (currentBalance - billsCents).clamp(0, 1 << 62);
    final safeDailyCents = safeToSpendCents ~/ daysUntilPayday;

    final paydayHint = nextPayday != null
        ? '≈ ${CurrencyFormatter.formatCompact(safeDailyCents)} a day until ${DateFormat('EEE').format(nextPayday)}'
        : '≈ ${CurrencyFormatter.formatCompact(safeDailyCents)} a day over the next 7 days';

    // Allocation breakdown: Bills, Savings, Safe to spend.
    final monthlyIncome = monthlyTotals['income'] ?? 0;
    final monthlyExpense = monthlyTotals['expense'] ?? 0;
    final monthlySavings =
        (monthlyIncome - monthlyExpense).clamp(0, 1 << 62);
    final savingsSliceCents =
        monthlySavings > 0 ? monthlySavings : goalsSavedCents;

    final totalPoolCents =
        billsCents + savingsSliceCents + safeToSpendCents;

    final savingsRatePct = monthlyIncome > 0
        ? (((monthlyIncome - monthlyExpense) / monthlyIncome) * 100).round()
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Greeting Header ──
        Padding(
          padding: const EdgeInsets.only(bottom: kSpacing12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greetingForHour(now.hour),
                style: context.ts(
                  24,
                  fontWeight: FontWeight.w800,
                  color: onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                "here's your week",
                style: context.ts(
                  18,
                  fontWeight: FontWeight.w500,
                  color: context.appColors.textMedium,
                ),
              ),
            ],
          ),
        ),

        // ── Card 1: Safe to spend ──
        PesaSurface.bleed(
          fill: theme.colorScheme.surfaceContainerHigh,
          radius: AppTheme.radiusDialog,
          padding: const EdgeInsets.all(kSpacing20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Safe to spend',
                style: context.ts(
                  13,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.textMedium,
                ),
              ),
              const SizedBox(height: kSpacing4),
              AmountText(
                amountInCents: safeToSpendCents,
                animate: true,
                style: context.ts(
                  34,
                  fontWeight: FontWeight.w900,
                  color: onSurface,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: kSpacing4),
              Text(
                paydayHint,
                style: context.ts(
                  13,
                  fontWeight: FontWeight.w700,
                  color: warningColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: kSpacing12),

        // ── Card 2: Where your money goes ──
        if (totalPoolCents > 0) ...[
          _AllocationCard(
            totalPoolCents: totalPoolCents,
            billsCents: billsCents,
            savingsCents: savingsSliceCents,
            safeToSpendCents: safeToSpendCents,
            incomeColor: incomeColor,
          ),
          const SizedBox(height: kSpacing12),
        ],

        // ── Card 3: Primary Savings Goal (Segmented Pill Bar) ──
        if (primaryGoal != null) ...[
          _SegmentedGoalCard(goal: primaryGoal, incomeColor: incomeColor),
          const SizedBox(height: kSpacing12),
        ],

        // ── Card 4: Spending Behavior Digest ──
        _SpendingBehaviorCard(
          dailyBurn30dCents: dailyBurn30d,
          safeDailyCents: safeDailyCents,
          savingsRatePct: savingsRatePct,
          topCategory: topCategories.isNotEmpty ? topCategories.first : null,
          monthlyExpenseCents: monthlyExpense,
        ),
        const SizedBox(height: kSpacing16),
      ],
    );
  }
}

class _AllocationCard extends StatelessWidget {
  final int totalPoolCents;
  final int billsCents;
  final int savingsCents;
  final int safeToSpendCents;
  final Color incomeColor;

  const _AllocationCard({
    required this.totalPoolCents,
    required this.billsCents,
    required this.savingsCents,
    required this.safeToSpendCents,
    required this.incomeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    final segments = [
      (
        label: 'Bills',
        cents: billsCents,
        color: incomeColor,
        textColor: Colors.white,
      ),
      (
        label: 'Savings',
        cents: savingsCents,
        color: incomeColor.withValues(alpha: 0.55),
        textColor: Colors.white,
      ),
      (
        label: 'Safe to spend',
        cents: safeToSpendCents,
        color: incomeColor.withValues(alpha: 0.24),
        textColor: onSurface,
      ),
    ].where((s) => s.cents > 0).toList();

    return PesaSurface.bleed(
      fill: theme.colorScheme.surfaceContainerHigh,
      radius: AppTheme.radiusDialog,
      padding: const EdgeInsets.all(kSpacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where your ${CurrencyFormatter.formatCompact(totalPoolCents)} goes',
            style: context.ts(
              14,
              fontWeight: FontWeight.w600,
              color: context.appColors.textMedium,
            ),
          ),
          const SizedBox(height: kSpacing14),

          // Proportional rounded blocks
          Row(
            children: [
              for (int i = 0; i < segments.length; i++) ...[
                if (i > 0) const SizedBox(width: kSpacing4),
                Expanded(
                  flex: ((segments[i].cents / totalPoolCents) * 100)
                      .round()
                      .clamp(12, 100),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: kSpacing8),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: segments[i].color,
                      borderRadius: BorderRadius.circular(
                        AppTheme.squircleRadius(12),
                      ),
                    ),
                    child: Text(
                      CurrencyFormatter.formatCompact(segments[i].cents),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.ts(
                        12,
                        fontWeight: FontWeight.w800,
                        color: segments[i].textColor,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: kSpacing14),

          // Legend rows
          for (final seg in segments) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: kSpacing4),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: seg.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: kSpacing10),
                  Expanded(
                    child: Text(
                      seg.label,
                      style: context.ts(
                        13,
                        fontWeight: FontWeight.w600,
                        color: onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '${((seg.cents / totalPoolCents) * 100).round()}%',
                    style: context.ts(
                      12,
                      fontWeight: FontWeight.w500,
                      color: context.appColors.textMedium,
                    ),
                  ),
                  const SizedBox(width: kSpacing14),
                  SizedBox(
                    width: 84,
                    child: Text(
                      CurrencyFormatter.formatCompact(seg.cents),
                      textAlign: TextAlign.right,
                      style: context.ts(
                        13,
                        fontWeight: FontWeight.w700,
                        color: onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentedGoalCard extends StatelessWidget {
  final SavingsGoal goal;
  final Color incomeColor;

  const _SegmentedGoalCard({
    required this.goal,
    required this.incomeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final ratio = goal.targetAmount > 0
        ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    const totalSegments = 16;
    final filledCount = (ratio * totalSegments).floor();
    final hasPartialTip = (ratio * totalSegments) - filledCount >= 0.25;

    return PesaSurface.bleed(
      fill: theme.colorScheme.surfaceContainerHigh,
      radius: AppTheme.radiusDialog,
      padding: const EdgeInsets.all(kSpacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Savings goal · ${goal.name}',
            style: context.ts(
              13,
              fontWeight: FontWeight.w600,
              color: context.appColors.textMedium,
            ),
          ),
          const SizedBox(height: kSpacing6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: kSpacing6,
            children: [
              AmountText(
                amountInCents: goal.currentAmount,
                animate: true,
                style: context.ts(
                  24,
                  fontWeight: FontWeight.w800,
                  color: onSurface,
                ),
              ),
              Text(
                'of ${CurrencyFormatter.formatCompact(goal.targetAmount)}',
                style: context.ts(
                  14,
                  fontWeight: FontWeight.w500,
                  color: context.appColors.textMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing14),
          Row(
            children: List.generate(totalSegments, (index) {
              Color segColor;
              if (index < filledCount) {
                segColor = incomeColor.withValues(alpha: 0.65);
              } else if (index == filledCount && hasPartialTip) {
                segColor = incomeColor.withValues(alpha: 0.28);
              } else {
                segColor = onSurface.withValues(alpha: 0.07);
              }
              return Expanded(
                child: Container(
                  height: 22,
                  margin: EdgeInsets.only(
                    right: index < totalSegments - 1 ? kSpacing4 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: segColor,
                    borderRadius: BorderRadius.circular(
                      AppTheme.squircleRadius(6),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SpendingBehaviorCard extends StatelessWidget {
  final int dailyBurn30dCents;
  final int safeDailyCents;
  final int savingsRatePct;
  final Map<String, dynamic>? topCategory;
  final int monthlyExpenseCents;

  const _SpendingBehaviorCard({
    required this.dailyBurn30dCents,
    required this.safeDailyCents,
    required this.savingsRatePct,
    required this.topCategory,
    required this.monthlyExpenseCents,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final onPace = safeDailyCents <= 0 || dailyBurn30dCents <= safeDailyCents;
    final paceColor = onPace
        ? context.appColors.incomeColor
        : context.appColors.warningColor;

    final topCatName = (topCategory?['name'] as String?) ?? 'None yet';
    final topCatAmount = (topCategory?['total'] as int?) ?? 0;
    final topCatPct = monthlyExpenseCents > 0 && topCatAmount > 0
        ? '${((topCatAmount / monthlyExpenseCents) * 100).round()}%'
        : '—';

    return PesaSurface.bleed(
      fill: theme.colorScheme.surfaceContainerHigh,
      radius: AppTheme.radiusDialog,
      padding: const EdgeInsets.all(kSpacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PesaFlowIcons.analytics,
                    size: 16,
                    color: context.appColors.textMedium,
                  ),
                  const SizedBox(width: kSpacing8),
                  Text(
                    'SPENDING BEHAVIOR DIGEST',
                    style: context.ts(
                      11,
                      fontWeight: FontWeight.w800,
                      color: context.appColors.textMedium,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacing8,
                  vertical: kSpacing2,
                ),
                decoration: BoxDecoration(
                  color: paceColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  onPace ? 'On pace' : 'Above safe pace',
                  style: context.ts(
                    10,
                    fontWeight: FontWeight.w700,
                    color: paceColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing14),
          _behaviorRow(
            context,
            label: '30-day average spend',
            value: '${CurrencyFormatter.formatCompact(dailyBurn30dCents)}/day',
            detail: safeDailyCents > 0
                ? 'vs ${CurrencyFormatter.formatCompact(safeDailyCents)}/day safe'
                : 'last 30 days',
            onSurface: onSurface,
          ),
          Divider(height: kSpacing16, thickness: 0.5, color: context.appColors.hairline),
          _behaviorRow(
            context,
            label: 'Top spending category',
            value: topCatName,
            detail: topCatAmount > 0
                ? '${CurrencyFormatter.formatCompact(topCatAmount)} ($topCatPct)'
                : 'No expenses this month',
            onSurface: onSurface,
          ),
          Divider(height: kSpacing16, thickness: 0.5, color: context.appColors.hairline),
          _behaviorRow(
            context,
            label: 'Monthly savings rate',
            value: '$savingsRatePct%',
            detail: savingsRatePct >= 20
                ? 'Healthy cushion'
                : savingsRatePct > 0
                    ? 'Building momentum'
                    : 'Expenses exceed income',
            onSurface: onSurface,
          ),
        ],
      ),
    );
  }

  Widget _behaviorRow(
    BuildContext context, {
    required String label,
    required String value,
    required String detail,
    required Color onSurface,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.ts(
                  13,
                  fontWeight: FontWeight.w600,
                  color: onSurface,
                ),
              ),
              Text(
                detail,
                style: context.ts(
                  11,
                  color: context.appColors.textMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: kSpacing12),
        Text(
          value,
          style: context.ts(
            14,
            fontWeight: FontWeight.w800,
            color: onSurface,
          ),
        ),
      ],
    );
  }
}
