import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/account_repository.dart';
import 'package:pesaflow/data/repositories/category_repository.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';
import 'package:pesaflow/presentation/common/ios/ios_list_section.dart';
import 'package:pesaflow/presentation/common/ios/ios_sheet.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dropdown.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/settings/widgets/export_dialog.dart';
import 'package:pesaflow/services/backup_service.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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
              leading: Icon(getAccountIcon(acc.icon), color: theme.colorScheme.primary),
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
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _showEditAccountDialog(context, ref, acc),
                    child: Icon(Icons.edit_rounded, size: 18, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _confirmDeleteAccount(context, ref, acc),
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

  void _showEditAccountDialog(BuildContext context, WidgetRef ref, Account acc) {
    final nameController = TextEditingController(text: acc.name);
    String accountType;
    switch (acc.type) {
      case 'mobile_money':
        accountType = 'Mobile Money';
        break;
      case 'bank':
        accountType = 'Bank';
        break;
      default:
        accountType = 'Cash';
    }
    String? phoneNumber = acc.phoneNumber;
    String? provider = acc.provider;
    final balanceController = TextEditingController(text: (acc.balance / 100).toStringAsFixed(0));

    ModernDialog.show(
      context: context,
      title: const Text('Edit Account'),
      titleIcon: Icons.edit_rounded,
      content: StatefulBuilder(
        builder: (context, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Account Name',
                  hintText: 'e.g. M-Pesa, Cash Wallet, NMB Savings',
                  prefixIcon: Icon(Icons.edit_rounded, size: 18),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              ModernDropdown<String>(
                labelText: 'Account Type',
                value: accountType,
                prefixIcon: Icons.wallet_rounded,
                items: const [
                  ModernDropdownItem(
                    value: 'Cash',
                    label: 'Cash Wallet',
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppTheme.transferColorDark,
                    subtitle: 'Physical cash and local wallets',
                  ),
                  ModernDropdownItem(
                    value: 'Mobile Money',
                    label: 'Mobile Money',
                    icon: Icons.phone_android_rounded,
                    color: Color(0xFF609F8A),
                    subtitle: 'M-Pesa, Tigo Pesa, Airtel Money, etc.',
                  ),
                  ModernDropdownItem(
                    value: 'Bank',
                    label: 'Bank Account',
                    icon: Icons.account_balance_rounded,
                    color: Color(0xFFFF9F0A),
                    subtitle: 'NMB, CRDB, NBC, and other banks',
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      accountType = val;
                      if (accountType == 'Mobile Money') {
                        provider = provider ?? 'M-Pesa_TZ';
                      } else if (accountType == 'Bank') {
                        provider = provider ?? 'NMB';
                      } else {
                        provider = null;
                      }
                    });
                  }
                },
              ),
              if (accountType == 'Mobile Money') ...[
                const SizedBox(height: 16),
                ModernDropdown<String>(
                  labelText: 'Carrier Provider',
                  value: provider ?? 'M-Pesa_TZ',
                  prefixIcon: Icons.phone_iphone_rounded,
                  items: const [
                    ModernDropdownItem(
                      value: 'M-Pesa_TZ',
                      label: 'Vodacom M-Pesa',
                      icon: Icons.offline_bolt_rounded,
                      color: Colors.redAccent,
                      subtitle: 'Vodacom Mobile Money service',
                    ),
                    ModernDropdownItem(
                      value: 'TigoPesa_TZ',
                      label: 'Tigo Pesa',
                      icon: Icons.offline_bolt_rounded,
                      color: Colors.blueAccent,
                      subtitle: 'Tigo Mobile Money service',
                    ),
                    ModernDropdownItem(
                      value: 'AirtelMoney_TZ',
                      label: 'Airtel Money',
                      icon: Icons.offline_bolt_rounded,
                      color: Colors.red,
                      subtitle: 'Airtel Mobile Money service',
                    ),
                    ModernDropdownItem(
                      value: 'Halopesa_TZ',
                      label: 'HaloPesa',
                      icon: Icons.offline_bolt_rounded,
                      color: Colors.orangeAccent,
                      subtitle: 'Halotel Mobile Money service',
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      provider = val;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'e.g. 076XXXXXXX',
                    prefixIcon: Icon(Icons.phone_rounded, size: 18),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                  ),
                  controller: TextEditingController(text: phoneNumber ?? ''),
                  onChanged: (val) {
                    phoneNumber = val;
                  },
                ),
              ],
              if (accountType == 'Bank') ...[
                const SizedBox(height: 16),
                ModernDropdown<String>(
                  labelText: 'Bank Brand',
                  value: provider ?? 'NMB',
                  prefixIcon: Icons.account_balance_rounded,
                  items: const [
                    ModernDropdownItem(
                      value: 'NMB',
                      label: 'NMB Bank',
                      icon: Icons.account_balance_rounded,
                      color: Colors.blue,
                      subtitle: 'National Microfinance Bank',
                    ),
                    ModernDropdownItem(
                      value: 'CRDB',
                      label: 'CRDB Bank',
                      icon: Icons.account_balance_rounded,
                      color: Colors.green,
                      subtitle: 'CRDB Bank Plc',
                    ),
                    ModernDropdownItem(
                      value: 'NBC',
                      label: 'NBC Bank',
                      icon: Icons.account_balance_rounded,
                      color: Colors.cyan,
                      subtitle: 'National Bank of Commerce',
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      provider = val;
                    });
                  },
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: balanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Balance (Tsh)',
                  hintText: 'e.g. 150,000',
                  prefixIcon: Icon(Icons.payments_rounded, size: 18),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).scaffoldBackgroundColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: () async {
            if (nameController.text.trim().isEmpty) return;

            String iconName = 'wallet';
            if (accountType == 'Mobile Money') {
              iconName = 'phone-android';
            } else if (accountType == 'Bank') {
              iconName = 'account-balance';
            }

            final type = accountType.toLowerCase().replaceAll(' ', '_');
            final rawAmount = balanceController.text;
            final cleanAmount = rawAmount.replaceAll(RegExp(r'[^0-9.]'), '');
            final parsedDouble = double.tryParse(cleanAmount) ?? (acc.balance / 100);
            final newBalance = (parsedDouble * 100).round();

            final updated = acc.copyWith(
              name: nameController.text.trim(),
              type: type,
              icon: iconName,
              balance: newBalance,
              provider: Value<String?>(provider),
              phoneNumber: Value<String?>(accountType == 'Mobile Money' ? phoneNumber : null),
            );

            try {
              await ref.read(accountRepositoryProvider).updateAccount(updated);
              ref.invalidate(accountsStreamProvider);
              ref.invalidate(netWorthProvider);
              if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to update account: $e')),
              );
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref, Account acc) {
    ModernDialog.show(
      context: context,
      title: const Text('Delete Account'),
      titleIcon: Icons.delete_rounded,
      iconColor: Colors.red,
      content: Text('Delete "${acc.name}" and all its transactions? This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () async {
            Navigator.of(context, rootNavigator: true).pop();
            try {
              await ref.read(accountRepositoryProvider).deleteAccount(acc.id);
              ref.invalidate(accountsStreamProvider);
              ref.invalidate(netWorthProvider);
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"${acc.name}" deleted')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete account: $e')),
                );
              }
            }
          },
          child: const Text('Delete'),
        ),
      ],
    );
  }

  void _showCategoriesManager(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesFutureProvider).value ?? [];
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
                  color: hexToColor(cat.color).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(getCategoryIcon(cat.icon), color: hexToColor(cat.color)),
              ),
              title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(cat.type.toUpperCase(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              trailing: cat.isSystem
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: const Text('System', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    )
                   : Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         GestureDetector(
                           onTap: () {
                             Navigator.of(context).pop();
                             _showAddCategoryDialog(context, ref, existing: cat);
                           },
                           child: const Icon(Icons.edit_rounded, size: 20, color: Colors.blue),
                         ),
                         const SizedBox(width: 12),
                         GestureDetector(
                           onTap: () async {
                             try {
                               await ref.read(categoryRepositoryProvider).deleteCategory(cat.id);
                               ref.invalidate(categoriesFutureProvider);
                               ref.invalidate(filteredTransactionsStreamProvider);
                               if (context.mounted) Navigator.of(context).pop();
                             } catch (e) {
                               if (context.mounted) {
                                 ScaffoldMessenger.of(context).showSnackBar(
                                   SnackBar(content: Text('Failed to delete category: $e')),
                                 );
                               }
                             }
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

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref, {Category? existing}) {
    final isEditing = existing != null;
    final nameController = TextEditingController(text: existing?.name ?? '');
    String categoryType = existing?.type == 'income' ? 'Income' : 'Expense';
    String selectedHexColor = existing?.color ?? '#FF9800';
    String selectedIcon = existing?.icon ?? 'cart';

    final hexColors = ['#F44336', '#E91E63', '#9C27B0', '#673AB7', '#2196F3', '#00BCD4', '#009688', '#4CAF50', '#FFC107', '#FF9800', '#795548', '#607D8B'];
    final icons = ['cart', 'briefcase', 'store', 'bus', 'home', 'zap', 'phone', 'heart', 'book', 'film', 'coffee', 'send', 'piggy-bank'];

    ModernDialog.show(
      context: context,
      title: Text(isEditing ? 'Edit Category' : 'Add Custom Category'),
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
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g. Subscriptions, Laundry',
                  prefixIcon: Icon(Icons.edit_rounded, size: 18),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
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
                    color: AppTheme.transferColorDark,
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
                        color: hexToColor(hex),
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
                        color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8.0),
                        border: isSelected ? Border.all(color: theme.colorScheme.primary, width: 1.5) : null,
                      ),
                      child: Icon(getCategoryIcon(icName), size: 24, color: isSelected ? theme.colorScheme.primary : Colors.grey),
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
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).scaffoldBackgroundColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: () async {
            if (nameController.text.trim().isEmpty) return;

            if (isEditing) {
              final updated = existing.copyWith(
                name: nameController.text.trim(),
                icon: selectedIcon,
                color: selectedHexColor,
                type: categoryType.toLowerCase(),
              );
              await ref.read(categoryRepositoryProvider).updateCategory(updated);
            } else {
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
            }
            ref.invalidate(categoriesFutureProvider);
            ref.invalidate(filteredTransactionsStreamProvider);
            if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
          },
          child: Text(isEditing ? 'Save' : 'Create'),
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
      ModernDialog.show(
        context: context,
        barrierDismissible: false,
        title: const Text('Profile Restored'),
        titleIcon: Icons.check_circle_rounded,
        iconColor: AppTheme.incomeColor,
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
    } catch (e) {
      if (context.mounted) {
        ModernDialog.show(
          context: context,
          title: const Text('Restore Failed'),
          titleIcon: Icons.error_outline_rounded,
          iconColor: Colors.red,
          content: Text(
            e is FormatException
                ? e.message
                : 'An unexpected error occurred during database restoration: $e',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      }
    }
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xF01C1C1E) : const Color(0xF0F2F2F7),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const Text('App Theme', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _themeOption(ctx, ref, ThemeMode.system, current, 'System default', Icons.settings_brightness_rounded, 'Follow your device settings'),
              _themeOption(ctx, ref, ThemeMode.light, current, 'Light', Icons.light_mode_rounded, 'Always use light mode'),
              _themeOption(ctx, ref, ThemeMode.dark, current, 'Dark', Icons.dark_mode_rounded, 'Always use dark mode'),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeOption(BuildContext ctx, WidgetRef ref, ThemeMode mode, ThemeMode current, String label, IconData icon, String subtitle) {
    final isSelected = mode == current;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          ref.read(themeModeProvider.notifier).setThemeMode(mode);
          Navigator.pop(ctx);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                : (Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.surfaceContainerDark : AppTheme.surfaceLight),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                  : (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0x1FFFFFFF) : const Color(0x1F000000)),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isSelected ? Theme.of(context).colorScheme.primary : null)),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.7) : Colors.grey)),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsStreamProvider).value ?? [];
    final categories = ref.watch(categoriesFutureProvider).value ?? [];
    final recentTransactions = ref.watch(recentTransactionsStreamProvider).value ?? [];

    return Scaffold(
      appBar: const IosNavBar(title: 'Settings', largeTitle: true),
      body: SafeArea(top: false, child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Privacy section
              StaggeredFadeSlide(
                index: 0,
                child: IosListSection(
                rows: [
                  IosListRow(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
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
              ),

              // System Management
              StaggeredFadeSlide(
                index: 5,
                child: IosListSection(
                header: 'System Management',
                rows: [
                  TactileSpringContainer(
                    onTap: () => _showAccountsManager(context, ref),
                    child: IosListRow(
                    leading: Icon(Icons.account_balance_wallet_rounded, color: theme.colorScheme.primary, size: 24),
                    title: const Text('Accounts Manager'),
                    subtitle: const Text('Manage bank, mobile money & cash wallets'),
                    onTap: () => _showAccountsManager(context, ref),
                  ),),
                  TactileSpringContainer(
                    onTap: () => _showCategoriesManager(context, ref),
                    child: IosListRow(
                    leading: Icon(Icons.category_rounded, color: theme.colorScheme.primary, size: 24),
                    title: const Text('Categories Manager'),
                    subtitle: const Text('Add custom financial categories'),
                    onTap: () => _showCategoriesManager(context, ref),
                  ),),
                ],
              ),
              ),

              // Data Export
              StaggeredFadeSlide(
                index: 8,
                child: IosListSection(
                header: 'Data Export',
                rows: [
                  TactileSpringContainer(
                    onTap: () => showExportDialog(context, ref),
                    child: IosListRow(
                    leading: Icon(
                      Icons.insert_drive_file_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    title: const Text('Export Monthly Statement'),
                    subtitle: const Text('Download as PDF or CSV'),
                    onTap: () => showExportDialog(context, ref),
                  ),),
                ],
              ),
              ),

              // Data Management
              StaggeredFadeSlide(
                index: 10,
                child: IosListSection(
                header: 'Data Management',
                rows: [
                  TactileSpringContainer(
                    onTap: () => _handleExportCsv(context, ref),
                    child: IosListRow(
                    leading: Icon(
                      Icons.file_download_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    title: const Text('Export to CSV'),
                    subtitle: const Text('Download transactions as CSV file'),
                    onTap: () => _handleExportCsv(context, ref),
                  ),),
                  TactileSpringContainer(
                    onTap: () => _handleBackupDb(context, ref),
                    child: IosListRow(
                    leading: const Icon(Icons.backup_rounded, color: Colors.blue, size: 24),
                    title: const Text('Backup Database'),
                    subtitle: const Text('Save an offline backup of your data'),
                    onTap: () => _handleBackupDb(context, ref),
                  ),),
                  TactileSpringContainer(
                    onTap: () => _handleRestoreDb(context, ref),
                    child: IosListRow(
                    leading: const Icon(Icons.restore_rounded, color: Colors.orange, size: 24),
                    title: const Text('Restore Database'),
                    subtitle: const Text('Restore from a previous backup'),
                    onTap: () => _handleRestoreDb(context, ref),
                  ),),
                ],
              ),
              ),

              // Preferences & Design Theme
              StaggeredFadeSlide(
                index: 15,
                child: IosListSection(
                header: 'Preferences & Theme',
                rows: [
                  IosToggleRow(
                    leading: Icon(Icons.pin_rounded, color: theme.colorScheme.primary, size: 24),
                    title: const Text('Show Decimals'),
                    subtitle: const Text('Format currency with cents (.00) globally'),
                    value: ref.watch(currencyShowDecimalsProvider).value ?? false,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      ref.read(settingsRepositoryProvider).setSetting('currency_show_decimals', val.toString());
                    },
                  ),
                  IosToggleRow(
                    leading: Icon(Icons.fingerprint_rounded, color: theme.colorScheme.primary, size: 24),
                    title: const Text('Biometric App Lock'),
                    subtitle: const Text('Require biometrics to open PesaFlow'),
                    value: ref.watch(appLockEnabledProvider).value ?? false,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      ref.read(settingsRepositoryProvider).setSetting('app_lock_enabled', val.toString());
                    },
                  ),
                  IosToggleRow(
                    leading: Icon(Icons.sms_rounded, color: theme.colorScheme.primary, size: 24),
                    title: const Text('SMS Auto-Deduplication'),
                    subtitle: const Text('Automatically deduplicate incoming telco messages'),
                    value: ref.watch(smsAutoDeduplicationProvider).value ?? false,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      ref.read(settingsRepositoryProvider).setSetting('sms_auto_deduplication', val.toString());
                    },
                  ),
                  IosListRow(
                    leading: Icon(Icons.brightness_6_rounded, color: theme.colorScheme.primary, size: 24),
                    title: const Text('App Theme'),
                    subtitle: Text(switch (ref.watch(themeModeProvider)) {
                      ThemeMode.light => 'Light',
                      ThemeMode.dark => 'Dark',
                      _ => 'System default',
                    }),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                    onTap: () => _showThemePicker(context, ref),
                  ),
                ],
              ),
              ),

              // Database Health
              StaggeredFadeSlide(
                index: 20,
                child: Column(
                  children: [
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



