import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Amount Hero
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            borderRadius: AppTheme.radiusCard,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: amountColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    color: amountColor,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isIncome ? 'Income' : 'Expense',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  CurrencyFormatter.formatCents(t.amount),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: amountColor,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Details
          GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: AppTheme.radiusCard,
            child: Column(
              children: [
                _detailRow(theme, Icons.description_rounded, 'Description', t.description.isNotEmpty ? t.description : 'No description'),
                const Divider(height: 24, thickness: 0.5),
                _detailRow(theme, Icons.category_rounded, 'Category', cat.name,
                  trailing: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(color: catColor, shape: BoxShape.circle),
                  ),
                ),
                const Divider(height: 24, thickness: 0.5),
                _detailRow(theme, Icons.account_balance_wallet_rounded, 'Account', acc.name),
                if (t.reference != null && t.reference!.isNotEmpty) ...[
                  const Divider(height: 24, thickness: 0.5),
                  _detailRow(theme, Icons.tag_rounded, 'Reference', t.reference!),
                ],
                if (t.sender != null && t.sender!.isNotEmpty) ...[
                  const Divider(height: 24, thickness: 0.5),
                  _detailRow(theme, Icons.person_outline_rounded, 'Sender', t.sender!),
                ],
                if (t.recipient != null && t.recipient!.isNotEmpty) ...[
                  const Divider(height: 24, thickness: 0.5),
                  _detailRow(theme, Icons.person_rounded, 'Recipient', t.recipient!),
                ],
                if (t.balanceAfter != null) ...[
                  const Divider(height: 24, thickness: 0.5),
                  _detailRow(theme, Icons.account_balance_rounded, 'Balance After',
                    CurrencyFormatter.formatCents(t.balanceAfter!),
                    valueColor: isDark ? Colors.white : Colors.black,
                  ),
                ],
                const Divider(height: 24, thickness: 0.5),
                _detailRow(theme, Icons.calendar_today_rounded, 'Date', '${t.createdAt.day}/${t.createdAt.month}/${t.createdAt.year}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(ThemeData theme, IconData icon, String label, String value, {Widget? trailing, Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? (theme.brightness == Brightness.dark ? Colors.white : Colors.black))),
          ],
        ),
        const Spacer(),
        ?trailing,
      ],
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
