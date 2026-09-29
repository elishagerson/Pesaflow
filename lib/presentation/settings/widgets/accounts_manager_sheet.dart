import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/presentation/common/widgets/motion/haptic_pattern.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/provider_brand_colors.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/database_providers.dart';
import 'package:pesaflow/data/repositories/account_repository.dart';
import 'package:pesaflow/presentation/common/ios/ios_list_section.dart';
import 'package:pesaflow/presentation/common/ios/ios_sheet.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dropdown.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/undo_delete.dart';
import 'package:pesaflow/presentation/dashboard/widgets/add_account_dialog.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

/// Opens the Accounts Manager bottom sheet.
void showAccountsManager(BuildContext context, WidgetRef ref) {
  final theme = Theme.of(context);
  IosBottomSheet.show(
    context: context,
    initialChildSize: 0.6,
    maxChildSize: 0.9,
    child: Consumer(
      builder: (context, ref, _) {
        final accounts = ref.watch(accountsStreamProvider).value ?? [];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: kSpacing20,
                right: kSpacing16,
                top: kSpacing16,
                bottom: kSpacing12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Manage Accounts',
                    style: context.ts(22, fontWeight: FontWeight.bold),
                  ),
                  TactileSpringContainer(
                    haptic: HapticType.soft,
                    onTap: () {
                      showAddAccountDialog(context, ref);
                    },
                    selectedColor: theme.colorScheme.onSurface,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusPill,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PesaFlowIcons.add,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: kSpacing4),
                          Text(
                            'Add',
                            style: context.ts(
                              14,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
              IosListSection(
                rows: accounts
                    .map(
                      (acc) => IosListRow(
                        leading: Container(
                          padding: const EdgeInsets.all(kSpacing8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusCompact,
                            ),
                          ),
                          child: Icon(
                            getAccountIcon(acc.icon),
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          acc.name,
                          style: context.ts(15, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          acc.type.toUpperCase().replaceAll('_', ' ') +
                              (acc.phoneNumber != null
                                  ? ' • ${acc.phoneNumber}'
                                  : ''),
                          style: context.ts(
                            12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AmountText(
                              amountInCents: acc.balance,
                              style: context.ts(
                                15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: kSpacing8),
                            TactileSpringContainer(
                              onTap: () =>
                                  _showEditAccountDialog(context, ref, acc),
                              selectedColor: theme.colorScheme.onSurface,
                              child: Container(
                                padding: const EdgeInsets.all(kSpacing6),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.squircleRadius(28),
                                  ),
                                ),
                                child: Icon(
                                  PesaFlowIcons.edit,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: kSpacing6),
                            TactileSpringContainer(
                              onTap: () =>
                                  _confirmDeleteAccount(context, ref, acc),
                              selectedColor: theme.colorScheme.onSurface,
                              child: Container(
                                padding: const EdgeInsets.all(kSpacing6),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.error.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.squircleRadius(28),
                                  ),
                                ),
                                child: Icon(
                                  PesaFlowIcons.delete,
                                  size: 16,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: kSpacing24),
          ],
        );
      },
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
  String? provider = acc.provider;
  final phoneController = TextEditingController(text: acc.phoneNumber ?? '');
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
              prefixIcon: PesaFlowIcons.wallet,
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
                items: [
                  ModernDropdownItem(
                    value: 'M-Pesa_TZ',
                    label: 'Vodacom M-Pesa',
                    icon: PesaFlowIcons.offline,
                    color: kProviderBrandColors['M-Pesa_TZ']!,
                    subtitle: 'Vodacom Mobile Money service',
                  ),
                  ModernDropdownItem(
                    value: 'TigoPesa_TZ',
                    label: 'Tigo Pesa',
                    icon: PesaFlowIcons.offline,
                    color: kProviderBrandColors['TigoPesa_TZ']!,
                    subtitle: 'Tigo Mobile Money service',
                  ),
                  ModernDropdownItem(
                    value: 'AirtelMoney_TZ',
                    label: 'Airtel Money',
                    icon: PesaFlowIcons.offline,
                    color: kProviderBrandColors['AirtelMoney_TZ']!,
                    subtitle: 'Airtel Mobile Money service',
                  ),
                  ModernDropdownItem(
                    value: 'Halopesa_TZ',
                    label: 'HaloPesa',
                    icon: PesaFlowIcons.offline,
                    color: kProviderBrandColors['Halopesa_TZ']!,
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
                controller: phoneController,
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
                    color: kProviderBrandColors['NMB']!,
                    subtitle: 'National Microfinance Bank',
                  ),
                  ModernDropdownItem(
                    value: 'CRDB',
                    label: 'CRDB Bank',
                    icon: PesaFlowIcons.loans,
                    color: kProviderBrandColors['CRDB']!,
                    subtitle: 'CRDB Bank Plc',
                  ),
                  ModernDropdownItem(
                    value: 'NBC',
                    label: 'NBC Bank',
                    icon: PesaFlowIcons.loans,
                    color: kProviderBrandColors['NBC']!,
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
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
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
              accountType == 'Mobile Money'
                  ? phoneController.text.trim().isEmpty
                        ? null
                        : phoneController.text.trim()
                  : null,
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
          foregroundColor: theme.colorScheme.onError,
        ),
        onPressed: () async {
          Navigator.of(context, rootNavigator: true).pop();
          final backupTxs = await ref
              .read(transactionDaoProvider)
              .getFilteredTransactions(accountId: acc.id);
          final destTxs =
              await (ref
                      .read(databaseProvider)
                      .select(ref.read(databaseProvider).transactions)
                    ..where((t) => t.destinationAccountId.equals(acc.id)))
                  .get();
          final allBackup = [
            ...backupTxs.map((e) => e.transaction),
            ...destTxs,
          ];
          try {
            await ref.read(accountRepositoryProvider).deleteAccount(acc.id);
            PesaHaptics.medium();
            if (context.mounted) context.pop();
          } catch (e) {
            if (context.mounted) {
              CustomToast.show(
                context,
                message: 'Failed to delete account: $e',
                type: ToastType.error,
              );
            }
            return;
          }
          if (!context.mounted) return;
          UndoDelete.show(
            context: context,
            entityName: 'Account',
            message: '"${acc.name}" deleted',
            onUndo: () async {
              try {
                await ref.read(accountRepositoryProvider).createAccount(acc);
                for (final tx in allBackup) {
                  await ref
                      .read(transactionDaoProvider)
                      .writeTransactionWithBalanceAdjustment(tx);
                }
                PesaHaptics.light();
              } catch (_) {}
            },
            onDelete: () async {},
          );
        },
        child: const Text('Delete'),
      ),
    ],
  );
}
