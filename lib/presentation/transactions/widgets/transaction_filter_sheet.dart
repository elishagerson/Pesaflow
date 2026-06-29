import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/presentation/common/ios/ios_list_section.dart';
import 'package:pesaflow/presentation/common/ios/ios_sheet.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

Future<void> showTransactionFilterSheet(BuildContext context, WidgetRef ref) {
  final accounts = ref.watch(accountsStreamProvider).value ?? [];
  final allCategories = ref.watch(categoriesFutureProvider).value ?? [];

  final amountMinInitial = ref.read(transactionAmountMinProvider);
  final amountMaxInitial = ref.read(transactionAmountMaxProvider);
  final minCtl = TextEditingController(
    text: amountMinInitial != null
        ? (amountMinInitial / 100).toStringAsFixed(0)
        : '',
  );
  final maxCtl = TextEditingController(
    text: amountMaxInitial != null
        ? (amountMaxInitial / 100).toStringAsFixed(0)
        : '',
  );

  minCtl.selection = TextSelection.collapsed(offset: minCtl.text.length);
  maxCtl.selection = TextSelection.collapsed(offset: maxCtl.text.length);

  return IosBottomSheet.show(
    context: context,
    initialChildSize: 0.85,
    maxChildSize: 0.95,
    child: _TransactionFilterSheetContent(
      accounts: accounts,
      allCategories: allCategories,
      minCtl: minCtl,
      maxCtl: maxCtl,
    ),
  );
}

class _TransactionFilterSheetContent extends ConsumerWidget {
  final List<Account> accounts;
  final List<Category> allCategories;
  final TextEditingController minCtl;
  final TextEditingController maxCtl;

