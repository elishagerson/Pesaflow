import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/frequency_helpers.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/core/utils/app_illustrations.dart';
import 'package:pesaflow/presentation/common/widgets/empty_state.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';

class SubscriptionListScreen extends ConsumerWidget {
  const SubscriptionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subscriptionsAsync = ref.watch(subscriptionsStreamProvider);
    final dueSubscriptionsAsync = ref.watch(dueSubscriptionsProvider);

    return Scaffold(
      appBar: IosNavBar(
        title: 'Subscriptions',
        largeTitle: true,
        actions: [
          IconButton(
            icon: const Icon(PesaFlowIcons.add, size: 28),
            onPressed: () => context.push('/subscriptions/add'),
          ),
        ],
      ),
      body: subscriptionsAsync.when(
        data: (subscriptions) {
          final due = dueSubscriptionsAsync.asData?.value ?? [];
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(subscriptionsStreamProvider);
              ref.invalidate(dueSubscriptionsProvider);
            },
            child: subscriptions.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: EmptyState(
                      icon: Icons.subscriptions_outlined,
                      title: 'No subscriptions yet',
                      illustration: PesaFlowIllustration.emptySubscriptions(),
                      action: TextButton(
                        onPressed: () => context.push('/subscriptions/add'),
                        child: const Text('Add a subscription'),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(kSpacing16, kSpacing8, kSpacing16, kSpacing64),
                    children: [
                      if (due.isNotEmpty)
                        StaggeredFadeSlide(
                          index: 0,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: kSpacing12),
                            child: Container(
                              padding: const EdgeInsets.all(kSpacing14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                                border: Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(PesaFlowIcons.warning, color: Color(0xFFFF6B35), size: 20),
                                  const SizedBox(width: kSpacing10),
                                  Text('${due.length} subscription${due.length == 1 ? '' : 's'} due',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ...subscriptions.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final sub = entry.value;
                        return StaggeredFadeSlide(
                          index: idx + (due.isNotEmpty ? 1 : 0),
                          child: _buildSubscriptionTile(context, ref, sub, isDark, due.contains(sub)),
                        );
                      }),
                    ],
                  ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildSubscriptionTile(BuildContext context, WidgetRef ref, Subscription sub, bool isDark, bool isDue) {
    final freqLabel = frequencyLabel(sub.frequency, sub.intervalValue);
    final statusColor = sub.status == 'active' ? const Color(0xFF609F8A) : Colors.grey;
    final catColor = sub.categoryId != null
        ? (ref.read(categoriesFutureProvider).asData?.value
            .where((c) => c.id == sub.categoryId)
            .map((c) => hexToColor(c.color))
            .firstOrNull)
        : null;

    return Hero(
      tag: 'subscription-${sub.id}',
      child: Container(
      margin: const EdgeInsets.only(bottom: kSpacing8),
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
        onTap: () => context.push('/subscriptions/${sub.id}'),
        child: Padding(
          padding: const EdgeInsets.all(kSpacing14),
          child: Row(
            children: [
              Container(
                                  padding: const EdgeInsets.all(kSpacing10),
                decoration: BoxDecoration(
                  color: catColor != null ? catColor.withValues(alpha: 0.15) : (isDue ? const Color(0xFFFF6B35).withValues(alpha: 0.15) : statusColor.withValues(alpha: 0.15)),
                  shape: BoxShape.circle,
                ),
                child: Icon(PesaFlowIcons.subscriptions, color: catColor ?? (isDue ? const Color(0xFFFF6B35) : statusColor), size: 20),
              ),
              const SizedBox(width: kSpacing14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (catColor != null) ...[
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: catColor, shape: BoxShape.circle)),
                          const SizedBox(width: kSpacing6),
                        ],
                        Expanded(child: Text(sub.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                      ],
                    ),
                    const SizedBox(height: kSpacing2),
                    Text(freqLabel, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyFormatter.formatCents(sub.amount),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: kSpacing2),
                  Text(
                    sub.status == 'active' ? (isDue ? 'Due' : 'Active') : 'Paused',
                    style: TextStyle(fontSize: 11, color: isDue ? const Color(0xFFFF6B35) : statusColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    ),
  );
  }

}
