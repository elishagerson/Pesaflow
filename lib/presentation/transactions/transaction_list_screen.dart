import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/app_illustrations.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/domain/analytics/insight_generator.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/empty_state.dart';
import 'package:pesaflow/presentation/common/widgets/glass_list_container.dart';
import 'package:pesaflow/presentation/common/widgets/hero_card_route.dart';
import 'package:pesaflow/presentation/common/widgets/ios_large_title_header.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/motion/skeleton_crossfade.dart';
import 'package:pesaflow/presentation/common/widgets/premium_fab.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_list.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/undo_delete.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/transactions/transaction_detail_screen.dart';
import 'package:pesaflow/presentation/transactions/widgets/transaction_filter_sheet.dart';
import 'package:pesaflow/presentation/common/widgets/spring_sheet_route.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() =>
      _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen>
    with AutomaticKeepAliveClientMixin {
  Timer? _searchDebounce;
  late TextEditingController _searchController;
  bool _isSearchVisible = false;
  Set<String> _previousTransactionIds = {};
  bool _isFirstBuild = true;
  final Set<String> _pendingDeleteIds = {};
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.offset <= 0) return;
    if (context.isReducedMotion) {
      _scrollController.jumpTo(0);
    } else {
      _scrollController.animateTo(
        0,
        duration: MotionTokens.durationNormal,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showTransactionActions(
    BuildContext context,
    TransactionWithCategory item,
  ) {
    final trans = item.transaction;
    final theme = Theme.of(context);
    showSpringSheet(
      context,
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpacing20,
            vertical: kSpacing16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                trans.description.isNotEmpty
                    ? trans.description
                    : item.category.name,
                style: context.ts(17, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: kSpacing4),
              Text(
                '${CurrencyFormatter.formatCents(trans.amount)} • ${item.category.name}',
                style: context.ts(
                  13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: kSpacing16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    PesaFlowIcons.info,
                    color: theme.colorScheme.primary,
                    size: 18,
                  ),
                ),
                title: Text(
                  'View Details',
                  style: context.ts(15, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  context.push('/transactions/${trans.id}');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    PesaFlowIcons.edit,
                    color: theme.colorScheme.secondary,
                    size: 18,
                  ),
                ),
                title: Text(
                  'Edit',
                  style: context.ts(15, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  context.push('/transactions/${trans.id}');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    PesaFlowIcons.delete,
                    color: theme.colorScheme.error,
                    size: 18,
                  ),
                ),
                title: Text(
                  'Delete',
                  style: context.ts(
                    15,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.error,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  setState(() {
                    _pendingDeleteIds.add(trans.id);
                  });
                  UndoDelete.show(
                    context: context,
                    entityName: 'Transaction',
                    onUndo: () async {
                      setState(() {
                        _pendingDeleteIds.remove(trans.id);
                      });
                      await ref
                          .read(transactionRepositoryProvider)
                          .createTransaction(trans);
                    },
                    onDelete: () async {
                      setState(() {
                        _pendingDeleteIds.remove(trans.id);
                      });
                      await ref
                          .read(transactionRepositoryProvider)
                          .deleteTransaction(trans.id);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatHeaderDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final compareDate = DateTime(date.year, date.month, date.day);

    if (compareDate == today) {
      return 'Today';
    } else if (compareDate == yesterday) {
      return 'Yesterday';
    } else if (date.year == now.year) {
      return DateFormat('EEE, MMM d').format(date);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(scrollToTopProvider, (_, _) => _scrollToTop());
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    // Watch filters
    final activeType = ref.watch(transactionTypeFilterProvider);
    final activeAccount = ref.watch(transactionAccountFilterProvider);
    final activeCategory = ref.watch(transactionCategoryFilterProvider);
    final searchQuery = ref.watch(transactionSearchQueryProvider);
    if (_searchController.text != searchQuery) {
      _searchController.text = searchQuery;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: searchQuery.length),
      );
    }
    final amountMin = ref.watch(transactionAmountMinProvider);
    final amountMax = ref.watch(transactionAmountMaxProvider);
    final dateFrom = ref.watch(transactionDateFromProvider);
    final dateTo = ref.watch(transactionDateToProvider);

    // Watch streams/futures
    final transactionsAsync = ref.watch(filteredTransactionsStreamProvider);
    final accounts = ref.watch(accountsStreamProvider).value ?? [];
    final categories = ref.watch(categoriesFutureProvider).value ?? [];

    final isFiltered =
        activeAccount != null ||
        activeCategory != null ||
        searchQuery.isNotEmpty ||
        activeType != 'All' ||
        amountMin != null ||
        amountMax != null ||
        dateFrom != null ||
        dateTo != null;

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: kSpacing80),
        child: PremiumExtendedFab(
          label: 'New Transaction',
          onPressed: () {
            PesaHaptics.medium();
            context.push('/transactions/add');
          },
        ),
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── TOP HEADER (LARGE TITLE) ──
            IosLargeTitleHeader(
              title: 'Transactions',
              scrollController: _scrollController,
              actions: [
                if (isFiltered)
                  IconButton(
                    icon: Icon(
                      PesaFlowIcons.clearAll,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    tooltip: 'Clear All Filters',
                    onPressed: () {
                      ref.read(transactionTypeFilterProvider.notifier).state =
                          'All';
                      ref
                          .read(transactionAccountFilterProvider.notifier)
                          .state = null;
                      ref
                          .read(transactionCategoryFilterProvider.notifier)
                          .state = null;
                      ref
                          .read(transactionSearchQueryProvider.notifier)
                          .state = '';
                      ref.read(transactionAmountMinProvider.notifier).state =
                          null;
                      ref.read(transactionAmountMaxProvider.notifier).state =
                          null;
                      ref.read(transactionDateFromProvider.notifier).state =
                          null;
                      ref.read(transactionDateToProvider.notifier).state =
                          null;
                    },
                  ),
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(
                      AppTheme.radiusHero,
                    ),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.2),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FilterButton(
                        isActive: isFiltered,
                        activeCount: [
                          if (activeType != 'All') 1,
                          if (activeAccount != null) 1,
                          if (activeCategory != null) 1,
                          if (searchQuery.isNotEmpty) 1,
                          if (amountMin != null || amountMax != null) 1,
                          if (dateFrom != null || dateTo != null) 1,
                        ].length,
                        onPressed: () =>
                            showTransactionFilterSheet(context, ref),
                      ),
                      Container(
                        width: 1,
                        height: 18,
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.3),
                      ),
                      TactileSpringContainer(
                        onTap: () {
                          setState(() {
                            _isSearchVisible = !_isSearchVisible;
                            if (!_isSearchVisible) {
                              _searchController.clear();
                              ref
                                  .read(
                                    transactionSearchQueryProvider.notifier,
                                  )
                                  .state = '';
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Icon(
                            PesaFlowIcons.search,
                            size: 17,
                            color: _isSearchVisible || searchQuery.isNotEmpty
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: kSpacing16),
              ],
            ),

            // ── SEARCH FIELD ──
            AnimatedSize(
              duration: MotionTokens.durationNormal,
              curve: Curves.fastOutSlowIn,
              child: _isSearchVisible || searchQuery.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(
                        kSpacing16,
                        kSpacing8,
                        kSpacing16,
                        kSpacing8,
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: _isSearchVisible,
                        onChanged: (val) {
                          _searchDebounce?.cancel();
                          _searchDebounce = Timer(
                            MotionTokens.durationNormal,
                            () {
                              ref
                                  .read(
                                    transactionSearchQueryProvider.notifier,
                                  )
                                  .state = val.trim();
                            },
                          );
                        },
                        decoration: context.inputDecoration(
                          hintText: 'Search transactions, accounts, notes...',
                          prefixIcon: const Icon(
                            PesaFlowIcons.search,
                            size: 20,
                          ),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  tooltip: 'Clear search',
                                  icon: Icon(
                                    PesaFlowIcons.clear,
                                    size: 16,
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.6),
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref
                                        .read(
                                          transactionSearchQueryProvider
                                              .notifier,
                                        )
                                        .state = '';
                                  },
                                )
                              : null,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // ── TYPE FILTER BAR ──
            Padding(
              padding: const EdgeInsets.only(top: kSpacing4, bottom: kSpacing6),
              child: SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: kSpacing16),
                  children: ['All', 'Income', 'Expense', 'Transfer']
                      .map((type) {
                    final isSelected = activeType == type;
                    return Padding(
                      padding: const EdgeInsets.only(right: kSpacing8),
                      child: TactileSpringContainer(
                        onTap: () {
                          ref
                              .read(transactionTypeFilterProvider.notifier)
                              .state = type;
                        },
                        child: AnimatedContainer(
                          duration: MotionTokens.durationFast,
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusPill,
                            ),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.25),
                              width: 1.0,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            type,
                            style: context.ts(
                              13,
                              color: isSelected
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // ── ACTIVE SECONDARY FILTERS BAR ──
            _buildActiveFiltersBar(
              context,
              ref,
              activeAccount: activeAccount,
              activeCategory: activeCategory,
              dateFrom: dateFrom,
              dateTo: dateTo,
              amountMin: amountMin,
              amountMax: amountMax,
              accounts: accounts,
              categories: categories,
            ),

            const SizedBox(height: kSpacing4),
            Divider(
              height: 1,
              thickness: 0.5,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),

            // ── SCROLLABLE LIST VIEW LAYER ──
            Expanded(
              child: RefreshIndicator(
                color: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surface,
                onRefresh: () async {
                  ref.invalidate(filteredTransactionsStreamProvider);
                  ref.invalidate(recentTransactionsStreamProvider);
                  ref.invalidate(accountsStreamProvider);
                },
                child: SkeletonCrossfade(
                  isLoading: transactionsAsync is AsyncLoading &&
                      !transactionsAsync.hasValue,
                  skeleton: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: kSpacing16,
                      vertical: kSpacing12,
                    ),
                    child: Column(
                      children: [
                        SkeletonCard(height: 80),
                        SizedBox(height: kSpacing8),
                        SkeletonCard(height: 80),
                        SizedBox(height: kSpacing8),
                        SkeletonCard(height: 80),
                        SizedBox(height: kSpacing8),
                        SkeletonCard(height: 80),
                      ],
                    ),
                  ),
                  child: transactionsAsync.when(
                    data: (transactionsList) {
                      final visibleTransactions = transactionsList
                          .where(
                            (t) =>
                                !_pendingDeleteIds.contains(t.transaction.id),
                          )
                          .toList();
                      if (visibleTransactions.isEmpty) {
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Center(
                                  child: StaggeredFadeSlide(
                                    index: 0,
                                    child: EmptyState(
                                      icon: isFiltered
                                          ? PesaFlowIcons.search
                                          : PesaFlowIcons.transactions,
                                      title: isFiltered
                                          ? 'No Transactions Found'
                                          : 'No Transactions Recorded',
                                      subtitle: isFiltered
                                          ? 'Try adjusting your filters or typing a different query.'
                                          : 'Start logging your offline financial transactions to track your spending habits.',
                                      illustration: PesaFlowIllustration
                                          .emptyTransactions(),
                                      action: TactileSpringContainer(
                                        onTap: () {
                                          if (isFiltered) {
                                            ref
                                                .read(
                                                  transactionTypeFilterProvider
                                                      .notifier,
                                                )
                                                .state = 'All';
                                            ref
                                                .read(
                                                  transactionAccountFilterProvider
                                                      .notifier,
                                                )
                                                .state = null;
                                            ref
                                                .read(
                                                  transactionCategoryFilterProvider
                                                      .notifier,
                                                )
                                                .state = null;
                                            ref
                                                .read(
                                                  transactionSearchQueryProvider
                                                      .notifier,
                                                )
                                                .state = '';
                                            ref
                                                .read(
                                                  transactionAmountMinProvider
                                                      .notifier,
                                                )
                                                .state = null;
                                            ref
                                                .read(
                                                  transactionAmountMaxProvider
                                                      .notifier,
                                                )
                                                .state = null;
                                            ref
                                                .read(
                                                  transactionDateFromProvider
                                                      .notifier,
                                                )
                                                .state = null;
                                            ref
                                                .read(
                                                  transactionDateToProvider
                                                      .notifier,
                                                )
                                                .state = null;
                                          } else {
                                            context.push('/transactions/add');
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary,
                                            borderRadius:
                                                BorderRadius.circular(
                                              AppTheme.radiusPill,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: theme
                                                    .colorScheme
                                                    .primary
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isFiltered
                                                    ? PesaFlowIcons.clearAll
                                                    : PesaFlowIcons.add,
                                                color:
                                                    theme.colorScheme.onPrimary,
                                                size: 20,
                                              ),
                                              const SizedBox(width: kSpacing8),
                                              Text(
                                                isFiltered
                                                    ? 'Clear Filters'
                                                    : 'Add First Transaction',
                                                style: context.ts(
                                                  14,
                                                  fontWeight: FontWeight.bold,
                                                  color: theme
                                                      .colorScheme
                                                      .onPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }

                      // Track new transactions for highlight animation
                      final Set<String> currentIds = visibleTransactions
                          .map((t) => t.transaction.id)
                          .toSet();
                      final Set<String> newIds = _isFirstBuild
                          ? <String>{}
                          : currentIds.difference(_previousTransactionIds);
                      _previousTransactionIds = currentIds;
                      _isFirstBuild = false;

                      // Group items by calendar day
                      final Map<String, List<TransactionWithCategoryAndAccount>>
                          grouped = {};
                      for (final item in visibleTransactions) {
                        final dayStr = DateFormat(
                          'yyyy-MM-dd',
                        ).format(item.transaction.createdAt);
                        if (grouped[dayStr] == null) {
                          grouped[dayStr] = [];
                        }
                        grouped[dayStr]!.add(item);
                      }

                      final sortedDays = grouped.keys.toList()
                        ..sort((a, b) => b.compareTo(a));

                      return StaggeredList(
                        controller: _scrollController,
                        key: const PageStorageKey('transaction_list'),
                        shrinkWrap: false,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          kSpacing16,
                          kSpacing8,
                          kSpacing16,
                          110.0,
                        ),
                        itemCount: sortedDays.length + 1,
                        itemBuilder: (context, dayIndex) {
                          // Append insights card at the end of the transactions list
                          if (dayIndex == sortedDays.length) {
                            return _buildInsightsCard(context, ref);
                          }

                          final dayStr = sortedDays[dayIndex];
                          final dayItems = grouped[dayStr]!;
                          final firstItemDate =
                              dayItems.first.transaction.createdAt;

                          // Calculate daily net balance change (income - expense)
                          int dailyNetChange = 0;
                          for (final item in dayItems) {
                            final type = item.transaction.type.toLowerCase();
                            if (type == 'income') {
                              dailyNetChange += item.transaction.amount;
                            } else if (type == 'expense' ||
                                type == 'airtime' ||
                                type == 'fee') {
                              dailyNetChange -= item.transaction.amount;
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Group Date Header
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  kSpacing4,
                                  kSpacing16,
                                  kSpacing4,
                                  kSpacing8,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatHeaderDate(firstItemDate),
                                      style: context.ts(
                                        13,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    // Monospace Net Change Indicator
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: kSpacing8,
                                        vertical: kSpacing2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (dailyNetChange > 0
                                                ? context.appColors.incomeColor
                                                : (dailyNetChange < 0
                                                    ? context
                                                        .appColors
                                                        .expenseColor
                                                    : theme
                                                        .colorScheme
                                                        .onSurfaceVariant))
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusPill,
                                        ),
                                      ),
                                      child: AmountText(
                                        amountInCents: dailyNetChange.abs(),
                                        type: dailyNetChange > 0
                                            ? AmountType.income
                                            : (dailyNetChange < 0
                                                ? AmountType.expense
                                                : AmountType.neutral),
                                        style: context.ts(
                                          12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Transaction Items as single group GlassListContainer
                              GlassListContainer(
                                child: Column(
                                  children: dayItems
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final item = entry.value;
                                    final trans = item.transaction;

                                    AmountType amtType = AmountType.neutral;
                                    if (trans.type.toLowerCase() == 'income') {
                                      amtType = AmountType.income;
                                    } else if (trans.type.toLowerCase() ==
                                            'expense' ||
                                        trans.type.toLowerCase() == 'airtime' ||
                                        trans.type.toLowerCase() == 'fee') {
                                      amtType = AmountType.expense;
                                    }

                                    final categoryColor = hexToColor(
                                      item.category.color,
                                    );
                                    final formattedTime = DateFormat(
                                      'HH:mm',
                                    ).format(trans.createdAt);
                                    final isNewRow = newIds.contains(trans.id);

                                    final Widget row = Dismissible(
                                      key: Key(trans.id),
                                      direction: DismissDirection.endToStart,
                                        background: Container(
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.only(
                                            right: kSpacing20,
                                          ),
                                          color: theme.colorScheme.error,
                                          child: Icon(
                                            PesaFlowIcons.delete,
                                            color: theme.colorScheme.onError,
                                          ),
                                        ),
                                        confirmDismiss: (_) async {
                                          return await ModernDialog.show<bool>(
                                                context: context,
                                                title: const Text(
                                                  'Delete Transaction',
                                                ),
                                                titleIcon:
                                                    PesaFlowIcons.warning,
                                                iconColor: context
                                                    .appColors
                                                    .expenseColor,
                                                content: const Text(
                                                  'This action cannot be undone.',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                      context,
                                                      rootNavigator: true,
                                                    ).pop(false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  ElevatedButton(
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                      backgroundColor: context
                                                          .appColors
                                                          .expenseColor,
                                                    ),
                                                    onPressed: () =>
                                                        Navigator.of(
                                                      context,
                                                      rootNavigator: true,
                                                    ).pop(true),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ) ??
                                              false;
                                        },
                                        onDismissed: (_) {
                                          final tx = trans;
                                          setState(() {
                                            _pendingDeleteIds.add(tx.id);
                                          });
                                          UndoDelete.show(
                                            context: context,
                                            entityName: 'Transaction',
                                            onUndo: () async {
                                              setState(() {
                                                _pendingDeleteIds.remove(tx.id);
                                              });
                                              await ref
                                                  .read(
                                                    transactionRepositoryProvider,
                                                  )
                                                  .createTransaction(tx);
                                            },
                                            onDelete: () async {
                                              setState(() {
                                                _pendingDeleteIds.remove(tx.id);
                                              });
                                              await ref
                                                  .read(
                                                    transactionRepositoryProvider,
                                                  )
                                                  .deleteTransaction(tx.id);
                                            },
                                          );
                                        },
                                        child: TactileSpringContainer(
                                          onTap: () {
                                            pushHeroCard(
                                              context,
                                              TransactionDetailScreen(
                                                transactionId: trans.id,
                                              ),
                                              'transaction_${trans.id}',
                                            );
                                          },
                                          onLongPress: () => _showTransactionActions(context, item),
                                          selectedColor:
                                              theme.colorScheme.onSurface,
                                          child: Hero(
                                            tag: 'transaction_${trans.id}',
                                            child: Semantics(
                                              label:
                                                  '${trans.description.isNotEmpty ? trans.description : item.category.name}, ${CurrencyFormatter.formatCents(trans.amount)} ${trans.type}',
                                              button: true,
                                              child: Column(
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: kSpacing16,
                                                      vertical: kSpacing12,
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          width: 38,
                                                          height: 38,
                                                          alignment:
                                                              Alignment.center,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: categoryColor
                                                                .withValues(
                                                              alpha: 0.12,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                              10,
                                                            ),
                                                          ),
                                                          child: Icon(
                                                            getCategoryIcon(
                                                              item.category.icon,
                                                            ),
                                                            color: categoryColor,
                                                            size: 18,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: kSpacing12,
                                                        ),
                                                        // Content
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                trans.description
                                                                        .isNotEmpty
                                                                    ? trans
                                                                        .description
                                                                    : item
                                                                        .category
                                                                        .name,
                                                                style: context.ts(
                                                                  14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color:
                                                                      onSurface,
                                                                ),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                              const SizedBox(
                                                                height: 2,
                                                              ),
                                                              Row(
                                                                children: [
                                                                  Text(
                                                                    item.account
                                                                            ?.name ??
                                                                        'Offline',
                                                                    style: context.ts(
                                                                      11,
                                                                      color: theme
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                    ),
                                                                  ),
                                                                  if (trans.reference !=
                                                                          null &&
                                                                      trans
                                                                          .reference!
                                                                          .isNotEmpty) ...[
                                                                    const SizedBox(
                                                                      width:
                                                                          kSpacing6,
                                                                    ),
                                                                    Text(
                                                                      '•',
                                                                      style: context.ts(
                                                                          13,
                                                                          color:
                                                                              onSurface.withValues(alpha: 0.11)),
                                                                    ),
                                                                    const SizedBox(
                                                                      width:
                                                                          kSpacing6,
                                                                    ),
                                                                    Flexible(
                                                                      child:
                                                                          Text(
                                                                        trans
                                                                            .reference!,
                                                                        style: context.ts(
                                                                            13,
                                                                            color:
                                                                                onSurface.withValues(alpha: 0.34)),
                                                                        maxLines:
                                                                            1,
                                                                        overflow:
                                                                            TextOverflow
                                                                                .ellipsis,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                  if (trans.source
                                                                      .startsWith(
                                                                    'sms',
                                                                  )) ...[
                                                                    const SizedBox(
                                                                      width:
                                                                          kSpacing6,
                                                                    ),
                                                                    Container(
                                                                      padding: const EdgeInsets
                                                                          .symmetric(
                                                                        horizontal:
                                                                            kSpacing6,
                                                                        vertical:
                                                                            kSpacing2,
                                                                      ),
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        color: theme
                                                                            .colorScheme
                                                                            .primary
                                                                            .withValues(
                                                                              alpha:
                                                                                  0.05,
                                                                            ),
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                          kSpacing6,
                                                                        ),
                                                                      ),
                                                                      child:
                                                                          Icon(
                                                                        PesaFlowIcons
                                                                            .sms,
                                                                        size:
                                                                            11,
                                                                        color: theme
                                                                            .colorScheme
                                                                            .primary,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ],
                                                             ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: kSpacing12,
                                                        ),
                                                        // Amount & Time
                                                        Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .end,
                                                          children: [
                                                            AmountText(
                                                              amountInCents:
                                                                  trans.amount,
                                                              type: amtType,
                                                              showDecimals:
                                                                  true,
                                                              style: context.ts(
                                                                14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: amtType ==
                                                                        AmountType
                                                                            .income
                                                                    ? context
                                                                        .appColors
                                                                        .incomeColor
                                                                    : (amtType ==
                                                                            AmountType
                                                                                .expense
                                                                        ? context
                                                                            .appColors
                                                                            .expenseColor
                                                                        : theme
                                                                            .colorScheme
                                                                            .onSurfaceVariant),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            Text(
                                                              formattedTime,
                                                              style: context.ts(
                                                                10,
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (index <
                                                      dayItems.length - 1)
                                                    Divider(
                                                      height: 1,
                                                      thickness: 0.5,
                                                      color: onSurface
                                                          .withValues(
                                                              alpha: 0.06),
                                                      indent: 68,
                                                      endIndent: 16,
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                      if (isNewRow) {
                                      return _NewRowHighlight(child: row);
                                    }
                                    return row;
                                  }).toList(),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (err, _) =>
                        Center(child: Text('Error loading transactions: $err')),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ACTIVE FILTERS BAR BUILDER ──
  Widget _buildActiveFiltersBar(
    BuildContext context,
    WidgetRef ref, {
    required String? activeAccount,
    required String? activeCategory,
    required DateTime? dateFrom,
    required DateTime? dateTo,
    required int? amountMin,
    required int? amountMax,
    required List<Account> accounts,
    required List<Category> categories,
  }) {
    final theme = Theme.of(context);
    final hasSecondaryFilters = activeAccount != null ||
        activeCategory != null ||
        dateFrom != null ||
        dateTo != null ||
        amountMin != null ||
        amountMax != null;

    if (!hasSecondaryFilters) return const SizedBox.shrink();

    final chips = <Widget>[];

    if (activeAccount != null) {
      final acc = accounts.where((a) => a.id == activeAccount).firstOrNull;
      final name = acc?.name ?? 'Account';
      chips.add(_FilterChip(
        icon: PesaFlowIcons.wallet,
        label: name,
        onDeleted: () =>
            ref.read(transactionAccountFilterProvider.notifier).state = null,
      ));
    }

    if (activeCategory != null) {
      final cat = categories.where((c) => c.id == activeCategory).firstOrNull;
      final name = cat?.name ?? 'Category';
      chips.add(_FilterChip(
        icon: PesaFlowIcons.category,
        label: name,
        onDeleted: () =>
            ref.read(transactionCategoryFilterProvider.notifier).state = null,
      ));
    }

    if (dateFrom != null || dateTo != null) {
      final String dateLabel;
      if (dateFrom != null && dateTo != null) {
        dateLabel =
            '${DateFormat('MMM d').format(dateFrom)} - ${DateFormat('MMM d').format(dateTo)}';
      } else if (dateFrom != null) {
        dateLabel = 'From ${DateFormat('MMM d').format(dateFrom)}';
      } else {
        dateLabel = 'Until ${DateFormat('MMM d').format(dateTo!)}';
      }
      chips.add(_FilterChip(
        icon: PesaFlowIcons.calendar,
        label: dateLabel,
        onDeleted: () {
          ref.read(transactionDateFromProvider.notifier).state = null;
          ref.read(transactionDateToProvider.notifier).state = null;
        },
      ));
    }

    if (amountMin != null || amountMax != null) {
      final String amountLabel;
      if (amountMin != null && amountMax != null) {
        amountLabel =
            '${CurrencyFormatter.formatCompact(amountMin)} - ${CurrencyFormatter.formatCompact(amountMax)}';
      } else if (amountMin != null) {
        amountLabel = '>= ${CurrencyFormatter.formatCompact(amountMin)}';
      } else {
        amountLabel = '<= ${CurrencyFormatter.formatCompact(amountMax!)}';
      }
      chips.add(_FilterChip(
        icon: PesaFlowIcons.analytics,
        label: amountLabel,
        onDeleted: () {
          ref.read(transactionAmountMinProvider.notifier).state = null;
          ref.read(transactionAmountMaxProvider.notifier).state = null;
        },
      ));
    }

    if (chips.length > 1) {
      chips.add(
        TactileSpringContainer(
          onTap: () {
            ref.read(transactionAccountFilterProvider.notifier).state = null;
            ref.read(transactionCategoryFilterProvider.notifier).state = null;
            ref.read(transactionDateFromProvider.notifier).state = null;
            ref.read(transactionDateToProvider.notifier).state = null;
            ref.read(transactionAmountMinProvider.notifier).state = null;
            ref.read(transactionAmountMaxProvider.notifier).state = null;
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: kSpacing10,
              vertical: kSpacing6,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  PesaFlowIcons.clearAll,
                  size: 13,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: kSpacing4),
                Text(
                  'Reset Filters',
                  style: context.ts(
                    11,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: kSpacing6),
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: kSpacing16),
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: kSpacing6),
          itemBuilder: (_, index) => chips[index],
        ),
      ),
    );
  }

  // ── INSIGHTS CARD BUILDER ──
  Widget _buildInsightsCard(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final insightsAsync = ref.watch(insightsProvider);
    final monthlyTotalsAsync = ref.watch(monthlyTotalsProvider);

    return insightsAsync.maybeWhen(
      data: (insights) {
        final String title;
        final String message;
        final InsightSeverity severity;

        if (insights.isNotEmpty) {
          title = insights.first.title;
          message = insights.first.message;
          severity = insights.first.severity;
        } else {
          title = 'Spend Analysis Complete';
          message =
              "You saved 12% more than last month in the 'Dining' category.";
          severity = InsightSeverity.positive;
        }

        final Color accentColor = switch (severity) {
          InsightSeverity.positive => context.appColors.incomeColor,
          InsightSeverity.neutral => context.appColors.transferColor,
          InsightSeverity.warning => context.appColors.expenseColor,
          InsightSeverity.critical => context.appColors.expenseColor,
        };

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            0,
            kSpacing20,
            0,
            kSpacing24,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppTheme.radiusDialog),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.appColors.shadowMedium.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(kSpacing20),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kSpacing8,
                          vertical: kSpacing2,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusPill),
                        ),
                        child: Text(
                          'EXECUTIVE INSIGHT',
                          style: context.ts(
                            9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: kSpacing8),
                      Text(
                        title,
                        style: context.ts(
                          17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.4,
                          color: theme.colorScheme.onSurface,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: kSpacing6),
                      Text(
                        message,
                        style: context.ts(
                          12,
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: kSpacing16),
                Expanded(
                  flex: 2,
                  child: monthlyTotalsAsync.when(
                    data: (totals) {
                      final incomeCents = totals['income'] ?? 0;
                      final expenseCents = totals['expense'] ?? 0;
                      final maxCents = [
                        incomeCents,
                        expenseCents,
                        1,
                      ].reduce((a, b) => a > b ? a : b);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _MiniBar(
                            label: 'Income',
                            valueCents: incomeCents,
                            maxCents: maxCents,
                            color: context.appColors.incomeColor,
                          ),
                          const SizedBox(height: kSpacing10),
                          _MiniBar(
                            label: 'Expense',
                            valueCents: expenseCents,
                            maxCents: maxCents,
                            color: accentColor,
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onDeleted;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        kSpacing10,
        kSpacing4,
        kSpacing6,
        kSpacing4,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: kSpacing6),
          Text(
            label,
            style: context.ts(
              11,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: kSpacing4),
          TactileSpringContainer(
            onTap: onDeleted,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                PesaFlowIcons.clear,
                size: 12,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final bool isActive;
  final int activeCount;
  final VoidCallback onPressed;

  const _FilterButton({
    required this.isActive,
    required this.activeCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return TactileSpringContainer(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              PesaFlowIcons.filter,
              color: isActive
                  ? theme.colorScheme.primary
                  : onSurface.withValues(alpha: 0.5),
              size: 17,
            ),
            if (isActive && activeCount > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  width: 14,
                  height: 14,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$activeCount',
                    style: context.ts(
                      8,
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final String label;
  final int valueCents;
  final int maxCents;
  final Color color;

  const _MiniBar({
    required this.label,
    required this.valueCents,
    required this.maxCents,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction =
        maxCents > 0 ? (valueCents / maxCents).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              label,
              style: context.ts(
                11,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              CurrencyFormatter.formatCompact(valueCents),
              style: context.ts(
                11,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: kSpacing4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction),
            duration: MotionTokens.durationNormal,
            curve: Curves.easeOutCubic,
            builder: (context, val, _) {
              return Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: val,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NewRowHighlight extends StatefulWidget {
  final Widget child;
  const _NewRowHighlight({required this.child});

  @override
  State<_NewRowHighlight> createState() => _NewRowHighlightState();
}

class _NewRowHighlightState extends State<_NewRowHighlight>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _animation = _controller.drive(Tween<double>(begin: 0.12, end: 0));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (context.isReducedMotion) {
        _controller.value = 1.0;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highlightColor = context.appColors.incomeColor;

    return AnimatedBuilder(
      animation: _animation,
      builder: (_, child) {
        final alpha = _animation.value;
        return ColoredBox(
          color: highlightColor.withValues(alpha: alpha),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
