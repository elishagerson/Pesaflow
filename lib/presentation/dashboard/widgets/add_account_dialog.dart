import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/account_repository.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dropdown.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

void showAddAccountDialog(BuildContext context, WidgetRef ref) {
  final nameController = TextEditingController();
  String accountType = 'Cash';
  final balanceController = TextEditingController();
  String? phoneNumber;
  String? provider;

  ModernDialog.show(
    context: context,
    title: const Text('Add Account'),
    titleIcon: PesaFlowIcons.wallet,
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
                prefixIcon: Icon(PesaFlowIcons.edit, size: 18),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1C1C1E)
                    : const Color(0xFFF2F2F7),
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
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: kSpacing16),
            ModernDropdown<String>(
              labelText: 'Account Type',
              value: accountType,
              prefixIcon: Icons.wallet_rounded,
              items: const [
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
                  color: Color(0xFF609F8A),
                  subtitle: 'M-Pesa, Tigo Pesa, Airtel Money, etc.',
                ),
                ModernDropdownItem(
                  value: 'Bank',
                  label: 'Bank Account',
                  icon: PesaFlowIcons.loans,
                  color: Color(0xFFFF9F0A),
                  subtitle: 'NMB, CRDB, NBC, and other banks',
                ),
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
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'e.g. 076XXXXXXX',
                  prefixIcon: Icon(Icons.phone_rounded, size: 18),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1C1C1E)
                      : const Color(0xFFF2F2F7),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                ),
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
                items: const [
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
              decoration: InputDecoration(
                labelText: 'Initial Balance (Tsh)',
                hintText: 'e.g. 150,000',
                prefixIcon: Icon(PesaFlowIcons.cash, size: 18),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1C1C1E)
                    : const Color(0xFFF2F2F7),
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
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.5),
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

          try {
            await ref.read(accountRepositoryProvider).createAccount(newAccount);

            ref.invalidate(accountsStreamProvider);

            if (context.mounted) {
              Navigator.of(context, rootNavigator: true).pop();
            }
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to create account: $e')),
            );
          }
        },
        child: const Text('Create'),
      ),
    ],
  );
}
