import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/account_repository.dart';
import 'package:pesaflow/data/repositories/category_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/services/backup_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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

  void _showAccountsManager(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            final accounts = ref.watch(accountsStreamProvider).value ?? [];
            final theme = Theme.of(context);

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manage Accounts',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: accounts.isEmpty
                        ? const Center(child: Text('No active accounts.'))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: accounts.length,
                            itemBuilder: (context, index) {
                              final acc = accounts[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8.0),
                                child: ListTile(
                                  leading: Icon(_getAccountIcon(acc.icon), color: theme.colorScheme.primary),
                                  title: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                    acc.type.toUpperCase().replaceAll('_', ' ') +
                                        (acc.phoneNumber != null ? ' • ${acc.phoneNumber}' : ''),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AmountText(amountInCents: acc.balance, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete_rounded, color: Colors.red),
                                        onPressed: () async {
                                          await ref.read(accountRepositoryProvider).deleteAccount(acc.id);
                                          ref.invalidate(accountsStreamProvider);
                                          ref.invalidate(netWorthProvider);
                                          if (context.mounted) Navigator.of(context).pop();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCategoriesManager(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            final categories = ref.watch(categoriesFutureProvider).value ?? [];
            final theme = Theme.of(context);

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Manage Categories',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Custom'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showAddCategoryDialog(context, ref);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: categories.isEmpty
                        ? const Center(child: Text('No categories seeded.'))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8.0),
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    decoration: BoxDecoration(
                                      color: _hexToColor(cat.color).withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(_getCategoryIcon(cat.icon), color: _hexToColor(cat.color)),
                                  ),
                                  title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(cat.type.toUpperCase(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  trailing: cat.isSystem
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4.0),
                                          ),
                                          child: const Text('System', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                        )
                                      : IconButton(
                                          icon: const Icon(Icons.delete_rounded, color: Colors.red),
                                          onPressed: () async {
                                            await ref.read(categoryRepositoryProvider).deleteCategory(cat.id);
                                            ref.invalidate(categoriesFutureProvider);
                                            ref.invalidate(filteredTransactionsStreamProvider);
                                            if (context.mounted) Navigator.of(context).pop();
                                          },
                                        ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    String categoryType = 'Expense';
    String selectedHexColor = '#FF9800'; // Default Orange
    String selectedIcon = 'cart';

    final hexColors = ['#F44336', '#E91E63', '#9C27B0', '#673AB7', '#2196F3', '#00BCD4', '#009688', '#4CAF50', '#FFC107', '#FF9800', '#795548', '#607D8B'];
    final icons = ['cart', 'briefcase', 'store', 'bus', 'home', 'zap', 'phone', 'heart', 'book', 'film', 'coffee', 'send', 'piggy-bank'];

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
              title: const Text('Add Custom Category'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                        hintText: 'e.g. Subscriptions, Laundry',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: categoryType,
                      decoration: const InputDecoration(labelText: 'Category Type'),
                      items: const [
                        DropdownMenuItem(value: 'Expense', child: Text('Expense')),
                        DropdownMenuItem(value: 'Income', child: Text('Income')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            categoryType = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Select Theme Color', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: hexColors.map((hex) {
                        final isSelected = selectedHexColor == hex;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedHexColor = hex;
                            });
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _hexToColor(hex),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: theme.brightness == Brightness.dark ? Colors.white : Colors.black, width: 2)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Select Icon', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: icons.map((icName) {
                        final isSelected = selectedIcon == icName;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedIcon = icName;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: isSelected ? theme.colorScheme.primary.withOpacity(0.15) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8.0),
                              border: isSelected ? Border.all(color: theme.colorScheme.primary, width: 1.5) : null,
                            ),
                            child: Icon(_getCategoryIcon(icName), size: 24, color: isSelected ? theme.colorScheme.primary : Colors.grey),
                          ),
                        );
                      }).toList(),
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

                    final newCategory = Category(
                      id: const Uuid().v4(),
                      name: nameController.text.trim(),
                      icon: selectedIcon,
                      color: selectedHexColor,
                      type: categoryType.toLowerCase(),
                      isSystem: false,
                      sortOrder: 100,
                      createdAt: DateTime.now(),
                    );

                    await ref.read(categoryRepositoryProvider).createCategory(newCategory);
                    ref.invalidate(categoriesFutureProvider);
                    ref.invalidate(filteredTransactionsStreamProvider);
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

  Future<void> _handleExportCsv(BuildContext context, WidgetRef ref) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating CSV export...')),
      );
      await ref.read(backupServiceProvider).exportTransactionsToCsv();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export CSV: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleBackupDb(BuildContext context, WidgetRef ref) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Creating local backup...')),
      );
      await ref.read(backupServiceProvider).backupDatabase();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleRestoreDb(BuildContext context, WidgetRef ref) async {
    try {
      final success = await ref.read(backupServiceProvider).restoreDatabase();
      if (!success || !context.mounted) return;

      // Show relaunch alert dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final theme = Theme.of(context);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusDialog)),
            title: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppTheme.incomeColor, size: 28),
                const SizedBox(width: 12),
                const Text('Profile Restored'),
              ],
            ),
            content: const Text(
              'Your offline database backup has been successfully restored.\n\n'
              'To cleanly load your transactions, budgets, and settings, PesaFlow needs to relaunch.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => exit(0),
                child: const Text('Relaunch App'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusDialog)),
            title: Row(
              children: const [
                Icon(Icons.error_outline_rounded, color: Colors.red, size: 28),
                SizedBox(width: 12),
                Text('Restore Failed'),
              ],
            ),
            content: Text(
              e is FormatException
                  ? e.message
                  : 'An unexpected error occurred during database restoration: $e',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsStreamProvider).value ?? [];
    final categories = ref.watch(categoriesFutureProvider).value ?? [];
    final recentTransactions = ref.watch(recentTransactionsStreamProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Premium local privacy indicator card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10.0),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.shield_rounded, color: theme.colorScheme.primary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Offline Privacy Protection',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'PesaFlow stores all financial records, carrier receipts, and bank logs in a sandboxed, strictly local offline SQLite database on your device. Absolutely zero cloud transfers.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Configuration Section Header
              const Text('SYSTEM MANAGEMENT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12, letterSpacing: 1.2)),
              const SizedBox(height: 8),

              // Accounts Manager
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_rounded),
                title: const Text('Accounts Manager', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Add, edit, or archive bank, mobile money, and cash balances'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showAccountsManager(context, ref),
              ),
              const Divider(height: 1),

              // Categories Manager
              ListTile(
                leading: const Icon(Icons.category_rounded),
                title: const Text('Categories Manager', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Add custom financial category folders or edit envelopes'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showCategoriesManager(context, ref),
              ),
              const Divider(height: 1),

              // Data Management Section Header
              const SizedBox(height: 24),
              const Text('DATA MANAGEMENT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12, letterSpacing: 1.2)),
              const SizedBox(height: 8),

              // Export CSV
              ListTile(
                leading: const Icon(Icons.file_download_rounded, color: Colors.green),
                title: const Text('Export to CSV', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Download all transaction logs as a standard spreadsheet file'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _handleExportCsv(context, ref),
              ),
              const Divider(height: 1),

              // Backup Database
              ListTile(
                leading: const Icon(Icons.backup_rounded, color: Colors.blue),
                title: const Text('Backup Profile Database', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Generate an offline, portable SQLite file backup of your PesaFlow profile'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _handleBackupDb(context, ref),
              ),
              const Divider(height: 1),

              // Restore Database
              ListTile(
                leading: const Icon(Icons.restore_rounded, color: Colors.orange),
                title: const Text('Restore Profile Database', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Restore full transaction and budget history from a valid SQLite backup'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _handleRestoreDb(context, ref),
              ),
              const Divider(height: 1),

              // Preferences Section Header
              const SizedBox(height: 24),
              const Text('PREFERENCES', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12, letterSpacing: 1.2)),
              const SizedBox(height: 8),

              // Interface Language indicator (strictly English)
              ListTile(
                leading: const Icon(Icons.translate_rounded),
                title: const Text('Interface Language', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Locking system text strictly to English (Phase 1)'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: Text('English Only', style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                ),
              ),
              const Divider(height: 1),

              // Theme configuration display
              ListTile(
                leading: const Icon(Icons.dark_mode_rounded),
                title: const Text('Visual Display Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Theme adapts dynamically based on system environment (Light/Dark)'),
                trailing: const Icon(Icons.brightness_medium_rounded),
              ),
              const Divider(height: 1),

              // Database Stats Section Header
              const SizedBox(height: 24),
              const Text('DATABASE HEALTH & METRICS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12, letterSpacing: 1.2)),
              const SizedBox(height: 12),

              // Database Stats Row
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(context, 'Accounts', '${accounts.length}', Icons.account_balance_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(context, 'Categories', '${categories.length}', Icons.category_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(context, 'Transactions', '${recentTransactions.length}', Icons.receipt_long_rounded),
                  ),
                ],
              ),

              // Version / Legal footer
              const SizedBox(height: 36),
              const Center(
                child: Column(
                  children: [
                    Text('PesaFlow v1.0.0 (Phase 1 Foundation)', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Built Offline for privacy in Tanzania', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 22),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
