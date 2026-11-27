import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/frequency_helpers.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/repositories/recurring_transaction_repository.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/empty_state.dart';
import 'package:pesaflow/presentation/common/widgets/error_state.dart';
import 'package:pesaflow/presentation/common/widgets/glass_list_container.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/presentation/common/widgets/app_fab.dart';
import 'package:pesaflow/presentation/recurring/widgets/mark_recurring_payment_sheet.dart';
import 'package:pesaflow/presentation/common/widgets/pesa_surface.dart';
import 'package:pesaflow/presentation/common/widgets/floating_top_bar.dart';
import 'package:pesaflow/core/utils/scroll_helpers.dart';
import 'package:pesaflow/presentation/common/widgets/motion/haptic_pattern.dart';
import 'package:pesaflow/presentation/recurring/utils/recurring_schedule_helpers.dart';
import 'package:pesaflow/presentation/recurring/widgets/affordability_check_view.dart';
import 'package:pesaflow/presentation/recurring/widgets/bills_overview_card.dart';
import 'package:pesaflow/presentation/recurring/widgets/payday_view.dart';

/// View tabs for the recurring flows screen.
enum _RecurringFilter { bills, payday, check, all }

class RecurringTransactionListScreen extends ConsumerStatefulWidget {
  const RecurringTransactionListScreen({super.key});

  @override
  ConsumerState<RecurringTransactionListScreen> createState() =>
      _RecurringTransactionListScreenState();
}

