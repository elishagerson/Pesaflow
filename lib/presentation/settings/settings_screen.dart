import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/account_repository.dart';
import 'package:pesaflow/data/repositories/category_repository.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/ios/ios_list_section.dart';
import 'package:pesaflow/presentation/common/ios/ios_sheet.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dropdown.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/presentation/common/widgets/spring_sheet_route.dart';
import 'package:pesaflow/presentation/settings/widgets/export_dialog.dart';
import 'package:pesaflow/presentation/settings/widgets/import_dialog.dart';

import 'package:pesaflow/services/backup_service.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/add_category_dialog.dart';

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
          Padding(
            padding: EdgeInsets.symmetric(vertical: kSpacing16),
            child: Text(
              'Manage Accounts',
              style: context.ts(22, fontWeight: FontWeight.bold),
            ),
          ),
          if (accounts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(kSpacing32),
                child: Text('No active accounts.'),
              ),
            )
          else
            ...accounts.map(
              (acc) => IosListRow(
                leading: Icon(
                  getAccountIcon(acc.icon),
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  acc.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  acc.type.toUpperCase().replaceAll('_', ' ') +
                      (acc.phoneNumber != null ? ' • ${acc.phoneNumber}' : ''),
                  style: theme.textTheme.labelMedium!,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AmountText(
                      amountInCents: acc.balance,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: kSpacing4),
                    GestureDetector(
                      onTap: () => _showEditAccountDialog(context, ref, acc),
                      child: Icon(
                        PesaFlowIcons.edit,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: kSpacing4),
                    GestureDetector(
                      onTap: () => _confirmDeleteAccount(context, ref, acc),
                      child: Icon(
                        PesaFlowIcons.delete,
                        size: 20,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: kSpacing24),
        ],
      ),
    );
  }

  void _showEditAccountDialog(
    BuildContext context,
    WidgetRef ref,
    Account acc,
  ) {
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
    final balanceController = TextEditingController(
      text: (acc.balance / 100).toStringAsFixed(0),
    );

    ModernDialog.show(
      context: context,
      title: const Text('Edit Account'),
      titleIcon: PesaFlowIcons.edit,
      content: StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: context.inputDecoration(
                  labelText: 'Account Name',
                  hintText: 'e.g. M-Pesa, Cash Wallet, NMB Savings',
                  prefixIcon: Icon(PesaFlowIcons.edit, size: 18),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: kSpacing16),
              ModernDropdown<String>(
                labelText: 'Account Type',
                value: accountType,
                prefixIcon: Icons.wallet_rounded,
                items: [
                  ModernDropdownItem(
                    value: 'Cash',
                    label: 'Cash Wallet',
                    icon: PesaFlowIcons.wallet,
                    color: AppTheme.transferColorDark,
                    subtitle: 'Physical cash and local wallets',
                  ),
                  ModernDropdownItem(
                    value: 'Mobile Money',
                    label: 'Mobile Money',
                    icon: PesaFlowIcons.cash,
                    color: theme.colorScheme.primary,
                    subtitle: 'M-Pesa, Tigo Pesa, Airtel Money, etc.',
                  ),
                  ModernDropdownItem(
                    value: 'Bank',
                    label: 'Bank Account',
                    icon: PesaFlowIcons.loans,
                    color: context.appColors.transferColor,
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
                const SizedBox(height: kSpacing16),
                ModernDropdown<String>(
                  labelText: 'Carrier Provider',
                  value: provider ?? 'M-Pesa_TZ',
                  prefixIcon: PesaFlowIcons.cash,
                  items: const [
                    ModernDropdownItem(
                      value: 'M-Pesa_TZ',
                      label: 'Vodacom M-Pesa',
                      icon: PesaFlowIcons.offline,
                      color: Colors.redAccent,
                      subtitle: 'Vodacom Mobile Money service',
                    ),
                    ModernDropdownItem(
                      value: 'TigoPesa_TZ',
                      label: 'Tigo Pesa',
                      icon: PesaFlowIcons.offline,
                      color: Colors.blueAccent,
                      subtitle: 'Tigo Mobile Money service',
                    ),
                    ModernDropdownItem(
                      value: 'AirtelMoney_TZ',
                      label: 'Airtel Money',
                      icon: PesaFlowIcons.offline,
                      color: Colors.red,
                      subtitle: 'Airtel Mobile Money service',
                    ),
                    ModernDropdownItem(
                      value: 'Halopesa_TZ',
                      label: 'HaloPesa',
                      icon: PesaFlowIcons.offline,
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
                const SizedBox(height: kSpacing16),
                TextField(
                  keyboardType: TextInputType.phone,
                  decoration: context.inputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'e.g. 076XXXXXXX',
                    prefixIcon: const Icon(PesaFlowIcons.phone, size: 18),
                  ),
                  controller: TextEditingController(text: phoneNumber ?? ''),
                  onChanged: (val) {
                    phoneNumber = val;
                  },
                ),
              ],
              if (accountType == 'Bank') ...[
                const SizedBox(height: kSpacing16),
                ModernDropdown<String>(
                  labelText: 'Bank Brand',
                  value: provider ?? 'NMB',
                  prefixIcon: PesaFlowIcons.loans,
                  items: [
                    ModernDropdownItem(
                      value: 'NMB',
                      label: 'NMB Bank',
                      icon: PesaFlowIcons.loans,
                      color: Colors.blue,
                      subtitle: 'National Microfinance Bank',
                    ),
                    ModernDropdownItem(
                      value: 'CRDB',
                      label: 'CRDB Bank',
                      icon: PesaFlowIcons.loans,
                      color: Colors.green,
                      subtitle: 'CRDB Bank Plc',
                    ),
                    ModernDropdownItem(
                      value: 'NBC',
                      label: 'NBC Bank',
                      icon: PesaFlowIcons.loans,
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
              const SizedBox(height: kSpacing16),
              TextField(
                controller: balanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: context.inputDecoration(
                  labelText: 'Balance (Tsh)',
                  hintText: 'e.g. 150,000',
                  prefixIcon: Icon(PesaFlowIcons.cash, size: 18),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: kSpacing20,
              vertical: kSpacing12,
            ),
          ),
          onPressed: () async {
            if (nameController.text.trim().isEmpty) {
              return;
            }

            String iconName = 'wallet';
            if (accountType == 'Mobile Money') {
              iconName = 'phone-android';
            } else if (accountType == 'Bank') {
              iconName = 'account-balance';
            }

            final type = accountType.toLowerCase().replaceAll(' ', '_');
            final rawAmount = balanceController.text;
            final cleanAmount = rawAmount.replaceAll(RegExp(r'[^0-9.]'), '');
            final parsedDouble =
                double.tryParse(cleanAmount) ?? (acc.balance / 100);
            final newBalance = (parsedDouble * 100).round();

            final updated = acc.copyWith(
              name: nameController.text.trim(),
              type: type,
              icon: iconName,
              balance: newBalance,
              provider: Value<String?>(provider),
              phoneNumber: Value<String?>(
                accountType == 'Mobile Money' ? phoneNumber : null,
              ),
            );

            try {
              await ref.read(accountRepositoryProvider).updateAccount(updated);
              ref.invalidate(accountsStreamProvider);
              ref.invalidate(netWorthProvider);
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pop();
              }
            } catch (e) {
              if (!context.mounted) return;
              CustomToast.show(
                context,
                message: 'Failed to update account: $e',
                type: ToastType.error,
              );
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref, Account acc) {
    final theme = Theme.of(context);
    ModernDialog.show(
      context: context,
      title: const Text('Delete Account'),
      titleIcon: PesaFlowIcons.delete,
      iconColor: theme.colorScheme.error,
      content: Text(
        'Delete "${acc.name}" and all its transactions? This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            Navigator.of(context, rootNavigator: true).pop();
            try {
              await ref.read(accountRepositoryProvider).deleteAccount(acc.id);
              ref.invalidate(accountsStreamProvider);
              ref.invalidate(netWorthProvider);
              if (context.mounted) {
                Navigator.of(context).pop();
                CustomToast.show(
                  context,
                  message: '"${acc.name}" deleted',
                  type: ToastType.info,
                );
              }
            } catch (e) {
              if (context.mounted) {
                CustomToast.show(
                  context,
                  message: 'Failed to delete account: $e',
                  type: ToastType.error,
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
    final theme = Theme.of(context);
    IosBottomSheet.show(
      context: context,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: kSpacing16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Manage Categories',
                  style: context.ts(22, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  icon: const Icon(PesaFlowIcons.add),
                  label: const Text('Add Custom'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    showAddCategoryDialog(context, ref);
                  },
                ),
              ],
            ),
          ),
          if (categories.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(kSpacing32),
                child: Text('No categories seeded.'),
              ),
            )
          else
            ...categories.map(
              (cat) => IosListRow(
                leading: Container(
                  padding: const EdgeInsets.all(kSpacing8),
                  decoration: BoxDecoration(
                    color: hexToColor(cat.color).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    getCategoryIcon(cat.icon),
                    color: hexToColor(cat.color),
                  ),
                ),
                title: Text(
                  cat.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  cat.type.toUpperCase(),
                  style: context.ts(11, color: context.appColors.textMedium),
                ),
                trailing: cat.isSystem
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kSpacing8,
                          vertical: kSpacing2,
                        ),
                        decoration: BoxDecoration(
                          color: context.appColors.textMedium.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          'System',
                          style: theme
                              .extension<AppTypographyTheme>()!
                              .labelMicro
                              .copyWith(color: context.appColors.textMedium),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                              showAddCategoryDialog(
                                context,
                                ref,
                                existing: cat,
                              );
                            },
                            child: Icon(
                              PesaFlowIcons.edit,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: kSpacing12),
                          GestureDetector(
                            onTap: () async {
                              try {
                                await ref
                                    .read(categoryRepositoryProvider)
                                    .deleteCategory(cat.id);
                                ref.invalidate(categoriesFutureProvider);
                                ref.invalidate(
                                  filteredTransactionsStreamProvider,
                                );
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  CustomToast.show(
                                    context,
                                    message: 'Failed to delete category: $e',
                                    type: ToastType.error,
                                  );
                                }
                              }
                            },
                            child: Icon(
                              PesaFlowIcons.delete,
                              size: 20,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          const SizedBox(height: kSpacing24),
        ],
      ),
    );
  }

  Future<void> _handleExportCsv(BuildContext context, WidgetRef ref) async {
    try {
      CustomToast.show(
        context,
        message: 'Generating CSV export...',
        type: ToastType.info,
      );
      await ref.read(backupServiceProvider).exportTransactionsToCsv();
    } catch (e) {
      if (context.mounted) {
        CustomToast.show(
          context,
          message: 'Failed to export CSV: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _handleImportCsv(BuildContext context, WidgetRef ref) async {
    final accounts = ref.read(accountsStreamProvider).value ?? [];
    final categories = await ref
        .read(categoryRepositoryProvider)
        .getAllCategories();

    if (!context.mounted) return;

    final result = await showImportCsvDialog(
      context,
      accounts: accounts,
      categories: categories,
    );

    if (result == null || !context.mounted) return;

    final repo = ref.read(transactionRepositoryProvider);
    var imported = 0;

    for (final tx in result.transactions) {
      try {
        final resolvedTx = tx.accountId == null && result.accountId != null
            ? Transaction(
                id: tx.id,
                accountId: result.accountId,
                categoryId: tx.categoryId,
                amount: tx.amount,
                type: tx.type,
                description: tx.description,
                reference: tx.reference,
                sender: tx.sender,
                recipient: tx.recipient,
                source: tx.source,
                createdAt: tx.createdAt,
                updatedAt: tx.updatedAt,
              )
            : tx;

        await repo.createTransactionNoBalanceAdjustment(resolvedTx);
        imported++;
      } catch (_) {
        // Skip duplicates or invalid rows
      }
    }

    if (context.mounted) {
      CustomToast.show(
        context,
        message: 'Imported $imported transactions',
        type: ToastType.success,
      );
    }
  }

  Future<void> _handleBackupDb(BuildContext context, WidgetRef ref) async {
    try {
      CustomToast.show(
        context,
        message: 'Creating local backup...',
        type: ToastType.info,
      );
      await ref.read(backupServiceProvider).backupDatabase();
    } catch (e) {
      if (context.mounted) {
        CustomToast.show(
          context,
          message: 'Backup failed: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _handleRestoreDb(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    try {
      final success = await ref.read(backupServiceProvider).restoreDatabase();
      if (!success || !context.mounted) return;

      // Show relaunch alert dialog
      ModernDialog.show(
        context: context,
        barrierDismissible: false,
        title: const Text('Profile Restored'),
        titleIcon: PesaFlowIcons.success,
        iconColor: context.appColors.incomeColor,
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
          titleIcon: PesaFlowIcons.error,
          iconColor: theme.colorScheme.error,
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
    showSpringSheet(
      context,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: kSpacing24,
            horizontal: kSpacing20,
          ),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.94),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: kSpacing20),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              Text(
                'App Theme',
                style: context.ts(22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: kSpacing16),
              _themeOption(
                ctx,
                ref,
                ThemeMode.system,
                current,
                'System default',
                PesaFlowIcons.themeMode,
                'Follow your device settings',
              ),
              _themeOption(
                ctx,
                ref,
                ThemeMode.light,
                current,
                'Light',
                PesaFlowIcons.lightMode,
                'Always use light mode',
              ),
              _themeOption(
                ctx,
                ref,
                ThemeMode.dark,
                current,
                'Dark',
                PesaFlowIcons.darkMode,
                'Always use dark mode',
              ),
              const SizedBox(height: kSpacing12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeOption(
    BuildContext ctx,
    WidgetRef ref,
    ThemeMode mode,
    ThemeMode current,
    String label,
    IconData icon,
    String subtitle,
  ) {
    final isSelected = mode == current;
    final theme = Theme.of(ctx);
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpacing8),
      child: GestureDetector(
        onTap: () {
          ref.read(themeModeProvider.notifier).setThemeMode(mode);
          Navigator.pop(ctx);
        },
        child: Container(
          padding: const EdgeInsets.all(kSpacing16),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                : (theme.brightness == Brightness.dark
                      ? AppTheme.surfaceContainerDark
                      : AppTheme.surfaceLight),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.3)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(kSpacing10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                      : ctx.appColors.textMedium.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : ctx.appColors.textMedium,
                  size: 20,
                ),
              ),
              const SizedBox(width: kSpacing14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: ctx.ts(
                        14,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? theme.colorScheme.primary : null,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: ctx.ts(
                        11,
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.7)
                            : ctx.appColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  PesaFlowIcons.success,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
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
    final recentTransactions =
        ref.watch(recentTransactionsStreamProvider).value ?? [];

    return Scaffold(
      appBar: const IosNavBar(title: 'Settings', largeTitle: true),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: kSpacing16),

              // Privacy section
              StaggeredFadeSlide(
                index: 0,
                child: IosListSection(
                  rows: [
                    IosListRow(
                      leading: Container(
                        padding: const EdgeInsets.all(kSpacing8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          PesaFlowIcons.security,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      title: const Text('Offline Privacy'),
                      subtitle: const Text(
                        'All data stored locally. Zero cloud transfers.',
                      ),
                      indent: 48,
                    ),
                  ],
                ),
              ),

              // Security
              StaggeredFadeSlide(
                index: 1,
                child: IosListSection(
                  header: 'Security',
                  rows: [
                    IosToggleRow(
                      leading: Icon(
                        PesaFlowIcons.biometric,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                      title: const Text('Biometric App Lock'),
                      subtitle: const Text(
                        'Require biometrics to open PesaFlow',
                      ),
                      value: ref.watch(appLockEnabledProvider).value ?? false,
                      onChanged: (val) {
                        HapticFeedback.lightImpact();
                        ref
                            .read(settingsRepositoryProvider)
                            .setSetting('app_lock_enabled', val.toString());
                      },
                    ),
                    IosToggleRow(
                      leading: Icon(
                        PesaFlowIcons.unlock,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                      title: const Text('Lock Screen Balance'),
                      subtitle: const Text(
                        'Show current balance in notification shade',
                      ),
                      value:
                          ref.watch(lockScreenBalanceEnabledProvider).value ??
                          false,
                      onChanged: (val) {
                        HapticFeedback.lightImpact();
                        ref
                            .read(settingsRepositoryProvider)
                            .setSetting('lock_screen_balance', val.toString());
                      },
                    ),
                  ],
                ),
              ),

              // Preferences
              StaggeredFadeSlide(
                index: 2,
                child: IosListSection(
                  header: 'Preferences',
                  rows: [
                    IosToggleRow(
                      leading: Icon(
                        PesaFlowIcons.pin,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                      title: const Text('Show Decimals'),
                      subtitle: const Text(
                        'Format currency with cents (.00) globally',
                      ),
                      value:
                          ref.watch(currencyShowDecimalsProvider).value ??
                          false,
                      onChanged: (val) {
                        HapticFeedback.lightImpact();
                        ref
                            .read(settingsRepositoryProvider)
                            .setSetting(
                              'currency_show_decimals',
                              val.toString(),
                            );
                      },
                    ),
                    IosToggleRow(
                      leading: Icon(
                        PesaFlowIcons.sms,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                      title: const Text('SMS Auto-Deduplication'),
                      subtitle: const Text(
                        'Automatically deduplicate incoming telco messages',
                      ),
                      value:
                          ref.watch(smsAutoDeduplicationProvider).value ??
                          false,
                      onChanged: (val) {
                        HapticFeedback.lightImpact();
                        ref
                            .read(settingsRepositoryProvider)
                            .setSetting(
                              'sms_auto_deduplication',
                              val.toString(),
                            );
                      },
                    ),
                    IosListRow(
                      leading: Icon(
                        PesaFlowIcons.themeMode,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                      title: const Text('App Theme'),
                      subtitle: Text(switch (ref.watch(themeModeProvider)) {
                        ThemeMode.light => 'Light',
                        ThemeMode.dark => 'Dark',
                        _ => 'System default',
                      }),
                      trailing: Icon(
                        PesaFlowIcons.chevronRight,
                        size: 18,
                        color: context.appColors.textMedium,
                      ),
                      onTap: () => _showThemePicker(context, ref),
                    ),
                  ],
                ),
              ),

              // Data
              StaggeredFadeSlide(
                index: 3,
                child: IosListSection(
                  header: 'Data',
                  rows: [
                    TactileSpringContainer(
                      onTap: () => _showAccountsManager(context, ref),
                      child: IosListRow(
                        leading: Icon(
                          PesaFlowIcons.wallet,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        title: const Text('Accounts Manager'),
                        subtitle: const Text(
                          'Manage bank, mobile money & cash wallets',
                        ),
                        onTap: () => _showAccountsManager(context, ref),
                      ),
                    ),
                    TactileSpringContainer(
                      onTap: () => _showCategoriesManager(context, ref),
                      child: IosListRow(
                        leading: Icon(
                          Icons.category_rounded,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        title: const Text('Categories Manager'),
                        subtitle: const Text('Add custom financial categories'),
                        onTap: () => _showCategoriesManager(context, ref),
                      ),
                    ),
                    TactileSpringContainer(
                      onTap: () => context.push('/recurring'),
                      child: IosListRow(
                        leading: Icon(
                          PesaFlowIcons.subscriptions,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        title: const Text('Recurring & Bills'),
                        subtitle: const Text(
                          'Manage your recurring payments and bills',
                        ),
                        onTap: () => context.push('/recurring'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: IosMetricCard(
                              icon: PesaFlowIcons.loans,
                              label: 'Accounts',
                              value: '${accounts.length}',
                            ),
                          ),
                          const SizedBox(width: kSpacing8),
                          Expanded(
                            child: IosMetricCard(
                              icon: PesaFlowIcons.category,
                              label: 'Categories',
                              value: '${categories.length}',
                            ),
                          ),
                          const SizedBox(width: kSpacing8),
                          Expanded(
                            child: IosMetricCard(
                              icon: PesaFlowIcons.transactions,
                              label: 'Transactions',
                              value: '${recentTransactions.length}',
                            ),
                          ),
                        ],
                      ),
                    ),
                    TactileSpringContainer(
                      onTap: () => showExportDialog(context, ref),
                      child: IosListRow(
                        leading: Icon(
                          PesaFlowIcons.file,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        title: const Text('Export Monthly Statement'),
                        subtitle: const Text('Download as PDF or CSV'),
                        onTap: () => showExportDialog(context, ref),
                      ),
                    ),
                    TactileSpringContainer(
                      onTap: () => _handleExportCsv(context, ref),
                      child: IosListRow(
                        leading: Icon(
                          PesaFlowIcons.download,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        title: const Text('Export to CSV'),
                        subtitle: const Text(
                          'Download transactions as CSV file',
                        ),
                        onTap: () => _handleExportCsv(context, ref),
                      ),
                    ),
                    TactileSpringContainer(
                      onTap: () => _handleImportCsv(context, ref),
                      child: IosListRow(
                        leading: Icon(
                          PesaFlowIcons.upload,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        title: const Text('Import CSV'),
                        subtitle: const Text(
                          'Import transactions from CSV file',
                        ),
                        onTap: () => _handleImportCsv(context, ref),
                      ),
                    ),
                    TactileSpringContainer(
                      onTap: () => _handleBackupDb(context, ref),
                      child: IosListRow(
                        leading: const Icon(
                          PesaFlowIcons.backup,
                          color: Colors.blue,
                          size: 24,
                        ),
                        title: const Text('Backup Database'),
                        subtitle: const Text(
                          'Save an offline backup of your data',
                        ),
                        onTap: () => _handleBackupDb(context, ref),
                      ),
                    ),
                    TactileSpringContainer(
                      onTap: () => _handleRestoreDb(context, ref),
                      child: IosListRow(
                        leading: const Icon(
                          PesaFlowIcons.restore,
                          color: Colors.orange,
                          size: 24,
                        ),
                        title: const Text('Restore Database'),
                        subtitle: const Text('Restore from a previous backup'),
                        onTap: () => _handleRestoreDb(context, ref),
                      ),
                    ),
                  ],
                ),
              ),

              // Footer
              const SizedBox(height: kSpacing40),
              Center(
                child: Column(
                  children: [
                    Text(
                      'PesaFlow v1.0.0',
                      style: context.ts(
                        12,
                        fontWeight: FontWeight.bold,
                        color: theme.brightness == Brightness.dark
                            ? context.appColors.textMedium
                            : context.appColors.textMedium,
                      ),
                    ),
                    const SizedBox(height: kSpacing2),
                    Text(
                      'Built Offline for privacy in Tanzania',
                      style: context.ts(
                        11,
                        color: theme.brightness == Brightness.dark
                            ? context.appColors.textLow
                            : context.appColors.textLow,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: kSpacing24),
            ],
          ),
        ),
      ),
    );
  }
}
