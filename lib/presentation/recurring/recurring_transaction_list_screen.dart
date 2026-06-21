import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/frequency_helpers.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/premium_fab.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class RecurringTransactionListScreen extends ConsumerWidget {
  const RecurringTransactionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final recurringAsync = ref.watch(recurringTransactionsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring'),
        centerTitle: true,
      ),
      floatingActionButton: PremiumExtendedFab(
        onPressed: () => context.push('/recurring/add'),
        label: 'Add Recurring',
      ),
      body: recurringAsync.when(
        data: (recurring) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(recurringTransactionsStreamProvider);
              ref.invalidate(dueRecurringTransactionsProvider);
            },
            child: recurring.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: StaggeredFadeSlide(index: 0, child: _buildEmptyState(theme, isDark)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: recurring.length,
                    itemBuilder: (_, i) => StaggeredFadeSlide(
                      index: i + 1,
                      child: _buildRecurringTile(context, recurring[i], theme, isDark),
                    ),
                  ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.repeat_rounded,
                color: theme.colorScheme.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Recurring Transactions',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add recurring bills, subscriptions,\nor savings to automate them.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurringTile(BuildContext context, RecurringTransaction recurring, ThemeData theme, bool isDark) {
    final statusColor = recurring.status == 'active'
        ? const Color(0xFF609F8A)
        : recurring.status == 'paused'
            ? const Color(0xFFFF9F0A)
            : Colors.grey;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      borderRadius: AppTheme.radiusCard,
      elevation: CardElevation.low,
      accentColor: statusColor,
      onTap: () => context.push('/recurring/${recurring.id}/edit'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.repeat_rounded,
                    color: statusColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recurring.description ?? 'Recurring ${recurring.type}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                            Text(
                              frequencyLabel(recurring.frequency, recurring.intervalValue),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.formatCents(recurring.amount),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    _buildStatusBadge(recurring.status),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 12, color: isDark ? Colors.grey[500] : Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  'Next: ${recurring.nextDate.day}/${recurring.nextDate.month}/${recurring.nextDate.year}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final (label, color) = switch (status) {
      'active' => ('Active', const Color(0xFF609F8A)),
      'paused' => ('Paused', const Color(0xFFFF9F0A)),
      'cancelled' => ('Cancelled', Colors.grey),
      _ => (status, Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

}
