import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/account_repository.dart';
import 'package:pesaflow/data/repositories/category_repository.dart';
import 'package:pesaflow/data/repositories/loan_repository.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/widgets/liquid_glass.dart';
import 'package:pesaflow/presentation/common/widgets/spring_sheet_route.dart';

import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

class LoanProgressRing extends StatelessWidget {
  final Loan loan;
  final int remainingCents;

  const LoanProgressRing({
    super.key,
    required this.loan,
    required this.remainingCents,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final totalInstallments = loan.totalInstallments ?? 0;
    final paidInstallments = loan.paidInstallments ?? 0;
    final totalAmount = loan.amount;
    final paidAmount = totalAmount - remainingCents;
    final paidFraction = totalAmount > 0
        ? (paidAmount / totalAmount).clamp(0.0, 1.0)
        : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  value: paidFraction,
                  strokeWidth: 5,
                  backgroundColor: onSurface.withValues(alpha: 0.07),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    context.appColors.incomeColor,
                  ),
                ),
              ),
              Text(
                '${(paidFraction * 100).round()}%',
                style: context.ts(13, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        const SizedBox(width: kSpacing16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Paid',
                    style: context.ts(12, color: onSurface.withValues(alpha: 0.6)),
                  ),
                  Text(
                    CurrencyFormatter.formatCents(paidAmount),
                    style: context.ts(12, fontWeight: FontWeight.bold, color: context.appColors.incomeColor),
                  ),
                ],
              ),
              const SizedBox(height: kSpacing4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Remaining',
                    style: context.ts(12, color: onSurface.withValues(alpha: 0.6)),
                  ),
                  Text(
                    CurrencyFormatter.formatCents(remainingCents),
                    style: context.ts(12, fontWeight: FontWeight.bold, color: context.appColors.expenseColor),
                  ),
                ],
              ),
              if (totalInstallments > 0) ...[
                const SizedBox(height: kSpacing4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Installments',
                      style: context.ts(12, color: onSurface.withValues(alpha: 0.6)),
                    ),
                    Text(
                      '$paidInstallments/$totalInstallments',
                      style: context.ts(12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class QuickAmountChip extends StatelessWidget {
  final String label;
  final int amount;
  final bool isActive;
  final VoidCallback onTap;

  const QuickAmountChip({
    super.key,
    required this.label,
    required this.amount,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: kSpacing10),
          decoration: BoxDecoration(
            color: isActive
                ? context.appColors.incomeColor.withValues(alpha: 0.15)
                : onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? context.appColors.incomeColor.withValues(alpha: 0.5)
                  : onSurface.withValues(alpha: 0.07),
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: context.ts(13, fontWeight: FontWeight.w700, color: isActive ? context.appColors.incomeColor : onSurface.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: kSpacing2),
              Text(
                CurrencyFormatter.formatCents(amount),
                style: context.ts(10, fontWeight: FontWeight.w500, color: onSurface.withValues(alpha: 0.38)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showPaymentSheet(BuildContext context, WidgetRef ref, Loan loan) {
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();
  final theme = Theme.of(context);
  final onSurface = theme.colorScheme.onSurface;
  final remainingCents = loan.remaining;

  showSpringSheet(
    context,
    isScrollControlled: true,
    builder: (sheetContext) {
      String? selectedAccountId;
      bool sheetIsProcessing = false;

      int paymentAmount() =>
          CurrencyFormatter.parseToCents(amountController.text);

      return StatefulBuilder(
        builder: (context, setSheetState) {
          final canSubmit = paymentAmount() > 0 && selectedAccountId != null;

          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            expand: false,
            builder: (ctx, scrollController) => ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
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
                    child: Column(
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
                                          color: context.appColors.incomeColor.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                         child: Icon(
                                           PesaFlowIcons.cash,
                                           color: context.appColors.incomeColor,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: kSpacing14),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Make a Payment',
                                            style: theme.textTheme.titleLarge!
                                                .copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: kSpacing2),
                                          Text(
                                            'Remaining: ${CurrencyFormatter.formatCents(remainingCents)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall!
                                                .copyWith(
                                                  color: onSurface.withValues(
                                                    alpha: 0.6,
                                                  ),
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: kSpacing24),
                                  LoanProgressRing(
                                    loan: loan,
                                    remainingCents: remainingCents,
                                  ),
                                  const SizedBox(height: kSpacing24),
                                  Text(
                                    'PAYMENT AMOUNT',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall!
                                        .copyWith(letterSpacing: 0.5),
                                  ),
                                  const SizedBox(height: kSpacing8),
                                  _buildAmountField(
                                    theme: theme,
                                    amountController: amountController,
                                    paymentAmount: paymentAmount,
                                    setSheetState: setSheetState,
                                  ),
                                  const SizedBox(height: kSpacing16),
                                  Row(
                                    children: [
                                      QuickAmountChip(
                                        label: '25%',
                                        amount: (remainingCents * 0.25).round(),
                                        isActive:
                                            paymentAmount() ==
                                            (remainingCents * 0.25).round(),
                                        onTap: () {
                                          amountController.text =
                                              ((remainingCents * 0.25).round() /
                                                      100)
                                                  .toStringAsFixed(0);
                                          amountController.selection =
                                              TextSelection.fromPosition(
                                                TextPosition(
                                                  offset: amountController
                                                      .text
                                                      .length,
                                                ),
                                              );
                                          setSheetState(() {});
                                        },
                                      ),
                                      const SizedBox(width: kSpacing8),
                                      QuickAmountChip(
                                        label: '50%',
                                        amount: (remainingCents * 0.5).round(),
                                        isActive:
                                            paymentAmount() ==
                                            (remainingCents * 0.5).round(),
                                        onTap: () {
                                          amountController.text =
                                              ((remainingCents * 0.5).round() /
                                                      100)
                                                  .toStringAsFixed(0);
                                          amountController.selection =
                                              TextSelection.fromPosition(
                                                TextPosition(
                                                  offset: amountController
                                                      .text
                                                      .length,
                                                ),
                                              );
                                          setSheetState(() {});
                                        },
                                      ),
                                      const SizedBox(width: kSpacing8),
                                      QuickAmountChip(
                                        label: '75%',
                                        amount: (remainingCents * 0.75).round(),
                                        isActive:
                                            paymentAmount() ==
                                            (remainingCents * 0.75).round(),
                                        onTap: () {
                                          amountController.text =
                                              ((remainingCents * 0.75).round() /
                                                      100)
                                                  .toStringAsFixed(0);
                                          amountController.selection =
                                              TextSelection.fromPosition(
                                                TextPosition(
                                                  offset: amountController
                                                      .text
                                                      .length,
                                                ),
                                              );
                                          setSheetState(() {});
                                        },
                                      ),
                                      const SizedBox(width: kSpacing8),
                                      QuickAmountChip(
                                        label: '100%',
                                        amount: remainingCents,
                                        isActive:
                                            paymentAmount() == remainingCents,
                                        onTap: () {
                                          amountController.text =
                                              (remainingCents / 100)
                                                  .toStringAsFixed(0);
                                          amountController.selection =
                                              TextSelection.fromPosition(
                                                TextPosition(
                                                  offset: amountController
                                                      .text
                                                      .length,
                                                ),
                                              );
                                          setSheetState(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: kSpacing24),
                                  Text(
                                    'MEMO',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall!
                                        .copyWith(letterSpacing: 0.5),
                                  ),
                                  const SizedBox(height: kSpacing8),
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
                                    child: TextField(
                                      controller: descriptionController,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium!
                                          .copyWith(color: onSurface),
                                      decoration: InputDecoration(
                                        hintText: 'Add a note (optional)',
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
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: kSpacing24),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'FROM ACCOUNT',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall!
                                            .copyWith(letterSpacing: 0.5),
                                      ),
                                      if (selectedAccountId != null)
                                        GestureDetector(
                                          onTap: () => setSheetState(
                                            () => selectedAccountId = null,
                                          ),
                                          child: Text(
                                            'Clear',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium!
                                                .copyWith(
                                                  color: context.appColors.expenseColor.withValues(alpha: 0.8),
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: kSpacing8),
                                  FutureBuilder<List<Account>>(
                                    future: ref
                                        .read(accountRepositoryProvider)
                                        .getAllAccounts(),
                                    builder: (context, snapshot) {
                                      final accounts = snapshot.data ?? [];
                                      if (accounts.isEmpty) {
                                        return Container(
                                          padding: const EdgeInsets.all(
                                            kSpacing16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: context.appColors.expenseColor.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: context.appColors.expenseColor.withValues(alpha: 0.2),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                               Icon(
                                                 PesaFlowIcons.warning,
                                                 size: 18,
                                                 color: context.appColors.expenseColor,
                                              ),
                                              const SizedBox(width: kSpacing10),
                                              Text(
                                                'No accounts available. Create one first.',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall!
                                                    .copyWith(
                                                      color: context.appColors.expenseColor.withValues(alpha: 0.9),
                                                    ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                      return Column(
                                        children: accounts.map((account) {
                                          final isSelected =
                                              account.id == selectedAccountId;
                                          final balanceCents = account.balance;
                                          final hasFunds =
                                              balanceCents >= paymentAmount();
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: kSpacing8,
                                            ),
                                            child: GestureDetector(
                                              onTap: () => setSheetState(
                                                () => selectedAccountId =
                                                    account.id,
                                              ),
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 200,
                                                ),
                                                curve: Curves.easeOutCubic,
                                                padding: const EdgeInsets.all(
                                                  14,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? context.appColors.incomeColor.withValues(
                                                          alpha: 0.12,
                                                        )
                                                      : theme
                                                            .colorScheme
                                                            .surface,
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? context.appColors.incomeColor.withValues(
                                                            alpha: 0.5,
                                                          )
                                                        : onSurface.withValues(
                                                            alpha: 0.07,
                                                          ),
                                                    width: isSelected ? 1.5 : 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: isSelected
                                                            ? context.appColors.incomeColor.withValues(
                                                                alpha: 0.2,
                                                              )
                                                            : onSurface
                                                                  .withValues(
                                                                    alpha: 0.05,
                                                                  ),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        isSelected
                                                            ? PesaFlowIcons
                                                                  .success
                                                            : PesaFlowIcons
                                                                  .wallet,
                                                        size: 20,
                                                        color: isSelected
                                                            ? context.appColors.incomeColor
                                                            : onSurface
                                                                  .withValues(
                                                                    alpha: 0.55,
                                                                  ),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      width: kSpacing12,
                                                    ),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            account.name,
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .bodyMedium!
                                                                .copyWith(
                                                                  color:
                                                                      isSelected
                                                                      ? context.appColors.incomeColor
                                                                      : onSurface,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          Row(
                                                            children: [
                                                              Text(
                                                                'Balance: ${CurrencyFormatter.formatCents(balanceCents)}',
                                                                style: Theme.of(context)
                                                                    .textTheme
                                                                    .labelMedium!
                                                                    .copyWith(
                                                                      color: onSurface.withValues(
                                                                        alpha:
                                                                            0.38,
                                                                      ),
                                                                    ),
                                                              ),
                                                              if (selectedAccountId !=
                                                                      null &&
                                                                  !hasFunds &&
                                                                  paymentAmount() >
                                                                      0) ...[
                                                                const SizedBox(
                                                                  width: 8,
                                                                ),
                                                                Container(
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            6,
                                                                        vertical:
                                                                            2,
                                                                      ),
                                                                  decoration: BoxDecoration(
                                                                    color:
                                                                        context.appColors.expenseColor.withValues(
                                                                          alpha:
                                                                              0.12,
                                                                        ),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          4,
                                                                        ),
                                                                  ),
                                                                  child: Text(
                                                                    'Insufficient',
                                                                    style: theme
                                                                        .extension<
                                                                          AppTypographyTheme
                                                                        >()!
                                                                        .labelMicro
                                                                        .copyWith(
                                                                          color: Color(
                                                                            0xFFE53935,
                                                                          ),
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (isSelected)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              4,
                                                            ),
                                                        decoration:
                                                            BoxDecoration(
                                                              color:
                                                                  context.appColors.incomeColor.withValues(
                                                                    alpha: 0.15,
                                                                  ),
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                        child: const Icon(
                                                          Icons.check_rounded,
                                                          size: 16,
                                                          color: Color(
                                                            0xFF609F8A,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: kSpacing24),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 54,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: canSubmit
                                            ? [
                                                BoxShadow(
                                                  color: context.appColors.incomeColor.withValues(alpha: 0.3),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: ElevatedButton(
                                        onPressed:
                                            canSubmit && !sheetIsProcessing
                                            ? () async {
                                                final desc =
                                                    descriptionController.text
                                                        .trim();
                                                setSheetState(() {
                                                  sheetIsProcessing = true;
                                                });
                                                final success =
                                                    await processPayment(
                                                      context: context,
                                                      ref: ref,
                                                      loan: loan,
                                                      amount: paymentAmount(),
                                                      description:
                                                          desc.isNotEmpty
                                                          ? desc
                                                          : 'Manual loan payment',
                                                      accountId:
                                                          selectedAccountId!,
                                                    );
                                                if (success) {
                                                  if (sheetContext.mounted) {
                                                    Navigator.of(
                                                      sheetContext,
                                                    ).pop();
                                                  }
                                                } else {
                                                  setSheetState(() {
                                                    sheetIsProcessing = false;
                                                  });
                                                }
                                              }
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: context.appColors.incomeColor,
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: onSurface
                                              .withValues(alpha: 0.05),
                                          disabledForegroundColor: onSurface
                                              .withValues(alpha: 0.25),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                        ),
                                        child: sheetIsProcessing
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  if (paymentAmount() > 0 &&
                                                      selectedAccountId != null)
                                                    Icon(
                                                      PesaFlowIcons.lock,
                                                      size: 16,
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.8,
                                                          ),
                                                    ),
                                                  if (paymentAmount() > 0 &&
                                                      selectedAccountId != null)
                                                    const SizedBox(
                                                      width: kSpacing8,
                                                    ),
                                                  Text(
                                                    paymentAmount() <= 0
                                                        ? 'Enter an amount'
                                                        : selectedAccountId ==
                                                              null
                                                        ? 'Select an account'
                                                        : 'Pay ${CurrencyFormatter.formatCents(paymentAmount())}',
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
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildAmountField({
  required ThemeData theme,
  required TextEditingController amountController,
  required int Function() paymentAmount,
  required StateSetter setSheetState,
}) {
  final onSurface = theme.colorScheme.onSurface;
  return Container(
    decoration: BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: onSurface.withValues(alpha: 0.07)),
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: kSpacing16,
      vertical: kSpacing4,
    ),
    child: Row(
      children: [
        Text(
          'TSh',
          style: theme.textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.w900,
            color: onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(width: kSpacing12),
        Expanded(
          child: TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
            ],
            style: theme.textTheme.headlineMedium!.copyWith(
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
            decoration: const InputDecoration(
              hintText: 'Enter amount',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: kSpacing12),
            ),
            onChanged: (val) {
              setSheetState(() {});
            },
          ),
        ),
        if (paymentAmount() > 0)
          GestureDetector(
            onTap: () {
              amountController.clear();
              setSheetState(() {});
            },
            child: Container(
              padding: const EdgeInsets.all(kSpacing4),
              decoration: BoxDecoration(
                color: onSurface.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(
                PesaFlowIcons.close,
                size: 18,
                color: onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
      ],
    ),
  );
}

Future<bool> processPayment({
  required BuildContext context,
  required WidgetRef ref,
  required Loan loan,
  required int amount,
  required String description,
  required String accountId,
}) async {
  try {
    final activeTrackerId =
        await ref
            .read(settingsRepositoryProvider)
            .getSetting('active_tracker_id') ??
        'default_personal';
    final categories = await ref
        .read(categoryRepositoryProvider)
        .getAllCategories();
    final expenseCat = categories.firstWhere(
      (c) => c.type == 'expense',
      orElse: () => categories.first,
    );

    final txn = Transaction(
      id: const Uuid().v4(),
      accountId: accountId,
      categoryId: expenseCat.id,
      trackerId: activeTrackerId,
      loanId: loan.id,
      amount: amount,
      type: 'expense',
      description: description,
      source: 'manual',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await ref
        .read(transactionRepositoryNoAlertsProvider)
        .createTransaction(txn);
    await ref.read(loanRepositoryProvider).applyPayment(loan.id, amount);

    HapticFeedback.mediumImpact();
    return true;
  } catch (e) {
    HapticFeedback.heavyImpact();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: context.appColors.expenseColor,
        ),
      );
    }
    return false;
  }
}
