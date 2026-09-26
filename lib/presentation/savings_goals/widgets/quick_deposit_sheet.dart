import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/savings_goal_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/presentation/common/widgets/spring_sheet_route.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

Future<void> showQuickDepositSheet(
  BuildContext context,
  WidgetRef ref,
  SavingsGoal goal,
) async {
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  bool deductFromWallet = false;
  String? selectedAccountId;
  bool isSubmitting = false;

  final accounts = ref.watch(accountsStreamProvider).value ?? [];
  if (accounts.isNotEmpty) {
    selectedAccountId = accounts.first.id;
  }

  final goalColor = hexToColor(goal.color);
  final remainingCents = (goal.targetAmount - goal.currentAmount).clamp(
    0,
    goal.targetAmount,
  );

  await showSpringSheet(
    context,
    isScrollControlled: true,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      final onSurface = theme.colorScheme.onSurface;

      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          int depositCents() =>
              CurrencyFormatter.parseToCents(amountController.text);

          void appendQuickAmount(int additionalCents) {
            PesaHaptics.selection();
            final currentVal = depositCents();
            final newVal = currentVal + additionalCents;
            amountController.text = (newVal ~/ 100).toString();
            setSheetState(() {});
          }

          void fillRemaining() {
            PesaHaptics.selection();
            amountController.text = (remainingCents ~/ 100).toString();
            setSheetState(() {});
          }

          final cents = depositCents();
          final selectedAccount = accounts
              .where((a) => a.id == selectedAccountId)
              .firstOrNull;
          final hasSufficientFunds =
              !deductFromWallet ||
              selectedAccount == null ||
              selectedAccount.balance >= cents;

          final currentAmt = goal.currentAmount;
          final targetAmt = goal.targetAmount;
          final projectedAmt = (currentAmt + cents).clamp(0, targetAmt);
          final currentFraction = targetAmt > 0
              ? (currentAmt / targetAmt).clamp(0.0, 1.0)
              : 0.0;
          final projectedFraction = targetAmt > 0
              ? (projectedAmt / targetAmt).clamp(0.0, 1.0)
              : 0.0;
          final remainingGap = (targetAmt - projectedAmt).clamp(0, targetAmt);
          final isCompleted = cents > 0 && remainingGap == 0;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                kSpacing20,
                kSpacing12,
                kSpacing20,
                kSpacing24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusPill,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: kSpacing16),
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: goalColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusCard,
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
                              'Deposit into ${goal.name}',
                              style: sheetCtx.ts(
                                17,
                                fontWeight: FontWeight.w700,
                                color: onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              remainingCents > 0
                                  ? '${CurrencyFormatter.formatCents(remainingCents)} remaining to target'
                                  : 'Target completed',
                              style: sheetCtx.ts(
                                12,
                                color: onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpacing16),
                  // ── Live Milestone Progress Simulator Card ──
                  Container(
                    padding: const EdgeInsets.all(kSpacing14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                      border: Border.all(
                        color: isCompleted
                            ? goalColor.withValues(alpha: 0.4)
                            : onSurface.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'MILESTONE PROGRESS',
                              style: sheetCtx.ts(
                                10,
                                fontWeight: FontWeight.w700,
                                color: onSurface.withValues(alpha: 0.5),
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (cents > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: kSpacing8,
                                  vertical: kSpacing2,
                                ),
                                decoration: BoxDecoration(
                                  color: goalColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusPill,
                                  ),
                                ),
                                child: Text(
                                  isCompleted
                                      ? 'TARGET REACHED! 🎯'
                                      : '+${((projectedFraction - currentFraction) * 100).round()}% JUMP',
                                  style: sheetCtx.ts(
                                    10,
                                    fontWeight: FontWeight.w700,
                                    color: goalColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: kSpacing12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
                          child: Container(
                            height: 8,
                            width: double.infinity,
                            color: onSurface.withValues(alpha: 0.08),
                            child: Stack(
                              children: [
                                FractionallySizedBox(
                                  widthFactor: projectedFraction,
                                  child: Container(
                                    color: goalColor.withValues(alpha: 0.4),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: currentFraction,
                                  child: Container(color: goalColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: kSpacing12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current: ${(currentFraction * 100).round()}%',
                                  style: sheetCtx.ts(
                                    11,
                                    color: onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.formatCents(currentAmt),
                                  style: sheetCtx.ts(
                                    13,
                                    fontWeight: FontWeight.w700,
                                    color: goalColor,
                                  ),
                                ),
                              ],
                            ),
                            if (cents > 0) ...[
                              Icon(
                                PesaFlowIcons.chevronRight,
                                size: 16,
                                color: onSurface.withValues(alpha: 0.3),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    isCompleted
                                        ? 'Target Achieved'
                                        : 'Projected: ${(projectedFraction * 100).round()}%',
                                    style: sheetCtx.ts(
                                      11,
                                      color: onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    CurrencyFormatter.formatCents(projectedAmt),
                                    style: sheetCtx.ts(
                                      13,
                                      fontWeight: FontWeight.w700,
                                      color: goalColor,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Target Goal',
                                    style: sheetCtx.ts(
                                      11,
                                      color: onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    CurrencyFormatter.formatCents(targetAmt),
                                    style: sheetCtx.ts(
                                      13,
                                      fontWeight: FontWeight.w700,
                                      color: onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: kSpacing16),
                  Text(
                    'DEPOSIT AMOUNT',
                    style: sheetCtx.ts(
                      10,
                      fontWeight: FontWeight.w700,
                      color: onSurface.withValues(alpha: 0.5),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: kSpacing8),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autofocus: false,
                    style: sheetCtx.ts(
                      24,
                      fontWeight: FontWeight.w800,
                      color: onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(
                          left: kSpacing14,
                          right: kSpacing8,
                          top: 12,
                        ),
                        child: Text(
                          'TSh',
                          style: sheetCtx.ts(
                            16,
                            fontWeight: FontWeight.w700,
                            color: goalColor,
                          ),
                        ),
                      ),
                      suffixIcon: amountController.text.isNotEmpty
                          ? IconButton(
                              tooltip: 'Clear amount',
                              icon: const Icon(PesaFlowIcons.clear, size: 18),
                              onPressed: () {
                                amountController.clear();
                                setSheetState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: kSpacing16,
                        vertical: kSpacing14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusCard,
                        ),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusCard,
                        ),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusCard,
                        ),
                        borderSide: BorderSide(color: goalColor, width: 1.5),
                      ),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: kSpacing12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        QuickDepositChip(
                          label: '+10,000',
                          onTap: () => appendQuickAmount(1000000),
                        ),
                        const SizedBox(width: kSpacing8),
                        QuickDepositChip(
                          label: '+20,000',
                          onTap: () => appendQuickAmount(2000000),
                        ),
                        const SizedBox(width: kSpacing8),
                        QuickDepositChip(
                          label: '+50,000',
                          onTap: () => appendQuickAmount(5000000),
                        ),
                        const SizedBox(width: kSpacing8),
                        QuickDepositChip(
                          label: '+100,000',
                          onTap: () => appendQuickAmount(10000000),
                        ),
                        if (remainingCents > 0) ...[
                          const SizedBox(width: kSpacing8),
                          QuickDepositChip(
                            label: 'Remainder',
                            accent: true,
                            accentColor: goalColor,
                            onTap: fillRemaining,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: kSpacing16),
                  // Note TextField
                  TextField(
                    controller: noteController,
                    textCapitalization: TextCapitalization.sentences,
                    style: sheetCtx.ts(13, color: onSurface),
                    decoration: InputDecoration(
                      hintText: 'Add a note (optional)',
                      prefixIcon: Icon(
                        PesaFlowIcons.edit,
                        size: 18,
                        color: onSurface.withValues(alpha: 0.4),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: kSpacing14,
                        vertical: kSpacing12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusCard,
                        ),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusCard,
                        ),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (accounts.isNotEmpty) ...[
                    const SizedBox(height: kSpacing14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kSpacing12,
                        vertical: kSpacing8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusCard,
                        ),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    PesaFlowIcons.wallet,
                                    size: 16,
                                    color: onSurface.withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: kSpacing8),
                                  Text(
                                    'Deduct from wallet account',
                                    style: sheetCtx.ts(
                                      12,
                                      fontWeight: FontWeight.w600,
                                      color: onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              Switch.adaptive(
                                value: deductFromWallet,
                                activeTrackColor: goalColor,
                                onChanged: (v) {
                                  PesaHaptics.selection();
                                  setSheetState(() => deductFromWallet = v);
                                },
                              ),
                            ],
                          ),
                          if (deductFromWallet) ...[
                            const SizedBox(height: kSpacing8),
                            DropdownButtonFormField<String>(
                              initialValue: selectedAccountId,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: kSpacing12,
                                  vertical: kSpacing8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusCompact,
                                  ),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                              items: accounts.map((acc) {
                                return DropdownMenuItem(
                                  value: acc.id,
                                  child: Text(
                                    '${acc.name} (${CurrencyFormatter.formatCents(acc.balance)})',
                                    style: sheetCtx.ts(12),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setSheetState(() => selectedAccountId = val);
                              },
                            ),
                            if (!hasSufficientFunds && cents > 0) ...[
                              const SizedBox(height: kSpacing6),
                              Row(
                                children: [
                                  Icon(
                                    PesaFlowIcons.warning,
                                    size: 14,
                                    color: context.appColors.expenseColor,
                                  ),
                                  const SizedBox(width: kSpacing4),
                                  Text(
                                    'Selected account has insufficient funds',
                                    style: sheetCtx.ts(
                                      11,
                                      color: context.appColors.expenseColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: kSpacing20),
                  TactileSpringContainer(
                    onTap: isSubmitting || cents <= 0
                        ? null
                        : () async {
                            final cents = CurrencyFormatter.parseToCents(
                              amountController.text,
                            );
                            if (cents <= 0) {
                              CustomToast.show(
                                sheetCtx,
                                message: 'Please enter a valid amount',
                                type: ToastType.error,
                              );
                              return;
                            }
                            setSheetState(() => isSubmitting = true);
                            try {
                              final repo = ref.read(
                                savingsGoalRepositoryProvider,
                              );
                              final trackerId = ref.read(
                                activeTrackerIdProvider,
                              );

                              await repo.addContribution(
                                savingsGoalId: goal.id,
                                amount: cents,
                                notes: noteController.text.trim().isEmpty
                                    ? null
                                    : noteController.text.trim(),
                              );

                              if (deductFromWallet &&
                                  selectedAccountId != null) {
                                final txRepo = ref.read(
                                  transactionRepositoryProvider,
                                );
                                final categories =
                                    ref.watch(categoriesFutureProvider).value ??
                                    [];
                                final savingsCategory = categories.firstWhere(
                                  (c) =>
                                      c.name.toLowerCase() == 'savings' ||
                                      c.icon == 'piggy-bank',
                                  orElse: () => categories.first,
                                );
                                final tx = Transaction(
                                  id: const Uuid().v4(),
                                  accountId: selectedAccountId!,
                                  categoryId: savingsCategory.id,
                                  trackerId: trackerId,
                                  amount: cents,
                                  type: 'expense',
                                  description: 'Saved: ${goal.name}',
                                  source: 'manual',
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                );
                                await txRepo.createTransaction(tx);
                                ref.invalidate(
                                  recentTransactionsStreamProvider,
                                );
                                ref.invalidate(
                                  filteredTransactionsStreamProvider,
                                );
                                ref.invalidate(accountsStreamProvider);
                                ref.invalidate(netWorthProvider);
                              }

                              ref.invalidate(savingsGoalsStreamProvider);
                              ref.invalidate(savingsGoalsTotalSavedProvider);

                              PesaHaptics.success();
                              if (sheetCtx.mounted) {
                                Navigator.of(sheetCtx).pop();
                              }
                              if (context.mounted) {
                                CustomToast.show(
                                  context,
                                  message:
                                      'Deposited ${CurrencyFormatter.formatCents(cents)} into ${goal.name}!',
                                  type: ToastType.success,
                                );
                              }
                            } catch (e) {
                              setSheetState(() => isSubmitting = false);
                              if (sheetCtx.mounted) {
                                CustomToast.show(
                                  sheetCtx,
                                  message: 'Error depositing: $e',
                                  type: ToastType.error,
                                );
                              }
                            }
                          },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: kSpacing14),
                      decoration: BoxDecoration(
                        color: cents > 0
                            ? goalColor
                            : onSurface.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusPill,
                        ),
                        boxShadow: cents > 0
                            ? [
                                BoxShadow(
                                  color: goalColor.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              cents > 0
                                  ? 'Confirm Deposit (${CurrencyFormatter.formatCents(cents)})'
                                  : 'Confirm Deposit',
                              style: sheetCtx.ts(
                                14,
                                fontWeight: FontWeight.w700,
                                color: cents > 0
                                    ? Colors.white
                                    : onSurface.withValues(alpha: 0.35),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class QuickDepositChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool accent;
  final Color? accentColor;

  const QuickDepositChip({
    super.key,
    required this.label,
    required this.onTap,
    this.accent = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final col = accentColor ?? theme.colorScheme.primary;

    return TactileSpringContainer(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: kSpacing12,
          vertical: kSpacing6,
        ),
        decoration: BoxDecoration(
          color: accent
              ? col.withValues(alpha: 0.14)
              : theme.colorScheme.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(
            color: accent
                ? col.withValues(alpha: 0.3)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: context.ts(
            11,
            fontWeight: FontWeight.w700,
            color: accent
                ? col
                : theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}
