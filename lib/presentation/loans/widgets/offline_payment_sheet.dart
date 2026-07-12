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
import 'package:pesaflow/presentation/common/widgets/spring_sheet_route.dart';
import 'payment_sheet.dart';

import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

void showOfflinePaymentSheet(BuildContext context, WidgetRef ref, Loan loan) {
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();
  final theme = Theme.of(context);
  final onSurface = theme.colorScheme.onSurface;
  final remainingCents = loan.remaining;

  showSpringSheet(
    context,
    isScrollControlled: true,
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
                                      const SizedBox(width: kSpacing14),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Record Offline Payment',
                                            style: theme.textTheme.titleLarge!
                                                .copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: kSpacing2),
                                          Text(
                                            'No wallet account will be affected',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium!
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
                                            color: onSurface.withValues(
                                              alpha: 0.55,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: kSpacing12),
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
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineMedium!
                                                .copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: onSurface,
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
                                                  alpha: 0.55,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
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
                                  const SizedBox(height: kSpacing20),
                                  Container(
                                    padding: const EdgeInsets.all(kSpacing12),
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
                                        const SizedBox(width: kSpacing8),
                                        Expanded(
                                          child: Text(
                                            'This records the payment without deducting from any wallet account. Use this for cash or external payments.',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall!
                                                .copyWith(
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
                                  const SizedBox(height: kSpacing24),
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
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              paymentAmount() <= 0
                                                  ? 'Enter an amount'
                                                  : 'Record ${CurrencyFormatter.formatCents(paymentAmount())}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium!
                                                  .copyWith(
                                                    fontWeight: FontWeight.bold,
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
