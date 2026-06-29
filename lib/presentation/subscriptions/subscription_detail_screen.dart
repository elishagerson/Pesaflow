import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/frequency_helpers.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/repositories/subscription_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

final subscriptionTransactionsProvider = StreamProvider.family<List<TransactionWithCategoryAndAccount>, Subscription>((ref, sub) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchFilteredTransactions(
    type: 'expense',
  ).map((txs) {
    final keywords = sub.merchantKeywords.split(',').map((k) => k.trim().toLowerCase()).toList();
    return txs.where((t) {
      final desc = '${t.transaction.description} ${t.transaction.rawSms ?? ''}'.toLowerCase();
      return keywords.any((k) => k.isNotEmpty && desc.contains(k));
    }).toList();
  });
});

class SubscriptionDetailScreen extends ConsumerWidget {
  final String subscriptionId;
  const SubscriptionDetailScreen({super.key, required this.subscriptionId});

  Future<void> _toggleStatus(BuildContext context, WidgetRef ref, Subscription sub) async {
    final newStatus = sub.status == 'active' ? 'paused' : 'active';
    final repo = ref.read(subscriptionRepositoryProvider);
    try {
      await repo.updateSubscription(sub.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      ));
      ref.invalidate(subscriptionsStreamProvider);
      ref.invalidate(dueSubscriptionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Subscription tracking ${newStatus == 'active' ? 'resumed' : 'paused'}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Subscription sub) {
    ModernDialog.show(
      context: context,
      title: const Text('Delete Subscription?'),
      titleIcon: Icons.delete_forever_rounded,
      iconColor: Colors.red,
      content: Text(
        'Are you sure you want to delete "${sub.name}"? This will stop tracking it. Match payment transactions will not be deleted.',
        style: const TextStyle(fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            try {
              final repo = ref.read(subscriptionRepositoryProvider);
              await repo.deleteSubscription(sub.id);
              ref.invalidate(subscriptionsStreamProvider);
              ref.invalidate(dueSubscriptionsProvider);
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pop();
                context.pop(); // Go back to subscriptions list
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete subscription: $e')),
                );
              }
            }
          },
          child: const Text('Delete'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subscriptionsAsync = ref.watch(subscriptionsStreamProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesFutureProvider);

    return subscriptionsAsync.when(
      data: (subscriptions) {
        final sub = subscriptions.where((s) => s.id == subscriptionId).firstOrNull;
        if (sub == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Details')),
            body: const Center(child: Text('Subscription not found')),
          );
        }

        final accounts = accountsAsync.value ?? [];
        final categories = categoriesAsync.value ?? [];
        final account = accounts.where((a) => a.id == sub.accountId).firstOrNull;
        final category = categories.where((c) => c.id == sub.categoryId).firstOrNull;

        final isDue = sub.status == 'active' && sub.nextDueDate.isBefore(DateTime.now());
        final statusColor = sub.status == 'active'
            ? (isDue ? const Color(0xFFFF6B35) : const Color(0xFF609F8A))
            : Colors.grey;

        final transactionsAsync = ref.watch(subscriptionTransactionsProvider(sub));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Subscription Details'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(PesaFlowIcons.edit),
                onPressed: () => context.push('/subscriptions/${sub.id}/edit'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              // 1. Hero Card
              StaggeredFadeSlide(
                index: 0,
                child: Hero(
                  tag: 'subscription-${sub.id}',
                  child: GlassCard(
                  borderRadius: AppTheme.radiusCard,
                  elevation: CardElevation.medium,
                  accentColor: statusColor,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(PesaFlowIcons.subscriptions, color: statusColor, size: 28),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          sub.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${CurrencyFormatter.formatCents(sub.amount)} / ${frequencyLabel(sub.frequency, sub.intervalValue)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            sub.status == 'active' ? (isDue ? 'DUE' : 'ACTIVE') : 'PAUSED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Info Summary Card
              StaggeredFadeSlide(
                index: 1,
                child: GlassCard(
                  borderRadius: AppTheme.radiusCard,
                  elevation: CardElevation.low,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Account', account?.name ?? 'Not set', PesaFlowIcons.loans, isDark),
                      const Divider(height: 24),
                      _buildInfoRow(
                        'Category',
                        category?.name ?? 'None',
                        category != null ? getCategoryIcon(category.icon) : Icons.category_rounded,
                        isDark,
                        iconColor: category != null ? hexToColor(category.color) : null,
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        'Next Due Date',
                        '${sub.nextDueDate.day}/${sub.nextDueDate.month}/${sub.nextDueDate.year}',
                        PesaFlowIcons.calendar,
                        isDark,
                      ),
                      const Divider(height: 24),
                      _buildInfoRow('Total Paid', CurrencyFormatter.formatCents(sub.totalPaid), PesaFlowIcons.cash, isDark),
                      const Divider(height: 24),
                      _buildInfoRow('Payments Logged', '${sub.paymentCount} payments', Icons.history_toggle_off_rounded, isDark),
                      const Divider(height: 24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.vpn_key_rounded, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              const SizedBox(width: 8),
                              Text(
                                'SMS Keywords',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: sub.merchantKeywords.split(',').map((kw) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(kw.trim(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Status Action Card
              StaggeredFadeSlide(
                index: 2,
                child: GlassCard(
                  borderRadius: AppTheme.radiusCard,
                  elevation: CardElevation.low,
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => _toggleStatus(context, ref, sub),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusCard)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                sub.status == 'active' ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                                color: sub.status == 'active' ? Colors.orange : Colors.green,
                                size: 24,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sub.status == 'active' ? 'Pause Subscription' : 'Resume Subscription',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      sub.status == 'active'
                                          ? 'Temporarily stop tracking transaction SMS'
                                          : 'Resume matching incoming transaction SMS',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 54),
                      InkWell(
                        onTap: () => _confirmDelete(context, ref, sub),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusCard)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(PesaFlowIcons.delete, color: Colors.red, size: 24),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Delete Subscription',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red),
                                    ),
                                    Text(
                                      'Remove this subscription track permanently',
                                      style: TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 4. Payment History
              StaggeredFadeSlide(
                index: 3,
                child: Text(
                  'Payment History',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),

              transactionsAsync.when(
                data: (txs) {
                  if (txs.isEmpty) {
                    return StaggeredFadeSlide(
                      index: 4,
                      child: GlassCard(
                        borderRadius: AppTheme.radiusCard,
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No matched payment transactions',
                            style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600]),
                          ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: txs.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final tx = entry.value;
                      return StaggeredFadeSlide(
                        index: 4 + idx,
                        child: _buildTransactionTile(context, tx, theme, isDark),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: LinearProgressIndicator()),
                error: (e, _) => Center(child: Text('Error loading history: $e')),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error loading subscription details: $e'))),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, bool isDark, {Color? iconColor}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor ?? (isDark ? Colors.grey[400] : Colors.grey[600])),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionTile(BuildContext context, TransactionWithCategoryAndAccount item, ThemeData theme, bool isDark) {
    final trans = item.transaction;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceContainerDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: isDark ? Colors.grey[850]! : Colors.grey[200]!),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          onTap: () => context.push('/transactions/${trans.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hexToColor(item.category.color).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    getCategoryIcon(item.category.icon),
                    color: hexToColor(item.category.color),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trans.description.isNotEmpty ? trans.description : item.category.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            item.account?.name ?? 'Offline',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            trans.createdAt.toString().substring(0, 10),
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.formatCents(trans.amount),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
