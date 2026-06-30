import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/frequency_helpers.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/empty_state.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';

/// Filter options for the recurring flows list.
enum _RecurringFilter { all, expenses, income }

class RecurringTransactionListScreen extends ConsumerStatefulWidget {
  const RecurringTransactionListScreen({super.key});

  @override
  ConsumerState<RecurringTransactionListScreen> createState() =>
      _RecurringTransactionListScreenState();
}

class _RecurringTransactionListScreenState
    extends ConsumerState<RecurringTransactionListScreen> {
  _RecurringFilter _activeFilter = _RecurringFilter.all;

  List<RecurringTransaction> _applyFilter(List<RecurringTransaction> items) {
    return switch (_activeFilter) {
      _RecurringFilter.all => items,
      _RecurringFilter.expenses =>
        items.where((r) => r.type == 'expense').toList(),
      _RecurringFilter.income =>
        items.where((r) => r.type == 'income').toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final recurringAsync = ref.watch(recurringTransactionsStreamProvider);
    final dueAsync = ref.watch(dueRecurringTransactionsProvider);
    final totals = ref.watch(recurringTotalsProvider);
    final categoriesAsync = ref.watch(categoriesFutureProvider);

    final dueIds = dueAsync.asData?.value.map((d) => d.id).toSet() ?? {};
    final categories = categoriesAsync.asData?.value ?? [];

    Color? catColor(String? catId) {
      if (catId == null) return null;
      final cat = categories.where((c) => c.id == catId).firstOrNull;
      return cat != null ? hexToColor(cat.color) : null;
    }

    return Scaffold(
      appBar: IosNavBar(
        title: 'Recurring Flows',
        largeTitle: true,
        actions: [
          IconButton(
            icon: const Icon(PesaFlowIcons.add, size: 28),
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/recurring/add');
            },
          ),
        ],
      ),
      body: recurringAsync.when(
        data: (recurring) {
          final filtered = _applyFilter(recurring);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(recurringTransactionsStreamProvider);
              ref.invalidate(dueRecurringTransactionsProvider);
            },
            child: recurring.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: _buildEmptyState(context, theme, isDark),
                  )
                : CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // ── Summary Header ──
                      SliverToBoxAdapter(
                        child: StaggeredFadeSlide(
                          index: 0,
                          child: _buildSummaryHeader(
                            theme,
                            isDark,
                            totals,
                            recurring,
                            dueIds,
                          ),
                        ),
                      ),

                      // ── Segmented Filter ──
                      SliverToBoxAdapter(
                        child: StaggeredFadeSlide(
                          index: 1,
                          child: _buildSegmentedFilter(
                            theme,
                            isDark,
                            recurring,
                          ),
                        ),
                      ),

                      // ── Due Soon Header (if any) ──
                      if (dueIds.isNotEmpty &&
                          _activeFilter != _RecurringFilter.income)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              kSpacing16,
                              kSpacing4,
                              kSpacing16,
                              kSpacing8,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  PesaFlowIcons.calendar,
                                  size: 12,
                                  color: const Color(0xFFFF6B35),
                                ),
                                const SizedBox(width: kSpacing6),
                                Text(
                                  '${dueIds.length} DUE NOW',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: const Color(0xFFFF6B35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ── List Items ──
                      if (filtered.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: EmptyState(
                              icon: _activeFilter == _RecurringFilter.income
                                  ? PesaFlowIcons.income
                                  : PesaFlowIcons.expense,
                              title:
                                  'No ${_activeFilter == _RecurringFilter.income ? 'income' : 'expense'} flows',
                              subtitle:
                                  'Tap + to add a recurring ${_activeFilter == _RecurringFilter.income ? 'income' : 'expense'}.',
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            kSpacing16,
                            0,
                            kSpacing16,
                            100,
                          ),
                          sliver: SliverList.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              // Sort: due items first, then by nextDate
                              final sorted =
                                  List<RecurringTransaction>.from(
                                    filtered,
                                  )..sort((a, b) {
                                    final aDue = dueIds.contains(a.id) ? 0 : 1;
                                    final bDue = dueIds.contains(b.id) ? 0 : 1;
                                    if (aDue != bDue) return aDue - bDue;
                                    return a.nextDate.compareTo(b.nextDate);
                                  });
                              return StaggeredFadeSlide(
                                index: i + 2,
                                child: _buildRecurringTile(
                                  context,
                                  sorted[i],
                                  theme,
                                  isDark,
                                  dueIds.contains(sorted[i].id),
                                  catColor(sorted[i].categoryId),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(horizontal: kSpacing16, vertical: kSpacing8),
          child: Column(
            children: [
              SkeletonCard(height: 100),
              SizedBox(height: 8),
              SkeletonCard(height: 100),
              SizedBox(height: 8),
              SkeletonCard(height: 100),
              SizedBox(height: 8),
              SkeletonCard(height: 100),
            ],
          ),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  // ── Summary Header ──────────────────────────────────────────────────────
  Widget _buildSummaryHeader(
    ThemeData theme,
    bool isDark,
    RecurringTotals totals,
    List<RecurringTransaction> allRecurring,
    Set<String> dueIds,
  ) {
    final activeExpenses = allRecurring.where(
      (r) => r.type == 'expense' && r.status == 'active',
    );
    final activeIncome = allRecurring.where(
      (r) => r.type == 'income' && r.status == 'active',
    );
    final paused = allRecurring.where((r) => r.status == 'paused');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kSpacing16,
        kSpacing12,
        kSpacing16,
        kSpacing8,
      ),
      child: GlassCard(
        borderRadius: AppTheme.radiusCard,
        elevation: CardElevation.medium,
        accentColor: theme.colorScheme.primary,
        padding: const EdgeInsets.all(kSpacing18),
        child: Column(
          children: [
            // Monthly cost headline
            if (totals.monthly > 0) ...[
              Text(
                'COMMITTED MONTHLY',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: kSpacing6),
              AmountText(
                amountInCents: totals.monthly,
                type: AmountType.expense,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: kSpacing12),
              // Cycle chips
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _cycleChip(theme, isDark, '${_fmtShort(totals.daily)}/day'),
                  const SizedBox(width: kSpacing8),
                  _cycleChip(theme, isDark, '${_fmtShort(totals.weekly)}/wk'),
                  const SizedBox(width: kSpacing8),
                  _cycleChip(theme, isDark, '${_fmtShort(totals.yearly)}/yr'),
                ],
              ),
              const SizedBox(height: kSpacing14),
              Divider(
                height: 0.5,
                color: isDark
                    ? const Color(0x1AFFFFFF)
                    : const Color(0x1A000000),
              ),
              const SizedBox(height: kSpacing14),
            ],
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statPill(
                  theme,
                  isDark,
                  '${activeExpenses.length}',
                  'Expenses',
                  isDark ? AppTheme.expenseColorDark : AppTheme.expenseColor,
                ),
                _statPill(
                  theme,
                  isDark,
                  '${activeIncome.length}',
                  'Income',
                  isDark ? AppTheme.incomeColorDark : AppTheme.incomeColor,
                ),
                if (paused.isNotEmpty)
                  _statPill(
                    theme,
                    isDark,
                    '${paused.length}',
                    'Paused',
                    const Color(0xFFFF9F0A),
                  ),
                if (dueIds.isNotEmpty)
                  _statPill(
                    theme,
                    isDark,
                    '${dueIds.length}',
                    'Due',
                    const Color(0xFFFF6B35),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statPill(
    ThemeData theme,
    bool isDark,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpacing12,
            vertical: kSpacing6,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: kSpacing4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _cycleChip(ThemeData theme, bool isDark, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpacing8,
        vertical: kSpacing4,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  String _fmtShort(int cents) {
    if (cents <= 0) return '0';
    final raw = CurrencyFormatter.formatCents(cents);
    return raw.startsWith('Tsh ') ? raw.substring(4) : raw;
  }

  // ── Segmented Filter ────────────────────────────────────────────────────
  Widget _buildSegmentedFilter(
    ThemeData theme,
    bool isDark,
    List<RecurringTransaction> allRecurring,
  ) {
    final allCount = allRecurring.length;
    final expenseCount = allRecurring.where((r) => r.type == 'expense').length;
    final incomeCount = allRecurring.where((r) => r.type == 'income').length;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: kSpacing16,
        vertical: kSpacing8,
      ),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          _filterTab(theme, isDark, 'All', allCount, _RecurringFilter.all),
          _filterTab(
            theme,
            isDark,
            'Expenses',
            expenseCount,
            _RecurringFilter.expenses,
          ),
          _filterTab(
            theme,
            isDark,
            'Income',
            incomeCount,
            _RecurringFilter.income,
          ),
        ],
      ),
    );
  }

  Widget _filterTab(
    ThemeData theme,
    bool isDark,
    String label,
    int count,
    _RecurringFilter filter,
  ) {
    final isActive = _activeFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _activeFilter = filter);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: kSpacing8),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.2 : 0.06,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '$count',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty State ─────────────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context, ThemeData theme, bool isDark) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.15),
      child: EmptyState(
        icon: PesaFlowIcons.calendar,
        title: 'No Recurring Flows',
        subtitle:
            'Add recurring bills, subscriptions, or income\nstreams to track them automatically.',
        action: FilledButton.icon(
          onPressed: () => context.push('/recurring/add'),
          icon: const Icon(PesaFlowIcons.add, size: 18),
          label: const Text('Add Recurring Flow'),
        ),
      ),
    );
  }

  // ── Recurring Item Tile ─────────────────────────────────────────────────
  Widget _buildRecurringTile(
    BuildContext context,
    RecurringTransaction recurring,
    ThemeData theme,
    bool isDark,
    bool isDue,
    Color? categoryColor,
  ) {
    final isExpense = recurring.type == 'expense';
    final accentColor = isDue
        ? const Color(0xFFFF6B35)
        : recurring.status == 'paused'
        ? const Color(0xFFFF9F0A)
        : recurring.status != 'active'
        ? Colors.grey
        : categoryColor ??
              (isExpense
                  ? (isDark ? AppTheme.expenseColorDark : AppTheme.expenseColor)
                  : (isDark ? AppTheme.incomeColorDark : AppTheme.incomeColor));

    final daysUntil = recurring.nextDate.difference(DateTime.now()).inDays;
    final nextDateLabel = daysUntil == 0
        ? 'Today'
        : daysUntil == 1
        ? 'Tomorrow'
        : daysUntil < 0
        ? '${daysUntil.abs()}d overdue'
        : 'in $daysUntil days';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: kSpacing10),
      borderRadius: AppTheme.radiusCard,
      elevation: isDue ? CardElevation.medium : CardElevation.low,
      accentColor: accentColor,
      onTap: () => context.push('/recurring/${recurring.id}/edit'),
      child: Padding(
        padding: const EdgeInsets.all(kSpacing14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(kSpacing10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isExpense
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    color: accentColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: kSpacing12),
                // Title + frequency
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              recurring.description ??
                                  'Recurring ${recurring.type}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Badges
                          ..._buildBadges(recurring, theme, isDue),
                        ],
                      ),
                      const SizedBox(height: kSpacing4),
                      Row(
                        children: [
                          Text(
                            frequencyLabel(
                              recurring.frequency,
                              recurring.intervalValue,
                            ),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          Container(
                            width: 3,
                            height: 3,
                            margin: const EdgeInsets.symmetric(
                              horizontal: kSpacing6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.2,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Icon(
                            PesaFlowIcons.calendar,
                            size: 11,
                            color: isDue
                                ? const Color(0xFFFF6B35)
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            nextDateLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 11,
                              fontWeight: isDue
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isDue
                                  ? const Color(0xFFFF6B35)
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.5,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: kSpacing8),
                // Amount
                AmountText(
                  amountInCents: recurring.amount,
                  type: isExpense ? AmountType.expense : AmountType.income,
                  useMonospace: true,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            // Payment stats (for auto-matched expenses)
            if (isExpense && recurring.paymentCount > 0) ...[
              const SizedBox(height: kSpacing10),
              Divider(
                height: 0.5,
                color: isDark
                    ? const Color(0x10FFFFFF)
                    : const Color(0x10000000),
              ),
              const SizedBox(height: kSpacing10),
              Row(
                children: [
                  Icon(
                    PesaFlowIcons.analytics,
                    size: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: kSpacing6),
                  Text(
                    'Paid ${CurrencyFormatter.formatCents(recurring.totalPaid)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  Container(
                    width: 3,
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: kSpacing6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(
                    '${recurring.paymentCount} payment${recurring.paymentCount > 1 ? 's' : ''}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const Spacer(),
                  if (recurring.lastPaidAt != null)
                    Text(
                      'Last: ${recurring.lastPaidAt!.day}/${recurring.lastPaidAt!.month}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBadges(
    RecurringTransaction recurring,
    ThemeData theme,
    bool isDue,
  ) {
    final badges = <Widget>[];

    if (recurring.merchantKeywords != null &&
        recurring.merchantKeywords!.isNotEmpty) {
      badges.add(
        Container(
          margin: const EdgeInsets.only(left: kSpacing6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bolt_rounded,
                size: 9,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 2),
              Text(
                'Auto',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Status badge
    final (label, color) = switch (recurring.status) {
      'active' => ('Active', const Color(0xFF609F8A)),
      'paused' => ('Paused', const Color(0xFFFF9F0A)),
      'cancelled' => ('Cancelled', Colors.grey),
      _ => (recurring.status, Colors.grey),
    };

    badges.add(
      Container(
        margin: const EdgeInsets.only(left: kSpacing4),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );

    return badges;
  }
}
