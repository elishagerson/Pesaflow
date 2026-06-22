import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:flutter/services.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;
  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final itemAsync = ref.watch(transactionDetailProvider(transactionId));

    return Scaffold(
      appBar: IosNavBar(
        title: 'Transaction',
        largeTitle: false,
        actions: [
          TactileSpringContainer(
            onTap: () => context.go('/transactions/edit/$transactionId'),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.edit_rounded, size: 18, color: isDark ? Colors.white : Colors.black),
            ),
          ),
          const SizedBox(width: 8),
          TactileSpringContainer(
            onTap: () => _confirmDelete(context, ref),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF453A).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_rounded, size: 18, color: Color(0xFFFF453A)),
            ),
          ),
        ],
      ),
      body: itemAsync.when(
        data: (item) {
          if (item == null) {
            return const Center(child: Text('Transaction not found'));
          }
          return _buildDetail(context, theme, isDark, item);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildDetail(BuildContext context, ThemeData theme, bool isDark, TransactionWithCategoryAndAccount item) {
    final t = item.transaction;
    final cat = item.category;
    final acc = item.account;
    final catColor = hexToColor(cat.color);
    final isIncome = t.type == 'income';
    final amountColor = isIncome ? const Color(0xFF609F8A) : const Color(0xFFFF453A);

    final hasExtraDetails = (t.reference != null && t.reference!.isNotEmpty) ||
        (t.sender != null && t.sender!.isNotEmpty) ||
        (t.recipient != null && t.recipient!.isNotEmpty) ||
        (t.balanceAfter != null);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Amount Hero
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
            borderRadius: AppTheme.radiusCard,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: isDark ? 0.15 : 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: catColor.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: catColor.withValues(alpha: 0.2),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    getCategoryIcon(cat.icon),
                    color: catColor,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  t.description.isNotEmpty ? t.description : 'No Description',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: amountColor.withValues(alpha: isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: amountColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: amountColor,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isIncome ? 'INCOME' : 'EXPENSE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: amountColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  (isIncome ? '+ ' : '- ') + CurrencyFormatter.formatCents(t.amount),
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: amountColor,
                    letterSpacing: -1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Main Details Card (Category, Account, Date in a Grid)
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            borderRadius: AppTheme.radiusCard,
            child: Row(
              children: [
                Expanded(
                  child: _gridItem(
                    context,
                    icon: getCategoryIcon(cat.icon),
                    iconColor: catColor,
                    label: 'Category',
                    value: cat.name,
                  ),
                ),
                _verticalDivider(isDark),
                Expanded(
                  child: _gridItem(
                    context,
                    icon: getAccountIcon(acc.icon),
                    iconColor: isDark ? Colors.white70 : Colors.black87,
                    label: 'Account',
                    value: acc.name,
                  ),
                ),
                _verticalDivider(isDark),
                Expanded(
                  child: _gridItem(
                    context,
                    icon: Icons.calendar_today_rounded,
                    iconColor: Colors.blueAccent,
                    label: 'Date',
                    value: '${t.createdAt.day}/${t.createdAt.month}/${t.createdAt.year}',
                  ),
                ),
              ],
            ),
          ),

          if (hasExtraDetails) ...[
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: AppTheme.radiusCard,
              child: Column(
                children: [
                  if (t.reference != null && t.reference!.isNotEmpty) ...[
                    _copyableDetailRow(
                      context,
                      theme,
                      Icons.tag_rounded,
                      'Reference',
                      t.reference!,
                    ),
                  ],
                  if (t.sender != null && t.sender!.isNotEmpty) ...[
                    if (t.reference != null && t.reference!.isNotEmpty)
                      _divider(isDark),
                    _copyableDetailRow(
                      context,
                      theme,
                      Icons.person_outline_rounded,
                      'Sender',
                      t.sender!,
                    ),
                  ],
                  if (t.recipient != null && t.recipient!.isNotEmpty) ...[
                    if ((t.reference != null && t.reference!.isNotEmpty) ||
                        (t.sender != null && t.sender!.isNotEmpty))
                      _divider(isDark),
                    _copyableDetailRow(
                      context,
                      theme,
                      Icons.person_rounded,
                      'Recipient',
                      t.recipient!,
                    ),
                  ],
                  if (t.balanceAfter != null) ...[
                    if ((t.reference != null && t.reference!.isNotEmpty) ||
                        (t.sender != null && t.sender!.isNotEmpty) ||
                        (t.recipient != null && t.recipient!.isNotEmpty))
                      _divider(isDark),
                    _detailRow(
                      theme,
                      Icons.account_balance_rounded,
                      'Balance After',
                      CurrencyFormatter.formatCents(t.balanceAfter!),
                      valueColor: isDark ? Colors.white : Colors.black87,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gridItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _verticalDivider(bool isDark) {
    return Container(
      width: 0.5,
      height: 36,
      color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(
      height: 24,
      thickness: 0.5,
      color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
    );
  }

  Widget _copyableDetailRow(BuildContext context, ThemeData theme, IconData icon, String label, String value) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied $label to clipboard'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            width: 250,
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.copy_rounded,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(ThemeData theme, IconData icon, String label, String value, {Widget? trailing, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? (theme.brightness == Brightness.dark ? Colors.white : Colors.black),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing,
          ],
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    ModernDialog.show(
      context: context,
      title: const Text('Delete Transaction'),
      titleIcon: Icons.delete_rounded,
      iconColor: Colors.red,
      content: const Text('Are you sure you want to delete this transaction? This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () async {
            try {
              await ref.read(transactionRepositoryProvider).deleteTransaction(transactionId);
              ref.invalidate(recentTransactionsStreamProvider);
              ref.invalidate(accountsStreamProvider);
              ref.invalidate(netWorthProvider);
              ref.invalidate(monthlyTotalsProvider);
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pop();
                context.pop();
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete: $e')),
                );
              }
            }
          },
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
