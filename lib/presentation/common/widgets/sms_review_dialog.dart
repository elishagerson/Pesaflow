import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/domain/sms/pending_review_notifier.dart';

import 'package:pesaflow/core/utils/context_extensions.dart';

import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/undo_delete.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';

class SmsReviewDialog extends ConsumerStatefulWidget {
  final TransactionWithCategoryAndAccount item;

  const SmsReviewDialog({super.key, required this.item});

  @override
  ConsumerState<SmsReviewDialog> createState() => _SmsReviewDialogState();
}

class _SmsReviewDialogState extends ConsumerState<SmsReviewDialog> {
  String? _selectedCategoryId;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.item.category.id;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    await ref
        .read(transactionRepositoryProvider)
        .approveReviewedTransaction(
          widget.item.transaction.id,
          newCategoryId: _selectedCategoryId,
        );
    ref.invalidate(reviewQueueStreamProvider);
    ref.invalidate(recentTransactionsStreamProvider);
    ref.read(pendingReviewProvider.notifier).clear();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _reject() async {
    final txData = widget.item;
    ref.read(pendingReviewProvider.notifier).clear();
    if (mounted) Navigator.of(context).pop();
    UndoDelete.show(
      context: context,
      entityName: 'Transaction',
      message: 'Transaction rejected',
      onUndo: () async {
        await ref
            .read(transactionRepositoryProvider)
            .createTransaction(txData.transaction);
      },
      onDelete: () async {
        await ref
            .read(transactionRepositoryProvider)
            .deleteTransaction(txData.transaction.id);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trans = widget.item.transaction;
    final categoriesAsync = ref.watch(categoriesFutureProvider);
    final categories = categoriesAsync.value ?? [];

    final transactedCents = trans.amount;
    AmountType amountType = AmountType.neutral;
    if (trans.type == 'income') {
      amountType = AmountType.income;
    } else if (trans.type == 'expense' ||
        trans.type == 'airtime' ||
        trans.type == 'fee') {
      amountType = AmountType.expense;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: kSpacing16,
        vertical: kSpacing40,
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(kSpacing20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    PesaFlowIcons.sms,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: kSpacing8),
                  Text(
                    'New Transaction',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(PesaFlowIcons.close, size: 20),
                    onPressed: () {
                      ref.read(pendingReviewProvider.notifier).clear();
                      Navigator.of(context).pop();
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: kSpacing16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(kSpacing14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    AmountText(
                      amountInCents: transactedCents,
                      type: amountType,
                      style: context
                          .ts(28, fontWeight: FontWeight.bold)
                          .copyWith(
                            fontFamily:
                                context.appTypography.monospace.fontFamily,
                          ),
                    ),
                    const SizedBox(height: kSpacing6),
                    Text(
                      trans.description.isNotEmpty
                          ? trans.description
                          : '(no description)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: kSpacing4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.item.account!.name,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: kSpacing16),
              Text(
                'Assign Category',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: kSpacing8),
              TextField(
                controller: _searchController,
                decoration: context.inputDecoration(
                  hintText: 'Search categories...',
                  prefixIcon: const Icon(PesaFlowIcons.search, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(PesaFlowIcons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (v) =>
                    setState(() => _searchQuery = v.toLowerCase()),
              ),
              const SizedBox(height: kSpacing8),
              if (categories.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(kSpacing16),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                SizedBox(
                  height: 180,
                  child: ListView.separated(
                    itemCount: categories.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: kSpacing2),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isSelected = cat.id == _selectedCategoryId;
                      if (_searchQuery.isNotEmpty &&
                          !cat.name.toLowerCase().contains(_searchQuery) &&
                          !cat.type.toLowerCase().contains(_searchQuery)) {
                        return const SizedBox.shrink();
                      }
                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        selectedTileColor: theme.colorScheme.primary.withValues(
                          alpha: 0.08,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(kSpacing6),
                          decoration: BoxDecoration(
                            color: hexToColor(
                              cat.color,
                            ).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            getCategoryIcon(cat.icon),
                            color: hexToColor(cat.color),
                            size: 18,
                          ),
                        ),
                        title: Text(
                          cat.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          cat.type.toUpperCase(),
                          style: context.appTypography.labelMicro.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                PesaFlowIcons.success,
                                color: theme.colorScheme.primary,
                                size: 20,
                              )
                            : null,
                        onTap: () =>
                            setState(() => _selectedCategoryId = cat.id),
                      );
                    },
                  ),
                ),
              const SizedBox(height: kSpacing16),
              Row(
                children: [
                  Expanded(
                    child: TactileSpringContainer(
                      onTap: _reject,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: kSpacing12,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.error.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              PesaFlowIcons.close,
                              size: 18,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: kSpacing8),
                            Text(
                              'Reject',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.bold,
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
                      onTap: _approve,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: kSpacing12,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              PesaFlowIcons.check,
                              size: 18,
                              color: theme.colorScheme.onPrimary,
                            ),
                            const SizedBox(width: kSpacing8),
                            Text(
                              'Approve',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
