import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/category_repository.dart';
import 'package:pesaflow/data/repositories/loan_repository.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/widgets/liquid_glass.dart';
import 'payment_sheet.dart';

void showOfflinePaymentSheet(BuildContext context, WidgetRef ref, Loan loan) {
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final remainingCents = loan.remaining;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      bool sheetIsProcessing = false;

      int paymentAmount() =>
          CurrencyFormatter.parseToCents(amountController.text);

      return StatefulBuilder(
        builder: (context, setSheetState) {
          final canSubmit = paymentAmount() > 0;

          return DraggableScrollableSheet(
            initialChildSize: 0.5,
            maxChildSize: 0.7,
            minChildSize: 0.4,
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
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
                                          PesaFlowIcons.transactions,
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
                                            'Record Offline Payment',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'No wallet account will be affected',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? Colors.grey[500]
                                                  : Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'AMOUNT',
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
                                      borderRadius: BorderRadius.circular(16),
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
                                  ),
                                  const SizedBox(height: 16),
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
                                      const SizedBox(width: 8),
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
                                      const SizedBox(width: 8),
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
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF609F8A,
                                      ).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF609F8A,
                                        ).withValues(alpha: 0.15),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          PesaFlowIcons.info,
                                          size: 16,
                                          color: const Color(
                                            0xFF609F8A,
                                          ).withValues(alpha: 0.8),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'This records the payment without deducting from any wallet account. Use this for cash or external payments.',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: const Color(
                                                0xFF609F8A,
                                              ).withValues(alpha: 0.8),
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 54,
                                    child: ElevatedButton(
                                      onPressed: canSubmit && !sheetIsProcessing
                                          ? () async {
                                              final desc = descriptionController
                                                  .text
                                                  .trim();
                                              setSheetState(() {
                                                sheetIsProcessing = true;
                                              });
                                              final success =
                                                  await processOfflinePayment(
                                                    context: context,
                                                    ref: ref,
                                                    loan: loan,
                                                    amount: paymentAmount(),
                                                    description: desc.isNotEmpty
                                                        ? desc
                                                        : 'Offline loan payment',
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
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              paymentAmount() <= 0
                                                  ? 'Enter an amount'
                                                  : 'Record ${CurrencyFormatter.formatCents(paymentAmount())}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
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

Future<bool> processOfflinePayment({
  required BuildContext context,
  required WidgetRef ref,
  required Loan loan,
  required int amount,
  required String description,
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
      accountId: null,
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
        .createTransactionNoBalanceAdjustment(txn);
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
