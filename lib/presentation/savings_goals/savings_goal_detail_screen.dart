import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/savings_goal_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pesaflow/presentation/common/widgets/success_confetti_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';

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
  bool _isOperationLoading = false;

  int _calculateDaysRemaining(DateTime targetDate) {
    final diff = targetDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  Future<void> _handleContribution(SavingsGoal goal, bool isDeposit) async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) return;

    final amountVal = int.tryParse(amountText) ?? 0;
    if (amountVal <= 0) return;

    final amountCents = amountVal * 100;

    setState(() => _isOperationLoading = true);

    try {
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

      final updatedGoal = await repo.getSavingsGoalById(goal.id);
      final reachedMilestone = isDeposit &&
          updatedGoal != null &&
          updatedGoal.currentAmount >= updatedGoal.targetAmount &&
          goal.currentAmount < goal.targetAmount;

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDeposit
                  ? 'Successfully deposited ${CurrencyFormatter.formatCents(amountCents)}!'
                  : 'Successfully withdrew ${CurrencyFormatter.formatCents(amountCents)}!',
            ),
            backgroundColor:
                isDeposit ? AppTheme.transferColorDark : const Color(0xFFFF453A),
          ),
        );

        if (reachedMilestone) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              ModernDialog.showCustom(
                context: context,
                barrierDismissible: true,
                child: SuccessConfettiDialog(
                  goalName: goal.name,
                  targetAmount: goal.targetAmount,
                ),
              );
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isOperationLoading = false);
    }
  }

  void _showAddMoneySheet(BuildContext context, SavingsGoal goal, bool isDeposit) {
    _amountController.clear();
    _noteController.clear();
    _deductFromWallet = false;
    _selectedAccountId = null;

    final accounts = ref.read(accountsStreamProvider).value ?? [];
    if (accounts.isNotEmpty) {
      _selectedAccountId = accounts.first.id;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        final accentColor =
            isDeposit ? const Color(0xFF609F8A) : const Color(0xFFFF453A);

        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xF01C1C1E) : const Color(0xF0F2F2F7),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
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
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.15),
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
                              padding: const EdgeInsets.fromLTRB(kSpacing20, 0, kSpacing20, kSpacing24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(kSpacing10),
                                        decoration: BoxDecoration(
                                          color: accentColor
                                              .withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isDeposit
                                              ? Icons.savings_rounded
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
                                              style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: kSpacing2),
                                            Text(
                                              isDeposit
                                                  ? 'Add money to your savings goal'
                                                  : 'Take money out of your savings goal',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: kSpacing24),
                                  const Text('AMOUNT',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5)),
                                  const SizedBox(height: kSpacing8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1C1C1E)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.08)
                                            : Colors.black
                                                .withValues(alpha: 0.06),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: kSpacing16, vertical: kSpacing4),
                                    child: Row(
                                      children: [
                                        Text(
                                          'TSh',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
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
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: '0',
                                              hintStyle: TextStyle(
                                                  color: isDark
                                                      ? Colors.white30
                                                      : Colors.black26),
                                              filled: true,
                                              fillColor: isDark
                                                  ? const Color(0xFF1C1C1E)
                                                  : const Color(0xFFF2F2F7),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                borderSide: BorderSide.none,
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                borderSide: BorderSide(
                                                    color: isDark
                                                        ? Colors.white
                                                            .withValues(alpha: 0.08)
                                                        : Colors.black
                                                            .withValues(alpha: 0.06)),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                borderSide: BorderSide(
                                                    color: theme
                                                        .colorScheme.primary
                                                        .withValues(alpha: 0.5),
                                                    width: 1.5),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12),
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
                                              padding: const EdgeInsets.all(kSpacing4),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.white
                                                        .withValues(alpha: 0.1)
                                                    : Colors.black
                                                        .withValues(alpha: 0.05),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                  Icons.close_rounded,
                                                  size: 18,
                                                  color: isDark
                                                      ? Colors.white54
                                                      : Colors.black45),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: kSpacing20),
                                  const Text('MEMO',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5)),
                                  const SizedBox(height: kSpacing8),
                                  TextFormField(
                                    controller: _noteController,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    style: TextStyle(
                                        fontSize: 15,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black),
                                    decoration: InputDecoration(
                                      hintText: 'Add an optional note',
                                      hintStyle: TextStyle(
                                          color: isDark
                                              ? Colors.white30
                                              : Colors.black26),
                                      prefixIcon: Icon(
                                          Icons.edit_note_rounded,
                                          size: 20,
                                          color: isDark
                                              ? Colors.white38
                                              : Colors.black26),
                                      filled: true,
                                      fillColor: isDark
                                          ? const Color(0xFF1C1C1E)
                                          : const Color(0xFFF2F2F7),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                            color: isDark
                                                ? Colors.white
                                                    .withValues(alpha: 0.08)
                                                : Colors.black
                                                    .withValues(alpha: 0.06)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                            color: theme
                                                .colorScheme.primary
                                                .withValues(alpha: 0.5),
                                            width: 1.5),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: kSpacing16, vertical: kSpacing14),
                                    ),
                                  ),
                                  const SizedBox(height: kSpacing20),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1C1C1E)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.08)
                                            : Colors.black
                                                .withValues(alpha: 0.06),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: kSpacing16, vertical: kSpacing12),
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
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 15,
                                                        color: isDark
                                                            ? Colors.white
                                                            : Colors.black87,
                                                      ),
                                                    ),
                                                    const SizedBox(height: kSpacing2),
                                                    Text(
                                                      'Updates real balance & logs a transaction',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: isDark
                                                            ? Colors.white38
                                                            : Colors.black38,
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
                                            color: isDark
                                                ? Colors.white
                                                    .withValues(alpha: 0.08)
                                                : Colors.black
                                                    .withValues(alpha: 0.06),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: kSpacing16, vertical: kSpacing8),
                                            child: Row(
                                              children: [
                                                Icon(
                                                    Icons
                                                        .account_balance_wallet_rounded,
                                                    size: 18,
                                                    color: isDark
                                                        ? Colors.white38
                                                        : Colors.black38),
                                                const SizedBox(width: kSpacing10),
                                                const Expanded(
                                                  child: Text(
                                                      'Source Account',
                                                      style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w500)),
                                                ),
                                                DropdownButton<String>(
                                                  value: _selectedAccountId,
                                                  dropdownColor: isDark
                                                      ? const Color(0xFF1C1C1E)
                                                      : Colors.white,
                                                  underline: const SizedBox(),
                                                  icon: Icon(
                                                      Icons
                                                          .keyboard_arrow_down_rounded,
                                                      size: 20,
                                                      color: isDark
                                                          ? Colors.white54
                                                          : Colors.black45),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark
                                                        ? Colors.white
                                                        : Colors.black87,
                                                  ),
                                                  items: accounts.map((acc) {
                                                    return DropdownMenuItem<
                                                        String>(
                                                      value: acc.id,
                                                      child: Text(
                                                          '${acc.name} (${CurrencyFormatter.formatCents(acc.balance)})'),
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
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 250),
                                      curve: Curves.easeOutCubic,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(16),
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
                                                goal, isDeposit),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: accentColor,
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.05)
                                              : Colors.black
                                                  .withValues(alpha: 0.05),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16)),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: kSpacing14),
                                        ),
                                        child: _isOperationLoading
                                            ? const SizedBox(
                                                width: kSpacing24,
                                                height: kSpacing24,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2.5,
                                                        color: Colors.white),
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
                                                      color: Colors.white
                                                          .withValues(alpha: 0.8)),
                                                  const SizedBox(width: kSpacing8),
                                                  Text(
                                                    isDeposit
                                                        ? 'Confirm Deposit'
                                                        : 'Confirm Withdrawal',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16),
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
      titleIcon: Icons.warning_amber_rounded,
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
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    );

    if (confirm == true) {
      await ref.read(savingsGoalRepositoryProvider).deleteSavingsGoal(id);
      ref.invalidate(savingsGoalsStreamProvider);
      ref.invalidate(savingsGoalsTotalSavedProvider);
      if (mounted) context.pop();
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
    final isDark = theme.brightness == Brightness.dark;
    final goalsAsync = ref.watch(savingsGoalsStreamProvider);

    return goalsAsync.when(
      data: (goals) {
        final goal = goals.where((g) => g.id == widget.goalId).firstOrNull;
        if (goal == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Goal not found')),
          );
        }

        final goalColor = hexToColor(goal.color);
        final contributionsAsync = ref
            .watch(savingsGoalContributionsStreamProvider(goal.id));

        final remainingDays = _calculateDaysRemaining(goal.targetDate);
        final pct = goal.targetAmount > 0
            ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
            : 0.0;
        final percentInt = (pct * 100).round();

        return Scaffold(
          appBar: AppBar(
            title: Text(goal.name),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => context.push('/savings-goals/${goal.id}/edit'),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    size: 20, color: Colors.red.withValues(alpha: 0.7)),
                onPressed: () => _deleteGoal(goal.id),
              ),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(kSpacing16, 0, kSpacing16, kSpacing24),
            child: Column(
              children: [
                const SizedBox(height: kSpacing8),
                // Goal header
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: goalColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: goalColor.withValues(alpha: 0.3),
                            width: 1.5),
                      ),
                      child: Icon(
                        getGoalIcon(goal.icon),
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
                            goal.name,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: kSpacing4),
                          Text(
                            'Target deadline: ${goal.targetDate.day}/${goal.targetDate.month}/${goal.targetDate.year} ($remainingDays days remaining)',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: kSpacing16),

                // Progress Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(kSpacing20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1C1C1E)
                        : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? const Color(0x1AFFFFFF)
                          : const Color(0x0F000000),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        height: kSpacing64,
                        width: kSpacing64,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(PieChartData(
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
                            )),
                            Text(
                              '$percentInt%',
                              style: TextStyle(
                                color: goalColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
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
                                  goal.currentAmount),
                              style: TextStyle(
                                fontSize: 22,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w900,
                                color:
                                    isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: kSpacing4),
                            Text(
                              'Goal target: ${CurrencyFormatter.formatCents(goal.targetAmount)}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: kSpacing16),

                // Deposit / Withdraw buttons
                Row(
                  children: [
                    Expanded(
                      child: TactileSpringContainer(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          _showAddMoneySheet(context, goal, true);
                        },
                        child: Container(
                          height: kSpacing48,
                          decoration: BoxDecoration(
                            color: AppTheme.transferColorDark
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_rounded,
                                  color: AppTheme.transferColorDark,
                                  size: 18),
                              const SizedBox(width: kSpacing6),
                              Text(
                                'Add Money',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF2E7D32),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
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
                          _showAddMoneySheet(context, goal, false);
                        },
                        child: Container(
                          height: kSpacing48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF453A)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.remove_rounded,
                                  color: Color(0xFFFF453A), size: 18),
                              const SizedBox(width: kSpacing6),
                              Text(
                                'Withdraw',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFFC62828),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
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

                // Contribution Ledger
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
                        padding: const EdgeInsets.symmetric(vertical: kSpacing32),
                        alignment: Alignment.center,
                        child: Text(
                          'No deposits or withdrawals logged yet.',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 13),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: logs.length,
                      separatorBuilder: (_, _) => Divider(
                        color: isDark
                            ? const Color(0xFF2C2C2E)
                            : Colors.grey[200],
                        height: 1,
                      ),
                      itemBuilder: (context, idx) {
                        final log = logs[idx];
                        final isPos = log.amount >= 0;

                        return StaggeredFadeSlide(
                          index: idx,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: kSpacing12),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isPos
                                        ? AppTheme.transferColorDark
                                        : const Color(0xFFFF453A),
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
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                      ),
                                      if (log.notes != null) ...[
                                        const SizedBox(height: kSpacing4),
                                        Text(
                                          log.notes!,
                                          style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 11),
                                        ),
                                      ],
                                      const SizedBox(height: kSpacing2),
                                      Text(
                                        '${log.createdAt.day}/${log.createdAt.month}/${log.createdAt.year} ${log.createdAt.hour}:${log.createdAt.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 9),
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
                                              log.amount.abs()),
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isPos
                                            ? AppTheme.transferColorDark
                                            : const Color(0xFFFF453A),
                                      ),
                                    ),
                                    const SizedBox(height: kSpacing2),
                                    GestureDetector(
                                      onTap: () async {
                                        final confirm =
                                            await ModernDialog.show<bool>(
                                          context: context,
                                          title: const Text(
                                              'Delete Contribution?'),
                                          titleIcon:
                                              Icons.warning_amber_rounded,
                                          content: const Text(
                                            'This will undo this deposit/withdrawal from this visual savings goal balance.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context)
                                                      .pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context)
                                                      .pop(true),
                                              child: const Text('Delete',
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                            ),
                                          ],
                                        );

                                        if (confirm == true) {
                                          await ref
                                              .read(
                                                  savingsGoalRepositoryProvider)
                                              .deleteContribution(log.id);
                                          ref.invalidate(
                                              savingsGoalsStreamProvider);
                                          ref.invalidate(
                                              savingsGoalsTotalSavedProvider);
                                        }
                                      },
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 16,
                                        color: Colors.red
                                            .withValues(alpha: 0.7),
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
              ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CupertinoActivityIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $err')),
      ),
    );
  }
}
