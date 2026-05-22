import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/ios/ios_list_section.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class SmsReviewScreen extends ConsumerWidget {
  const SmsReviewScreen({super.key});

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

  void _showCategoryPicker(
    BuildContext context,
    WidgetRef ref,
    TransactionWithCategoryAndAccount item,
  ) async {
    final categoriesAsync = ref.read(categoriesFutureProvider);
    final categories = categoriesAsync.valueOrNull ?? [];
    if (categories.isEmpty) return;

    final selectedCategoryId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Assign Category',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isSelected = cat.id == item.category.id;
                      return ListTile(
                        selected: isSelected,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _hexToColor(cat.color).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getCategoryIcon(cat.icon),
                            color: _hexToColor(cat.color),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          cat.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          cat.type.toUpperCase(),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                            : null,
                        onTap: () => Navigator.of(context).pop(cat.id),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedCategoryId != null) {
      await ref.read(transactionRepositoryProvider).approveReviewedTransaction(
            item.transaction.id,
            newCategoryId: selectedCategoryId,
          );
      ref.invalidate(reviewQueueStreamProvider);
      ref.invalidate(recentTransactionsStreamProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewAsync = ref.watch(reviewQueueStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            IosNavBar(
              title: 'SMS Review',
              largeTitle: true,
            ),
            Expanded(
              child: reviewAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 56,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'All Clear!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No transactions awaiting review.\nAuto-logged entries appear on the Dashboard.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: items.length + 1, // +1 for header
            itemBuilder: (context, index) {
              if (index == 0) {
                // Header
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.tertiary.withOpacity(0.15),
                          theme.colorScheme.tertiary.withOpacity(0.05),
                        ],
                      ),
                      border: Border.all(
                        color: theme.colorScheme.tertiary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sms_rounded,
                          color: theme.colorScheme.tertiary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${items.length} transaction${items.length == 1 ? '' : 's'} to review',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Swipe right to approve, left to reject',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final item = items[index - 1];
              final trans = item.transaction;

              AmountType amtType = AmountType.neutral;
              if (trans.type.toLowerCase() == 'income') {
                amtType = AmountType.income;
              } else if (trans.type.toLowerCase() == 'expense' ||
                  trans.type.toLowerCase() == 'airtime' ||
                  trans.type.toLowerCase() == 'fee') {
                amtType = AmountType.expense;
              }

              return Dismissible(
                key: Key(trans.id),
                // Swipe right to approve
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 24),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF),
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_rounded, color: Colors.white, size: 28),
                      SizedBox(width: 8),
                      Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                // Swipe left to reject/delete
                secondaryBackground: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Reject', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    ],
                  ),
                ),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.startToEnd) {
                    // Approve: mark as sms_auto
                    await ref.read(transactionRepositoryProvider).approveReviewedTransaction(trans.id);
                    ref.invalidate(reviewQueueStreamProvider);
                    ref.invalidate(recentTransactionsStreamProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Transaction approved: ${trans.description}'),
                          backgroundColor: theme.brightness == Brightness.dark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    return true;
                  } else {
                    // Reject: delete the transaction
                    await ref.read(transactionRepositoryProvider).deleteTransaction(trans.id);
                    ref.invalidate(reviewQueueStreamProvider);
                    ref.invalidate(recentTransactionsStreamProvider);
                    ref.invalidate(accountsStreamProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Transaction rejected: ${trans.description}'),
                          backgroundColor: theme.colorScheme.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    return true;
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? AppTheme.surfaceContainerDark
                        : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    border: Border.all(
                      color: theme.brightness == Brightness.dark
                          ? const Color(0x12FFFFFF)
                          : const Color(0x1F000000),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top section: provider badge + amount
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _hexToColor(item.category.color).withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getCategoryIcon(item.category.icon),
                                color: _hexToColor(item.category.color),
                                size: 22,
                                                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    trans.description.isNotEmpty
                                        ? trans.description
                                        : item.category.name,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          item.account.name,
                                          style: TextStyle(
                                            color: theme.colorScheme.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        trans.type.toUpperCase(),
                                        style: const TextStyle(
                                            fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            AmountText(
                              amountInCents: trans.amount,
                              type: amtType,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                                              ),
                            ),
                          ],
                        ),
                      ),

                      // Raw SMS preview
                      if (trans.rawSms != null && trans.rawSms!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              trans.rawSms!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: theme.colorScheme.onSurfaceVariant
                                    .withOpacity(0.7),
                              ),
                            ),
                          ),
                        ),

                      // Action buttons
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => _showCategoryPicker(context, ref, item),
                              icon: const Icon(Icons.category_rounded, size: 16),
                              label: const Text('Change Category',
                                  style: TextStyle(fontSize: 12)),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () async {
                                await ref
                                    .read(transactionRepositoryProvider)
                                    .approveReviewedTransaction(trans.id);
                                ref.invalidate(reviewQueueStreamProvider);
                                ref.invalidate(recentTransactionsStreamProvider);
                              },
                              icon: Icon(Icons.check_rounded,
                                  size: 16, color: theme.brightness == Brightness.dark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF)),
                              label: Text('Approve',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: theme.brightness == Brightness.dark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF))),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading review queue: $err')),
      ),
          ),
        ],
      ),
    ));
  }
}
