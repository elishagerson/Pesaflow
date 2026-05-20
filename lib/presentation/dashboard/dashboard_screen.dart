import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/account_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    String accountType = 'Cash'; // Default
    final balanceController = TextEditingController();
    String? phoneNumber;
    String? provider;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusDialog),
              ),
              title: const Text('Add Account'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Account Name',
                        hintText: 'e.g. M-Pesa, Cash Wallet, NMB Savings',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: accountType,
                      decoration: const InputDecoration(labelText: 'Account Type'),
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Cash Wallet')),
                        DropdownMenuItem(value: 'Mobile Money', child: Text('Mobile Money')),
                        DropdownMenuItem(value: 'Bank', child: Text('Bank Account')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            accountType = val;
                            if (accountType == 'Mobile Money') {
                              provider = 'M-Pesa_TZ';
                            } else if (accountType == 'Bank') {
                              provider = 'NMB';
                            } else {
                              provider = null;
                            }
                          });
                        }
                      },
                    ),
                    if (accountType == 'Mobile Money') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: provider ?? 'M-Pesa_TZ',
                        decoration: const InputDecoration(labelText: 'Carrier Provider'),
                        items: const [
                          DropdownMenuItem(value: 'M-Pesa_TZ', child: Text('Vodacom M-Pesa')),
                          DropdownMenuItem(value: 'TigoPesa_TZ', child: Text('Tigo Pesa')),
                          DropdownMenuItem(value: 'AirtelMoney_TZ', child: Text('Airtel Money')),
                          DropdownMenuItem(value: 'Halopesa_TZ', child: Text('HaloPesa')),
                        ],
                        onChanged: (val) {
                          setState(() {
                            provider = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          hintText: 'e.g. 076XXXXXXX',
                        ),
                        onChanged: (val) {
                          phoneNumber = val;
                        },
                      ),
                    ],
                    if (accountType == 'Bank') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: provider ?? 'NMB',
                        decoration: const InputDecoration(labelText: 'Bank Brand'),
                        items: const [
                          DropdownMenuItem(value: 'NMB', child: Text('NMB Bank')),
                          DropdownMenuItem(value: 'CRDB', child: Text('CRDB Bank')),
                          DropdownMenuItem(value: 'NBC', child: Text('NBC Bank')),
                        ],
                        onChanged: (val) {
                          setState(() {
                            provider = val;
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: balanceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Initial Balance (Tsh)',
                        hintText: 'e.g. 150,000',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;
                    
                    final rawAmount = balanceController.text;
                    final cleanAmount = rawAmount.replaceAll(RegExp(r'[^0-9.]'), '');
                    final parsedDouble = double.tryParse(cleanAmount) ?? 0.0;
                    final int cents = (parsedDouble * 100).round();

                    String iconName = 'wallet';
                    if (accountType == 'Mobile Money') {
                      iconName = 'phone-android';
                    } else if (accountType == 'Bank') {
                      iconName = 'account-balance';
                    }

                    final newAccount = Account(
                      id: const Uuid().v4(),
                      name: nameController.text.trim(),
                      type: accountType.toLowerCase().replaceAll(' ', '_'),
                      balance: cents,
                      provider: provider,
                      phoneNumber: phoneNumber,
                      icon: iconName,
                      sortOrder: 0,
                      isArchived: false,
                      createdAt: DateTime.now(),
                    );

                    await ref.read(accountRepositoryProvider).createAccount(newAccount);
                    
                    // Force Riverpod cache invalidation for accounts stream
                    ref.invalidate(accountsStreamProvider);
                    
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _getAccountIcon(String iconStr) {
    switch (iconStr) {
      case 'phone-android':
        return Icons.phone_android_rounded;
      case 'account-balance':
        return Icons.account_balance_rounded;
      case 'wallet':
      default:
        return Icons.account_balance_wallet_rounded;
    }
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

  Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final netWorth = ref.watch(netWorthProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final recentTransAsync = ref.watch(recentTransactionsStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Block
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                      Text(
                        'Hello, Friend!',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    child: Icon(Icons.person_rounded, color: theme.colorScheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Glassmorphic Premium Net Worth Hero Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withRed(15).withGreen(120),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL NET WORTH',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white70,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AmountText(
                      amountInCents: netWorth,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.security_rounded, color: Colors.white60, size: 16),
                        SizedBox(width: 6),
                        Text(
                          '100% Secure & On-Device Only',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Primary Interactive Actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/transactions/add'),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Transaction'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddAccountDialog(context, ref),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                      ),
                      icon: const Icon(Icons.account_balance_wallet_rounded),
                      label: const Text('Add Account'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Horizontal Scrollable Accounts Carousel
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Accounts',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  accountsAsync.when(
                    data: (list) => Text(
                      '${list.length} active',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 105,
                child: accountsAsync.when(
                  data: (accounts) {
                    if (accounts.isEmpty) {
                      return GestureDetector(
                        onTap: () => _showAddAccountDialog(context, ref),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                              style: BorderStyle.solid,
                              width: 1,
                            ),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_card_rounded, color: Colors.grey, size: 28),
                              SizedBox(height: 6),
                              Text(
                                'No accounts added yet. Tap to create one!',
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      scrollDirection: Axis.horizontal,
                      itemCount: accounts.length,
                      itemBuilder: (context, index) {
                        final account = accounts[index];
                        return Container(
                          width: 180,
                          margin: const EdgeInsets.only(right: 12.0),
                          padding: const EdgeInsets.all(14.0),
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark
                                ? AppTheme.surfaceContainerDark
                                : AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                            border: Border.all(
                              color: theme.brightness == Brightness.dark
                                  ? const Color(0x1FFFFFFF)
                                  : const Color(0x1F000000),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _getAccountIcon(account.icon),
                                    size: 20,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      account.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    account.type.toUpperCase().replaceAll('_', ' '),
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 2),
                                  AmountText(
                                    amountInCents: account.balance,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error loading accounts: $err')),
                ),
              ),
              const SizedBox(height: 28),

              // Recent Transactions Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Activity',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to index 1 of the stateful shell (which is /transactions)
                      context.go('/transactions');
                    },
                    child: const Text('See All'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              recentTransAsync.when(
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 36.0),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? AppTheme.surfaceContainerDark
                            : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 40,
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No transactions recorded.',
                            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Your offline financial logs will display here.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final item = transactions[index];
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
                          ref.invalidate(recentTransactionsStreamProvider);
                          ref.invalidate(accountsStreamProvider);
                          ref.invalidate(netWorthProvider);
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8.0),
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
                                Text(
                                  trans.createdAt.toString().substring(0, 10),
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
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading activity: $err')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
