import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class SubscriptionListScreen extends ConsumerWidget {
  const SubscriptionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subscriptionsAsync = ref.watch(subscriptionsStreamProvider);
    final dueSubscriptionsAsync = ref.watch(dueSubscriptionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push('/subscriptions/add'),
          ),
        ],
      ),
      body: subscriptionsAsync.when(
        data: (subscriptions) {
          if (subscriptions.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.subscriptions_outlined, size: 64, color: isDark ? Colors.grey[600] : Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No subscriptions yet', style: TextStyle(fontSize: 17, color: isDark ? Colors.grey[400] : Colors.grey[500])),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.push('/subscriptions/add'),
                    child: const Text('Add a subscription'),
                  ),
                ],
              ),
            );
          }

          final due = dueSubscriptionsAsync.asData?.value ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            children: [
              if (due.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                      border: Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_rounded, color: Color(0xFFFF6B35), size: 20),
                        const SizedBox(width: 10),
                        Text('${due.length} subscription${due.length == 1 ? '' : 's'} due',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ...subscriptions.map((sub) => _buildSubscriptionTile(context, sub, isDark, due.contains(sub))),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildSubscriptionTile(BuildContext context, Subscription sub, bool isDark, bool isDue) {
    final freqLabel = _frequencyLabel(sub.frequency, sub.intervalValue);
    final statusColor = sub.status == 'active' ? const Color(0xFF609F8A) : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceContainerDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: isDue ? const Color(0xFFFF6B35).withValues(alpha: 0.3) : (isDark ? Colors.grey[800]! : Colors.grey[200]!)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          onTap: () => context.push('/subscriptions/${sub.id}/edit'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDue ? const Color(0xFFFF6B35).withValues(alpha: 0.15) : statusColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.subscriptions_rounded, color: isDue ? const Color(0xFFFF6B35) : statusColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sub.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(freqLabel, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(CurrencyFormatter.formatCents(sub.amount),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      sub.status == 'active' ? (isDue ? 'Due' : 'Active') : sub.status,
                      style: TextStyle(fontSize: 11, color: isDue ? const Color(0xFFFF6B35) : statusColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _frequencyLabel(String frequency, int interval) {
    final label = switch (frequency) {
      'weekly' => 'week',
      'biweekly' => '2 weeks',
      'monthly' => 'month',
      'quarterly' => 'quarter',
      'yearly' => 'year',
      _ => frequency,
    };
    return interval > 1 ? 'Every $interval $label' : 'Every $label';
  }
}
