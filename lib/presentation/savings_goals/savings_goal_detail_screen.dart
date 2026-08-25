import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/savings_goal_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/widgets/spring_sheet_route.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/empty_state.dart';
import 'package:pesaflow/presentation/common/widgets/error_state.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/undo_delete.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';

class SavingsGoalDetailScreen extends ConsumerStatefulWidget {
  final String goalId;
  const SavingsGoalDetailScreen({required this.goalId, super.key});

  @override
  ConsumerState<SavingsGoalDetailScreen> createState() =>
      _SavingsGoalDetailScreenState();
}

class _SavingsGoalDetailScreenState
    extends ConsumerState<SavingsGoalDetailScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedAccountId;
  bool _deductFromWallet = false;

  int _calculateDaysRemaining(DateTime targetDate) {
    final diff = targetDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  Future<void> _handleContribution(SavingsGoal goal, bool isDeposit) async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      CustomToast.show(
        context,
        message: 'Please enter an amount.',
        type: ToastType.error,
      );
      return;
    }

    final amountVal = int.tryParse(amountText) ?? 0;
    if (amountVal <= 0) {
      CustomToast.show(
        context,
        message: 'Please enter a valid amount.',
        type: ToastType.error,
      );
      return;
    }

    final amountCents = amountVal * 100;

    final repo = ref.read(savingsGoalRepositoryProvider);
    final trackerId = ref.read(activeTrackerIdProvider);

    final contributionAmount = isDeposit ? amountCents : -amountCents;

    await repo.addContribution(
      savingsGoalId: goal.id,
      amount: contributionAmount,
      notes: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    if (mounted) {
      if (isDeposit) {
        CustomToast.show(
          context,
          message: 'Contribution saved successfully!',
          type: ToastType.success,
        );
      } else {
        CustomToast.show(
          context,
          message: 'Withdrawal completed!',
          type: ToastType.success,
        );
      }
      _amountController.clear();
      _noteController.clear();
    }

    if (_deductFromWallet && _selectedAccountId != null) {
      final txRepo = ref.read(transactionRepositoryProvider);
      final categories = ref.read(categoriesFutureProvider).value ?? [];
      if (categories.isNotEmpty) {
        final savingsCategory = categories.firstWhere(
          (c) => c.name.toLowerCase() == 'savings' || c.icon == 'piggy-bank',
          orElse: () => categories.first,
        );

        final uuid = const Uuid();
        final tx = Transaction(
          id: uuid.v4(),
          accountId: _selectedAccountId!,
          categoryId: savingsCategory.id,
          trackerId: trackerId,
          amount: amountCents,
          type: isDeposit ? 'expense' : 'income',
          description: isDeposit
              ? 'Saved: ${goal.name}'
              : 'Withdrawal: ${goal.name}',
          source: 'manual',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await txRepo.createTransaction(tx);

        ref.invalidate(recentTransactionsStreamProvider);
        ref.invalidate(filteredTransactionsStreamProvider);
        ref.invalidate(accountsStreamProvider);
        ref.invalidate(netWorthProvider);
      }
    }

    ref.invalidate(savingsGoalsStreamProvider);
    ref.invalidate(savingsGoalsTotalSavedProvider);
  }

  void _showAddMoneySheet(
    BuildContext context,
    SavingsGoal goal,
    bool isDeposit,
  ) {
    _amountController.clear();
    _noteController.clear();
    _deductFromWallet = false;
    _selectedAccountId = null;

    final accounts = ref.read(accountsStreamProvider).value ?? [];
    if (accounts.isNotEmpty) {
      _selectedAccountId = accounts.first.id;
    }

    showSpringSheet(
      context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final onSurface = theme.colorScheme.onSurface;
        final accentColor = isDeposit
            ? context.appColors.incomeColor
            : context.appColors.expenseColor;
        bool sheetIsContributing = false;

        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.94),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: StatefulBuilder(
                  builder: (context, setModalState) {
                    return Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        const SizedBox(height: kSpacing10),
                        Container(
                          width: 38,
                          height: 5,
                          decoration: BoxDecoration(
                            color: onSurface.withValues(alpha: 0.17),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        const SizedBox(height: kSpacing16),
                        Expanded(
                          child: RawScrollbar(
                            controller: scrollController,
                            child: SingleChildScrollView(
                              controller: scrollController,
                              physics: const ClampingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                kSpacing20,
                                0,
                                kSpacing20,
                                kSpacing24,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(
                                          kSpacing10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: accentColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isDeposit
                                              ? PesaFlowIcons.savings
                                              : Icons
                                                    .account_balance_wallet_rounded,
                                          color: accentColor,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: kSpacing14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isDeposit
                                                  ? 'Deposit Savings'
                                                  : 'Withdraw Savings',
                                              style: context.ts(
                                                17,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: kSpacing2),
                                            Text(
                                              isDeposit
                                                  ? 'Add money to your savings goal'
                                                  : 'Take money out of your savings goal',
                                              style: context.ts(
                                                12,
                                                color: onSurface.withValues(
                                                  alpha: 0.6,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: kSpacing24),
                                  Text(
                                    'AMOUNT',
                                    style: theme.textTheme.labelSmall!.copyWith(
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: kSpacing8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: onSurface.withValues(
                                          alpha: 0.07,
                                        ),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: kSpacing16,
                                      vertical: kSpacing4,
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          'TSh',
                                          style: theme.textTheme.titleMedium!
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: accentColor,
                                              ),
                                        ),
                                        const SizedBox(width: kSpacing12),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _amountController,
                                            keyboardType: TextInputType.number,
                                            autofocus: true,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            style: theme
                                                .textTheme
                                                .headlineMedium!
                                                .copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: onSurface,
                                                ),
                                            decoration: context.inputDecoration(
                                              hintText: '0',
                                            ),
                                          ),
                                        ),
                                        if (_amountController.text.isNotEmpty)
                                          GestureDetector(
                                            onTap: () {
                                              _amountController.clear();
                                              setModalState(() {});
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(
                                                kSpacing4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: onSurface.withValues(
                                                  alpha: 0.07,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                PesaFlowIcons.close,
                                                size: 18,
                                                color: onSurface.withValues(
                                                  alpha: 0.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: kSpacing20),
                                  Text(
                                    'MEMO',
                                    style: theme.textTheme.labelSmall!.copyWith(
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: kSpacing8),
                                  TextFormField(
                                    controller: _noteController,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    style: theme.textTheme.bodyMedium!.copyWith(
                                      color: onSurface,
                                    ),
                                    decoration: context.inputDecoration(
                                      hintText: 'Add an optional note',
                                      prefixIcon: Icon(
                                        PesaFlowIcons.edit,
                                        size: 20,
                                        color: onSurface.withValues(
                                          alpha: 0.32,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: kSpacing20),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: onSurface.withValues(
                                          alpha: 0.07,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: kSpacing16,
                                            vertical: kSpacing12,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      isDeposit
                                                          ? 'Deduct from Wallet'
                                                          : 'Refund to Wallet',
                                                      style: theme
                                                          .textTheme
                                                          .bodyMedium!
                                                          .copyWith(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: onSurface,
                                                          ),
                                                    ),
                                                    const SizedBox(
                                                      height: kSpacing2,
                                                    ),
                                                    Text(
                                                      'Updates real balance & logs a transaction',
                                                      style: theme
                                                          .textTheme
                                                          .labelMedium!
                                                          .copyWith(
                                                            color: onSurface
                                                                .withValues(
                                                                  alpha: 0.38,
                                                                ),
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              CupertinoSwitch(
                                                value: _deductFromWallet,
                                                activeTrackColor: accentColor,
                                                onChanged: (v) {
                                                  setModalState(() {
                                                    _deductFromWallet = v;
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (_deductFromWallet) ...[
                                          Divider(
                                            height: 0.5,
                                            thickness: 0.5,
                                            color: onSurface.withValues(
                                              alpha: 0.07,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: kSpacing16,
                                              vertical: kSpacing8,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons
                                                      .account_balance_wallet_rounded,
                                                  size: 18,
                                                  color: onSurface.withValues(
                                                    alpha: 0.38,
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: kSpacing10,
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    'Source Account',
                                                    style: theme
                                                        .textTheme
                                                        .bodyMedium!
                                                        .copyWith(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                  ),
                                                ),
                                                DropdownButton<String>(
                                                  value: _selectedAccountId,
                                                  dropdownColor:
                                                      theme.colorScheme.surface,
                                                  underline: const SizedBox(),
                                                  icon: Icon(
                                                    Icons
                                                        .keyboard_arrow_down_rounded,
                                                    size: 20,
                                                    color: onSurface.withValues(
                                                      alpha: 0.5,
                                                    ),
                                                  ),
                                                  style: theme
                                                      .textTheme
                                                      .titleSmall!
                                                      .copyWith(
                                                        color: onSurface,
                                                      ),
                                                  items: accounts.map((acc) {
                                                    return DropdownMenuItem<
                                                      String
                                                    >(
                                                      value: acc.id,
                                                      child: Text(
                                                        '${acc.name} (${CurrencyFormatter.formatCents(acc.balance)})',
                                                      ),
                                                    );
                                                  }).toList(),
                                                  onChanged: (v) {
                                                    setModalState(() {
                                                      _selectedAccountId = v;
                                                    });
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: kSpacing28),
                                  SizedBox(
                                    width: double.infinity,
                                    height: kSpacing56,
                                    child: ElevatedButton(
                                      onPressed: sheetIsContributing
                                          ? null
                                          : () async {
                                              setModalState(() {
                                                sheetIsContributing = true;
                                              });
                                              try {
                                                await _handleContribution(
                                                  goal,
                                                  isDeposit,
                                                );
                                                if (context.mounted) {
                                                  Navigator.of(context).pop();
                                                }
                                              } catch (e) {
                                                setModalState(() {
                                                  sheetIsContributing = false;
                                                });
                                                if (context.mounted) {
                                                  CustomToast.show(
                                                    context,
                                                    message: 'Error: $e',
                                                    type: ToastType.error,
                                                  );
                                                }
                                              }
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: accentColor,
                                        foregroundColor:
                                            theme.colorScheme.onPrimary,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: kSpacing14,
                                        ),
                                      ),
                                      child: sheetIsContributing
                                          ? SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color:
                                                    theme.colorScheme.onPrimary,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  isDeposit
                                                      ? Icons
                                                            .add_circle_outline_rounded
                                                      : Icons
                                                            .remove_circle_outline_rounded,
                                                  size: 18,
                                                  color: theme
                                                      .colorScheme
                                                      .onPrimary
                                                      .withValues(alpha: 0.8),
                                                ),
                                                const SizedBox(
                                                  width: kSpacing8,
                                                ),
                                                Text(
                                                  isDeposit
                                                      ? 'Confirm Deposit'
                                                      : 'Confirm Withdrawal',
                                                  style: theme
                                                      .textTheme
                                                      .titleMedium!
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteGoal(String id) async {
    final confirm = await ModernDialog.show<bool>(
      context: context,
      title: const Text('Delete Savings Goal?'),
      titleIcon: PesaFlowIcons.warning,
      content: const Text(
        'This will permanently delete this goal and all its contribution history.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Delete', style: context.ts(14, color: Colors.red)),
        ),
      ],
    );

    if (confirm == true) {
      if (!mounted) return;
      final goalsAsync = ref.read(savingsGoalsStreamProvider);
      final goal = goalsAsync.value?.where((g) => g.id == id).firstOrNull;
      if (goal == null) return;
      final goalName = goal.name;
      final trackerId = goal.trackerId;

      if (!context.mounted) return;
      UndoDelete.show(
        context: context,
        entityName: 'Savings Goal',
        message: '"$goalName" deleted',
        onUndo: () async {
          await ref
              .read(savingsGoalRepositoryProvider)
              .createSavingsGoal(
                name: goal.name,
                targetAmount: goal.targetAmount,
                targetDate: goal.targetDate,
                color: goal.color,
                icon: goal.icon,
                trackerId: trackerId,
              );
          if (mounted) {
            ref.invalidate(savingsGoalsStreamProvider);
            ref.invalidate(savingsGoalsTotalSavedProvider);
          }
        },
        onDelete: () async {
          await ref.read(savingsGoalRepositoryProvider).deleteSavingsGoal(id);
          if (mounted) {
            ref.invalidate(savingsGoalsStreamProvider);
            ref.invalidate(savingsGoalsTotalSavedProvider);
            context.pop();
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goalsAsync = ref.watch(savingsGoalsStreamProvider);

    return goalsAsync.when(
      data: (goals) {
        final goal = goals.where((g) => g.id == widget.goalId).firstOrNull;
        if (goal == null) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Row(
                      children: [
                        TactileSpringContainer(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Container(
                            padding: const EdgeInsets.all(kSpacing10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: EmptyState(
                      icon: PesaFlowIcons.savings,
                      title: 'Goal Not Found',
                      subtitle:
                          'The requested savings goal details could not be located.',
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final goalColor = hexToColor(goal.color);
        final contributionsAsync = ref.watch(
          savingsGoalContributionsStreamProvider(goal.id),
        );

        final remainingDays = _calculateDaysRemaining(goal.targetDate);
        final pct = goal.targetAmount > 0
            ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
            : 0.0;
        final percentInt = (pct * 100).round();

        final daysElapsed = DateTime.now().difference(goal.targetDate).inDays < 0
            ? DateTime.now().difference(
                DateTime.now().subtract(
                  DateTime.now().difference(goal.targetDate),
                ),
              ).inDays
            : 0;
        final dailyTarget = remainingDays > 0
            ? (goal.targetAmount - goal.currentAmount) ~/ (remainingDays * 100)
            : 0;
        final totalSaved = goal.currentAmount;

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ── OLED Black Header ──
                Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.of(context).padding.top + 8,
                    20,
                    16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TactileSpringContainer(
                            onTap: () => Navigator.of(context).maybePop(),
                            child: Container(
                              padding: const EdgeInsets.all(kSpacing10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                          const Spacer(),
                          TactileSpringContainer(
                            onTap: () =>
                                context.push('/savings-goals/${goal.id}/edit'),
                            child: Container(
                              padding: const EdgeInsets.all(kSpacing10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                PesaFlowIcons.edit,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: kSpacing8),
                          TactileSpringContainer(
                            onTap: () => _deleteGoal(goal.id),
                            child: Container(
                              padding: const EdgeInsets.all(kSpacing10),
                              decoration: BoxDecoration(
                                color: context.appColors.expenseColor
                                    .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                PesaFlowIcons.delete,
                                size: 18,
                                color: context.appColors.expenseColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: kSpacing12),
                      Text(
                        goal.name,
                        style: context.ts(
                          28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: kSpacing4),
                      Row(
                        children: [
                          Icon(
                            getGoalIcon(goal.icon),
                            size: 14,
                            color: goalColor,
                          ),
                          const SizedBox(width: kSpacing6),
                          Text(
                            remainingDays > 0
                                ? '$remainingDays days remaining'
                                : 'Target date reached',
                            style: context.ts(
                              12,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                          const SizedBox(width: kSpacing10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: kSpacing8,
                              vertical: kSpacing2,
                            ),
                            decoration: BoxDecoration(
                              color: goalColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$percentInt%',
                              style: context.ts(
                                11,
                                fontWeight: FontWeight.w700,
                                color: goalColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Scrollable body ──
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      kSpacing16,
                      0,
                      kSpacing16,
                      kSpacing24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Hero Progress Card ──
                        Hero(
                          tag: 'goal-${goal.id}',
                          child: GlassCard(
                            padding: const EdgeInsets.all(kSpacing24),
                            child: Center(
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 140,
                                    width: 140,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SizedBox(
                                          height: 140,
                                          width: 140,
                                          child: CircularProgressIndicator(
                                            value: pct,
                                            strokeWidth: 10,
                                            backgroundColor: goalColor
                                                .withValues(alpha: 0.1),
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              goalColor,
                                            ),
                                            strokeCap: StrokeCap.round,
                                          ),
                                        ),
                                        Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            color: goalColor
                                                .withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            getGoalIcon(goal.icon),
                                            color: goalColor,
                                            size: 32,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: kSpacing16),
                                  AmountText(
                                    amountInCents: totalSaved,
                                    style: context.ts(
                                      32,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.8,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: kSpacing2),
                                  Text(
                                    'of ${CurrencyFormatter.formatCents(goal.targetAmount)}',
                                    style: context.ts(
                                      13,
                                      color: Colors.white.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: kSpacing16),

                        // ── Stats Row ──
                        Row(
                          children: [
                            _GoalStatCard(
                              label: 'Remaining',
                              value: CurrencyFormatter.formatCents(
                                (goal.targetAmount - goal.currentAmount)
                                    .clamp(0, goal.targetAmount),
                              ),
                              color: goalColor,
                              theme: theme,
                            ),
                            const SizedBox(width: kSpacing10),
                            _GoalStatCard(
                              label: 'Days Left',
                              value: '$remainingDays',
                              color: theme.colorScheme.secondary,
                              theme: theme,
                            ),
                            const SizedBox(width: kSpacing10),
                            _GoalStatCard(
                              label: 'Daily Target',
                              value: CurrencyFormatter.formatCents(
                                dailyTarget * 100,
                              ),
                              color: Colors.orange,
                              theme: theme,
                            ),
                          ],
                        ),
                        const SizedBox(height: kSpacing16),

                        // ── Action Buttons ──
                        Row(
                          children: [
                            Expanded(
                              child: TactileSpringContainer(
                                onTap: () {
                                  _showAddMoneySheet(context, goal, true);
                                },
                                child: Container(
                                  height: kSpacing52,
                                  decoration: BoxDecoration(
                                    color: context.appColors.incomeColor
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        PesaFlowIcons.add,
                                        color: context.appColors.incomeColor,
                                        size: 18,
                                      ),
                                      const SizedBox(width: kSpacing6),
                                      Text(
                                        'Deposit',
                                        style: context.ts(
                                          14,
                                          fontWeight: FontWeight.w700,
                                          color: context.appColors.incomeColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: kSpacing10),
                            Expanded(
                              child: TactileSpringContainer(
                                onTap: () {
                                  _showAddMoneySheet(context, goal, false);
                                },
                                child: Container(
                                  height: kSpacing52,
                                  decoration: BoxDecoration(
                                    color: context.appColors.expenseColor
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        PesaFlowIcons.remove,
                                        color: context.appColors.expenseColor,
                                        size: 18,
                                      ),
                                      const SizedBox(width: kSpacing6),
                                      Text(
                                        'Withdraw',
                                        style: context.ts(
                                          14,
                                          fontWeight: FontWeight.w700,
                                          color: context.appColors.expenseColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: kSpacing24),

                        // ── Contribution History ──
                        Row(
                          children: [
                            Text(
                              'Contribution History',
                              style: context.ts(
                                15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: kSpacing10),

                        contributionsAsync.when(
                          data: (logs) {
                            if (logs.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: kSpacing32,
                                ),
                                child: Center(
                                  child: Text(
                                    'No contributions yet. Tap Deposit to get started.',
                                    style: context.ts(
                                      13,
                                      color: Colors.white.withValues(alpha: 0.35),
                                    ),
                                  ),
                                ),
                              );
                            }

                            return Column(
                              children: logs.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final log = entry.value;
                                final isPos = log.amount >= 0;

                                return StaggeredFadeSlide(
                                  index: idx,
                                  child: GlassCard(
                                    margin: const EdgeInsets.only(
                                      bottom: kSpacing8,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: kSpacing14,
                                      vertical: kSpacing12,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: (isPos
                                                    ? context
                                                        .appColors.incomeColor
                                                    : context
                                                        .appColors.expenseColor)
                                                .withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isPos
                                                ? PesaFlowIcons.add
                                                : PesaFlowIcons.remove,
                                            size: 16,
                                            color: isPos
                                                ? context.appColors.incomeColor
                                                : context
                                                    .appColors.expenseColor,
                                          ),
                                        ),
                                        const SizedBox(width: kSpacing12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                isPos
                                                    ? 'Deposit'
                                                    : 'Withdrawal',
                                                style: context.ts(
                                                  13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              if (log.notes != null &&
                                                  log.notes!.isNotEmpty) ...[
                                                const SizedBox(
                                                  height: kSpacing2,
                                                ),
                                                Text(
                                                  log.notes!,
                                                  style: context.ts(
                                                    11,
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.4,
                                                        ),
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '${isPos ? '+' : '-'}${CurrencyFormatter.formatCents(log.amount.abs())}',
                                              style: context.ts(
                                                13,
                                                fontWeight: FontWeight.w700,
                                                color: isPos
                                                    ? context
                                                        .appColors.incomeColor
                                                    : context
                                                        .appColors.expenseColor,
                                              ),
                                            ),
                                            const SizedBox(height: kSpacing2),
                                            Text(
                                              '${log.createdAt.day}/${log.createdAt.month}/${log.createdAt.year}',
                                              style: context.ts(
                                                10,
                                                color: Colors.white
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: kSpacing8),
                                        GestureDetector(
                                          onTap: () async {
                                            final confirm =
                                                await ModernDialog.show<bool>(
                                                  context: context,
                                                  title: const Text(
                                                    'Delete Contribution?',
                                                  ),
                                                  titleIcon:
                                                      PesaFlowIcons.warning,
                                                  content: const Text(
                                                    'This will undo this deposit/withdrawal from this goal\'s balance.',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(
                                                        context,
                                                      ).pop(false),
                                                      child:
                                                          const Text('Cancel'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(
                                                        context,
                                                      ).pop(true),
                                                      child: Text(
                                                        'Delete',
                                                        style: context.ts(
                                                          14,
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );

                                            if (confirm == true) {
                                              await ref
                                                  .read(
                                                    savingsGoalRepositoryProvider,
                                                  )
                                                  .deleteContribution(log.id);
                                              ref.invalidate(
                                                savingsGoalsStreamProvider,
                                              );
                                              ref.invalidate(
                                                savingsGoalsTotalSavedProvider,
                                              );
                                            }
                                          },
                                          child: Icon(
                                            PesaFlowIcons.delete,
                                            size: 14,
                                            color: Colors.white.withValues(
                                              alpha: 0.2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: kSpacing20),
                            child: SkeletonCard(height: 80),
                          ),
                          error: (e, _) => ErrorState(
                            title: 'Failed to Load Contributions',
                            message: e.toString(),
                            onRetry: () => ref.invalidate(
                              savingsGoalContributionsStreamProvider(goal.id),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  children: [
                    TactileSpringContainer(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        padding: const EdgeInsets.all(kSpacing10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(kSpacing20),
                child: Column(
                  children: [
                    SkeletonCard(height: 200),
                    SizedBox(height: kSpacing16),
                    SkeletonCard(height: 120),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  children: [
                    TactileSpringContainer(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        padding: const EdgeInsets.all(kSpacing10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ErrorState(
                  title: 'Failed to Load Goal Details',
                  message: err.toString(),
                  onRetry: () =>
                      ref.invalidate(savingsGoalsStreamProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
