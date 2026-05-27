import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/repositories/category_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/domain/sms/pending_review_notifier.dart';

IconData _getCategoryIcon(String iconName) {
  switch (iconName) {
    case 'briefcase':
      return Icons.work_rounded;
    case 'store':
      return Icons.storefront_rounded;
    case 'cart':
      return Icons.shopping_cart_rounded;
    case 'bus':
      return Icons.directions_bus_rounded;
    case 'home':
      return Icons.home_rounded;
    case 'zap':
      return Icons.electric_bolt_rounded;
    case 'phone':
      return Icons.phone_android_rounded;
    case 'heart':
      return Icons.favorite_rounded;
    case 'book':
      return Icons.menu_book_rounded;
    case 'film':
      return Icons.movie_rounded;
    case 'shopping-bag':
      return Icons.shopping_bag_rounded;
    case 'coffee':
      return Icons.coffee_rounded;
    case 'send':
      return Icons.send_rounded;
    case 'credit-card':
      return Icons.credit_card_rounded;
    case 'banknote':
      return Icons.payments_rounded;
    case 'piggy-bank':
      return Icons.savings_rounded;
    case 'arrow-left-right':
      return Icons.compare_arrows_rounded;
    case 'plus-circle':
    default:
      return Icons.add_circle_outline_rounded;
  }
}

Color _hexToColor(String hex) {
  final clean = hex.replaceAll('#', '');
  if (clean.length == 6) {
    return Color(int.parse('FF$clean', radix: 16));
  }
  return Colors.grey;
}

class SmsReviewDialog extends ConsumerStatefulWidget {
  final TransactionWithCategoryAndAccount item;

  const SmsReviewDialog({super.key, required this.item});

  @override
  ConsumerState<SmsReviewDialog> createState() => _SmsReviewDialogState();
}

class _SmsReviewDialogState extends ConsumerState<SmsReviewDialog> {
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.item.category.id;
  }

  Future<void> _approve() async {
    await ref.read(transactionRepositoryProvider).approveReviewedTransaction(
          widget.item.transaction.id,
          newCategoryId: _selectedCategoryId,
        );
    ref.invalidate(reviewQueueStreamProvider);
    ref.invalidate(recentTransactionsStreamProvider);
    ref.read(pendingReviewProvider.notifier).clear();
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _reject() async {
    await ref.read(transactionRepositoryProvider).deleteTransaction(widget.item.transaction.id);
    ref.invalidate(reviewQueueStreamProvider);
    ref.invalidate(recentTransactionsStreamProvider);
    ref.invalidate(accountsStreamProvider);
    ref.read(pendingReviewProvider.notifier).clear();
    if (context.mounted) Navigator.of(context).pop();
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
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
                        color: theme.colorScheme.primary.withOpacity(0.1),
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
              if (categories.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ))
              else
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 2),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isSelected = cat.id == _selectedCategoryId;
                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        selectedTileColor: theme.colorScheme.primary.withOpacity(0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _hexToColor(cat.color).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_getCategoryIcon(cat.icon),
                            color: _hexToColor(cat.color), size: 18),
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
                        side: BorderSide(color: theme.colorScheme.error.withOpacity(0.4)),
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
