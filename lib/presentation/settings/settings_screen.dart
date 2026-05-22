import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/account_repository.dart';
import 'package:pesaflow/data/repositories/category_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/ios/ios_list_section.dart';
import 'package:pesaflow/presentation/common/ios/ios_sheet.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dropdown.dart';
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
    final accounts = ref.watch(accountsStreamProvider).value ?? [];
    final theme = Theme.of(context);
    IosBottomSheet.show(
      context: context,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Manage Accounts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          if (accounts.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No active accounts.')))
          else
            ...accounts.map((acc) => IosListRow(
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
                  GestureDetector(
                    onTap: () async {
                      await ref.read(accountRepositoryProvider).deleteAccount(acc.id);
                      ref.invalidate(accountsStreamProvider);
                      ref.invalidate(netWorthProvider);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Icon(Icons.delete_rounded, size: 20, color: Colors.red),
                  ),
                ],
              ),
            )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showCategoriesManager(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesFutureProvider).value ?? [];
    final theme = Theme.of(context);
    IosBottomSheet.show(
      context: context,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Manage Categories', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
          ),
          if (categories.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No categories seeded.')))
          else
            ...categories.map((cat) => IosListRow(
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
                  : GestureDetector(
                      onTap: () async {
                        await ref.read(categoryRepositoryProvider).deleteCategory(cat.id);
                        ref.invalidate(categoriesFutureProvider);
                        ref.invalidate(filteredTransactionsStreamProvider);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      child: const Icon(Icons.delete_rounded, size: 20, color: Colors.red),
                    ),
            )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    String categoryType = 'Expense';
    String selectedHexColor = '#FF9800'; // Default Orange
    String selectedIcon = 'cart';

    final hexColors = ['#F44336', '#E91E63', '#9C27B0', '#673AB7', '#2196F3', '#00BCD4', '#009688', '#4CAF50', '#FFC107', '#FF9800', '#795548', '#607D8B'];
    final icons = ['cart', 'briefcase', 'store', 'bus', 'home', 'zap', 'phone', 'heart', 'book', 'film', 'coffee', 'send', 'piggy-bank'];

    ModernDialog.show(
      context: context,
      title: const Text('Add Custom Category'),
      titleIcon: Icons.category_rounded,
      content: StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g. Subscriptions, Laundry',
                  prefixIcon: Icon(Icons.edit_rounded, size: 18),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              ModernDropdown<String>(
                labelText: 'Category Type',
                value: categoryType,
                prefixIcon: Icons.unfold_more_rounded,
                items: const [
                  ModernDropdownItem(
                    value: 'Expense',
                    label: 'Expense',
                    icon: Icons.trending_down_rounded,
                    color: Color(0xFFFF453A),
                    subtitle: 'Money going out',
                  ),
                  ModernDropdownItem(
                    value: 'Income',
                    label: 'Income',
                    icon: Icons.trending_up_rounded,
                    color: Color(0xFF30D158),
                    subtitle: 'Money coming in',
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      categoryType = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              const Text('Select Theme Color', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 10),
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
              const SizedBox(height: 20),
              const Text('Select Icon', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 10),
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
          );
        },
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
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // iOS-style nav header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
                  ),
                ),
              ),

              // Privacy section
              IosListSection(
                rows: [
                  IosListRow(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.shield_rounded, color: theme.colorScheme.primary, size: 22),
                    ),
                    title: const Text('Offline Privacy'),
                    subtitle: const Text('All data stored locally. Zero cloud transfers.'),
                    indent: 48,
                  ),
                ],
              ),

              // System Management
              IosListSection(
                header: 'System Management',
                rows: [
                  IosListRow(
                    leading: Icon(Icons.account_balance_wallet_rounded, color: theme.colorScheme.primary, size: 24),
                    title: const Text('Accounts Manager'),
                    subtitle: const Text('Manage bank, mobile money & cash wallets'),
                    onTap: () => _showAccountsManager(context, ref),
                  ),
                  IosListRow(
                    leading: Icon(Icons.category_rounded, color: theme.colorScheme.primary, size: 24),
                    title: const Text('Categories Manager'),
                    subtitle: const Text('Add custom financial categories'),
                    onTap: () => _showCategoriesManager(context, ref),
                  ),
                ],
              ),

              // Data Management
              IosListSection(
                header: 'Data Management',
                rows: [
                  IosListRow(
                    leading: Icon(
                      Icons.file_download_rounded,
                      color: theme.brightness == Brightness.dark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF),
                      size: 24,
                    ),
                    title: const Text('Export to CSV'),
                    subtitle: const Text('Download transactions as CSV file'),
                    onTap: () => _handleExportCsv(context, ref),
                  ),
                  IosListRow(
                    leading: const Icon(Icons.backup_rounded, color: Colors.blue, size: 24),
                    title: const Text('Backup Database'),
                    subtitle: const Text('Save an offline backup of your data'),
                    onTap: () => _handleBackupDb(context, ref),
                  ),
                  IosListRow(
                    leading: const Icon(Icons.restore_rounded, color: Colors.orange, size: 24),
                    title: const Text('Restore Database'),
                    subtitle: const Text('Restore from a previous backup'),
                    onTap: () => _handleRestoreDb(context, ref),
                  ),
                ],
              ),

              // Preferences
              IosListSection(
                header: 'Preferences',
                rows: [
                  IosListRow(
                    leading: const Icon(Icons.translate_rounded, size: 24),
                    title: const Text('Interface Language'),
                    subtitle: const Text('English (only option in Phase 1)'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('English', style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  IosListRow(
                    leading: const Icon(Icons.dark_mode_rounded, size: 24),
                    title: const Text('Visual Display Mode'),
                    subtitle: const Text('Follows system theme (Light/Dark)'),
                    trailing: const Icon(Icons.brightness_medium_rounded, size: 20),
                  ),
                ],
              ),

              // Database Health
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 6, top: 24),
                child: Text(
                  'DATABASE HEALTH'.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: IosMetricCard(
                        icon: Icons.account_balance_rounded,
                        label: 'Accounts',
                        value: '${accounts.length}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: IosMetricCard(
                        icon: Icons.category_rounded,
                        label: 'Categories',
                        value: '${categories.length}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: IosMetricCard(
                        icon: Icons.receipt_long_rounded,
                        label: 'Transactions',
                        value: '${recentTransactions.length}',
                      ),
                    ),
                  ],
                ),
              ),

              // Footer
              const SizedBox(height: 36),
              Center(
                child: Column(
                  children: [
                    Text(
                      'PesaFlow v1.0.0',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.brightness == Brightness.dark ? Colors.grey[500] : Colors.grey[600]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Built Offline for privacy in Tanzania',
                      style: TextStyle(fontSize: 11, color: theme.brightness == Brightness.dark ? Colors.grey[600] : Colors.grey[400]),
                    ),
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
}
