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
import 'package:pesaflow/presentation/common/ios/ios_list_section.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/ios/ios_sheet.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/domain/analytics/insight_generator.dart';

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
      body: Stack(
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
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
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
                                    ? const Color(0xFF30D158)
                                    : (dailyNetChange < 0 ? const Color(0xFFFF453A) : Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Transaction Items as Individual GlassCards
                      ...dayItems.map((item) {
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

                        return Dismissible(
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
                                    ? const Color(0xFF1B1C22).withOpacity(0.65)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? const Color(0x10FFFFFF) : const Color(0x0F000000),
                                  width: 0.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
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
                                      color: categoryColor.withOpacity(0.15),
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
                                              ? const Color(0xFF30D158)
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
                        );
                      }).toList(),
                    ],
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading transactions: $err')),
          ),

          // ── FLOATING GLASSMOGRAPHIC HEADER ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 12,
                    bottom: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xCC0D0E11)
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
                      // Title, Profile Avatar & Filter Controls
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Transactions',
                              style: TextStyle(
                                fontFamily: 'system-ui',
                                fontSize: 32.0,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.0,
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
                                IconButton(
                                  icon: Icon(
                                    Icons.filter_list_rounded,
                                    color: (activeAccount != null || activeCategory != null)
                                        ? theme.colorScheme.primary
                                        : (isDark ? Colors.white70 : Colors.black87),
                                    size: 22,
                                  ),
                                  onPressed: () {
                                    _showFiltersBottomSheet(context, ref);
                                  },
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => context.go('/settings'),
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
                                        width: 0.8,
                                      ),
                                      image: const DecorationImage(
                                        image: AssetImage('assets/icon/app_icon.png'),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Search Bar Container
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1B1C22).withOpacity(0.6)
                                : Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: isDark ? const Color(0x10FFFFFF) : const Color(0x0F000000),
                              width: 0.5,
                            ),
                          ),
                          child: TextField(
                            controller: searchController,
                            onChanged: (val) {
                              ref.read(transactionSearchQueryProvider.notifier).state = val.trim();
                            },
                            decoration: InputDecoration(
                              hintText: 'Search transactions...',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white30 : Colors.black38,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: isDark ? Colors.white30 : Colors.black38,
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
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(vertical: 11),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Horizontal filter tabs row
                      SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          children: ['All', 'Income', 'Expense', 'Transfer'].map((type) {
                            final isSelected = activeType == type;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: TactileSpringContainer(
                                onTap: () {
                                  ref.read(transactionTypeFilterProvider.notifier).state = type;
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? (isDark ? const Color(0xFF2C2D35) : Colors.black12)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    type,
                                    style: TextStyle(
                                      color: isSelected
                                          ? (isDark ? Colors.white : Colors.black)
                                          : (isDark ? Colors.white30 : Colors.black38),
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
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
      // Glowing Floating Action Button (FAB)
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 80), // Positioned above the custom tab bar
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF30D158).withOpacity(0.35),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => context.go('/transactions/add'),
          backgroundColor: const Color(0xFF30D158),
          foregroundColor: Colors.black,
          shape: const CircleBorder(),
          elevation: 0,
          child: const Icon(
            Icons.add_rounded,
            size: 28,
          ),
        ),
      ),
    );
  }

  // ── INSIGHTS CARD BUILDER ──
  Widget _buildInsightsCard(BuildContext context, WidgetRef ref, bool isDark) {
    final insightsAsync = ref.watch(insightsProvider);

    return insightsAsync.maybeWhen(
      data: (insights) {
        final String title;
        final String message;

        if (insights.isNotEmpty) {
          title = insights.first.title;
          message = insights.first.message;
        } else {
          title = "Spend analysis complete.";
          message = "You saved 12% more than last month in the 'Dining' category.";
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF30D158).withOpacity(0.35),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF30D158).withOpacity(0.12),
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: Stack(
              children: [
                // Dark green gradient background panel
                Container(
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
                ),
                // Glowing emerald crystal positioned on the right
                Positioned(
                  right: -10,
                  bottom: -10,
                  top: -10,
                  child: Opacity(
                    opacity: 0.85,
                    child: Image.asset(
                      'assets/images/emerald_crystal.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                // Text details aligned on the left
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'INSIGHTS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: Color(0xFF30D158),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.52,
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: Colors.white,
                            height: 1.15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.52,
                        child: Text(
                          message,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.7),
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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
