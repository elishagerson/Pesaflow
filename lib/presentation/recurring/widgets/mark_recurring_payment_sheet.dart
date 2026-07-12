import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/recurring_transaction_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/spring_sheet_route.dart';

Future<void> showMarkRecurringPaymentSheet({
  required BuildContext context,
  required WidgetRef ref,
  required RecurringTransaction recurring,
  required String accountName,
}) async {
  final theme = Theme.of(context);
  final repo = ref.read(recurringTransactionRepositoryProvider);
  final txRepo = ref.read(transactionRepositoryProvider);

  bool deductBalance = true;
  bool isProcessing = false;

  await showSpringSheet(
    context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.58,
            maxChildSize: 0.7,
            minChildSize: 0.5,
            expand: false,
            builder: (ctx, scrollController) => ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Padding(
                      padding: const EdgeInsets.only(top: kSpacing8),
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Title
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        kSpacing20,
                        kSpacing16,
                        kSpacing20,
                        kSpacing16,
                      ),
                      child: Text(
                        'Mark Payment',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Divider(
                      height: 0.5,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.08,
                      ),
                    ),
                    // Scrollable content
                    Flexible(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(kSpacing20),
                        children: [
                          // Amount
                          _buildSummaryRow(
                            theme: theme,
                            label: 'Amount',
                            value: CurrencyFormatter.formatCents(
                              recurring.amount,
                            ),
                            valueStyle: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: kSpacing14),
                          _buildSummaryRow(
                            theme: theme,
                            label: 'Description',
                            value:
                                recurring.description ??
                                'Recurring ${recurring.type}',
                          ),
                          const SizedBox(height: kSpacing14),
                          _buildSummaryRow(
                            theme: theme,
                            label: 'Account',
                            value: accountName,
                          ),
                          const SizedBox(height: kSpacing14),
                          _buildSummaryRow(
                            theme: theme,
                            label: 'Category',
                            value: recurring.categoryId != null
                                ? 'Category set'
                                : 'Not set',
                          ),
                          const SizedBox(height: kSpacing14),
                          _buildSummaryRow(
                            theme: theme,
                            label: 'Next occurrence',
                            value:
                                '${recurring.nextDate.day}/'
                                '${recurring.nextDate.month}/'
                                '${recurring.nextDate.year}',
                          ),
                          const SizedBox(height: kSpacing24),
                          // Deduct toggle
                          GlassCard(
                            borderRadius: 12,
                            elevation: CardElevation.none,
                            hasBorder: true,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: kSpacing14,
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
                                          'Deduct from balance',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: kSpacing2),
                                        Text(
                                          'Record as a regular transaction'
                                          ' and adjust account balance',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.5),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: deductBalance,
                                    onChanged: isProcessing
                                        ? null
                                        : (v) {
                                            HapticFeedback.lightImpact();
                                            setSheetState(
                                              () => deductBalance = v,
                                            );
                                          },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Bottom actions
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        kSpacing20,
                        0,
                        kSpacing20,
                        kSpacing24,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              onPressed: isProcessing
                                  ? null
                                  : () async {
                                      setSheetState(() => isProcessing = true);
                                      try {
                                        await _confirmMarkPaid(
                                          context: context,
                                          ref: ref,
                                          repo: repo,
                                          txRepo: txRepo,
                                          recurring: recurring,
                                          deductBalance: deductBalance,
                                        );
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                        }
                                      } catch (e) {
                                        setSheetState(
                                          () => isProcessing = false,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Failed to mark payment: $e',
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              child: Text(
                                isProcessing
                                    ? 'Processing…'
                                    : 'Confirm Payment',
                              ),
                            ),
                          ),
                          const SizedBox(height: kSpacing10),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed: isProcessing
                                  ? null
                                  : () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildSummaryRow({
  required ThemeData theme,
  required String label,
  required String value,
  TextStyle? valueStyle,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 120,
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
      Expanded(
        child: Text(value, style: valueStyle ?? theme.textTheme.bodyMedium),
      ),
    ],
  );
}

Future<void> _confirmMarkPaid({
  required BuildContext context,
  required WidgetRef ref,
  required RecurringTransactionRepository repo,
  required TransactionRepository txRepo,
  required RecurringTransaction recurring,
  required bool deductBalance,
}) async {
  final now = DateTime.now();
  final transaction = Transaction(
    id: const Uuid().v4(),
    accountId: recurring.accountId,
    categoryId: recurring.categoryId ?? '',
    amount: recurring.amount,
    type: recurring.type,
    description: recurring.description ?? 'Recurring ${recurring.type}',
    source: 'manual',
    trackerId: recurring.id,
    createdAt: now,
    updatedAt: now,
  );

  await repo.recordMarkedPayment(
    transaction: transaction,
    recurringId: recurring.id,
    amount: recurring.amount,
    paidAt: now,
    deductBalance: deductBalance,
  );

  if (context.mounted) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Payment recorded'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
