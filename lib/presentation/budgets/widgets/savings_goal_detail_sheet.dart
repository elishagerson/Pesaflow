import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/savings_goal_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/widgets/spring_sheet_route.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pesaflow/presentation/common/widgets/success_confetti_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/liquid_glass.dart';

import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/core/utils/spacing.dart';

class SavingsGoalDetailSheet extends ConsumerStatefulWidget {
  final SavingsGoal goal;
  const SavingsGoalDetailSheet({required this.goal, super.key});

  @override
  ConsumerState<SavingsGoalDetailSheet> createState() =>
      _SavingsGoalDetailSheetState();
}

class _SavingsGoalDetailSheetState
    extends ConsumerState<SavingsGoalDetailSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedAccountId;
  bool _deductFromWallet = false;
  bool _isOperationLoading = false;

  int _calculateDaysRemaining(DateTime targetDate) {
    final diff = targetDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  Future<void> _handleContribution(bool isDeposit) async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) return;

    final amountVal = int.tryParse(amountText) ?? 0;
    if (amountVal <= 0) return;

    final amountCents = amountVal * 100;

    setState(() => _isOperationLoading = true);

    try {
      final repo = ref.read(savingsGoalRepositoryProvider);
      final trackerId = ref.read(activeTrackerIdProvider);

      // Log virtual goal contribution
      final contributionAmount = isDeposit ? amountCents : -amountCents;

      await repo.addContribution(
        savingsGoalId: widget.goal.id,
        amount: contributionAmount,
        notes: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      // If user checked wallet deduction, create a real transaction
      if (_deductFromWallet && _selectedAccountId != null) {
        final txRepo = ref.read(transactionRepositoryProvider);
        final categories = ref.read(categoriesFutureProvider).value ?? [];
        if (categories.isEmpty) return;

        // Find Savings category or default category
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
              ? 'Saved: ${widget.goal.name}'
              : 'Withdrawal: ${widget.goal.name}',
          source: 'manual',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await txRepo.createTransaction(tx);

        // Invalidate transaction state
        ref.invalidate(recentTransactionsStreamProvider);
        ref.invalidate(filteredTransactionsStreamProvider);
        ref.invalidate(accountsStreamProvider);
        ref.invalidate(netWorthProvider);
      }

      // Invalidate savings goal state
      ref.invalidate(savingsGoalsStreamProvider);
      ref.invalidate(savingsGoalsTotalSavedProvider);

      // Check if this deposit completed the savings goal milestone (crossed from < 100% to >= 100%)
      final updatedGoal = await repo.getSavingsGoalById(widget.goal.id);
      final reachedMilestone =
          isDeposit &&
          updatedGoal != null &&
          updatedGoal.currentAmount >= updatedGoal.targetAmount &&
          widget.goal.currentAmount < widget.goal.targetAmount;

      if (mounted) {
        Navigator.of(context).pop(); // pop amount modal
        CustomToast.show(
          context,
          message: isDeposit
              ? 'Successfully deposited ${CurrencyFormatter.formatCents(amountCents)}!'
              : 'Successfully withdrew ${CurrencyFormatter.formatCents(amountCents)}!',
          type: isDeposit ? ToastType.success : ToastType.error,
        );

        if (reachedMilestone) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              ModernDialog.showCustom(
                context: context,
                barrierDismissible: true,
                child: SuccessConfettiDialog(
                  goalName: widget.goal.name,
                  targetAmount: widget.goal.targetAmount,
                ),
              );
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, message: 'Error: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isOperationLoading = false);
    }
  }

  void _showAddMoneySheet(BuildContext context, bool isDeposit) {
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

        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: LiquidGlassOverlay(
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
                                  20,
                                  0,
                                  20,
                                  24,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header
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
                                                : PesaFlowIcons.wallet,
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
                                                style: theme
                                                    .textTheme
                                                    .titleLarge!
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              const SizedBox(height: kSpacing2),
                                              Text(
                                                isDeposit
                                                    ? 'Add money to your savings goal'
                                                    : 'Take money out of your savings goal',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelMedium!
                                                    .copyWith(
                                                      color: onSurface
                                                          .withValues(
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

                                    // Amount Entry
                                    Text(
                                      'AMOUNT',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall!
                                          .copyWith(letterSpacing: 0.5),
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
                                        horizontal: 16,
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            'TSh',
                                            style: theme.textTheme.titleMedium!
                                                .copyWith(
                                                  fontWeight: FontWeight.w900,
                                                  color: accentColor,
                                                ),
                                          ),
                                          const SizedBox(width: kSpacing12),
                                          Expanded(
                                            child: TextFormField(
                                              controller: _amountController,
                                              keyboardType:
                                                  TextInputType.number,
                                              autofocus: true,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                              ],
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineMedium!
                                                  .copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: onSurface,
                                                  ),
                                              decoration: InputDecoration(
                                                hintText: '0',
                                                hintStyle: TextStyle(
                                                  color: onSurface.withValues(
                                                    alpha: 0.28,
                                                  ),
                                                ),
                                                filled: true,
                                                fillColor: theme
                                                    .colorScheme
                                                    .surfaceContainerHigh,
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  borderSide: BorderSide.none,
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                      borderSide: BorderSide(
                                                        color: onSurface
                                                            .withValues(
                                                              alpha: 0.07,
                                                            ),
                                                      ),
                                                    ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                      borderSide: BorderSide(
                                                        color: theme
                                                            .colorScheme
                                                            .primary
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                        width: 1.5,
                                                      ),
                                                    ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12,
                                                    ),
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
                                                  4,
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

                                    // Note
                                    Text(
                                      'MEMO',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall!
                                          .copyWith(letterSpacing: 0.5),
                                    ),
                                    const SizedBox(height: kSpacing8),
                                    TextFormField(
                                      controller: _noteController,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium!
                                          .copyWith(color: onSurface),
                                      decoration: InputDecoration(
                                        hintText:
                                            'Add an optional note (e.g. Salary bonus)',
                                        hintStyle: TextStyle(
                                          color: onSurface.withValues(
                                            alpha: 0.28,
                                          ),
                                        ),
                                        prefixIcon: Icon(
                                          PesaFlowIcons.edit,
                                          size: 20,
                                          color: onSurface.withValues(
                                            alpha: 0.32,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: theme
                                            .colorScheme
                                            .surfaceContainerHigh,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: BorderSide(
                                            color: onSurface.withValues(
                                              alpha: 0.07,
                                            ),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: BorderSide(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.5),
                                            width: 1.5,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: kSpacing20),

                                    // Wallet deduct toggle
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
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        isDeposit
                                                            ? 'Deduct from Wallet'
                                                            : 'Refund to Wallet',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium!
                                                            .copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: onSurface,
                                                            ),
                                                      ),
                                                      const SizedBox(
                                                        height: kSpacing2,
                                                      ),
                                                      Text(
                                                        'Updates real balance & logs a transaction',
                                                        style: Theme.of(context)
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    PesaFlowIcons.wallet,
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
                                                      style: Theme.of(context)
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
                                                    dropdownColor: theme
                                                        .colorScheme
                                                        .surface,
                                                    underline: const SizedBox(),
                                                    icon: Icon(
                                                      Icons
                                                          .keyboard_arrow_down_rounded,
                                                      size: 20,
                                                      color: onSurface
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                    ),
                                                    style: Theme.of(context)
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

                                    // Action Submit Button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 54,
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          boxShadow: !_isOperationLoading
                                              ? [
                                                  BoxShadow(
                                                    color: accentColor
                                                        .withValues(alpha: 0.3),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: _isOperationLoading
                                              ? null
                                              : () => _handleContribution(
                                                  isDeposit,
                                                ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: accentColor,
                                            foregroundColor: Colors.white,
                                            disabledBackgroundColor: onSurface
                                                .withValues(alpha: 0.05),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                          ),
                                          child: _isOperationLoading
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2.5,
                                                        color: Colors.white,
                                                      ),
                                                )
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      isDeposit
                                                          ? PesaFlowIcons.add
                                                          : Icons
                                                                .remove_circle_outline_rounded,
                                                      size: 18,
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.8,
                                                          ),
                                                    ),
                                                    const SizedBox(
                                                      width: kSpacing8,
                                                    ),
                                                    Text(
                                                      isDeposit
                                                          ? 'Confirm Deposit'
                                                          : 'Confirm Withdrawal',
                                                      style: Theme.of(context)
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
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final goalColor = hexToColor(widget.goal.color);

    final contributionsAsync = ref.watch(
      savingsGoalContributionsStreamProvider(widget.goal.id),
    );

    final remainingDays = _calculateDaysRemaining(widget.goal.targetDate);
    final pct = widget.goal.targetAmount > 0
        ? (widget.goal.currentAmount / widget.goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final percentInt = (pct * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          // Top drag handle
          Center(
            child: Container(
              width: 36,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: kSpacing12),
              decoration: BoxDecoration(
                color: onSurface.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),

          // Goal Header Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpacing20),
            child: Row(
              children: [
                // Goal Icon circle
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: goalColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: goalColor.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    getGoalIcon(widget.goal.icon),
                    color: goalColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: kSpacing16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.goal.name,
                        style: theme.textTheme.titleLarge!.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: kSpacing4),
                      Text(
                        'Target deadline: ${widget.goal.targetDate.day}/${widget.goal.targetDate.month}/${widget.goal.targetDate.year} ($remainingDays days remaining)',
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(
                          color: onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: kSpacing16),

          // Main scrolling body containing dashboard progress and ledger list
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: kSpacing16),
              child: Column(
                children: [
                  // Progress Card bento
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(kSpacing20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: onSurface.withValues(alpha: 0.08),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Apple watch style circular progress ring
                        SizedBox(
                          height: 80,
                          width: 80,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  startDegreeOffset: -90,
                                  sectionsSpace: 0,
                                  centerSpaceRadius: 28,
                                  sections: [
                                    PieChartSectionData(
                                      value: pct * 100,
                                      color: goalColor,
                                      radius: 6,
                                      showTitle: false,
                                    ),
                                    PieChartSectionData(
                                      value: (1.0 - pct) * 100,
                                      color: goalColor.withValues(alpha: 0.12),
                                      radius: 6,
                                      showTitle: false,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '$percentInt%',
                                style: Theme.of(context).textTheme.bodyMedium!
                                    .copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: goalColor,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: kSpacing20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TOTAL SAVED',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: kSpacing4),
                              Text(
                                CurrencyFormatter.formatCents(
                                  widget.goal.currentAmount,
                                ),
                                style: Theme.of(context).textTheme.titleLarge!
                                    .copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: onSurface,
                                    ),
                              ),
                              const SizedBox(height: kSpacing4),
                              Text(
                                'Goal target: ${CurrencyFormatter.formatCents(widget.goal.targetAmount)}',
                                style: Theme.of(context).textTheme.labelSmall!
                                    .copyWith(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: kSpacing16),

                  // Deposit and Withdraw buttons row
                  Row(
                    children: [
                      Expanded(
                        child: TactileSpringContainer(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            _showAddMoneySheet(context, true);
                          },
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.transferColorDark.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  PesaFlowIcons.add,
                                  color: AppTheme.transferColorDark,
                                  size: 18,
                                ),
                                const SizedBox(width: kSpacing6),
                                Text(
                                  'Add Money',
                                  style: Theme.of(context).textTheme.bodySmall!
                                      .copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: context.appColors.incomeColor,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: kSpacing12),
                      Expanded(
                        child: TactileSpringContainer(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            _showAddMoneySheet(context, false);
                          },
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: context.appColors.expenseColor
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.remove_rounded,
                                  color: context.appColors.expenseColor,
                                  size: 18,
                                ),
                                const SizedBox(width: kSpacing6),
                                Text(
                                  'Withdraw',
                                  style: Theme.of(context).textTheme.bodySmall!
                                      .copyWith(
                                        fontWeight: FontWeight.bold,
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

                  // Contribution Ledger list
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'CONTRIBUTION LEDGER',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey[500],
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: kSpacing8),

                  contributionsAsync.when(
                    data: (logs) {
                      if (logs.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: kSpacing32,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'No deposits or withdrawals logged yet.',
                            style: Theme.of(context).textTheme.bodySmall!
                                .copyWith(color: Colors.grey[500]),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: logs.length,
                        separatorBuilder: (_, _) => Divider(
                          color: onSurface.withValues(alpha: 0.12),
                          height: 1,
                        ),
                        itemBuilder: (context, idx) {
                          final log = logs[idx];
                          final isPos = log.amount >= 0;

                          return StaggeredFadeSlide(
                            index: idx,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: kSpacing12,
                              ),
                              child: Row(
                                children: [
                                  // Dot indicator
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isPos
                                          ? AppTheme.transferColorDark
                                          : context.appColors.expenseColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: kSpacing14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isPos
                                              ? 'Savings Deposit'
                                              : 'Savings Withdrawal',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall!
                                              .copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        if (log.notes != null) ...[
                                          const SizedBox(height: kSpacing4),
                                          Text(
                                            log.notes!,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall!
                                                .copyWith(
                                                  color: Colors.grey[500],
                                                ),
                                          ),
                                        ],
                                        const SizedBox(height: kSpacing2),
                                        Text(
                                          '${log.createdAt.day}/${log.createdAt.month}/${log.createdAt.year} ${log.createdAt.hour}:${log.createdAt.minute.toString().padLeft(2, '0')}',
                                          style: theme.textTheme.labelSmall!.copyWith(
                                            fontSize: 9,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        (isPos ? '+' : '-') +
                                            CurrencyFormatter.formatCents(
                                              log.amount.abs(),
                                            ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall!
                                            .copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: isPos
                                                  ? AppTheme.transferColorDark
                                                  : context.appColors.expenseColor,
                                            ),
                                      ),
                                      const SizedBox(height: kSpacing2),
                                      GestureDetector(
                                        onTap: () async {
                                          final confirm =
                                              await ModernDialog.show<bool>(
                                                context: context,
                                                title: Text(
                                                  'Delete Contribution?',
                                                ),
                                                titleIcon:
                                                    PesaFlowIcons.warning,
                                                content: Text(
                                                  'This will undo this deposit/withdrawal from this visual savings goal balance.',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          context,
                                                        ).pop(false),
                                                    child: Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          context,
                                                        ).pop(true),
                                                    child: Text(
                                                      'Delete',
                                                      style: TextStyle(
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
                                          size: 16,
                                          color: Colors.red.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CupertinoActivityIndicator()),
                    error: (e, _) => Text('Error: $e'),
                  ),
                  const SizedBox(height: kSpacing20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
