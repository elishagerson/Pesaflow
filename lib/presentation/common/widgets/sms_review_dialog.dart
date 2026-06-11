import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/domain/sms/pending_review_notifier.dart';

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
    await ref.read(transactionRepositoryProvider).approveReviewedTransaction(
          widget.item.transaction.id,
          newCategoryId: _selectedCategoryId,
        );
    ref.invalidate(reviewQueueStreamProvider);
    ref.invalidate(recentTransactionsStreamProvider);
    ref.read(pendingReviewProvider.notifier).clear();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _reject() async {
    await ref.read(transactionRepositoryProvider).deleteTransaction(widget.item.transaction.id);
    ref.invalidate(reviewQueueStreamProvider);
    ref.invalidate(recentTransactionsStreamProvider);
    ref.invalidate(accountsStreamProvider);
    ref.read(pendingReviewProvider.notifier).clear();
    if (mounted) Navigator.of(context).pop();
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
    } else if (trans.type == 'expense' || trans.type == 'airtime' || trans.type == 'fee') {
      amountType = AmountType.expense;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sms_rounded, color: theme.colorScheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Text('New Transaction', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20),
                    onPressed: () {
                      ref.read(pendingReviewProvider.notifier).clear();
                      Navigator.of(context).pop();
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    AmountText(amountInCents: transactedCents, type: amountType,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(trans.description.isNotEmpty ? trans.description : '(no description)',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(widget.item.account.name,
                        style: TextStyle(color: theme.colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Assign Category', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search categories...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              ),
              const SizedBox(height: 8),
              if (categories.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ))
              else
                SizedBox(
                  height: 180,
                  child: ListView.separated(
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 2),
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
                        selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: hexToColor(cat.color).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(getCategoryIcon(cat.icon),
                            color: hexToColor(cat.color), size: 18),
                        ),
                        title: Text(cat.name, style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        )),
                        subtitle: Text(cat.type.toUpperCase(),
                          style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 20)
                            : null,
                        onTap: () => setState(() => _selectedCategoryId = cat.id),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reject,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _approve,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
