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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF10B981),
                  ),
                ),
              ),
              Text(
                '${(paidFraction * 100).round()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Paid',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatCents(paidAmount),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Remaining',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatCents(remainingCents),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE53935),
                    ),
                  ),
                ],
              ),
              if (totalInstallments > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Installments',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    Text(
                      '$paidInstallments/$totalInstallments',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                : isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF10B981).withValues(alpha: 0.5)
                  : isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? const Color(0xFF10B981)
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                CurrencyFormatter.formatCents(amount),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
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
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final remainingCents = loan.remaining;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      String? selectedAccountId;
      bool sheetIsProcessing = false;

      int paymentAmount() =>
          CurrencyFormatter.parseToCents(amountController.text);

      return StatefulBuilder(
        builder: (context, setSheetState) {
          final canSubmit =
              paymentAmount() > 0 &&
              selectedAccountId != null;

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
                      color: isDark
                          ? const Color(0xF01C1C1E)
                          : const Color(0xF0F2F2F7),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        const SizedBox(height: 10),
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
                        const SizedBox(height: 16),
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
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF609F8A,
                                          ).withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          PesaFlowIcons.cash,
                                          color: Color(0xFF10B981),
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Make a Payment',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Remaining: ${CurrencyFormatter.formatCents(remainingCents)}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  LoanProgressRing(
                                    loan: loan,
                                    remainingCents: remainingCents,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'PAYMENT AMOUNT',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildAmountField(
                                    isDark: isDark,
                                    amountController: amountController,
                                    paymentAmount: paymentAmount,
                                    setSheetState: setSheetState,
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      QuickAmountChip(
                                        label: '25%',
                                        amount: (remainingCents * 0.25)
                                            .round(),
                                        isActive:
                                            paymentAmount() ==
                                            (remainingCents * 0.25).round(),
                                        onTap: () {
                                          amountController.text =
                                              ((remainingCents * 0.25)
                                                          .round() /
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
                                        isDark: isDark,
                                      ),
                                      const SizedBox(width: 8),
                                      QuickAmountChip(
                                        label: '50%',
                                        amount: (remainingCents * 0.5)
                                            .round(),
                                        isActive:
                                            paymentAmount() ==
                                            (remainingCents * 0.5).round(),
                                        onTap: () {
                                          amountController.text =
                                              ((remainingCents * 0.5)
                                                          .round() /
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
                                        isDark: isDark,
                                      ),
                                      const SizedBox(width: 8),
                                      QuickAmountChip(
                                        label: '75%',
                                        amount: (remainingCents * 0.75)
                                            .round(),
                                        isActive:
                                            paymentAmount() ==
                                            (remainingCents * 0.75).round(),
                                        onTap: () {
                                          amountController.text =
                                              ((remainingCents * 0.75)
                                                          .round() /
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
                                        isDark: isDark,
                                      ),
                                      const SizedBox(width: 8),
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
                                        isDark: isDark,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'MEMO',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1C1C1E)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.08,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.06,
                                              ),
                                      ),
                                    ),
                                    child: TextField(
                                      controller: descriptionController,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Add a note (optional)',
                                        hintStyle: TextStyle(
                                          color: isDark
                                              ? Colors.white30
                                              : Colors.black26,
                                        ),
                                        prefixIcon: Icon(
                                          PesaFlowIcons.edit,
                                          size: 20,
                                          color: isDark
                                              ? Colors.white38
                                              : Colors.black26,
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
                                  const SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'FROM ACCOUNT',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      if (selectedAccountId != null)
                                        GestureDetector(
                                          onTap: () => setSheetState(
                                            () => selectedAccountId = null,
                                          ),
                                          child: Text(
                                            'Clear',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: const Color(
                                                0xFFE53935,
                                              ).withValues(alpha: 0.8),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  FutureBuilder<List<Account>>(
                                    future: ref
                                        .read(accountRepositoryProvider)
                                        .getAllAccounts(),
                                    builder: (context, snapshot) {
                                      final accounts = snapshot.data ?? [];
                                      if (accounts.isEmpty) {
                                        return Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFFE53935,
                                            ).withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                              color: const Color(
                                                0xFFE53935,
                                              ).withValues(alpha: 0.2),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                PesaFlowIcons.warning,
                                                size: 18,
                                                color: Color(0xFFE53935),
                                              ),
                                              const SizedBox(
                                                width: 10,
                                              ),
                                              Text(
                                                'No accounts available. Create one first.',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: const Color(
                                                    0xFFE53935,
                                                  ).withValues(alpha: 0.9),
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
                                          final balanceCents =
                                              account.balance;
                                          final hasFunds =
                                              balanceCents >= paymentAmount();
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
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
                                                      ? const Color(
                                                          0xFF609F8A,
                                                        ).withValues(
                                                          alpha: isDark
                                                              ? 0.15
                                                              : 0.08,
                                                        )
                                                      : isDark
                                                      ? const Color(
                                                          0xFF1C1C1E,
                                                        )
                                                      : Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        14,
                                                      ),
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? const Color(
                                                            0xFF609F8A,
                                                          ).withValues(
                                                            alpha: 0.5,
                                                          )
                                                        : isDark
                                                        ? Colors.white
                                                              .withValues(
                                                                alpha: 0.08,
                                                              )
                                                        : Colors.black
                                                              .withValues(
                                                                alpha: 0.06,
                                                              ),
                                                    width: isSelected
                                                        ? 1.5
                                                        : 1,
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
                                                            ? const Color(
                                                                0xFF609F8A,
                                                              ).withValues(
                                                                alpha: 0.2,
                                                              )
                                                            : (isDark
                                                                  ? Colors
                                                                      .white
                                                                      .withValues(
                                                                        alpha:
                                                                            0.06,
                                                                      )
                                                                  : Colors
                                                                      .black
                                                                      .withValues(
                                                                        alpha:
                                                                            0.04,
                                                                      )),
                                                        shape:
                                                            BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        isSelected
                                                            ? PesaFlowIcons
                                                                  .success
                                                            : PesaFlowIcons
                                                                  .wallet,
                                                        size: 20,
                                                        color: isSelected
                                                            ? const Color(
                                                                0xFF609F8A,
                                                              )
                                                            : (isDark
                                                                  ? Colors
                                                                      .white54
                                                                  : Colors
                                                                      .black45),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      width: 12,
                                                    ),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            account.name,
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  isSelected
                                                                  ? FontWeight
                                                                      .w700
                                                                  : FontWeight
                                                                      .w500,
                                                              fontSize: 15,
                                                              color:
                                                                  isSelected
                                                                  ? (isDark
                                                                        ? Colors.white
                                                                        : const Color(
                                                                            0xFF609F8A,
                                                                          ))
                                                                  : (isDark
                                                                        ? Colors.white
                                                                        : Colors.black87),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          Row(
                                                            children: [
                                                              Text(
                                                                'Balance: ${CurrencyFormatter.formatCents(balanceCents)}',
                                                                style: TextStyle(
                                                                  fontSize:
                                                                      12,
                                                                  color:
                                                                      isDark
                                                                      ? Colors
                                                                          .white38
                                                                      : Colors
                                                                          .black38,
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
                                                                  padding: const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical:
                                                                        2,
                                                                  ),
                                                                  decoration: BoxDecoration(
                                                                    color:
                                                                        const Color(
                                                                          0xFFE53935,
                                                                        ).withValues(
                                                                          alpha:
                                                                              0.12,
                                                                        ),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          4,
                                                                        ),
                                                                  ),
                                                                  child: const Text(
                                                                    'Insufficient',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          10,
                                                                      color: Color(
                                                                        0xFFE53935,
                                                                      ),
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
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
                                                                  const Color(
                                                                    0xFF609F8A,
                                                                  ).withValues(
                                                                    alpha:
                                                                        0.15,
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
                                  const SizedBox(height: 24),
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
                                        boxShadow: canSubmit
                                            ? [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFF609F8A,
                                                  ).withValues(alpha: 0.3),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: canSubmit && !sheetIsProcessing
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
                                                  description: desc.isNotEmpty
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
                                          backgroundColor: const Color(
                                            0xFF609F8A,
                                          ),
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.05,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.05,
                                                ),
                                          disabledForegroundColor: isDark
                                              ? Colors.white24
                                              : Colors.black26,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
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
                                                      selectedAccountId !=
                                                          null)
                                                    Icon(
                                                      PesaFlowIcons.lock,
                                                      size: 16,
                                                      color: Colors.white
                                                          .withValues(
                                                        alpha: 0.8,
                                                      ),
                                                    ),
                                                  if (paymentAmount() > 0 &&
                                                      selectedAccountId !=
                                                          null)
                                                    const SizedBox(
                                                      width: 8,
                                                    ),
                                                  Text(
                                                    paymentAmount() <= 0
                                                        ? 'Enter an amount'
                                                        : selectedAccountId ==
                                                              null
                                                        ? 'Select an account'
                                                        : 'Pay ${CurrencyFormatter.formatCents(paymentAmount())}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
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
  required bool isDark,
  required TextEditingController amountController,
  required int Function() paymentAmount,
  required StateSetter setSheetState,
}) {
  return Container(
    decoration: BoxDecoration(
      color: isDark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
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
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isDark
                ? Colors.white60
                : Colors.black45,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: amountController,
            keyboardType:
                const TextInputType.numberWithOptions(
                  decimal: true,
                ),
            autofocus: true,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'[\d.,]'),
              ),
            ],
            style: TextStyle(
              fontSize: 28,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: isDark
                  ? Colors.white
                  : Colors.black,
            ),
            decoration: const InputDecoration(
              hintText: 'Enter amount',
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(
                    vertical: 12,
                  ),
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
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(
                        alpha: 0.1,
                      )
                    : Colors.black.withValues(
                        alpha: 0.05,
                      ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                PesaFlowIcons.close,
                size: 18,
                color: isDark
                    ? Colors.white54
                    : Colors.black45,
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
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
    return false;
  }
}
