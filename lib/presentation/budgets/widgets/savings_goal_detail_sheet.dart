import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
import 'package:pesaflow/presentation/common/ios/ios_list_section.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pesaflow/presentation/common/widgets/success_confetti_dialog.dart';

class SavingsGoalDetailSheet extends ConsumerStatefulWidget {
  final SavingsGoal goal;
  const SavingsGoalDetailSheet({required this.goal, super.key});

  @override
  ConsumerState<SavingsGoalDetailSheet> createState() => _SavingsGoalDetailSheetState();
}

class _SavingsGoalDetailSheetState extends ConsumerState<SavingsGoalDetailSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedAccountId;
  bool _deductFromWallet = false;
  bool _isOperationLoading = false;

  Color hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
    return Colors.grey;
  }

  IconData getGoalIcon(String iconName) {
    switch (iconName) {
      case 'savings': return Icons.savings_rounded;
      case 'laptop': return Icons.laptop_chromebook_rounded;
      case 'flight': return Icons.flight_takeoff_rounded;
      case 'home': return Icons.home_rounded;
      case 'car': return Icons.directions_car_rounded;
      case 'school': return Icons.school_rounded;
      case 'heart': return Icons.favorite_rounded;
      case 'gift': return Icons.card_giftcard_rounded;
      default: return Icons.savings_rounded;
    }
  }

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
        notes: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
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
      final reachedMilestone = isDeposit &&
          updatedGoal != null &&
          updatedGoal.currentAmount >= updatedGoal.targetAmount &&
          widget.goal.currentAmount < widget.goal.targetAmount;

      if (mounted) {
        Navigator.of(context).pop(); // pop amount modal
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDeposit 
                  ? 'Successfully deposited ${CurrencyFormatter.formatCents(amountCents)}!' 
                  : 'Successfully withdrew ${CurrencyFormatter.formatCents(amountCents)}!'
            ),
            backgroundColor: isDeposit ? const Color(0xFF30D158) : const Color(0xFFFF453A),
          ),
        );

        if (reachedMilestone) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: true,
                builder: (_) => SuccessConfettiDialog(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F0F10) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 16,
                right: 16,
                top: 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top indicator
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16, top: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isDeposit ? 'Deposit Savings' : 'Withdraw Savings',
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Amount Entry field
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          'Tsh',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDeposit ? const Color(0xFF30D158) : const Color(0xFFFF453A),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            autofocus: true,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: const TextStyle(
                              fontSize: 24,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              hintText: '0',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Note entry field
                  IosListSection(
                    header: 'MEMO',
                    rows: [
                      IosListRow(
                        title: TextFormField(
                          controller: _noteController,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Add an optional note (e.g. Salary bonus)',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Deduct option
                  IosListSection(
                    header: 'ACCOUNT TRANSACTION LOG',
                    rows: [
                      IosListRow(
                        title: Text(isDeposit ? 'Deduct from Account Wallet' : 'Refund to Account Wallet'),
                        subtitle: const Text('Updates real balance & logs a transaction'),
                        trailing: CupertinoSwitch(
                          value: _deductFromWallet,
                          activeColor: isDeposit ? const Color(0xFF30D158) : const Color(0xFFFF453A),
                          onChanged: (v) {
                            setModalState(() {
                              _deductFromWallet = v;
                            });
                          },
                        ),
                      ),
                      if (_deductFromWallet)
                        IosListRow(
                          title: const Text('Source Account'),
                          trailing: DropdownButton<String>(
                            value: _selectedAccountId,
                            dropdownColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            items: accounts.map((acc) {
                              return DropdownMenuItem<String>(
                                value: acc.id,
                                child: Text(
                                  acc.name,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              setModalState(() {
                                _selectedAccountId = v;
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isOperationLoading ? null : () => _handleContribution(isDeposit),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDeposit ? const Color(0xFF30D158) : const Color(0xFFFF453A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isOperationLoading
                          ? const CupertinoActivityIndicator(color: Colors.white)
                          : Text(
                              isDeposit ? 'Confirm Deposit' : 'Confirm Withdrawal',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final goalColor = hexToColor(widget.goal.color);
    
    final contributionsAsync = ref.watch(savingsGoalContributionsStreamProvider(widget.goal.id));

    final remainingDays = _calculateDaysRemaining(widget.goal.targetDate);
    final pct = widget.goal.targetAmount > 0 
        ? (widget.goal.currentAmount / widget.goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final percentInt = (pct * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F10) : Colors.white,
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
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),

          // Goal Header Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Goal Icon circle
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: goalColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: goalColor.withOpacity(0.3), width: 1.5),
                  ),
                  child: Icon(
                    getGoalIcon(widget.goal.icon),
                    color: goalColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.goal.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Target deadline: ${widget.goal.targetDate.day}/${widget.goal.targetDate.month}/${widget.goal.targetDate.year} ($remainingDays days remaining)',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Main scrolling body containing dashboard progress and ledger list
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Progress Card bento
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C1E) : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
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
                                    color: goalColor.withOpacity(0.12),
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
                        const SizedBox(width: 20),
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
                              const SizedBox(height: 4),
                              Text(
                                CurrencyFormatter.formatCents(widget.goal.currentAmount),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Goal target: ${CurrencyFormatter.formatCents(widget.goal.targetAmount)}',
                                style: const TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

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
                              color: const Color(0xFF30D158).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_rounded, color: Color(0xFF30D158), size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'Add Money',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFF2E7D32),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TactileSpringContainer(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            _showAddMoneySheet(context, false);
                          },
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF453A).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.remove_rounded, color: Color(0xFFFF453A), size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'Withdraw',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFFC62828),
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
                  const SizedBox(height: 24),

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
                  const SizedBox(height: 8),

                  contributionsAsync.when(
                    data: (logs) {
                      if (logs.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          alignment: Alignment.center,
                          child: Text(
                            'No deposits or withdrawals logged yet.',
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: logs.length,
                        separatorBuilder: (_, __) => Divider(
                          color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                          height: 1,
                        ),
                        itemBuilder: (context, idx) {
                          final log = logs[idx];
                          final isPos = log.amount >= 0;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                // Dot indicator
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isPos ? const Color(0xFF30D158) : const Color(0xFFFF453A),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isPos ? 'Savings Deposit' : 'Savings Withdrawal',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      if (log.notes != null) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          log.notes!,
                                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                        ),
                                      ],
                                      const SizedBox(height: 2),
                                      Text(
                                        '${log.createdAt.day}/${log.createdAt.month}/${log.createdAt.year} ${log.createdAt.hour}:${log.createdAt.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(color: Colors.grey[500], fontSize: 9),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      (isPos ? '+' : '-') + CurrencyFormatter.formatCents(log.amount.abs()),
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isPos ? const Color(0xFF30D158) : const Color(0xFFFF453A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    GestureDetector(
                                      onTap: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete Contribution?'),
                                            content: const Text('This will undo this deposit/withdrawal from this visual savings goal balance.'),
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
                                          ),
                                        );

                                        if (confirm == true) {
                                          await ref.read(savingsGoalRepositoryProvider).deleteContribution(log.id);
                                          ref.invalidate(savingsGoalsStreamProvider);
                                          ref.invalidate(savingsGoalsTotalSavedProvider);
                                        }
                                      },
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 16,
                                        color: Colors.red.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CupertinoActivityIndicator()),
                    error: (e, _) => Text('Error: $e'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