class _RecurringTransactionListScreenState
    extends ConsumerState<RecurringTransactionListScreen> {
  final _scrollController = ScrollController();
  final Set<String> _dismissedCandidates = {};
  _RecurringFilter _activeFilter = _RecurringFilter.bills;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<RecurringTransaction> _applyFilter(List<RecurringTransaction> items) {
    return switch (_activeFilter) {
      _RecurringFilter.bills =>
        items.where((r) => r.type == 'expense').toList(),
      _RecurringFilter.payday =>
        items.where((r) => r.type == 'income').toList(),
      _RecurringFilter.check => items,
      _RecurringFilter.all => items,
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(scrollToTopProvider, (_, _) {
      _scrollController.scrollToTop(context);
    });
    final theme = Theme.of(context);
    final recurringAsync = ref.watch(recurringTransactionsStreamProvider);
    final dueAsync = ref.watch(dueRecurringTransactionsProvider);
    final totals = ref.watch(recurringTotalsProvider);
    final categoriesAsync = ref.watch(categoriesFutureProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final candidatesAsync = ref.watch(discoveredRecurringCandidatesProvider);
    final currentBalanceCents = ref.watch(netWorthProvider);

    final dueIds = dueAsync.asData?.value.map((d) => d.id).toSet() ?? {};
    final categories = categoriesAsync.asData?.value ?? [];
    final accounts = accountsAsync.asData?.value ?? [];
    final accountNames = {for (final a in accounts) a.id: a.name};

    Color? catColor(String? catId) {
      if (catId == null) return null;
      final cat = categories.where((c) => c.id == catId).firstOrNull;
      return cat != null ? hexToColor(cat.color) : null;
    }

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: kSpacing16),
        child: AppExtendedFab(
          label: _activeFilter == _RecurringFilter.payday
              ? 'Add Payday'
              : 'New Recurring',
          onPressed: () {
            PesaHaptics.medium();
            context.push(
              '/recurring/add',
              extra: _activeFilter == _RecurringFilter.payday
                  ? const {'type': 'income'}
                  : null,
            );
          },
        ),
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // ── Floating Top Bar ──
            const FloatingTopBar(title: 'Recurring Flows'),
            // ── Content ──
            Expanded(
              child: recurringAsync.when(
                data: (recurring) {
                  final filtered = _applyFilter(recurring);
                  final sorted = List<RecurringTransaction>.from(filtered)
                    ..sort((a, b) {
                      final aDue = dueIds.contains(a.id) ? 0 : 1;
                      final bDue = dueIds.contains(b.id) ? 0 : 1;
                      if (aDue != bDue) return aDue - bDue;
                      return a.nextDate.compareTo(b.nextDate);
                    });

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(recurringTransactionsStreamProvider);
                      ref.invalidate(dueRecurringTransactionsProvider);
                    },
                    child: recurring.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: _buildEmptyState(context, theme),
                          )
                        : CustomScrollView(
                            controller: _scrollController,
                            key: const PageStorageKey('recurring_list'),
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              // ── Segmented View Switcher ──
                              SliverToBoxAdapter(
                                child: StaggeredFadeSlide(
                                  index: 0,
                                  child: _buildSegmentedFilter(
                                    theme,
                                    recurring,
                                  ),
                                ),
                              ),

                              if (_activeFilter == _RecurringFilter.bills) ...[
                                ..._buildBillsModeSlivers(
                                  context: context,
                                  theme: theme,
                                  recurring: recurring,
                                  dueIds: dueIds,
                                  currentBalanceCents: currentBalanceCents,
                                  candidatesAsync: candidatesAsync,
                                  catColor: catColor,
                                  accountNames: accountNames,
                                ),
                              ] else if (_activeFilter ==
                                  _RecurringFilter.payday) ...[
                                ..._buildPaydayModeSlivers(
                                  context: context,
                                  theme: theme,
                                  recurring: recurring,
                                  dueIds: dueIds,
                                  currentBalanceCents: currentBalanceCents,
                                  catColor: catColor,
                                  accountNames: accountNames,
                                ),
                              ] else ...[
                                // ── Summary Header (All view) ──
                                if (_activeFilter == _RecurringFilter.all)
                                  SliverToBoxAdapter(
                                    child: StaggeredFadeSlide(
                                      index: 1,
                                      child: _buildSummaryHeader(
                                        theme,
                                        totals,
                                        recurring,
                                        dueIds,
                                      ),
                                    ),
                                  ),

                                // ── Discovered Recurring Patterns ──
                                if (_activeFilter == _RecurringFilter.all)
                                  candidatesAsync.when(
                                    data: (candidates) {
                                      final activeCandidates = candidates
                                          .where(
                                            (c) => !_dismissedCandidates
                                                .contains(c.keyword),
                                          )
                                          .toList();
                                      if (activeCandidates.isEmpty) {
                                        return const SliverToBoxAdapter(
                                          child: SizedBox.shrink(),
                                        );
                                      }
                                      return SliverToBoxAdapter(
                                        child: _buildDiscoveredSection(
                                          context,
                                          theme,
                                          activeCandidates,
                                        ),
                                      );
                                    },
                                    loading: () => const SliverToBoxAdapter(
                                      child: SizedBox.shrink(),
                                    ),
                                    error: (_, _) => const SliverToBoxAdapter(
                                      child: SizedBox.shrink(),
                                    ),
                                  ),

                                // ── Due Soon Header (if any) ──
                                if (dueIds.isNotEmpty)
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
                                            color:
                                                context.appColors.transferColor,
                                          ),
                                          const SizedBox(width: kSpacing6),
                                          Text(
                                            '${dueIds.length} DUE NOW',
                                            style: context
                                                .ts(
                                                  10,
                                                  fontWeight: FontWeight.w800,
                                                  color: context
                                                      .appColors
                                                      .transferColor,
                                                )
                                                .copyWith(letterSpacing: 1.2),
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
                                        icon: PesaFlowIcons.transfer,
                                        title: 'No transfer flows',
                                        subtitle:
                                            'Tap + to add a recurring transfer.',
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
                                    sliver: SliverToBoxAdapter(
                                      child: _buildTilesContainer(
                                        context: context,
                                        items: sorted,
                                        theme: theme,
                                        dueIds: dueIds,
                                        catColor: catColor,
                                        accountNames: accountNames,
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: kSpacing16,
                    vertical: kSpacing8,
                  ),
                  child: Column(
                    children: [
                      SkeletonCard(height: 100),
                      SizedBox(height: kSpacing8),
                      SkeletonCard(height: 100),
                      SizedBox(height: kSpacing8),
                      SkeletonCard(height: 100),
                      SizedBox(height: kSpacing8),
                      SkeletonCard(height: 100),
                    ],
                  ),
                ),
                error: (e, _) => ErrorState(
                  title: 'Failed to load recurring transactions',
                  message: e.toString(),
                  onRetry: () {
                    ref.invalidate(recurringTransactionsStreamProvider);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Summary Header ──────────────────────────────────────────────────────
  Widget _buildSummaryHeader(
    ThemeData theme,
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

    final onSurface = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kSpacing16,
        kSpacing12,
        kSpacing16,
        kSpacing8,
      ),
      child: PesaSurface.bleed(
        fill: theme.colorScheme.surfaceContainerHigh,
        radius: AppTheme.radiusDialog,
        padding: const EdgeInsets.all(kSpacing20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(kSpacing6),
                      decoration: BoxDecoration(
                        color: onSurface.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(
                          AppTheme.squircleRadius(27),
                        ),
                      ),
                      child: Icon(
                        PesaFlowIcons.subscriptions,
                        size: 15,
                        color: onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: kSpacing8),
                    Text(
                      'MONTHLY COMMITMENTS',
                      style: context.ts(
                        11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: context.appColors.textMedium,
                      ),
                    ),
                  ],
                ),
                if (dueIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: kSpacing8,
                      vertical: kSpacing4,
                    ),
                    decoration: BoxDecoration(
                      color: context.appColors.transferColor.withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      border: Border.all(
                        color: context.appColors.transferColor.withValues(
                          alpha: 0.25,
                        ),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PesaFlowIcons.calendar,
                          size: 11,
                          color: context.appColors.transferColor,
                        ),
                        const SizedBox(width: kSpacing4),
                        Text(
                          '${dueIds.length} DUE NOW',
                          style: context.ts(
                            10,
                            fontWeight: FontWeight.w800,
                            color: context.appColors.transferColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: kSpacing8,
                      vertical: kSpacing4,
                    ),
                    decoration: BoxDecoration(
                      color: context.appColors.incomeColor.withValues(
                        alpha: 0.10,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      border: Border.all(
                        color: context.appColors.incomeColor.withValues(
                          alpha: 0.20,
                        ),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '${activeExpenses.length + activeIncome.length} ACTIVE',
                      style: context.ts(
                        10,
                        fontWeight: FontWeight.w800,
                        color: context.appColors.incomeColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: kSpacing16),
            // Monthly cost headline
            if (totals.monthly > 0) ...[
              AmountText(
                amountInCents: totals.monthly,
                animate: true,
                style: context.ts(
                  28,
                  fontWeight: FontWeight.w900,
                  color: onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Calculated fixed obligations per month',
                style: context.ts(
                  11,
                  color: context.appColors.textMedium,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: kSpacing12),
              // Cycle chips
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _cycleChip(theme, '${_fmtShort(totals.daily)}/day'),
                  const SizedBox(width: kSpacing8),
                  _cycleChip(theme, '${_fmtShort(totals.weekly)}/wk'),
                  const SizedBox(width: kSpacing8),
                  _cycleChip(theme, '${_fmtShort(totals.yearly)}/yr'),
                ],
              ),
              const SizedBox(height: kSpacing14),
              Divider(height: 0.5, color: onSurface.withValues(alpha: 0.08)),
              const SizedBox(height: kSpacing14),
            ],
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statPill(
                  theme,
                  '${activeExpenses.length}',
                  'Expenses',
                  context.appColors.expenseColor,
                ),
                _statPill(
                  theme,
                  '${activeIncome.length}',
                  'Income',
                  context.appColors.incomeColor,
                ),
                if (paused.isNotEmpty)
                  _statPill(
                    theme,
                    '${paused.length}',
                    'Paused',
                    onSurface.withValues(alpha: 0.6),
                  ),
                if (dueIds.isNotEmpty)
                  _statPill(
                    theme,
                    '${dueIds.length}',
                    'Due',
                    context.appColors.transferColor,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statPill(ThemeData theme, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpacing12,
            vertical: kSpacing6,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          child: Text(
            value,
            style: context.ts(16, fontWeight: FontWeight.w700, color: color),
          ),
        ),
        const SizedBox(height: kSpacing4),
        Text(
          label,
          style: context.ts(
            11,
            fontWeight: FontWeight.w700,
            color: context.appColors.textMedium,
          ),
        ),
      ],
    );
  }

  Widget _cycleChip(ThemeData theme, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpacing8,
        vertical: kSpacing4,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        text,
        style: context.ts(
          10,
          fontWeight: FontWeight.w700,
          color: context.appColors.textMedium,
        ),
      ),
    );
  }

  String _fmtShort(int cents) {
    if (cents <= 0) return '0';
    final raw = CurrencyFormatter.formatCents(cents);
    return raw.startsWith('Tsh ') ? raw.substring(4) : raw;
  }

  // ── Discovered Candidates Banner ────────────────────────────────────────
  Widget _buildDiscoveredSection(
    BuildContext context,
    ThemeData theme,
    List<RecurringCandidate> candidates,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kSpacing16,
        kSpacing8,
        kSpacing16,
        kSpacing4,
      ),
      child: Container(
        padding: const EdgeInsets.all(kSpacing14),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  PesaFlowIcons.lightbulb,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: kSpacing8),
                Expanded(
                  child: Text(
                    'DISCOVERED RECURRING BILLS (${candidates.length})',
                    style: context.ts(
                      11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                Text(
                  'From past SMS',
                  style: context.ts(
                    10,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: kSpacing10),
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: candidates.length,
                separatorBuilder: (_, _) => const SizedBox(width: kSpacing10),
                itemBuilder: (context, idx) {
                  final cand = candidates[idx];
                  final formattedAmt = CurrencyFormatter.formatCents(
                    cand.averageAmountCents,
                  );
                  return Container(
                    width: 220,
                    padding: const EdgeInsets.all(kSpacing10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                      border: Border.all(color: context.appColors.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                cand.title,
                                style: context.ts(
                                  13,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                PesaHaptics.light();
                                setState(
                                  () => _dismissedCandidates.add(cand.keyword),
                                );
                              },
                              child: Icon(
                                PesaFlowIcons.close,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$formattedAmt · ${cand.frequency}',
                          style: context.ts(
                            12,
                            fontWeight: FontWeight.w700,
                            color: context.appColors.expenseColor,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Paid ${cand.occurrenceCount}x recently',
                              style: context.ts(
                                10,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                            TactileSpringContainer(
                              onTap: () {
                                PesaHaptics.medium();
                                context.push(
                                  '/recurring/add',
                                  extra: {
                                    'title': cand.title,
                                    'amount': cand.averageAmountCents,
                                    'keywords': cand.keyword,
                                    'frequency': cand.frequency,
                                    'interval': cand.intervalValue,
                                    'categoryId': cand.categoryId,
                                    'accountId': cand.accountId,
                                    'nextDate': cand.suggestedNextDate,
                                    'isFlexible':
                                        cand.keyword == 'luku' ||
                                        cand.keyword == 'dawasa',
                                  },
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: kSpacing8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusPill,
                                  ),
                                ),
                                child: Text(
                                  'Set Up',
                                  style: context.ts(
                                    11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Segmented Filter ────────────────────────────────────────────────────
  Widget _buildSegmentedFilter(
    ThemeData theme,
    List<RecurringTransaction> allRecurring,
  ) {
    final allCount = allRecurring.length;
    final expenseCount = allRecurring.where((r) => r.type == 'expense').length;
    final incomeCount = allRecurring.where((r) => r.type == 'income').length;
    final transferCount = allRecurring
        .where((r) => r.type == 'transfer')
        .length;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: kSpacing16,
        vertical: kSpacing8,
      ),
      padding: const EdgeInsets.all(kSpacing4),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        children: [
          _filterTab(
            theme,
            'Bills',
            expenseCount,
            _RecurringFilter.bills,
          ),
          _filterTab(
            theme,
            'Payday',
            incomeCount,
            _RecurringFilter.payday,
          ),
          _filterTab(theme, 'All', allCount, _RecurringFilter.all),
          _filterTab(
            theme,
            'Transfer',
            transferCount,
            _RecurringFilter.transfers,
          ),
        ],
      ),
    );
  }

  // ── Bills Mode Slivers ──────────────────────────────────────────────────
  List<Widget> _buildBillsModeSlivers({
    required BuildContext context,
    required ThemeData theme,
    required List<RecurringTransaction> recurring,
    required Set<String> dueIds,
    required int currentBalanceCents,
    required AsyncValue<List<RecurringCandidate>> candidatesAsync,
    required Color? Function(String?) catColor,
    required Map<String, String> accountNames,
  }) {
    final nextPayday = nextPaydayFor(recurring);
    final classified = classifyUpcomingBills(recurring, nextPayday: nextPayday);

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: StaggeredFadeSlide(
          index: 1,
          child: BillsOverviewCard(
            classified: classified,
            currentBalanceCents: currentBalanceCents,
            nextPayday: nextPayday,
          ),
        ),
      ),
    ];

    candidatesAsync.whenData((candidates) {
      final activeCandidates = candidates
          .where((c) => !_dismissedCandidates.contains(c.keyword))
          .toList();
      if (activeCandidates.isNotEmpty) {
        slivers.add(
          SliverToBoxAdapter(
            child: _buildDiscoveredSection(context, theme, activeCandidates),
          ),
        );
      }
    });

    final hasAnyBills =
        classified.dueNow.isNotEmpty ||
        classified.dueBeforePayday.isNotEmpty ||
        classified.upcomingLater.isNotEmpty ||
        classified.inactive.isNotEmpty;

    if (!hasAnyBills) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: EmptyState(
              icon: PesaFlowIcons.expense,
              title: 'No recurring bills',
              subtitle: 'Tap + to add a recurring bill or subscription.',
            ),
          ),
        ),
      );
      return slivers;
    }

    // Paid this month summary bar
    if (classified.paidThisMonth.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              kSpacing16,
              kSpacing8,
              kSpacing16,
              kSpacing4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${classified.paidThisMonth.length} paid this month',
                  style: context.ts(
                    12,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.textMedium,
                  ),
                ),
                Text(
                  CurrencyFormatter.formatCents(
                    classified.paidThisMonthTotalCents,
                  ),
                  style: context.ts(
                    12,
                    fontWeight: FontWeight.w700,
                    color: context.appColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (classified.dueNow.isNotEmpty) {
      slivers.add(
        _buildSectionHeader(
          context,
          '${classified.dueNow.length} DUE NOW',
          color: context.appColors.transferColor,
          icon: PesaFlowIcons.calendar,
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: kSpacing16),
          sliver: SliverToBoxAdapter(
            child: _buildTilesContainer(
              context: context,
              items: classified.dueNow,
              theme: theme,
              dueIds: dueIds,
              catColor: catColor,
              accountNames: accountNames,
              highlightFirst: true,
            ),
          ),
        ),
      );
    }

    if (classified.dueBeforePayday.isNotEmpty) {
      final headerLabel = classified.hasPaydayAnchor
          ? 'DUE BEFORE PAYDAY (${classified.dueBeforePayday.length})'
          : 'DUE THIS WEEK (${classified.dueBeforePayday.length})';
      slivers.add(
        _buildSectionHeader(
          context,
          headerLabel,
          color: const Color(0xFFB45309),
          icon: PesaFlowIcons.calendar,
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: kSpacing16),
          sliver: SliverToBoxAdapter(
            child: _buildTilesContainer(
              context: context,
              items: classified.dueBeforePayday,
              theme: theme,
              dueIds: dueIds,
              catColor: catColor,
              accountNames: accountNames,
              highlightFirst: classified.dueNow.isEmpty,
            ),
          ),
        ),
      );
    }

    if (classified.upcomingLater.isNotEmpty) {
      slivers.add(
        _buildSectionHeader(
          context,
          classified.hasPaydayAnchor
              ? 'AFTER PAYDAY (${classified.upcomingLater.length})'
              : 'UPCOMING LATER (${classified.upcomingLater.length})',
          color: context.appColors.textMedium,
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: kSpacing16),
          sliver: SliverToBoxAdapter(
            child: _buildTilesContainer(
              context: context,
              items: classified.upcomingLater,
              theme: theme,
              dueIds: dueIds,
              catColor: catColor,
              accountNames: accountNames,
            ),
          ),
        ),
      );
    }

    if (classified.inactive.isNotEmpty) {
      slivers.add(
        _buildSectionHeader(
          context,
          'PAUSED (${classified.inactive.length})',
          color: context.appColors.textMedium,
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: kSpacing16),
          sliver: SliverToBoxAdapter(
            child: _buildTilesContainer(
              context: context,
              items: classified.inactive,
              theme: theme,
              dueIds: dueIds,
              catColor: catColor,
              accountNames: accountNames,
            ),
          ),
        ),
      );
    }

    slivers.add(
      const SliverToBoxAdapter(child: SizedBox(height: 100)),
    );
    return slivers;
  }

  // ── Payday Mode Slivers ─────────────────────────────────────────────────
  List<Widget> _buildPaydayModeSlivers({
    required BuildContext context,
    required ThemeData theme,
    required List<RecurringTransaction> recurring,
    required Set<String> dueIds,
    required int currentBalanceCents,
    required Color? Function(String?) catColor,
    required Map<String, String> accountNames,
  }) {
    final nextPayday = nextPaydayFor(recurring);
    final classified = classifyUpcomingBills(recurring, nextPayday: nextPayday);
    final incomes = recurring.where((r) => r.type == 'income').toList()
      ..sort((a, b) => a.nextDate.compareTo(b.nextDate));

    return [
      SliverToBoxAdapter(
        child: StaggeredFadeSlide(
          index: 1,
          child: PaydayView(
            allRecurring: recurring,
            currentBalanceCents: currentBalanceCents,
            billsDueBeforePaydayCents: classified.toPayTotalCents,
          ),
        ),
      ),
      if (incomes.isNotEmpty) ...[
        _buildSectionHeader(
          context,
          'INCOME STREAMS (${incomes.length})',
          color: context.appColors.incomeColor,
          icon: PesaFlowIcons.income,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            kSpacing16,
            0,
            kSpacing16,
            100,
          ),
          sliver: SliverToBoxAdapter(
            child: _buildTilesContainer(
              context: context,
              items: incomes,
              theme: theme,
              dueIds: dueIds,
              catColor: catColor,
              accountNames: accountNames,
            ),
          ),
        ),
      ] else
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
    ];
  }

  SliverToBoxAdapter _buildSectionHeader(
    BuildContext context,
    String title, {
    required Color color,
    IconData? icon,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          kSpacing16,
          kSpacing12,
          kSpacing16,
          kSpacing8,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: color),
              const SizedBox(width: kSpacing6),
            ],
            Text(
              title,
              style: context
                  .ts(10, fontWeight: FontWeight.w800, color: color)
                  .copyWith(letterSpacing: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTilesContainer({
    required BuildContext context,
    required List<RecurringTransaction> items,
    required ThemeData theme,
    required Set<String> dueIds,
    required Color? Function(String?) catColor,
    required Map<String, String> accountNames,
    bool highlightFirst = false,
  }) {
    return GlassListContainer(
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final item = items[i];
          return StaggeredFadeSlide(
            index: i + 2,
            child: Dismissible(
              key: ValueKey(item.id),
              direction: DismissDirection.horizontal,
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.endToStart) {
                  showMarkRecurringPaymentSheet(
                    context: context,
                    ref: ref,
                    recurring: item,
                    accountName: accountNames[item.accountId] ?? 'Unknown',
                  );
                } else {
                  await ref
                      .read(recurringTransactionRepositoryProvider)
                      .toggleStatus(item.id);
                  if (context.mounted) {
                    final newStatus =
                        item.status == 'active' ? 'paused' : 'active';
                    CustomToast.show(
                      context,
                      message:
                          'Recurring ${newStatus == 'paused' ? 'paused' : 'resumed'}',
                      type: ToastType.info,
                    );
                  }
                }
                return false;
              },
              background: Container(
                decoration: BoxDecoration(
                  color: context.appColors.incomeColor,
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: kSpacing24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      PesaFlowIcons.success,
                      color: context.appColors.onBgColor,
                      size: 24,
                    ),
                    const SizedBox(height: kSpacing4),
                    Text(
                      'Mark Paid',
                      style: context.ts(
                        11,
                        color: context.appColors.onBgColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              secondaryBackground: Container(
                decoration: BoxDecoration(
                  color: item.status == 'active'
                      ? context.appColors.expenseColor
                      : context.appColors.incomeColor,
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: kSpacing24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.status == 'active'
                          ? PesaFlowIcons.pause
                          : PesaFlowIcons.success,
                      color: context.appColors.onBgColor,
                      size: 24,
                    ),
                    const SizedBox(height: kSpacing4),
                    Text(
                      item.status == 'active' ? 'Pause' : 'Resume',
                      style: context.ts(
                        11,
                        color: context.appColors.onBgColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              child: _buildRecurringTile(
                context,
                item,
                theme,
                dueIds.contains(item.id),
                catColor(item.categoryId),
                accountNames,
                i,
                items.length,
                highlightUpcoming: highlightFirst && i == 0,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _filterTab(
    ThemeData theme,
    String label,
    int count,
    _RecurringFilter filter,
  ) {
    final isActive = _activeFilter == filter;
    return Expanded(
      child: TactileSpringContainer(
        haptic: HapticType.selection,
        onTap: () {
          setState(() => _activeFilter = filter);
        },
        child: AnimatedContainer(
          duration: MotionTokens.durationExit,
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: kSpacing8),
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.surfaceContainerHigh
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: context.appColors.shadowMedium,
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
                style: context.ts(
                  12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: kSpacing4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    '$count',
                    style: context.ts(
                      10,
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
  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.sizeOf(context).height * 0.15),
      child: EmptyState(
        icon: PesaFlowIcons.calendar,
        title: 'No Recurring Flows',
        subtitle:
            'Add recurring bills, subscriptions, or income\nstreams to track them automatically.',
        action: FilledButton.icon(
          onPressed: () => context.push('/recurring/add'),
          icon: const Icon(PesaFlowIcons.add, size: 18),
          label: Text(context.l10n.add_recurring_flow),
        ),
      ),
    );
  }

  // ── Recurring Item Tile ─────────────────────────────────────────────────
  Widget _buildRecurringTile(
    BuildContext context,
    RecurringTransaction recurring,
    ThemeData theme,
    bool isDue,
    Color? categoryColor,
    Map<String, String> accountNames,
    int index,
    int totalCount, {
    bool highlightUpcoming = false,
  }) {
    final isExpense = recurring.type == 'expense';
    final accentColor = isDue
        ? context.appColors.transferColor
        : recurring.status == 'paused'
        ? context.appColors.transferColor
        : recurring.status != 'active'
        ? context.appColors.textMedium
        : categoryColor ??
              (isExpense
                  ? context.appColors.expenseColor
                  : context.appColors.incomeColor);
    final mutedAccent = categoryColor != null
        ? desaturateColor(accentColor)
        : accentColor;

    final nextDateLabel = relativeDayLabel(recurring.nextDate);

    final Widget card = TactileSpringContainer(
      onTap: () => context.push('/recurring/${recurring.id}/edit'),
      selectedColor: theme.colorScheme.onSurface,
      child: Container(
        decoration: highlightUpcoming
            ? BoxDecoration(
                color: const Color(0xFFB45309).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              )
            : null,
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(kSpacing14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Icon
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: mutedAccent.withValues(
                          alpha: context.appColors.badgeFillAlpha,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.squircleRadius(38),
                        ),
                      ),
                      child: Icon(
                        isExpense
                            ? PesaFlowIcons.arrowUp
                            : PesaFlowIcons.arrowDown,
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
                                  style: context.ts(
                                    14,
                                    fontWeight: FontWeight.bold,
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
                                style: context.ts(
                                  11,
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
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.squircleRadius(3),
                                  ),
                                ),
                              ),
                              Icon(
                                PesaFlowIcons.calendar,
                                size: 11,
                                color: isDue
                                    ? context.appColors.transferColor
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.4,
                                      ),
                              ),
                              const SizedBox(width: kSpacing4),
                              Text(
                                nextDateLabel,
                                style: context.ts(
                                  11,
                                  fontWeight: isDue
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isDue
                                      ? context.appColors.transferColor
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
                      style: context.ts(14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                // Payment stats (for auto-matched expenses)
                if (isExpense && recurring.paymentCount > 0) ...[
                  const SizedBox(height: kSpacing10),
                  Divider(
                    height: 0.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                  ),
                  const SizedBox(height: kSpacing10),
                  Row(
                    children: [
                      Icon(
                        PesaFlowIcons.analytics,
                        size: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      const SizedBox(width: kSpacing6),
                      Text(
                        'Paid ${CurrencyFormatter.formatCents(recurring.totalPaid)}',
                        style: context.ts(
                          11,
                          fontWeight: FontWeight.w600,
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
                          borderRadius: BorderRadius.circular(
                            AppTheme.squircleRadius(3),
                          ),
                        ),
                      ),
                      Text(
                        '${recurring.paymentCount} payment${recurring.paymentCount > 1 ? 's' : ''}',
                        style: context.ts(
                          11,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (recurring.lastPaidAt != null)
                        Text(
                          'Last: ${recurring.lastPaidAt!.day}/${recurring.lastPaidAt!.month}',
                          style: context.ts(
                            10,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                // Mark Paid action for due items
                if (isDue) ...[
                  const SizedBox(height: kSpacing10),
                  if (isExpense && recurring.paymentCount > 0)
                    Divider(
                      height: 0.5,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.06,
                      ),
                    ),
                  const SizedBox(height: kSpacing10),
                  TactileSpringContainer(
                    haptic: HapticType.soft,
                    onTap: () {
                      showMarkRecurringPaymentSheet(
                        context: context,
                        ref: ref,
                        recurring: recurring,
                        accountName:
                            accountNames[recurring.accountId] ?? 'Unknown',
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kSpacing12,
                        vertical: kSpacing6,
                      ),
                      decoration: BoxDecoration(
                        color: context.appColors.incomeColor.withValues(
                          alpha: context.appColors.badgeFillAlpha,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusPill,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PesaFlowIcons.success,
                            size: 14,
                            color: context.appColors.incomeColor,
                          ),
                          const SizedBox(width: kSpacing6),
                          Text(
                            'Mark Paid',
                            style: context.ts(
                              11,
                              fontWeight: FontWeight.w700,
                              color: context.appColors.incomeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (index < totalCount - 1)
            Divider(
              height: 1,
              thickness: 0.5,
              color: context.appColors.hairline,
              indent: 14 + 38 + 12,
            ),
        ],
      ),
      ),
    );

    if (isDue) {
      return _DueItemPulse(child: card);
    }
    return card;
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
          padding: const EdgeInsets.symmetric(
            horizontal: kSpacing6,
            vertical: kSpacing2,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(
              alpha: context.appColors.badgeFillAlpha,
            ),
            borderRadius: BorderRadius.circular(AppTheme.squircleRadius(14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PesaFlowIcons.bolt,
                size: 9,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: kSpacing2),
              Text(
                'Auto',
                style: context.ts(
                  10,
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
      'active' => ('Active', context.appColors.incomeColor),
      'paused' => ('Paused', context.appColors.transferColor),
      'cancelled' => ('Cancelled', context.appColors.textMedium),
      _ => (recurring.status, context.appColors.textMedium),
    };

    badges.add(
      Container(
        margin: const EdgeInsets.only(left: kSpacing4),
        padding: const EdgeInsets.symmetric(
          horizontal: kSpacing8,
          vertical: kSpacing2,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Text(
          label,
          style: context.ts(10, fontWeight: FontWeight.w700, color: color),
        ),
      ),
    );

    final desc = (recurring.description ?? '').toLowerCase();
    final kw = (recurring.merchantKeywords ?? '').toLowerCase();
    final isFlex =
        desc.contains('luku') ||
        desc.contains('dawasa') ||
        kw.contains('luku') ||
        kw.contains('dawasa');
    if (isFlex) {
      badges.add(
        Container(
          margin: const EdgeInsets.only(left: kSpacing4),
          padding: const EdgeInsets.symmetric(
            horizontal: kSpacing6,
            vertical: kSpacing2,
          ),
          decoration: BoxDecoration(
            color: const Color(
              0xFFF59E0B,
            ).withValues(alpha: context.appColors.badgeFillAlpha),
            borderRadius: BorderRadius.circular(AppTheme.squircleRadius(14)),
          ),
          child: Text(
            'Flex',
            style: context.ts(
              10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF59E0B),
            ),
          ),
        ),
      );
    }

    return badges;
  }
}

class _DueItemPulse extends StatelessWidget {
  final Widget child;
  const _DueItemPulse({required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
