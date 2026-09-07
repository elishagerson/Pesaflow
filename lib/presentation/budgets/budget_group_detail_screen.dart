import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/daos/budget_group_dao.dart';
import 'package:pesaflow/data/repositories/budget_group_repository.dart';
import 'package:pesaflow/domain/models/enums.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/floating_top_bar.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/empty_state.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/data/repositories/budget_repository.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

/// Provider for loading a specific budget group's full data.
final budgetGroupDetailProvider =
    FutureProvider.family<BudgetGroupWithChildren?, String>((ref, groupId) async {
  ref.watch(dataChangesStreamProvider);
  final repo = ref.watch(budgetGroupRepositoryProvider);
  final groups = await repo.getGroupsWithProgress();
  return groups.where((g) => g.group.id == groupId).firstOrNull;
});

class BudgetGroupDetailScreen extends ConsumerWidget {
  final String groupId;
  const BudgetGroupDetailScreen({required this.groupId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(budgetGroupDetailProvider(groupId));
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      body: SafeArea(
        child: detailAsync.when(
          data: (groupData) {
            if (groupData == null) {
              return Column(
                children: [
                  const FloatingTopBar(
                    title: 'Budget Group',
                  ),
                  const Expanded(
                    child: EmptyState(
                      icon: PesaFlowIcons.budgets,
                      title: 'Group Not Found',
                      subtitle: 'This budget group could not be located.',
                    ),
                  ),
                ],
              );
            }

            final group = groupData.group;
            final groupType = BudgetGroupType.fromDbString(group.groupType);
            final (groupIcon, groupColor) = _groupVisuals(groupType);

            return Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FloatingTopBar(
                        padding: EdgeInsets.zero,
                        actions: [
                          TactileSpringContainer(
                            onTap: () => _deleteGroup(context, ref, groupData),
                            child: Container(
                              padding: const EdgeInsets.all(kSpacing10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.08,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                PesaFlowIcons.delete,
                                size: 18,
                                color: context.appColors.expenseColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: kSpacing8),
                          TactileSpringContainer(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context.push(
                                '/budgets/groups/$groupId/add',
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(kSpacing10),
                              decoration: BoxDecoration(
                                color: context.appColors.onBgColor.withValues(alpha: 0.06),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                PesaFlowIcons.add,
                                size: 18,
                                color: context.appColors.onBgColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: kSpacing12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(kSpacing10),
                            decoration: BoxDecoration(
                              color: groupColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusInput,
                              ),
                            ),
                            child: Icon(groupIcon, color: groupColor, size: 24),
                          ),
                          const SizedBox(width: kSpacing14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.name,
                                  style: context.ts(
                                    26,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.8,
                                    color: context.appColors.onBgColor,
                                  ),
                                ),
                                Text(
                                  '${(group.percentage * 100).round()}% of income',
                                  style: context.ts(
                                    12,
                                    color: context.appColors.onBgColor.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      kSpacing16,
                      kSpacing12,
                      kSpacing16,
                      kSpacing24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero amounts
                        StaggeredFadeSlide(
                          index: 0,
                          child: GlassCard(
                            padding: const EdgeInsets.all(kSpacing20),
                            borderRadius: AppTheme.radiusCard,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Spent',
                                        style: context.ts(
                                          12,
                                          color: onSurface.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: kSpacing4),
                                      AmountText(
                                        amountInCents: groupData.totalSpent,
                                        style: context.ts(
                                          28,
                                          fontWeight: FontWeight.w800,
                                          color: groupData.totalSpent >
                                                  groupData.totalAllocated
                                              ? context.appColors.expenseColor
                                              : onSurface,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: kSpacing6),
                                      Row(
                                        children: [
                                          Text(
                                            'of ',
                                            style: context.ts(
                                              12,
                                              color: onSurface.withValues(
                                                alpha: 0.4,
                                              ),
                                            ),
                                          ),
                                          AmountText(
                                            amountInCents:
                                                groupData.totalAllocated,
                                            style: context.ts(
                                              12,
                                              fontWeight: FontWeight.w600,
                                              color: onSurface.withValues(
                                                alpha: 0.6,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            ' allocated',
                                            style: context.ts(
                                              12,
                                              color: onSurface.withValues(
                                                alpha: 0.4,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Progress ring
                                SizedBox(
                                  height: 80,
                                  width: 80,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      TweenAnimationBuilder<double>(
                                        duration: const Duration(
                                          milliseconds: 1000,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        tween: Tween<double>(
                                          begin: 0,
                                          end: groupData.percentage.clamp(
                                            0.0,
                                            1.0,
                                          ),
                                        ),
                                        builder: (context, value, _) {
                                          return CircularProgressIndicator(
                                            value: value,
                                            strokeWidth: 7,
                                            strokeCap: StrokeCap.round,
                                            backgroundColor:
                                                onSurface.withValues(
                                                  alpha: 0.05,
                                                ),
                                            color: groupData.totalSpent >
                                                    groupData.totalAllocated
                                                ? context
                                                      .appColors
                                                      .expenseColor
                                                : groupColor,
                                          );
                                        },
                                      ),
                                      Text(
                                        '${(groupData.percentage * 100).round().clamp(0, 999)}%',
                                        style: context.ts(
                                          16,
                                          fontWeight: FontWeight.w800,
                                          color: onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: kSpacing24),

                        // Sub-budgets header
                        Row(
                          children: [
                            Text(
                              'Sub-Budgets',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${groupData.subBudgets.length} categories',
                              style: context.ts(
                                11,
                                color: onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: kSpacing12),

                        // Sub-budget list
                        if (groupData.subBudgets.isEmpty)
                          _buildEmptySubBudgets(
                            context,
                            theme,
                            groupColor,
                          )
                        else
                          ...groupData.subBudgets.asMap().entries.map((entry) {
                            final i = entry.key;
                            final sub = entry.value;
                            return StaggeredFadeSlide(
                              index: 2 + i,
                              child: _SubBudgetCard(
                                subBudget: sub,
                                groupColor: groupColor,
                              ),
                            );
                          }),

                        // Remaining unallocated
                        if (groupData.subBudgets.isNotEmpty) ...[
                          const SizedBox(height: kSpacing16),
                          _buildUnallocatedInfo(
                            context,
                            groupData,
                            theme,
                            onSurface,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => Column(
            children: [
              const FloatingTopBar(
                title: 'Budget Group',
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.all(kSpacing20),
                  child: Column(
                    children: [
                      SkeletonCard(height: 120),
                      SizedBox(height: kSpacing12),
                      SkeletonCard(height: 80),
                      SizedBox(height: kSpacing12),
                      SkeletonCard(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildEmptySubBudgets(
    BuildContext context,
    ThemeData theme,
    Color groupColor,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(kSpacing24),
      borderRadius: AppTheme.radiusCard,
      child: Column(
        children: [
          Icon(
            PesaFlowIcons.add,
            size: 32,
            color: groupColor.withValues(alpha: 0.4),
          ),
          const SizedBox(height: kSpacing12),
          Text(
            'No sub-budgets yet',
            style: context.ts(
              14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: kSpacing6),
          Text(
            'Add category budgets to track spending within this group.',
            textAlign: TextAlign.center,
            style: context.ts(
              12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: kSpacing16),
          TactileSpringContainer(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/budgets/groups/$groupId/add');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: kSpacing20,
                vertical: kSpacing10,
              ),
              decoration: BoxDecoration(
                color: groupColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              child: Text(
                'Add Sub-Budget',
                style: context.ts(
                  13,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.onBgColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnallocatedInfo(
    BuildContext context,
    BudgetGroupWithChildren groupData,
    ThemeData theme,
    Color onSurface,
  ) {
    final totalSubAllocated = groupData.subBudgets.fold<int>(
      0,
      (sum, b) => sum + b.budget.amount,
    );
    final unallocated = groupData.group.allocatedAmount - totalSubAllocated;

    if (unallocated <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(kSpacing12),
      decoration: BoxDecoration(
        color: context.appColors.warningColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusCompact),
        border: Border.all(
          color: context.appColors.warningColor.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(
            PesaFlowIcons.info,
            size: 16,
            color: context.appColors.warningColor,
          ),
          const SizedBox(width: kSpacing10),
          Expanded(
            child: Text(
              '${CurrencyFormatter.formatCents(unallocated)} unallocated in this group',
              style: context.ts(
                12,
                color: onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _groupVisuals(BudgetGroupType type) {
    return switch (type) {
      BudgetGroupType.needs => (PesaFlowIcons.home, const Color(0xFF2196F3)),
      BudgetGroupType.wants => (
        PesaFlowIcons.shoppingBag,
        const Color(0xFFFF9800),
      ),
      BudgetGroupType.investments => (
        PesaFlowIcons.income,
        const Color(0xFF4CAF50),
      ),
      BudgetGroupType.custom => (
        PesaFlowIcons.budgets,
        const Color(0xFF6B7280),
      ),
    };
  }

  Future<void> _deleteGroup(
    BuildContext context,
    WidgetRef ref,
    BudgetGroupWithChildren groupData,
  ) async {
    final group = groupData.group;
    final subCount = groupData.subBudgets.length;
    final contentText = subCount > 0
        ? 'Deleting the "${group.name}" group will preserve its $subCount sub-budget${subCount > 1 ? 's' : ''} as standalone envelopes.'
        : 'Are you sure you want to delete the "${group.name}" group?';

    final confirm = await ModernDialog.show<bool>(
      context: context,
      title: Text('Delete ${group.name} Group?'),
      titleIcon: PesaFlowIcons.delete,
      iconColor: context.appColors.expenseColor,
      content: Text(contentText),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(true),
          child: Text(
            'Delete Group',
            style: TextStyle(color: context.appColors.expenseColor),
          ),
        ),
      ],
    );

    if (confirm != true || !context.mounted) return;

    final repo = ref.read(budgetGroupRepositoryProvider);

    // Pop the group detail screen immediately back to budget list
    context.pop();

    try {
      await repo.deleteGroup(group.id);
      ref.invalidate(budgetGroupsProvider);
      ref.invalidate(standaloneBudgetsProvider);
      ref.invalidate(activeBudgetsStreamProvider);
      ref.invalidate(budgetProgressProvider);
      if (context.mounted) {
        CustomToast.show(
          context,
          message: '"${group.name}" group deleted',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        CustomToast.show(
          context,
          message: 'Error deleting group: $e',
          type: ToastType.error,
        );
      }
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SUB-BUDGET CARD
// ════════════════════════════════════════════════════════════════════════════

class _SubBudgetCard extends ConsumerWidget {
  final BudgetWithChildProgress subBudget;
  final Color groupColor;

  const _SubBudgetCard({
    required this.subBudget,
    required this.groupColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final catColor = hexToColor(subBudget.category.color);
    final allocated =
        subBudget.currentPeriod?.allocated ?? subBudget.budget.amount;
    final pct = allocated > 0
        ? (subBudget.spentInPeriod / allocated).clamp(0.0, 2.0)
        : 0.0;
    final isOver = subBudget.spentInPeriod > allocated;

    Color paceColor;
    if (isOver) {
      paceColor = context.appColors.expenseColor;
    } else if (pct > 0.8) {
      paceColor = context.appColors.warningColor;
    } else {
      paceColor = context.appColors.incomeColor;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: kSpacing10),
      child: Dismissible(
        key: ValueKey(subBudget.budget.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          return await ModernDialog.show<bool>(
            context: context,
            title: const Text('Delete Sub-Budget?'),
            titleIcon: PesaFlowIcons.delete,
            iconColor: context.appColors.expenseColor,
            content: Text(
              'Permanently remove the "${subBudget.budget.name}" envelope from this group?',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(true),
                child: Text(
                  'Delete',
                  style: TextStyle(color: context.appColors.expenseColor),
                ),
              ),
            ],
          );
        },
        onDismissed: (direction) async {
          final budget = subBudget.budget;
          final budgetRepo = ref.read(budgetRepositoryProvider);
          await budgetRepo.deleteBudget(budget.id);
          ref.invalidate(budgetGroupsProvider);
          ref.invalidate(standaloneBudgetsProvider);
          ref.invalidate(activeBudgetsStreamProvider);
          ref.invalidate(budgetProgressProvider);
          if (context.mounted) {
            CustomToast.show(
              context,
              message: '"${budget.name}" deleted',
              type: ToastType.success,
              duration: const Duration(seconds: 5),
              actionLabel: 'Undo',
              onAction: () async {
                await budgetRepo.createBudget(
                  name: budget.name,
                  categoryId: budget.categoryId,
                  period: budget.period,
                  amount: budget.amount,
                  rollover: budget.rollover,
                  rolloverType: budget.rolloverType,
                  rolloverCap: budget.rolloverCap,
                  startDate: budget.startDate,
                  notificationThreshold: budget.notificationThreshold,
                  groupId: budget.groupId,
                );
                ref.invalidate(budgetGroupsProvider);
                ref.invalidate(standaloneBudgetsProvider);
                ref.invalidate(activeBudgetsStreamProvider);
                ref.invalidate(budgetProgressProvider);
              },
            );
          }
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: kSpacing20),
          decoration: BoxDecoration(
            color: context.appColors.expenseColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          ),
          child: Icon(
            PesaFlowIcons.delete,
            color: context.appColors.expenseColor,
          ),
        ),
        child: TactileSpringContainer(
          onTap: () => context.push('/budgets/${subBudget.budget.id}'),
          child: GlassCard(
            padding: const EdgeInsets.all(kSpacing14),
            borderRadius: AppTheme.radiusCard,
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(kSpacing8),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusCompact,
                        ),
                      ),
                      child: Icon(
                        getCategoryIcon(subBudget.category.icon),
                        color: catColor,
                        size: 20,
                      ),
                    ),
                  const SizedBox(width: kSpacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subBudget.category.name,
                          style: context.ts(
                            14,
                            fontWeight: FontWeight.w600,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${CurrencyFormatter.formatCents(subBudget.spentInPeriod)} of ${CurrencyFormatter.formatCents(allocated)}',
                          style: context.ts(
                            11,
                            color: onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: paceColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isOver
                          ? 'Over'
                          : '${(pct * 100).round()}%',
                      style: context.ts(
                        10,
                        fontWeight: FontWeight.w700,
                        color: paceColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: kSpacing10),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(
                    begin: 0,
                    end: pct.clamp(0.0, 1.0),
                  ),
                  builder: (context, value, _) {
                    return LinearProgressIndicator(
                      value: value,
                      backgroundColor: onSurface.withValues(alpha: 0.05),
                      color: paceColor,
                      minHeight: 6,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
