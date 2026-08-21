import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pesaflow/core/utils/date_formatter.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/domain/analytics/insight_generator.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/glass_list_container.dart';
import 'package:pesaflow/presentation/common/widgets/premium_fab.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/core/utils/app_illustrations.dart';
import 'package:pesaflow/presentation/common/widgets/empty_state.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_list.dart';
import 'package:pesaflow/presentation/common/widgets/undo_delete.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

import 'package:pesaflow/presentation/state/palette_provider.dart';
import 'package:pesaflow/presentation/transactions/widgets/transaction_filter_sheet.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/motion/skeleton_crossfade.dart';

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
  Set<String> _previousTransactionIds = {};
  bool _isFirstBuild = true;
  final Set<String> _pendingDeleteIds = {};

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
    super.dispose();
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
    } else {
      return DateFormatter.relative(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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

    // Auto-tracking via filteredTransactionsStreamProvider handles all filter changes

    // Watch streams/futures
    final transactionsAsync = ref.watch(filteredTransactionsStreamProvider);

    return Scaffold(
      body: RefreshIndicator(
        color: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.surface,
        onRefresh: () async {
          ref.invalidate(filteredTransactionsStreamProvider);
          ref.invalidate(recentTransactionsStreamProvider);
          ref.invalidate(accountsStreamProvider);
        },
        child: Stack(
          children: [
            // ── TRANSACTIONS LIST LAYER ──
            SkeletonCrossfade(
              isLoading:
                  transactionsAsync is AsyncLoading &&
                  !transactionsAsync.hasValue,
              skeleton: const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: kSpacing20,
                  vertical: kSpacing8,
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
                        (t) => !_pendingDeleteIds.contains(t.transaction.id),
                      )
                      .toList();
                  if (visibleTransactions.isEmpty) {
                    final isFiltered =
                        activeAccount != null ||
                        activeCategory != null ||
                        searchQuery.isNotEmpty ||
                        activeType != 'All' ||
                        amountMin != null ||
                        amountMax != null ||
                        dateFrom != null ||
                        dateTo != null;

                    return StaggeredFadeSlide(
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
                        illustration: PesaFlowIllustration.emptyTransactions(),
                        action: TactileSpringContainer(
                          onTap: () {
                            if (isFiltered) {
                              ref
                                      .read(
                                        transactionTypeFilterProvider.notifier,
                                      )
                                      .state =
                                  'All';
                              ref
                                      .read(
                                        transactionAccountFilterProvider
                                            .notifier,
                                      )
                                      .state =
                                  null;
                              ref
                                      .read(
                                        transactionCategoryFilterProvider
                                            .notifier,
                                      )
                                      .state =
                                  null;
                              ref
                                      .read(
                                        transactionSearchQueryProvider.notifier,
                                      )
                                      .state =
                                  '';
                              ref
                                      .read(
                                        transactionAmountMinProvider.notifier,
                                      )
                                      .state =
                                  null;
                              ref
                                      .read(
                                        transactionAmountMaxProvider.notifier,
                                      )
                                      .state =
                                  null;
                              ref
                                      .read(
                                        transactionDateFromProvider.notifier,
                                      )
                                      .state =
                                  null;
                              ref
                                      .read(transactionDateToProvider.notifier)
                                      .state =
                                  null;
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
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.3,
                                  ),
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
                                  color: theme.colorScheme.onPrimary,
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
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
                    key: const PageStorageKey('transaction_list'),
                    shrinkWrap: false,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 176.0,
                      bottom: 110.0,
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
                                kSpacing16,
                                kSpacing16,
                                kSpacing20,
                                kSpacing12,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatHeaderDate(
                                      firstItemDate,
                                    ).toUpperCase(),
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                          color: onSurface.withValues(
                                            alpha: 0.34,
                                          ),
                                        ),
                                  ),
                                  // Monospace Net Change Indicator
                                  AmountText(
                                    amountInCents: dailyNetChange.abs(),
                                    type: dailyNetChange > 0
                                        ? AmountType.income
                                        : (dailyNetChange < 0
                                              ? AmountType.expense
                                              : AmountType.neutral),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Transaction Items as single group GlassListContainer
                            GlassListContainer(
                              child: Column(
                                children: dayItems.asMap().entries.map((entry) {
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
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: kSpacing20,
                                    vertical: kSpacing6,
                                  ),
                                  padding: const EdgeInsets.only(
                                    right: kSpacing20,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.error,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    PesaFlowIcons.delete,
                                    color: Colors.white,
                                  ),
                                ),
                                confirmDismiss: (_) async {
                                  return await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete transaction?'),
                                      content: const Text(
                                        'This action cannot be undone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: Text(
                                            'Delete',
                                            style: TextStyle(
                                              color: context
                                                  .appColors
                                                  .expenseColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
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
                                          .read(transactionRepositoryProvider)
                                          .createTransaction(tx);
                                    },
                                    onDelete: () async {
                                      setState(() {
                                        _pendingDeleteIds.remove(tx.id);
                                      });
                                      await ref
                                          .read(transactionRepositoryProvider)
                                          .deleteTransaction(tx.id);
                                    },
                                  );
                                },
                                child: TactileSpringContainer(
                                  onTap: () =>
                                      context.push('/transactions/${trans.id}'),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: kSpacing20,
                                          vertical: kSpacing12,
                                        ),
                                        child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        alignment: Alignment.center,
                                        child: Icon(
                                          getCategoryIcon(
                                            item.category.icon,
                                          ),
                                          color: categoryColor,
                                          size: 24,
                                        ),
                                      ),
                                        const SizedBox(width: kSpacing14),
                                        // Content
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                trans.description.isNotEmpty
                                                    ? trans.description
                                                    : item.category.name,
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: onSurface,
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: kSpacing2),
                                              Row(
                                                children: [
                                                  Text(
                                                    item.account?.name ??
                                                        'Offline',
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: onSurface
                                                              .withValues(
                                                                alpha: 0.6,
                                                              ),
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                  if (trans.reference != null &&
                                                      trans
                                                          .reference!
                                                          .isNotEmpty) ...[
                                                    const SizedBox(
                                                      width: kSpacing6,
                                                    ),
                                                    Text(
                                                      '•',
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: onSurface
                                                                .withValues(
                                                                  alpha: 0.11,
                                                                ),
                                                          ),
                                                    ),
                                                    const SizedBox(
                                                      width: kSpacing6,
                                                    ),
                                                    Flexible(
                                                      child: Text(
                                                        trans.reference!,
                                                        style: theme
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: onSurface
                                                                  .withValues(
                                                                    alpha: 0.34,
                                                                  ),
                                                            ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                  if (trans.source.startsWith(
                                                    'sms',
                                                  )) ...[
                                                    const SizedBox(
                                                      width: kSpacing6,
                                                    ),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal:
                                                                kSpacing6,
                                                            vertical: kSpacing2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: theme
                                                            .colorScheme
                                                            .primary
                                                            .withValues(
                                                              alpha: 0.08,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              kSpacing6,
                                                            ),
                                                      ),
                                                      child: Icon(
                                                        PesaFlowIcons.sms,
                                                        size: 11,
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
                                        const SizedBox(width: kSpacing12),
                                        // Amount & Time
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            AmountText(
                                              amountInCents: trans.amount,
                                              type: amtType,
                                              showDecimals: true,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const SizedBox(height: kSpacing4),
                                            Text(
                                              formattedTime,
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    color: onSurface.withValues(
                                                      alpha: 0.25,
                                                    ),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                          ],
                                        ),
                                          ],
                                        ),
                                      ),
                                      if (index < dayItems.length - 1)
                                        Divider(
                                          height: 1,
                                          thickness: 0.5,
                                          color: onSurface.withValues(alpha: 0.08),
                                          indent: 20 + 40 + 14,
                                        ),
                                    ],
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

            // ── HEADER ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: StaggeredFadeSlide(
                index: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.appColors.bgColor.withValues(alpha: 0.98),
                    border: Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                        width: 1.0,
                      ),
                    ),
                  ),
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 16,
                    bottom: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kSpacing20,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Transactions',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                                color: onSurface,
                              ),
                            ),
                            Row(
                              children: [
                                if (activeAccount != null ||
                                    activeCategory != null ||
                                    searchQuery.isNotEmpty ||
                                    activeType != 'All' ||
                                    amountMin != null ||
                                    amountMax != null ||
                                    dateFrom != null ||
                                    dateTo != null)
                                  IconButton(
                                    icon: Icon(
                                      PesaFlowIcons.clearAll,
                                      color: theme.colorScheme.error,
                                      size: 20,
                                    ),
                                    tooltip: 'Clear Filters',
                                    onPressed: () {
                                      ref
                                              .read(
                                                transactionTypeFilterProvider
                                                    .notifier,
                                              )
                                              .state =
                                          'All';
                                      ref
                                              .read(
                                                transactionAccountFilterProvider
                                                    .notifier,
                                              )
                                              .state =
                                          null;
                                      ref
                                              .read(
                                                transactionCategoryFilterProvider
                                                    .notifier,
                                              )
                                              .state =
                                          null;
                                      ref
                                              .read(
                                                transactionSearchQueryProvider
                                                    .notifier,
                                              )
                                              .state =
                                          '';
                                      ref
                                              .read(
                                                transactionAmountMinProvider
                                                    .notifier,
                                              )
                                              .state =
                                          null;
                                      ref
                                              .read(
                                                transactionAmountMaxProvider
                                                    .notifier,
                                              )
                                              .state =
                                          null;
                                      ref
                                              .read(
                                                transactionDateFromProvider
                                                    .notifier,
                                              )
                                              .state =
                                          null;
                                      ref
                                              .read(
                                                transactionDateToProvider
                                                    .notifier,
                                              )
                                              .state =
                                          null;
                                    },
                                  ),
                                _FilterButton(
                                  isActive:
                                      activeAccount != null ||
                                      activeCategory != null ||
                                      amountMin != null ||
                                      amountMax != null ||
                                      dateFrom != null ||
                                      dateTo != null ||
                                      searchQuery.isNotEmpty ||
                                      activeType != 'All',
                                  activeCount: [
                                    if (activeType != 'All') 1,
                                    if (activeAccount != null) 1,
                                    if (activeCategory != null) 1,
                                    if (searchQuery.isNotEmpty) 1,
                                    if (amountMin != null || amountMax != null)
                                      1,
                                    if (dateFrom != null || dateTo != null) 1,
                                  ].length,
                                  onPressed: () =>
                                      showTransactionFilterSheet(context, ref),
                                ),
                                const SizedBox(width: kSpacing8),
                                TactileSpringContainer(
                                  onTap: () => ref
                                      .read(paletteVisibilityProvider.notifier)
                                      .toggle(),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: onSurface.withValues(alpha: 0.04),
                                      border: Border.all(
                                        color: onSurface.withValues(
                                          alpha: 0.08,
                                        ),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Icon(
                                      PesaFlowIcons.search,
                                      size: 18,
                                      color: onSurface.withValues(alpha: 0.62),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: kSpacing8),
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: onSurface.withValues(alpha: 0.04),
                                    border: Border.all(
                                      color: onSurface.withValues(alpha: 0.08),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Icon(
                                    PesaFlowIcons.personOutline,
                                    size: 18,
                                    color: onSurface.withValues(alpha: 0.62),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: kSpacing16),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kSpacing20,
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            _searchDebounce?.cancel();
                            _searchDebounce = Timer(
                              const Duration(milliseconds: 300),
                              () {
                                ref
                                    .read(
                                      transactionSearchQueryProvider.notifier,
                                    )
                                    .state = val
                                    .trim();
                              },
                            );
                          },
                          decoration: context.inputDecoration(
                            hintText: 'Search transactions...',
                            prefixIcon: const Icon(PesaFlowIcons.search, size: 20),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      PesaFlowIcons.clear,
                                      size: 16,
                                      color: onSurface.withValues(alpha: 0.54),
                                    ),
                                    onPressed: () {
                                      ref
                                              .read(
                                                transactionSearchQueryProvider
                                                    .notifier,
                                              )
                                              .state =
                                          '';
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: kSpacing16),
                      SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: kSpacing16),
                          children: ['All', 'Income', 'Expense', 'Transfer']
                              .map((type) {
                                final isSelected = activeType == type;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: kSpacing4,
                                  ),
                                  child: TactileSpringContainer(
                                    onTap: () {
                                      ref
                                              .read(
                                                transactionTypeFilterProvider
                                                    .notifier,
                                              )
                                              .state =
                                          type;
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 22,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                        border: Border.all(
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                              : Colors.transparent,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          type,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                color: isSelected
                                                    ? theme.colorScheme.onPrimary
                                                    : onSurface.withValues(
                                                        alpha: 0.6,
                                                      ),
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              })
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: kSpacing80),
        child: PremiumFab(onPressed: () => context.push('/transactions/add')),
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
          title = "Spend analysis complete.";
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
          padding: EdgeInsets.fromLTRB(
            kSpacing20,
            kSpacing24,
            kSpacing20,
            kSpacing24,
          ),
          child: Container(
            height: 170,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.3),
                  width: 1.0,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(23),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.surfaceContainer,
                        theme.colorScheme.surface,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
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
                            Text(
                              'INSIGHTS',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: accentColor,
                              ),
                            ),
                            const SizedBox(height: kSpacing8),
                            Text(
                              title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.6,
                                color: Colors.white,
                                height: 1.15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: kSpacing6),
                            Text(
                              message,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.7),
                                height: 1.25,
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
                            final income = (totals['income'] ?? 0) / 100.0;
                            final expense = (totals['expense'] ?? 0) / 100.0;
                            final maxVal = [
                              income,
                              expense,
                              1.0,
                            ].reduce((a, b) => a > b ? a : b);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _MiniBar(
                                  label: 'Income',
                                  value: income,
                                  maxValue: maxVal,
                                  color: context.appColors.incomeColor,
                                  formatValue: (v) => 'TSh ${_formatKsh(v)}',
                                ),
                                const SizedBox(height: kSpacing10),
                                _MiniBar(
                                  label: 'Expense',
                                  value: expense,
                                  maxValue: maxVal,
                                  color: accentColor,
                                  formatValue: (v) => 'TSh ${_formatKsh(v)}',
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
              ),
            ),
          );
        },
      orElse: () => const SizedBox.shrink(),
    );
  }

  String _formatKsh(double val) {
    if (val >= 1_000_000) return '${(val / 1_000_000).toStringAsFixed(1)}M';
    if (val >= 1_000) return '${(val / 1_000).toStringAsFixed(1)}K';
    return val.toStringAsFixed(0);
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

    return Container(
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : onSurface.withValues(alpha: 0.04),
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.20)
              : onSurface.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: Icon(
              PesaFlowIcons.filter,
              color: isActive
                  ? theme.colorScheme.primary
                  : onSurface.withValues(alpha: 0.62),
              size: 22,
            ),
            onPressed: onPressed,
          ),
          if (isActive && activeCount > 0)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                padding: const EdgeInsets.all(kSpacing4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  '$activeCount',
                  style: context.ts(
                    10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final Color color;
  final String Function(double) formatValue;

  const _MiniBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
    required this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const Spacer(),
            Text(
              formatValue(value),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: kSpacing4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, val, _) {
              return Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _animation = _controller.drive(Tween<double>(begin: 0.12, end: 0));
    _controller.forward();
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
        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: kSpacing20,
            vertical: kSpacing6,
          ),
          decoration: BoxDecoration(
            color: highlightColor.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(20),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
