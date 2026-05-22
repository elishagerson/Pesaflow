import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class TransactionListScreen extends ConsumerWidget {
  const TransactionListScreen({super.key});

  String _formatHeaderDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final compareDate = DateTime(date.year, date.month, date.day);

    if (compareDate == today) {
      return 'Today';
    } else if (compareDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('EEEE, MMMM d, yyyy').format(date);
    }
  }

  Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return Colors.grey;
  }

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    // Watch filters
    final activeType = ref.watch(transactionTypeFilterProvider);
    final activeAccount = ref.watch(transactionAccountFilterProvider);
    final activeCategory = ref.watch(transactionCategoryFilterProvider);
    final searchQuery = ref.watch(transactionSearchQueryProvider);

    // Watch streams/futures
    final transactionsAsync = ref.watch(filteredTransactionsStreamProvider);

    final searchController = TextEditingController(text: searchQuery);
    searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: searchController.text.length),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // iOS-style nav header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transactions',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
                    ),
                  ),
                  Row(
                    children: [
                      if (activeAccount != null || activeCategory != null || searchQuery.isNotEmpty || activeType != 'All')
                        IconButton(
                          icon: const Icon(Icons.clear_all_rounded, color: Colors.red),
                          tooltip: 'Clear Filters',
                          onPressed: () {
                            ref.read(transactionTypeFilterProvider.notifier).state = 'All';
                            ref.read(transactionAccountFilterProvider.notifier).state = null;
                            ref.read(transactionCategoryFilterProvider.notifier).state = null;
                            ref.read(transactionSearchQueryProvider.notifier).state = '';
                          },
                        ),
                      IconButton(
                        icon: Icon(
                          Icons.filter_list_rounded,
                          color: (activeAccount != null || activeCategory != null)
                              ? theme.colorScheme.primary
                              : (theme.brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                        onPressed: () {
                          _showFiltersBottomSheet(context, ref);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Live Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: TextField(
                controller: searchController,
                onChanged: (val) {
                  ref.read(transactionSearchQueryProvider.notifier).state = val.trim();
                },
                decoration: InputDecoration(
                  hintText: 'Search description, recipient or reference...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            ref.read(transactionSearchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                ),
              ),
            ),

            // Segmented Type Pills
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: ['All', 'Income', 'Expense', 'Transfer'].map((type) {
                    final isSelected = activeType == type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            ref.read(transactionTypeFilterProvider.notifier).state = type;
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Filter Active Indicators
            if (activeAccount != null || activeCategory != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Filters active: '
                        '${activeAccount != null ? "Account locked" : ""}'
                        '${(activeAccount != null && activeCategory != null) ? " & " : ""}'
                        '${activeCategory != null ? "Category locked" : ""}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Grouped Transactions List Layer
            Expanded(
              child: transactionsAsync.when(
                data: (transactionsList) {
                  if (transactionsList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          const Text(
                            'No Transactions Found',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Try adjusting your filters or typing a different query.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  // Group items by calendar day
                  final Map<String, List<TransactionWithCategoryAndAccount>> grouped = {};
                  for (final item in transactionsList) {
                    final dayStr = DateFormat('yyyy-MM-dd').format(item.transaction.createdAt);
                    if (grouped[dayStr] == null) {
                      grouped[dayStr] = [];
                    }
                    grouped[dayStr]!.add(item);
                  }

                  final sortedDays = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: sortedDays.length,
                    itemBuilder: (context, dayIndex) {
                      final dayStr = sortedDays[dayIndex];
                      final dayItems = grouped[dayStr]!;
                      final firstItemDate = dayItems.first.transaction.createdAt;
                      
                      // Calculate daily net balance change (income - expense)
                      int dailyNetChange = 0;
                      for (final item in dayItems) {
                        final type = item.transaction.type.toLowerCase();
                        if (type == 'income') {
                          dailyNetChange += item.transaction.amount;
                        } else if (type == 'expense' || type == 'airtime' || type == 'fee') {
                          dailyNetChange -= item.transaction.amount;
                        }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Group Date Header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatHeaderDate(firstItemDate).toUpperCase(),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                // Monospace Net Change Indicator
                                AmountText(
                                  amountInCents: dailyNetChange.abs(),
                                  type: dailyNetChange > 0
                                      ? AmountType.income
                                      : (dailyNetChange < 0 ? AmountType.expense : AmountType.neutral),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Transaction Items under this group
                          ...dayItems.map((item) {
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
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20.0),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.error,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                                ),
                                child: const Icon(Icons.delete_rounded, color: Colors.white),
                              ),
                              onDismissed: (_) async {
                                await ref.read(transactionRepositoryProvider).deleteTransaction(trans.id);
                                ref.invalidate(filteredTransactionsStreamProvider);
                                ref.invalidate(accountsStreamProvider);
                                ref.invalidate(netWorthProvider);
                              },
                               child: GlassCard(
                                 margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                 borderRadius: AppTheme.radiusCard,
                                 child: ListTile(
                                   onTap: () => context.go('/transactions/edit/${trans.id}'),
                                   leading: Container(
                                     padding: const EdgeInsets.all(8.0),
                                     decoration: BoxDecoration(
                                       color: _hexToColor(item.category.color).withOpacity(0.15),
                                       shape: BoxShape.circle,
                                     ),
                                     child: Icon(
                                       _getCategoryIcon(item.category.icon),
                                       color: _hexToColor(item.category.color),
                                       size: 24,
                                     ),
                                   ),
                                   title: Text(
                                     trans.description.isNotEmpty ? trans.description : item.category.name,
                                     style: const TextStyle(fontWeight: FontWeight.bold),
                                   ),
                                   subtitle: Row(
                                     children: [
                                       Text(
                                         item.account.name,
                                         style: TextStyle(
                                           color: theme.colorScheme.primary,
                                           fontSize: 12,
                                           fontWeight: FontWeight.bold,
                                         ),
                                       ),
                                       const SizedBox(width: 8),
                                       if (trans.reference != null)
                                         Text(
                                           'Ref: ${trans.reference}',
                                           style: const TextStyle(color: Colors.grey, fontSize: 11),
                                         ),
                                     ],
                                   ),
                                   trailing: AmountText(
                                     amountInCents: trans.amount,
                                     type: amtType,
                                     style: const TextStyle(
                                       fontWeight: FontWeight.bold,
                                       fontSize: 16,
                                     ),
                                   ),
                                 ),
                                ));
                           }),
                        ],
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading transactions: $err')),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/transactions/add'),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showFiltersBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        final accounts = ref.watch(accountsStreamProvider).value ?? [];
        final categories = ref.watch(categoriesFutureProvider).value ?? [];
        final activeAccount = ref.watch(transactionAccountFilterProvider);
        final activeCategory = ref.watch(transactionCategoryFilterProvider);

        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter Transactions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // Account Picker
                  const Text('Filter by Account', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: activeAccount,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12.0)),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All Accounts')),
                      ...accounts.map((acc) => DropdownMenuItem<String?>(
                            value: acc.id,
                            child: Text(acc.name),
                          )),
                    ],
                    onChanged: (val) {
                      ref.read(transactionAccountFilterProvider.notifier).state = val;
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 20),

                  // Category Picker
                  const Text('Filter by Category', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: activeCategory,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12.0)),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All Categories')),
                      ...categories.map((cat) => DropdownMenuItem<String?>(
                            value: cat.id,
                            child: Text('${cat.type.toUpperCase()}: ${cat.name}'),
                          )),
                    ],
                    onChanged: (val) {
                      ref.read(transactionCategoryFilterProvider.notifier).state = val;
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
