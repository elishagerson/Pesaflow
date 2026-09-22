import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/database_providers.dart';
import 'package:pesaflow/data/repositories/recurring_transaction_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/widgets/spring_sheet_route.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:go_router/go_router.dart';

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
  int amountCents = recurring.amount;
  final amountController = TextEditingController(
    text: CurrencyFormatter.formatCents(recurring.amount),
  );
  final categoryDao = ref.read(categoryDaoProvider);

  String categoryName = 'Not set';
  if (recurring.categoryId != null && recurring.categoryId!.isNotEmpty) {
    final cat = await categoryDao.getCategoryById(recurring.categoryId!);
    if (cat != null) categoryName = cat.name;
  }

  if (!context.mounted) return;

  await showSpringSheet(
    context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final projectedNextDate = () {
        final d = recurring.nextDate;
        final interval = recurring.intervalValue > 0 ? recurring.intervalValue : 1;
        switch (recurring.frequency.toLowerCase()) {
          case 'daily':
            return d.add(Duration(days: interval));
          case 'weekly':
            return d.add(Duration(days: 7 * interval));
          case 'monthly':
            return DateTime(d.year, d.month + interval, d.day);
          case 'yearly':
            return DateTime(d.year + interval, d.month, d.day);
          default:
            return DateTime(d.year, d.month + 1, d.day);
        }
      }();

      return StatefulBuilder(
        builder: (context, setSheetState) {
          final isCustomAmount = amountCents != recurring.amount;

          return DraggableScrollableSheet(
            initialChildSize: 0.72,
            maxChildSize: 0.92,
            minChildSize: 0.5,
            expand: false,
            builder: (ctx, scrollController) => ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusDialog),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppTheme.radiusDialog),
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
                          borderRadius: BorderRadius.circular(kSpacing2),
                        ),
                      ),
                    ),
                    // Title
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        kSpacing20,
                        kSpacing16,
                        kSpacing20,
                        kSpacing12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(kSpacing8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppTheme.radiusCompact),
                            ),
                            child: Icon(
                              PesaFlowIcons.sync,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: kSpacing12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mark Bill Paid',
                                style: context.ts(20, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Record scheduled cycle payment',
                                style: context.ts(
                                  12,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ],
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
                          // ── Executive Receipt Card ──
                          Container(
                            padding: const EdgeInsets.all(kSpacing16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            recurring.description ?? 'Recurring ${recurring.type}',
                                            style: context.ts(16, fontWeight: FontWeight.w700),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Category: $categoryName • From: $accountName',
                                            style: context.ts(
                                              11,
                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: kSpacing8,
                                        vertical: kSpacing4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                      ),
                                      child: Text(
                                        recurring.frequency.toUpperCase(),
                                        style: context.ts(
                                          10,
                                          fontWeight: FontWeight.w700,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: kSpacing16),
                                // ── Timeline Advance Preview ──
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: kSpacing12,
                                    vertical: kSpacing10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(AppTheme.radiusCompact),
                                    border: Border.all(
                                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Current Cycle',
                                              style: context.ts(
                                                10,
                                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${recurring.nextDate.day}/${recurring.nextDate.month}/${recurring.nextDate.year}',
                                              style: context.ts(12, fontWeight: FontWeight.w700),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(kSpacing4),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          PesaFlowIcons.chevronRight,
                                          size: 14,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Next Cycle Due',
                                              style: context.ts(
                                                10,
                                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${projectedNextDate.day}/${projectedNextDate.month}/${projectedNextDate.year}',
                                              style: context.ts(
                                                12,
                                                fontWeight: FontWeight.w700,
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: kSpacing20),
                          // Payment Amount Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'PAYMENT AMOUNT',
                                style: context.ts(
                                  10,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (isCustomAmount)
                                GestureDetector(
                                  onTap: () {
                                    PesaHaptics.light();
                                    amountCents = recurring.amount;
                                    amountController.text = (recurring.amount ~/ 100).toString();
                                    setSheetState(() {});
                                  },
                                  child: Text(
                                    'Reset to default (${CurrencyFormatter.formatCents(recurring.amount)})',
                                    style: context.ts(
                                      11,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: kSpacing8),
                          TextField(
                            controller: amountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: context.ts(
                              22,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(
                                  left: 14,
                                  right: 8,
                                  top: 12,
                                ),
                                child: Text(
                                  'TSh',
                                  style: context.ts(
                                    16,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: kSpacing16,
                                vertical: kSpacing14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val);
                              if (parsed != null) {
                                amountCents = parsed * 100;
                              } else {
                                amountCents = 0;
                              }
                              setSheetState(() {});
                            },
                          ),
                          const SizedBox(height: kSpacing20),
                          // Deduct toggle card
                          Container(
                            padding: const EdgeInsets.all(kSpacing14),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(kSpacing8),
                                  decoration: BoxDecoration(
                                    color: (deductBalance ? context.appColors.incomeColor : theme.colorScheme.onSurface)
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    PesaFlowIcons.wallet,
                                    size: 18,
                                    color: deductBalance ? context.appColors.incomeColor : theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: kSpacing12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Deduct from $accountName',
                                        style: context.ts(
                                          14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        deductBalance
                                            ? 'Records regular transaction and reduces account balance'
                                            : 'Marks cycle without modifying account balance',
                                        style: context.ts(
                                          11,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: deductBalance,
                                  activeTrackColor: theme.colorScheme.primary,
                                  onChanged: isProcessing
                                      ? null
                                      : (v) {
                                          PesaHaptics.selection();
                                          setSheetState(
                                            () => deductBalance = v,
                                          );
                                        },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Bottom actions
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        kSpacing20,
                        kSpacing12,
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
                              onPressed: isProcessing || amountCents <= 0
                                  ? null
                                  : () async {
                                      PesaHaptics.success();
                                      setSheetState(() => isProcessing = true);
                                      try {
                                        await _confirmMarkPaid(
                                          context: context,
                                          ref: ref,
                                          repo: repo,
                                          txRepo: txRepo,
                                          recurring: recurring,
                                          deductBalance: deductBalance,
                                          amountCents: amountCents,
                                        );
                                        if (context.mounted) {
                                          context.pop();
                                        }
                                      } catch (e) {
                                        setSheetState(
                                          () => isProcessing = false,
                                        );
                                        if (context.mounted) {
                                          CustomToast.show(
                                            context,
                                            message:
                                                'Failed to mark payment: $e',
                                            type: ToastType.error,
                                          );
                                        }
                                      }
                                    },
                              child: Text(
                                isProcessing
                                    ? 'Processing…'
                                    : amountCents > 0
                                        ? 'Confirm Payment of ${CurrencyFormatter.formatCents(amountCents)}'
                                        : 'Enter an amount',
                              ),
                            ),
                          ),
                          const SizedBox(height: kSpacing10),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton(
                              onPressed: isProcessing
                                  ? null
                                  : () => context.pop(),
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

Future<void> _confirmMarkPaid({
  required BuildContext context,
  required WidgetRef ref,
  required RecurringTransactionRepository repo,
  required TransactionRepository txRepo,
  required RecurringTransaction recurring,
  required bool deductBalance,
  required int amountCents,
}) async {
  final now = DateTime.now();
  final transaction = Transaction(
    id: const Uuid().v4(),
    accountId: recurring.accountId,
    categoryId: recurring.categoryId ?? '',
    amount: amountCents,
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
    amount: amountCents,
    paidAt: now,
    deductBalance: deductBalance,
  );

  if (context.mounted) {
    PesaHaptics.success();
    CustomToast.show(
      context,
      message: 'Payment recorded',
      type: ToastType.success,
    );
  }
}