  const _TransactionFilterSheetContent({
    required this.accounts,
    required this.allCategories,
    required this.minCtl,
    required this.maxCtl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeType = ref.watch(transactionTypeFilterProvider);
    final activeAccount = ref.watch(transactionAccountFilterProvider);
    final activeCategory = ref.watch(transactionCategoryFilterProvider);
    final dateFrom = ref.watch(transactionDateFromProvider);
    final dateTo = ref.watch(transactionDateToProvider);

    final categories = allCategories
        .where(
          (c) =>
              activeType == 'All' ||
              c.type.toLowerCase() == activeType.toLowerCase(),
        )
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StaggeredFadeSlide(
          index: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.filter_alt_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Filter Transactions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                SizedBox(
                  height: 32,
                  child: TextButton(
                    onPressed: () {
                      ref.read(transactionAmountMinProvider.notifier).state =
                          null;
                      ref.read(transactionAmountMaxProvider.notifier).state =
                          null;
                      ref.read(transactionDateFromProvider.notifier).state =
                          null;
                      ref.read(transactionDateToProvider.notifier).state = null;
                      ref
                              .read(transactionAccountFilterProvider.notifier)
                              .state =
                          null;
                      ref
                              .read(transactionCategoryFilterProvider.notifier)
                              .state =
                          null;
                      ref.read(transactionTypeFilterProvider.notifier).state =
                          'All';
                      ref.read(transactionSearchQueryProvider.notifier).state =
                          '';
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent.withValues(alpha: 0.8),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text(
                      'Reset',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Amount Range
            StaggeredFadeSlide(
              index: 1,
              child: IosListSection(
                header: 'Amount Range (TSh)',
                rows: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minCtl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Min',
                              hintText: '0',
                              prefixText: 'TSh ',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : Colors.black.withValues(alpha: 0.1),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                                ),
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.black.withValues(alpha: 0.02),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '—',
                            style: TextStyle(
                              fontSize: 18,
                              color: isDark ? Colors.white38 : Colors.black26,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: maxCtl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Max',
                              hintText: '1000000',
                              prefixText: 'TSh ',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : Colors.black.withValues(alpha: 0.1),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                                ),
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.black.withValues(alpha: 0.02),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Date Range
            StaggeredFadeSlide(
              index: 2,
              child: IosListSection(
                header: 'Date Range',
                rows: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _DateButton(
                            label: 'From',
                            date: dateFrom,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dateFrom ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                ref
                                        .read(
                                          transactionDateFromProvider.notifier,
                                        )
                                        .state =
                                    picked;
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DateButton(
                            label: 'To',
                            date: dateTo,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dateTo ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                ref
                                        .read(
                                          transactionDateToProvider.notifier,
                                        )
                                        .state =
                                    picked;
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Account Selector
            StaggeredFadeSlide(
              index: 3,
              child: IosListSection(
                header: 'Account',
                rows: [
                  IosListRow(
                    title: const Text('All Accounts'),
                    trailing: activeAccount == null
                        ? Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      ref
                              .read(transactionAccountFilterProvider.notifier)
                              .state =
                          null;
                    },
                  ),
                  ...accounts.map(
                    (acc) => IosListRow(
                      title: Text(acc.name),
                      trailing: activeAccount == acc.id
                          ? Icon(
                              Icons.check_rounded,
                              size: 20,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        ref
                                .read(transactionAccountFilterProvider.notifier)
                                .state =
                            acc.id;
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Category
            StaggeredFadeSlide(
              index: 4,
              child: IosListSection(
                header: 'Category',
                rows: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: categories.isEmpty
                        ? Text(
                            'No categories for selected type',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 13,
                            ),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _CategoryChip(
                                label: 'All',
                                color: activeCategory == null
                                    ? theme.colorScheme.primary
                                    : null,
                                textColor: activeCategory == null
                                    ? theme.colorScheme.onPrimary
                                    : null,
                                onTap: () {
                                  ref
                                          .read(
                                            transactionCategoryFilterProvider
                                                .notifier,
                                          )
                                          .state =
                                      null;
                                },
                              ),
                              ...categories.map(
                                (cat) => _CategoryChip(
                                  label: cat.name,
                                  icon: getCategoryIcon(cat.icon),
                                  iconColor: hexToColor(cat.color),
                                  color: activeCategory == cat.id
                                      ? hexToColor(cat.color)
                                      : null,
                                  textColor: activeCategory == cat.id
                                      ? Colors.white
                                      : null,
                                  onTap: () {
                                    ref
                                        .read(
                                          transactionCategoryFilterProvider
                                              .notifier,
                                        )
                                        .state = activeCategory == cat.id
                                        ? null
                                        : cat.id;
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),

        // Apply / Reset buttons
        StaggeredFadeSlide(
          index: 5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white60 : Colors.black45,
                      side: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.1),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      final minText = minCtl.text.trim();
                      final maxText = maxCtl.text.trim();

                      if (minText.isNotEmpty) {
                        final parsed = double.tryParse(minText);
                        if (parsed != null) {
                          ref
                              .read(transactionAmountMinProvider.notifier)
                              .state = (parsed * 100)
                              .round();
                        }
                      } else {
                        ref.read(transactionAmountMinProvider.notifier).state =
                            null;
                      }

                      if (maxText.isNotEmpty) {
                        final parsed = double.tryParse(maxText);
                        if (parsed != null) {
                          ref
                              .read(transactionAmountMaxProvider.notifier)
                              .state = (parsed * 100)
                              .round();
                        }
                      } else {
                        ref.read(transactionAmountMaxProvider.notifier).state =
                            null;
                      }

                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Apply Filters',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final Color? color;
  final Color? textColor;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    this.icon,
    this.iconColor,
    this.color,
    this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg =
        color ??
        (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.04));
    final fg = textColor ?? (isDark ? Colors.white70 : Colors.black54);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(100),
          border: color != null
              ? Border.all(color: color!.withValues(alpha: 0.5), width: 0.5)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: iconColor ?? fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              date != null ? DateFormat('MMM d, yyyy').format(date!) : 'Any',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: date != null
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
