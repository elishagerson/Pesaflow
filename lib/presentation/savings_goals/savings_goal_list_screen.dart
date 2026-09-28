import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'widgets/quick_deposit_sheet.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/utils/scroll_helpers.dart';
import 'package:pesaflow/presentation/common/widgets/pesa_progress_bar.dart';
import 'package:pesaflow/presentation/common/widgets/pesa_surface.dart';
import 'package:pesaflow/presentation/common/widgets/premium_fab.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/floating_top_bar.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/empty_state.dart';
import 'package:pesaflow/presentation/common/widgets/error_state.dart';
import 'package:pesaflow/core/utils/app_illustrations.dart';
import 'package:pesaflow/presentation/common/widgets/motion/skeleton_crossfade.dart';
import 'package:pesaflow/presentation/common/widgets/hero_card_route.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_entrance.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/presentation/savings_goals/savings_goal_detail_screen.dart';
import 'package:pesaflow/data/database/app_database.dart';

class SavingsGoalListScreen extends ConsumerStatefulWidget {
  const SavingsGoalListScreen({super.key});

  @override
  ConsumerState<SavingsGoalListScreen> createState() =>
      _SavingsGoalListScreenState();
}

class _SavingsGoalListScreenState extends ConsumerState<SavingsGoalListScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(scrollToTopProvider, (_, _) {
      _scrollController.scrollToTop(context);
    });
    final theme = Theme.of(context);
    final savingsGoalsAsync = ref.watch(savingsGoalsStreamProvider);
    final totalSaved = ref.watch(savingsGoalsTotalSavedProvider);

    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            const FloatingTopBar(title: 'Savings Goals'),
            Expanded(
              child: SkeletonCrossfade(
                isLoading:
                    savingsGoalsAsync is AsyncLoading &&
                    !savingsGoalsAsync.hasValue,
                skeleton: const Padding(
                  padding: EdgeInsets.all(kSpacing16),
                  child: Column(
                    children: [
                      SkeletonCard(height: 130),
                      SizedBox(height: kSpacing12),
                      SkeletonCard(height: 130),
                      SizedBox(height: kSpacing12),
                      SkeletonCard(height: 130),
                      SizedBox(height: kSpacing12),
                      SkeletonCard(height: 130),
                    ],
                  ),
                ),
                child: savingsGoalsAsync.when(
                  data: (goals) {
                    if (goals.isEmpty) {
                      return _buildEmptyState(context, theme);
                    }

                    int totalTarget = 0;
                    for (final goal in goals) {
                      totalTarget += goal.targetAmount;
                    }
                    final overallPct = totalTarget > 0
                        ? (totalSaved / totalTarget).clamp(0.0, 1.0)
                        : 0.0;

                    final activeGoals = goals
                        .where(
                          (g) =>
                              !g.isCompleted &&
                              g.currentAmount < g.targetAmount,
                        )
                        .toList();
                    final completedGoals = goals
                        .where(
                          (g) =>
                              g.isCompleted ||
                              g.currentAmount >= g.targetAmount,
                        )
                        .toList();

                    // Calculate strategy pace metrics
                    int totalMonthlyCommitment = 0;
                    SavingsGoal? nextDueGoal;
                    int shortestDays = 999999;

                    for (final g in activeGoals) {
                      final rem = (g.targetAmount - g.currentAmount).clamp(
                        0,
                        g.targetAmount,
                      );
                      final diff = g.targetDate
                          .difference(DateTime.now())
                          .inDays;
                      final days = diff < 0 ? 0 : diff;
                      if (days < shortestDays) {
                        shortestDays = days;
                        nextDueGoal = g;
                      }
                      if (days <= 0 || days < 30) {
                        totalMonthlyCommitment += rem;
                      } else {
                        final months = (days / 30.4).clamp(1.0, 120.0);
                        totalMonthlyCommitment += (rem / months).round();
                      }
                    }

                    return RefreshIndicator(
                      color: theme.colorScheme.primary,
                      backgroundColor: theme.colorScheme.surfaceContainerHigh,
                      onRefresh: () async {
                        ref.invalidate(savingsGoalsStreamProvider);
                        ref.invalidate(savingsGoalsTotalSavedProvider);
                      },
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        key: const PageStorageKey('savings_goal_list'),
                        padding: const EdgeInsets.all(kSpacing16),
                        child: Column(
                          children: [
                            ...StaggeredEntrance(
                              children: [
                                _buildSummaryCard(
                                  context,
                                  theme,
                                  totalSaved,
                                  totalTarget,
                                  overallPct,
                                ),
                                const SizedBox(height: kSpacing20),
                                if (activeGoals.isNotEmpty) ...[
                                  _buildSectionHeader(
                                    context,
                                    'ACTIVE GOALS',
                                    '${activeGoals.length}',
                                    theme,
                                  ),
                                  const SizedBox(height: kSpacing12),
                                  ...activeGoals.map(
                                    (goal) => _buildGoalCard(
                                      context,
                                      ref,
                                      goal,
                                      theme,
                                    ),
                                  ),
                                ],
                                if (activeGoals.isNotEmpty) ...[
                                  const SizedBox(height: kSpacing12),
                                  _buildStrategyInsightCard(
                                    context,
                                    theme,
                                    activeGoals,
                                    totalMonthlyCommitment,
                                    nextDueGoal,
                                    shortestDays,
                                  ),
                                ],
                                if (activeGoals.length < 4) ...[
                                  const SizedBox(height: kSpacing20),
                                  _buildStarterSuggestions(context, theme),
                                ],
                                if (completedGoals.isNotEmpty) ...[
                                  const SizedBox(height: kSpacing20),
                                  _buildSectionHeader(
                                    context,
                                    'COMPLETED MILESTONES',
                                    '${completedGoals.length}',
                                    theme,
                                  ),
                                  const SizedBox(height: kSpacing12),
                                  ...completedGoals.map(
                                    (goal) => _buildGoalCard(
                                      context,
                                      ref,
                                      goal,
                                      theme,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: kSpacing80),
                              ],
                            ).children,
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (err, _) => ErrorState(
                    title: 'Could not load savings goals',
                    message: '$err',
                    onRetry: () => ref.invalidate(savingsGoalsStreamProvider),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: PremiumExtendedFab(
        onPressed: () {
          PesaHaptics.medium();
          context.push('/savings-goals/add');
        },
        label: 'New Goal',
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String badgeText,
    ThemeData theme,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: context.ts(
            11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          child: Text(
            badgeText,
            style: context.ts(
              10,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return EmptyState(
      icon: PesaFlowIcons.savings,
      title: 'No Savings Goals Yet',
      subtitle:
          'Set a savings target and track your progress.\nEvery journey starts with a goal.',
      illustration: PesaFlowIllustration.emptyGoals(),
      action: TactileSpringContainer(
        onTap: () {
          PesaHaptics.medium();
          context.push('/savings-goals/add');
        },
        selectedColor: theme.colorScheme.onSurface,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpacing28,
            vertical: kSpacing14,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          child: Text(
            'Set Your First Goal',
            style: context.ts(14, color: theme.colorScheme.onPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    ThemeData theme,
    int totalSaved,
    int totalTarget,
    double overallPct,
  ) {
    final onSurface = theme.colorScheme.onSurface;
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
                  Container(
                    padding: const EdgeInsets.all(kSpacing6),
                    decoration: BoxDecoration(
                      color: context.appColors.incomeColor.withValues(
                        alpha: 0.12,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PesaFlowIcons.savings,
                      size: 16,
                      color: context.appColors.incomeColor,
                    ),
                  ),
                  const SizedBox(width: kSpacing8),
                  Text(
                    'SAVINGS VAULT',
                    style: context.ts(
                      11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacing8,
                  vertical: kSpacing4,
                ),
                decoration: BoxDecoration(
                  color: context.appColors.incomeColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  border: Border.all(
                    color: context.appColors.incomeColor.withValues(
                      alpha: 0.20,
                    ),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '${(overallPct * 100).round()}% FUNDED',
                  style: context.ts(
                    10,
                    fontWeight: FontWeight.w800,
                    color: context.appColors.incomeColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL SAVED',
                      style: context.ts(
                        11,
                        fontWeight: FontWeight.w700,
                        color: onSurface.withValues(alpha: 0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: kSpacing4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AmountText(
                        amountInCents: totalSaved,
                        animate: true,
                        style: context.ts(
                          26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: kSpacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'COMBINED TARGET',
                      style: context.ts(
                        11,
                        fontWeight: FontWeight.w700,
                        color: onSurface.withValues(alpha: 0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: kSpacing4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: AmountText(
                        amountInCents: totalTarget,
                        animate: true,
                        style: context.ts(
                          18,
                          fontWeight: FontWeight.w700,
                          color: onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing16),
          // The one hero bar on this screen, so the one that gets the ripple.
          // Per-goal rows further down stay static.
          PesaProgressBar(
            value: overallPct,
            color: context.appColors.incomeColor,
            trackColor: onSurface.withValues(alpha: 0.06),
            growOnMount: true,
            semanticsLabel: 'Overall savings progress',
          ),
          const SizedBox(height: kSpacing6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${(overallPct * 100).round()}% of overall goal achieved',
                  style: context.ts(
                    11,
                    fontWeight: FontWeight.w500,
                    color: onSurface.withValues(alpha: 0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: kSpacing8),
              Flexible(
                child: Text(
                  totalTarget > totalSaved
                      ? '${CurrencyFormatter.formatCents(totalTarget - totalSaved)} to go'
                      : 'Target reached!',
                  style: context.ts(
                    11,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.incomeColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(
    BuildContext context,
    WidgetRef ref,
    SavingsGoal goal,
    ThemeData theme,
  ) {
    final goalColor = hexToColor(goal.color);
    final goalPct = goal.targetAmount > 0
        ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final diff = goal.targetDate.difference(DateTime.now()).inDays;
    final daysLeft = diff < 0 ? 0 : diff;
    final onSurface = theme.colorScheme.onSurface;
    final isCompleted = goal.isCompleted || goalPct >= 1.0;
    final remainingCents = (goal.targetAmount - goal.currentAmount).clamp(
      0,
      goal.targetAmount,
    );

    String paceInsight;
    if (isCompleted) {
      paceInsight = 'Goal achieved!';
    } else if (daysLeft <= 0) {
      paceInsight = 'Timeline arrived';
    } else if (daysLeft < 30) {
      final weeks = (daysLeft / 7).clamp(1.0, 4.0);
      final perWeek = (remainingCents / weeks).round();
      paceInsight = 'Save ~${CurrencyFormatter.formatCents(perWeek)} / wk';
    } else {
      final months = (daysLeft / 30.4).clamp(1.0, 120.0);
      final perMonth = (remainingCents / months).round();
      paceInsight = 'Save ~${CurrencyFormatter.formatCents(perMonth)} / mo';
    }

    String countdownLabel;
    if (isCompleted) {
      countdownLabel = 'Completed';
    } else if (daysLeft <= 0) {
      countdownLabel = 'Due today';
    } else if (daysLeft < 30) {
      countdownLabel = '$daysLeft days left';
    } else {
      final months = (daysLeft / 30.4).round();
      countdownLabel = months == 1 ? '~1 month left' : '~$months months left';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: kSpacing14),
      child: PesaSurface.bleed(
        fill: theme.colorScheme.surfaceContainerHigh,
        radius: AppTheme.radiusHero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              PesaHaptics.light();
              pushHeroCard(
                context,
                SavingsGoalDetailScreen(goalId: goal.id),
                'goal_${goal.id}',
              );
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusHero),
            child: Padding(
              padding: const EdgeInsets.all(kSpacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header: Squircle Icon, Title + Deadline, Status Pill ──
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: goalColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusInput,
                          ),
                          border: Border.all(
                            color: goalColor.withValues(alpha: 0.28),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          getGoalIcon(goal.icon),
                          color: goalColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: kSpacing12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.name,
                              style: context.ts(
                                16,
                                fontWeight: FontWeight.w700,
                                color: onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$countdownLabel • by ${goal.targetDate.day}/${goal.targetDate.month}/${goal.targetDate.year}',
                              style: context.ts(
                                11,
                                color: onSurface.withValues(alpha: 0.55),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: kSpacing8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kSpacing8,
                          vertical: kSpacing4,
                        ),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? context.appColors.incomeColor.withValues(
                                  alpha: 0.12,
                                )
                              : goalColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
                          border: Border.all(
                            color: isCompleted
                                ? context.appColors.incomeColor.withValues(
                                    alpha: 0.25,
                                  )
                                : goalColor.withValues(alpha: 0.25),
                            width: 0.8,
                          ),
                        ),
                        child: isCompleted
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    PesaFlowIcons.celebration,
                                    size: 11,
                                    color: context.appColors.incomeColor,
                                  ),
                                  const SizedBox(width: kSpacing4),
                                  Text(
                                    'COMPLETED',
                                    style: context.ts(
                                      10,
                                      fontWeight: FontWeight.w800,
                                      color: context.appColors.incomeColor,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                '${(goalPct * 100).round()}% FUNDED',
                                style: context.ts(
                                  10,
                                  fontWeight: FontWeight.w800,
                                  color: goalColor,
                                  letterSpacing: 0.4,
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpacing16),

                  // ── Financial Amounts ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CURRENTLY SAVED',
                              style: context.ts(
                                10,
                                fontWeight: FontWeight.w700,
                                color: onSurface.withValues(alpha: 0.5),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: AmountText(
                                amountInCents: goal.currentAmount,
                                animate: true,
                                style: context.ts(
                                  20,
                                  fontWeight: FontWeight.w800,
                                  color: onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: kSpacing12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'TARGET',
                              style: context.ts(
                                10,
                                fontWeight: FontWeight.w700,
                                color: onSurface.withValues(alpha: 0.5),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: AmountText(
                                amountInCents: goal.targetAmount,
                                animate: true,
                                style: context.ts(
                                  15,
                                  fontWeight: FontWeight.w700,
                                  color: onSurface.withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpacing12),

                  // ── Progress Bar ──
                  // Static: a list of goal rows would otherwise mount one
                  // rippling ticker per visible row.
                  PesaProgressBar(
                    value: goalPct,
                    color: goalColor,
                    trackColor: goalColor.withValues(alpha: 0.12),
                    height: 7,
                    wave: false,
                    showEndStop: false,
                    growOnMount: true,
                    semanticsLabel: '${goal.name} progress',
                  ),
                  const SizedBox(height: kSpacing8),

                  // ── Remaining & Smart Pace ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          remainingCents > 0
                              ? '${CurrencyFormatter.formatCents(remainingCents)} to go'
                              : 'Target reached',
                          style: context.ts(
                            11,
                            fontWeight: FontWeight.w600,
                            color: isCompleted
                                ? context.appColors.incomeColor
                                : onSurface.withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: kSpacing8),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              PesaFlowIcons.lightbulb,
                              size: 12,
                              color: goalColor,
                            ),
                            const SizedBox(width: kSpacing4),
                            Flexible(
                              child: Text(
                                paceInsight,
                                style: context.ts(
                                  11,
                                  fontWeight: FontWeight.w600,
                                  color: goalColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpacing12),
                  Divider(
                    height: 1,
                    thickness: 0.6,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.20,
                    ),
                  ),
                  const SizedBox(height: kSpacing10),

                  // ── Actions: Quick Deposit, Edit, Details ──
                  Row(
                    children: [
                      if (!isCompleted) ...[
                        TactileSpringContainer(
                          onTap: () =>
                              showQuickDepositSheet(context, ref, goal),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: kSpacing12,
                              vertical: kSpacing6,
                            ),
                            decoration: BoxDecoration(
                              color: goalColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusPill,
                              ),
                              border: Border.all(
                                color: goalColor.withValues(alpha: 0.25),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  PesaFlowIcons.add,
                                  size: 13,
                                  color: goalColor,
                                ),
                                const SizedBox(width: kSpacing4),
                                Text(
                                  'Deposit',
                                  style: context.ts(
                                    12,
                                    fontWeight: FontWeight.w700,
                                    color: goalColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: kSpacing8),
                      ],
                      TactileSpringContainer(
                        onTap: () =>
                            context.push('/savings-goals/${goal.id}/edit'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpacing12,
                            vertical: kSpacing6,
                          ),
                          decoration: BoxDecoration(
                            color: onSurface.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusPill,
                            ),
                            border: Border.all(
                              color: onSurface.withValues(alpha: 0.12),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PesaFlowIcons.edit,
                                size: 12,
                                color: onSurface.withValues(alpha: 0.75),
                              ),
                              const SizedBox(width: kSpacing4),
                              Text(
                                'Edit',
                                style: context.ts(
                                  12,
                                  fontWeight: FontWeight.w600,
                                  color: onSurface.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View Details',
                            style: context.ts(
                              11,
                              fontWeight: FontWeight.w600,
                              color: onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            PesaFlowIcons.chevronRight,
                            size: 13,
                            color: onSurface.withValues(alpha: 0.45),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStrategyInsightCard(
    BuildContext context,
    ThemeData theme,
    List<SavingsGoal> activeGoals,
    int totalMonthlyCommitment,
    SavingsGoal? nextDueGoal,
    int shortestDays,
  ) {
    final onSurface = theme.colorScheme.onSurface;
    return PesaSurface.bleed(
      fill: theme.colorScheme.surfaceContainerHigh,
      radius: AppTheme.radiusCard,
      padding: const EdgeInsets.all(kSpacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      PesaFlowIcons.lightbulb,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: kSpacing8),
                  Text(
                    'SAVINGS STRATEGY',
                    style: context.ts(
                      11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacing8,
                  vertical: kSpacing4,
                ),
                decoration: BoxDecoration(
                  color: context.appColors.incomeColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  border: Border.all(
                    color: context.appColors.incomeColor.withValues(
                      alpha: 0.20,
                    ),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  'PORTFOLIO PACE',
                  style: context.ts(
                    10,
                    fontWeight: FontWeight.w800,
                    color: context.appColors.incomeColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpacing16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MONTHLY COMMITMENT',
                      style: context.ts(
                        10,
                        fontWeight: FontWeight.w700,
                        color: onSurface.withValues(alpha: 0.5),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          AmountText(
                            amountInCents: totalMonthlyCommitment,
                            animate: true,
                            style: context.ts(
                              18,
                              fontWeight: FontWeight.w800,
                              color: onSurface,
                            ),
                          ),
                          Text(
                            ' / mo',
                            style: context.ts(
                              12,
                              fontWeight: FontWeight.w600,
                              color: onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (nextDueGoal != null) ...[
                Container(
                  width: 1,
                  height: 36,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.25,
                  ),
                ),
                const SizedBox(width: kSpacing16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NEXT MILESTONE DUE',
                        style: context.ts(
                          10,
                          fontWeight: FontWeight.w700,
                          color: onSurface.withValues(alpha: 0.5),
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        nextDueGoal.name,
                        style: context.ts(
                          15,
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        shortestDays <= 0
                            ? 'Due today'
                            : '$shortestDays days remaining',
                        style: context.ts(
                          11,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: kSpacing12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: kSpacing12,
              vertical: kSpacing8,
            ),
            decoration: BoxDecoration(
              color: onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AppTheme.radiusInput),
            ),
            child: Row(
              children: [
                Icon(
                  PesaFlowIcons.check,
                  size: 14,
                  color: context.appColors.incomeColor,
                ),
                const SizedBox(width: kSpacing8),
                Expanded(
                  child: Text(
                    'Funding ~${CurrencyFormatter.formatCents(totalMonthlyCommitment)} each month keeps all ${activeGoals.length} active goals on schedule.',
                    style: context.ts(
                      11,
                      color: onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarterSuggestions(BuildContext context, ThemeData theme) {
    final onSurface = theme.colorScheme.onSurface;
    final starters = [
      {
        'title': 'Emergency Fund',
        'subtitle': '3-6 months buffer',
        'icon': 'shield',
        'color': '#2563EB',
      },
      {
        'title': 'Vacation Trip',
        'subtitle': 'Travel & getaways',
        'icon': 'flight',
        'color': '#0D9488',
      },
      {
        'title': 'New Vehicle',
        'subtitle': 'Auto or transport',
        'icon': 'car',
        'color': '#4F46E5',
      },
      {
        'title': 'Tech Upgrade',
        'subtitle': 'Work & gadgets',
        'icon': 'laptop',
        'color': '#7C3AED',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'EXPLORE MILESTONES',
              style: context.ts(
                11,
                fontWeight: FontWeight.w700,
                color: onSurface.withValues(alpha: 0.55),
                letterSpacing: 0.8,
              ),
            ),
            Text(
              'Popular Ideas',
              style: context.ts(
                11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: kSpacing12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: kSpacing10,
            mainAxisSpacing: kSpacing10,
            childAspectRatio: 2.2,
          ),
          itemCount: starters.length,
          itemBuilder: (context, i) {
            final s = starters[i];
            final col = hexToColor(s['color'] as String);
            return TactileSpringContainer(
              onTap: () {
                PesaHaptics.selection();
                context.push('/savings-goals/add');
              },
              child: PesaSurface.bleed(
                fill: theme.colorScheme.surfaceContainerHigh,
                radius: AppTheme.radiusCard,
                padding: const EdgeInsets.all(kSpacing10),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: col.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusCompact,
                        ),
                        border: Border.all(
                          color: col.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        getGoalIcon(s['icon'] as String),
                        size: 16,
                        color: col,
                      ),
                    ),
                    const SizedBox(width: kSpacing8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            s['title'] as String,
                            style: context.ts(
                              12,
                              fontWeight: FontWeight.w700,
                              color: onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s['subtitle'] as String,
                            style: context.ts(
                              10,
                              color: onSurface.withValues(alpha: 0.5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
