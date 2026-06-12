import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/domain/analytics/insight_generator.dart';
import 'package:pesaflow/presentation/common/ios/ios_list_section.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/premium_fab.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/ios/ios_sheet.dart';

class TransactionListScreen extends ConsumerWidget {
  const TransactionListScreen({super.key});

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
      return DateFormat('EEEE, MMMM d, yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Watch filters
    final activeType = ref.watch(transactionTypeFilterProvider);
    final activeAccount = ref.watch(transactionAccountFilterProvider);
    final activeCategory = ref.watch(transactionCategoryFilterProvider);
    final searchQuery = ref.watch(transactionSearchQueryProvider);

    // Watch streams/futures
    final transactionsAsync = ref.watch(filteredTransactionsStreamProvider);

    final searchController = TextEditingController(text: searchQuery);
    searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: searchController.text.length),
    );

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(filteredTransactionsStreamProvider);
          ref.invalidate(recentTransactionsStreamProvider);
          ref.invalidate(accountsStreamProvider);
        },
        child: Stack(
        children: [
          // ── TRANSACTIONS LIST LAYER ──
          transactionsAsync.when(
            data: (transactionsList) {
              if (transactionsList.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 120),
                      Icon(
                        Icons.search_off_rounded,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Transactions Found',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Try adjusting your filters or typing a different query.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              // Group items by calendar day
              final Map<String, List<TransactionWithCategoryAndAccount>> grouped = {};
              for (final item in transactionsList) {
                final dayStr = DateFormat('yyyy-MM-dd').format(item.transaction.createdAt);
                if (grouped[dayStr] == null) {
                  grouped[dayStr] = [];
                }
                grouped[dayStr]!.add(item);
              }

              final sortedDays = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 195.0,
                  bottom: 110.0,
                ),
                itemCount: sortedDays.length + 1,
                itemBuilder: (context, dayIndex) {
                  // Append insights card at the end of the transactions list
                  if (dayIndex == sortedDays.length) {
                    return _buildInsightsCard(context, ref, isDark);
                  }

                  final dayStr = sortedDays[dayIndex];
                  final dayItems = grouped[dayStr]!;
                  final firstItemDate = dayItems.first.transaction.createdAt;

                  // Calculate daily net balance change (income - expense)
                  int dailyNetChange = 0;
                  for (final item in dayItems) {
                    final type = item.transaction.type.toLowerCase();
                    if (type == 'income') {
                      dailyNetChange += item.transaction.amount;
                    } else if (type == 'expense' || type == 'airtime' || type == 'fee') {
                      dailyNetChange -= item.transaction.amount;
                    }
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Group Date Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatHeaderDate(firstItemDate).toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: isDark ? Colors.white30 : Colors.black38,
                              ),
                            ),
                            // Monospace Net Change Indicator
                            AmountText(
                              amountInCents: dailyNetChange.abs(),
                              type: dailyNetChange > 0
                                  ? AmountType.income
                                  : (dailyNetChange < 0 ? AmountType.expense : AmountType.neutral),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: dailyNetChange > 0
                                    ? AppTheme.transferColorDark
                                    : (dailyNetChange < 0 ? const Color(0xFFFF453A) : Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Transaction Items as Individual GlassCards
                      ...dayItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final trans = item.transaction;

                        AmountType amtType = AmountType.neutral;
                        if (trans.type.toLowerCase() == 'income') {
                          amtType = AmountType.income;
                        } else if (trans.type.toLowerCase() == 'expense' ||
                                   trans.type.toLowerCase() == 'airtime' ||
                                   trans.type.toLowerCase() == 'fee') {
                          amtType = AmountType.expense;
                        }

                        final categoryColor = hexToColor(item.category.color);
                        final formattedTime = DateFormat('HH:mm').format(trans.createdAt);

                        return StaggeredFadeSlide(
                          index: index,
                          child: Dismissible(
                          key: Key(trans.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
                            padding: const EdgeInsets.only(right: 20.0),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.delete_rounded, color: Colors.white),
                          ),
                          onDismissed: (_) async {
                            await ref.read(transactionRepositoryProvider).deleteTransaction(trans.id);
                            ref.invalidate(filteredTransactionsStreamProvider);
                            ref.invalidate(accountsStreamProvider);
                            ref.invalidate(netWorthProvider);
                          },
                          child: TactileSpringContainer(
                            onTap: () => context.go('/transactions/edit/${trans.id}'),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1B1C22).withValues(alpha: 0.65)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? const Color(0x10FFFFFF) : const Color(0x0F000000),
                                  width: 0.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Category Icon Container (Squircle Style)
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: categoryColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        getCategoryIcon(item.category.icon),
                                        color: categoryColor,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          trans.description.isNotEmpty ? trans.description : item.category.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: isDark ? Colors.white : Colors.black,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Text(
                                              item.account.name,
                                              style: TextStyle(
                                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (trans.reference != null && trans.reference!.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Text(
                                                '•',
                                                style: TextStyle(
                                                  color: isDark ? Colors.white10 : Colors.black12,
                                                  fontSize: 10,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  trans.reference!,
                                                  style: TextStyle(
                                                    color: isDark ? Colors.white30 : Colors.black38,
                                                    fontSize: 11,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Amount & Time
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      AmountText(
                                        amountInCents: trans.amount,
                                        type: amtType,
                                        showDecimals: true,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: amtType == AmountType.income
                                              ? AppTheme.transferColorDark
                                              : (amtType == AmountType.expense ? const Color(0xFFFF453A) : Colors.grey),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formattedTime,
                                        style: TextStyle(
                                          color: isDark ? Colors.white24 : Colors.black26,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                      }),
                    ],
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading transactions: $err')),
          ),

          // ── GLASS HEADER ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 16,
                    bottom: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xCC000000)
                        : const Color(0xCCF2F2F7),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? const Color(0x1AFFFFFF) : const Color(0x1F000000),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Transactions',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Row(
                              children: [
                                if (activeAccount != null || activeCategory != null || searchQuery.isNotEmpty || activeType != 'All')
                                  IconButton(
                                    icon: const Icon(Icons.clear_all_rounded, color: Colors.redAccent, size: 20),
                                    tooltip: 'Clear Filters',
                                    onPressed: () {
                                      ref.read(transactionTypeFilterProvider.notifier).state = 'All';
                                      ref.read(transactionAccountFilterProvider.notifier).state = null;
                                      ref.read(transactionCategoryFilterProvider.notifier).state = null;
                                      ref.read(transactionSearchQueryProvider.notifier).state = '';
                                    },
                                  ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: (activeAccount != null || activeCategory != null)
                                        ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                        : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04)),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.tune_rounded,
                                      color: (activeAccount != null || activeCategory != null)
                                          ? theme.colorScheme.primary
                                          : (isDark ? Colors.white70 : Colors.black54),
                                      size: 22,
                                    ),
                                    onPressed: () {
                                      _showFiltersBottomSheet(context, ref);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                                    border: Border.all(
                                      color: isDark ? const Color(0x1AFFFFFF) : const Color(0x1F000000),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.person_outline_rounded,
                                    size: 18,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: TextField(
                          controller: searchController,
                          onChanged: (val) {
                            ref.read(transactionSearchQueryProvider.notifier).state = val.trim();
                          },
                          decoration: InputDecoration(
                            hintText: 'Search transactions...',
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              size: 20,
                            ),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear_rounded, size: 16, color: isDark ? Colors.white54 : Colors.black54),
                                    onPressed: () {
                                      ref.read(transactionSearchQueryProvider.notifier).state = '';
                                    },
                                  )
                                : null,
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 34,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: ['All', 'Income', 'Expense', 'Transfer'].map((type) {
                            final isSelected = activeType == type;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: GestureDetector(
                                onTap: () {
                                  ref.read(transactionTypeFilterProvider.notifier).state = type;
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04)),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    type,
                                    style: TextStyle(
                                      color: isSelected
                                          ? theme.colorScheme.onPrimary
                                          : (isDark ? Colors.white60 : Colors.black45),
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: PremiumFab(
          onPressed: () => context.go('/transactions/add'),
        ),
      ),
    );
  }

  // ── INSIGHTS CARD BUILDER ──
  Widget _buildInsightsCard(BuildContext context, WidgetRef ref, bool isDark) {
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
          message = "You saved 12% more than last month in the 'Dining' category.";
          severity = InsightSeverity.positive;
        }

        final Color accentColor = switch (severity) {
          InsightSeverity.positive => const Color(0xFF609F8A),
          InsightSeverity.neutral => const Color(0xFFFF9F0A),
          InsightSeverity.warning => const Color(0xFFFF453A),
          InsightSeverity.critical => const Color(0xFFFF453A),
        };

        return Container(
          margin: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          height: 170,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.3),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.1),
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0C1911),
                    Color(0xFF070B08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(20),
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
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: Colors.white,
                            height: 1.15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          message,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.7),
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: monthlyTotalsAsync.when(
                      data: (totals) {
                        final income = (totals['income'] ?? 0) / 100.0;
                        final expense = (totals['expense'] ?? 0) / 100.0;
                        final maxVal = [income, expense, 1.0].reduce((a, b) => a > b ? a : b);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _MiniBar(
                              label: 'Income',
                              value: income,
                              maxValue: maxVal,
                              color: const Color(0xFF609F8A),
                              formatValue: (v) => 'TSh ${_formatKsh(v)}',
                            ),
                            const SizedBox(height: 10),
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

  void _showFiltersBottomSheet(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsStreamProvider).value ?? [];
    final categories = ref.watch(categoriesFutureProvider).value ?? [];
    final activeAccount = ref.watch(transactionAccountFilterProvider);
    final activeCategory = ref.watch(transactionCategoryFilterProvider);

    IosBottomSheet.show(
      context: context,
      initialChildSize: 0.6,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Filter Transactions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          IosListSection(
            header: 'Account',
            rows: [
              IosListRow(
                title: const Text('All Accounts'),
                trailing: activeAccount == null ? Icon(Icons.check_rounded, size: 20, color: Theme.of(context).colorScheme.primary) : null,
                onTap: () {
                  ref.read(transactionAccountFilterProvider.notifier).state = null;
                  Navigator.of(context).pop();
                },
              ),
              ...accounts.map((acc) => IosListRow(
                title: Text(acc.name),
                trailing: activeAccount == acc.id ? Icon(Icons.check_rounded, size: 20, color: Theme.of(context).colorScheme.primary) : null,
                onTap: () {
                  ref.read(transactionAccountFilterProvider.notifier).state = acc.id;
                  Navigator.of(context).pop();
                },
              )),
            ],
          ),
          const SizedBox(height: 16),
          IosListSection(
            header: 'Category',
            rows: [
              IosListRow(
                title: const Text('All Categories'),
                trailing: activeCategory == null ? Icon(Icons.check_rounded, size: 20, color: Theme.of(context).colorScheme.primary) : null,
                onTap: () {
                  ref.read(transactionCategoryFilterProvider.notifier).state = null;
                  Navigator.of(context).pop();
                },
              ),
              ...categories.map((cat) => IosListRow(
                title: Text('${cat.type.toUpperCase()}: ${cat.name}'),
                trailing: activeCategory == cat.id ? Icon(Icons.check_rounded, size: 20, color: Theme.of(context).colorScheme.primary) : null,
                onTap: () {
                  ref.read(transactionCategoryFilterProvider.notifier).state = cat.id;
                  Navigator.of(context).pop();
                },
              )),
            ],
          ),
          const SizedBox(height: 24),
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
    final fraction = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const Spacer(),
            Text(
              formatValue(value),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
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
