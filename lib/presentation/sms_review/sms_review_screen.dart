import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/spring_sheet_route.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/empty_state.dart';
import 'package:pesaflow/presentation/common/widgets/floating_top_bar.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/presentation/common/widgets/add_category_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/undo_delete.dart';
import 'package:go_router/go_router.dart';

class SmsReviewScreen extends ConsumerStatefulWidget {
  const SmsReviewScreen({super.key});

  @override
  ConsumerState<SmsReviewScreen> createState() => _SmsReviewScreenState();
}

class _SmsReviewScreenState extends ConsumerState<SmsReviewScreen> {
  final Set<String> _selectedIds = {};
  bool _selectAll = false;

  Future<String?> _showCategorySheet({String? title}) async {
    return showSpringSheet<String>(
      context,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return Consumer(
          builder: (context, ref, _) {
            final categoriesAsync = ref.watch(categoriesFutureProvider);
            final categories = categoriesAsync.value ?? [];
            return DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.3,
              maxChildSize: 0.8,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: kSpacing12),
                      width: kSpacing40,
                      height: kSpacing4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(kSpacing16),
                      child: Text(
                        title ?? 'Assign Category',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: categories.length + 1,
                        itemBuilder: (context, index) {
                          if (index == categories.length) {
                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(kSpacing8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  PesaFlowIcons.add,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                'Add Custom Category',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () async {
                                final newCat = await showAddCategoryDialog(
                                  context,
                                  ref,
                                );
                                if (newCat != null && context.mounted) {
                                  context.pop(newCat.id);
                                }
                              },
                            );
                          }
                          final cat = categories[index];
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(kSpacing8),
                              decoration: BoxDecoration(
                                color: hexToColor(
                                  cat.color,
                                ).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                getCategoryIcon(cat.icon),
                                color: hexToColor(cat.color),
                                size: 20,
                              ),
                            ),
                            title: Text(cat.name),
                            subtitle: Text(
                              cat.type.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            onTap: () => context.pop(cat.id),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showCategoryPicker(TransactionWithCategoryAndAccount item) async {
    final selectedCategoryId = await _showCategorySheet();
    if (selectedCategoryId != null && mounted) {
      await ref
          .read(transactionRepositoryProvider)
          .approveReviewedTransaction(
            item.transaction.id,
            newCategoryId: selectedCategoryId,
          );
      ref.invalidate(reviewQueueStreamProvider);
      ref.invalidate(recentTransactionsStreamProvider);
    }
  }

  void _showBatchCategoryPicker() async {
    final selectedCategoryId = await _showCategorySheet(
      title: 'Assign Category (${_selectedIds.length} items)',
    );
    if (selectedCategoryId != null && mounted) {
      for (final id in _selectedIds) {
        await ref
            .read(transactionRepositoryProvider)
            .approveReviewedTransaction(id, newCategoryId: selectedCategoryId);
      }
      ref.invalidate(reviewQueueStreamProvider);
      ref.invalidate(recentTransactionsStreamProvider);
      setState(() {
        _selectedIds.clear();
        _selectAll = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    ref.listen<AsyncValue<List<TransactionWithCategoryAndAccount>>>(
      reviewQueueStreamProvider,
      (previous, next) {
        final prevItems = previous?.value;
        final nextItems = next.value;
        if (prevItems != null &&
            prevItems.isNotEmpty &&
            nextItems != null &&
            nextItems.isEmpty) {
          CustomToast.show(
            context,
            message: 'All transactions reviewed!',
            type: ToastType.success,
          );
        }
      },
    );

    final reviewAsync = ref.watch(reviewQueueStreamProvider);

    return Scaffold(
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            FloatingTopBar(
              title: 'SMS Review',
              actions: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TactileSpringContainer(
                      onTap: () {
                        setState(() {
                          _selectAll = !_selectAll;
                          final items = reviewAsync.asData?.value ?? [];
                          if (_selectAll) {
                            _selectedIds.addAll(
                              items.map((e) => e.transaction.id),
                            );
                          } else {
                            _selectedIds.clear();
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kSpacing8,
                          vertical: kSpacing8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _selectAll
                                  ? Icons.remove_done_rounded
                                  : Icons.done_all_rounded,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: kSpacing6),
                            Text(
                              _selectAll ? 'Deselect All' : 'Select All',
                              style: context.ts(
                                14,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedIds.isNotEmpty) ...[
                      const SizedBox(width: kSpacing10),
                      TactileSpringContainer(
                        onTap: _showBatchCategoryPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpacing12,
                            vertical: kSpacing8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(kSpacing8),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PesaFlowIcons.category,
                                size: 16,
                                color: theme.colorScheme.onPrimary,
                              ),
                              const SizedBox(width: kSpacing6),
                              Text(
                                'Categorize (${_selectedIds.length})',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            Expanded(
              child: reviewAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return EmptyState(
                      icon: PesaFlowIcons.success,
                      title: 'All Clear!',
                      subtitle:
                          'No transactions awaiting review.\nAuto-logged entries appear on the Dashboard.',
                    );
                  }

                  final isSelecting = _selectedIds.isNotEmpty;

                  return Stack(
                    children: [
                      ListView.builder(
                        key: const PageStorageKey('sms_review'),
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          kSpacing16,
                          kSpacing12,
                          kSpacing16,
                          isSelecting ? 80 : kSpacing24,
                        ),
                        itemCount: items.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return StaggeredFadeSlide(
                              index: 0,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  bottom: kSpacing16,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: kSpacing16,
                                    vertical: kSpacing12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.15),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        PesaFlowIcons.sms,
                                        color: theme.colorScheme.primary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: kSpacing10),
                                      Text(
                                        '${items.length} transaction${items.length == 1 ? '' : 's'}',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(width: kSpacing6),
                                      Icon(
                                        PesaFlowIcons.arrowForward,
                                        size: 14,
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.6),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          final item = items[index - 1];
                          final trans = item.transaction;
                          final isSelected = _selectedIds.contains(trans.id);

                          AmountType amtType = AmountType.neutral;
                          if (trans.type.toLowerCase() == 'income') {
                            amtType = AmountType.income;
                          } else if (trans.type.toLowerCase() == 'expense' ||
                              trans.type.toLowerCase() == 'airtime' ||
                              trans.type.toLowerCase() == 'fee') {
                            amtType = AmountType.expense;
                          }

                          return StaggeredFadeSlide(
                            index: index,
                            child: SwipeableCard(
                              onSwipeLeft: () async {
                                final txData = item;
                                UndoDelete.show(
                                  context: context,
                                  entityName: 'Transaction',
                                  message:
                                      'Transaction rejected: ${trans.description}',
                                  onUndo: () async {
                                    await ref
                                        .read(transactionRepositoryProvider)
                                        .createTransaction(txData.transaction);
                                  },
                                  onDelete: () async {
                                    await ref
                                        .read(transactionRepositoryProvider)
                                        .deleteTransaction(trans.id);
                                  },
                                );
                              },
                              onSwipeRight: () async {
                                await ref
                                    .read(transactionRepositoryProvider)
                                    .approveReviewedTransaction(trans.id);
                                ref.invalidate(reviewQueueStreamProvider);
                                ref.invalidate(
                                  recentTransactionsStreamProvider,
                                );
                                if (context.mounted) {
                                  CustomToast.show(
                                    context,
                                    message:
                                        'Transaction approved: ${trans.description}',
                                    type: ToastType.success,
                                  );
                                }
                              },
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedIds.remove(trans.id);
                                    } else {
                                      _selectedIds.add(trans.id);
                                    }
                                    _selectAll = false;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                  margin: const EdgeInsets.only(
                                    bottom: kSpacing16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.primary.withValues(
                                            alpha: 0.08,
                                          )
                                        : theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                                .withValues(alpha: 0.3)
                                          : theme.colorScheme.onSurface
                                                .withValues(alpha: 0.08),
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.colorScheme.shadow
                                            .withValues(alpha: 0.04),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      kSpacing16,
                                      kSpacing16,
                                      kSpacing16,
                                      kSpacing16,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              width: 22,
                                              height: 22,
                                              margin: const EdgeInsets.only(
                                                top: 2,
                                                right: kSpacing12,
                                              ),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isSelected
                                                    ? theme.colorScheme.primary
                                                    : Colors.transparent,
                                                border: Border.all(
                                                  color: isSelected
                                                      ? theme
                                                            .colorScheme
                                                            .primary
                                                      : theme
                                                            .colorScheme
                                                            .onSurface
                                                            .withValues(
                                                              alpha: 0.25,
                                                            ),
                                                  width: 2,
                                                ),
                                              ),
                                              child: isSelected
                                                  ? Icon(
                                                      PesaFlowIcons.check,
                                                      size: 14,
                                                      color: theme
                                                          .colorScheme
                                                          .onPrimary,
                                                    )
                                                  : null,
                                            ),
                                            Container(
                                              padding: const EdgeInsets.all(
                                                kSpacing10,
                                              ),
                                              decoration: BoxDecoration(
                                                color: hexToColor(
                                                  item.category.color,
                                                ).withValues(alpha: 0.12),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                getCategoryIcon(
                                                  item.category.icon,
                                                ),
                                                color: hexToColor(
                                                  item.category.color,
                                                ),
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: kSpacing12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    trans.description.isNotEmpty
                                                        ? trans.description
                                                        : item.category.name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: theme
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                  const SizedBox(
                                                    height: kSpacing4,
                                                  ),
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal:
                                                                  kSpacing8,
                                                              vertical:
                                                                  kSpacing2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                           color: theme
                                                               .colorScheme
                                                               .primary
                                                               .withValues(
                                                                 alpha: 0.05,
                                                               ),
                                                           borderRadius:
                                                               BorderRadius.circular(
                                                                6,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          item.account!.name,
                                                          style: theme
                                                              .textTheme
                                                              .labelSmall
                                                              ?.copyWith(
                                                                color: theme
                                                                    .colorScheme
                                                                    .primary,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontSize: 11,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: kSpacing8),
                                            AmountText(
                                              amountInCents: trans.amount,
                                              type: amtType,
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ],
                                        ),

                                        // Raw SMS preview
                                        if (trans.rawSms != null &&
                                            trans.rawSms!.isNotEmpty) ...[
                                          const SizedBox(height: kSpacing10),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(
                                              kSpacing10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: theme
                                                  .colorScheme
                                                  .surfaceContainerHighest
                                                  .withValues(alpha: 0.25),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              trans.rawSms!,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTheme.getMonospaceStyle(
                                                theme.textTheme.labelSmall!.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant
                                                      .withValues(alpha: 0.6),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],

                                        // Action buttons
                                        const SizedBox(height: kSpacing16),
                                        Row(
                                          children: [
                                            TactileSpringContainer(
                                              onTap: () =>
                                                  _showCategoryPicker(item),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: kSpacing12,
                                                      vertical: kSpacing8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: theme
                                                      .colorScheme
                                                      .surfaceContainerHighest
                                                      .withValues(alpha: 0.4),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      PesaFlowIcons.category,
                                                      size: 13,
                                                      color: theme
                                                          .colorScheme
                                                          .onSurface
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                    ),
                                                    const SizedBox(
                                                      width: kSpacing6,
                                                    ),
                                                    Text(
                                                      'Category',
                                                      style: theme
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                            color: theme
                                                                .colorScheme
                                                                .onSurface
                                                                .withValues(
                                                                  alpha: 0.6,
                                                                ),
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: kSpacing8),
                                            TactileSpringContainer(
                                              onTap: () async {
                                                await ref
                                                    .read(
                                                      transactionRepositoryProvider,
                                                    )
                                                    .approveReviewedTransaction(
                                                      trans.id,
                                                    );
                                                ref.invalidate(
                                                  reviewQueueStreamProvider,
                                                );
                                                ref.invalidate(
                                                  recentTransactionsStreamProvider,
                                                );
                                                if (context.mounted) {
                                                  CustomToast.show(
                                                    context,
                                                    message:
                                                        'Transaction approved',
                                                    type: ToastType.success,
                                                  );
                                                }
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: kSpacing14,
                                                      vertical: kSpacing8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: context
                                                      .appColors
                                                      .incomeColor
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      PesaFlowIcons.check,
                                                      size: 14,
                                                      color: context
                                                          .appColors
                                                          .incomeColor,
                                                    ),
                                                    const SizedBox(
                                                      width: kSpacing6,
                                                    ),
                                                    Text(
                                                      'Approve',
                                                      style: theme
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                            color: AppTheme
                                                                .incomeColor,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            TactileSpringContainer(
                                              onTap: () async {
                                                final txData = item;
                                                UndoDelete.show(
                                                  context: context,
                                                  entityName: 'Transaction',
                                                  message:
                                                      'Transaction rejected',
                                                  onUndo: () async {
                                                    await ref
                                                        .read(
                                                          transactionRepositoryProvider,
                                                        )
                                                        .createTransaction(
                                                          txData.transaction,
                                                        );
                                                  },
                                                  onDelete: () async {
                                                    await ref
                                                        .read(
                                                          transactionRepositoryProvider,
                                                        )
                                                        .deleteTransaction(
                                                          trans.id,
                                                        );
                                                  },
                                                );
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: kSpacing12,
                                                      vertical: kSpacing8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: context
                                                      .appColors
                                                       .expenseColor
                                                       .withValues(alpha: 0.05),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      PesaFlowIcons.close,
                                                      size: 14,
                                                      color: context
                                                          .appColors
                                                          .expenseColor,
                                                    ),
                                                    const SizedBox(
                                                      width: kSpacing6,
                                                    ),
                                                    Text(
                                                      'Reject',
                                                      style: theme
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                            color: context
                                                                .appColors
                                                                .expenseColor,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
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
                        },
                      ),

                      // Floating batch action bar
                      if (isSelecting)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: EdgeInsets.fromLTRB(
                              kSpacing16,
                              kSpacing12,
                              kSpacing16,
                              MediaQuery.of(context).padding.bottom +
                                  kSpacing12,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  theme.colorScheme.surface.withValues(
                                    alpha: 0,
                                  ),
                                  theme.colorScheme.surface,
                                  theme.colorScheme.surface,
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                TactileSpringContainer(
                                  onTap: () {
                                    setState(() {
                                      _selectedIds.clear();
                                      _selectAll = false;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: kSpacing14,
                                      vertical: kSpacing10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.1),
                                      ),
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.7),
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: kSpacing10),
                                Expanded(
                                  child: TactileSpringContainer(
                                    onTap: _showBatchCategoryPicker,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: kSpacing10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Categorize (${_selectedIds.length})',
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                color:
                                                    theme.colorScheme.onPrimary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: kSpacing10),
                                Expanded(
                                  child: TactileSpringContainer(
                                    onTap: () async {
                                      for (final id in _selectedIds) {
                                        await ref
                                            .read(transactionRepositoryProvider)
                                            .approveReviewedTransaction(id);
                                      }
                                      final approvedCount = _selectedIds.length;
                                      ref.invalidate(reviewQueueStreamProvider);
                                      ref.invalidate(
                                        recentTransactionsStreamProvider,
                                      );
                                      setState(() {
                                        _selectedIds.clear();
                                        _selectAll = false;
                                      });
                                      if (context.mounted) {
                                        CustomToast.show(
                                          context,
                                          message:
                                              '$approvedCount transactions approved',
                                          type: ToastType.success,
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: kSpacing10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.appColors.incomeColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Approve',
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
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
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(kSpacing32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          PesaFlowIcons.error,
                          size: 48,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: kSpacing16),
                        Text(
                          'Failed to load reviews',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: kSpacing8),
                        Text(
                          '$err',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
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
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ANIMATED CONFIDENCE RING WIDGET
// ════════════════════════════════════════════════════════════════════════════
class ConfidenceRing extends StatefulWidget {
  final double score;
  final Color color;
  final double size;

  const ConfidenceRing({
    super.key,
    required this.score,
    required this.color,
    this.size = 14,
  });

  @override
  State<ConfidenceRing> createState() => _ConfidenceRingState();
}

class _ConfidenceRingState extends State<ConfidenceRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _ConfidenceRingPainter(
          score: widget.score,
          color: widget.color,
          pulseAnimation: _pulseController,
        ),
      ),
    );
  }
}

class _ConfidenceRingPainter extends CustomPainter {
  final double score;
  final Color color;
  final Animation<double> pulseAnimation;

  _ConfidenceRingPainter({
    required this.score,
    required this.color,
    required this.pulseAnimation,
  }) : super(repaint: pulseAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0.0 || size.height <= 0.0) {
      return;
    }
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    final pulseValue = pulseAnimation.value;

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, bgPaint);

    final activePaint = Paint()
      ..color = color.withValues(alpha: 0.65 + 0.35 * pulseValue)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      6.28318 * score,
      false,
      activePaint,
    );

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.12 + 0.12 * pulseValue)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      6.28318 * score,
      false,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ConfidenceRingPainter oldDelegate) {
    return oldDelegate.score != score ||
        oldDelegate.color != color ||
        oldDelegate.pulseAnimation.value != pulseAnimation.value;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SPRING SWIPE CARD WIDGET — physics-based snap-back and fluid drag
// ════════════════════════════════════════════════════════════════════════════
class SwipeableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;

  const SwipeableCard({
    super.key,
    required this.child,
    required this.onSwipeLeft,
    required this.onSwipeRight,
  });

  @override
  State<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _position;
  late Animation<double> _rotation;
  late Animation<double> _scale;

  double _screenWidth = 400.0;

  final SpringDescription _snapSpring = const SpringDescription(
    mass: 0.6,
    stiffness: 200,
    damping: 18,
  );

  final SpringDescription _swipeSpring = const SpringDescription(
    mass: 1.0,
    stiffness: 300,
    damping: 30,
  );

  bool _hapticTriggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _position = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(_controller);
    _rotation = Tween<double>(begin: 0.0, end: 0.0).animate(_controller);
    _scale = Tween<double>(begin: 1.0, end: 1.0).animate(_controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenWidth = MediaQuery.sizeOf(context).width;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final newDx = (_position.value.dx + details.delta.dx).clamp(
      -_screenWidth,
      _screenWidth,
    );
    final newDy = _position.value.dy + details.delta.dy;
    final angle = newDx / 800.0;
    final scale = 1.0 - (newDx.abs() / _screenWidth) * 0.04;

    _position = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(newDx, newDy),
    ).animate(_controller);
    _rotation = Tween<double>(begin: 0.0, end: angle).animate(_controller);
    _scale = Tween<double>(begin: 1.0, end: scale).animate(_controller);

    final threshold = _screenWidth * 0.35;
    if (newDx.abs() > threshold && !_hapticTriggered) {
      HapticFeedback.mediumImpact();
      _hapticTriggered = true;
    } else if (newDx.abs() <= threshold) {
      _hapticTriggered = false;
    }

    _controller.value = 1.0;
  }

  void _onPanEnd(DragEndDetails details) {
    final threshold = _screenWidth * 0.35;
    final dx = _position.value.dx;

    if (dx > threshold) {
      _flyOut(const Offset(400, -40), widget.onSwipeRight);
    } else if (dx < -threshold) {
      _flyOut(const Offset(-400, -40), widget.onSwipeLeft);
    } else {
      _snapBack();
    }
  }

  void _flyOut(Offset target, VoidCallback onDone) {
    final sim = SpringSimulation(
      _swipeSpring,
      0.0,
      1.0,
      -_position.value.dx * 0.002,
    );
    _position = Tween<Offset>(
      begin: _position.value,
      end: target,
    ).animate(_controller);
    _rotation = Tween<double>(
      begin: _rotation.value,
      end: _rotation.value * 2.0,
    ).animate(_controller);
    _scale = Tween<double>(begin: _scale.value, end: 0.85).animate(_controller);
    _controller.animateWith(sim).then((_) => onDone());
  }

  void _snapBack() {
    final startPos = _position.value;
    final startRot = _rotation.value;

    _position = Tween<Offset>(
      begin: startPos,
      end: Offset.zero,
    ).animate(_controller);
    _rotation = Tween<double>(begin: startRot, end: 0.0).animate(_controller);
    _scale = Tween<double>(begin: _scale.value, end: 1.0).animate(_controller);
    _controller.animateWith(SpringSimulation(_snapSpring, 0.0, 1.0, 0.0));
    _hapticTriggered = false;
  }

  @override
  Widget build(BuildContext context) {
    final threshold = _screenWidth * 0.35;

    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final dx = _position.value.dx;
          final dy = _position.value.dy;
          final angle = _rotation.value;
          final scale = _scale.value;
          final approveOpacity = (dx / threshold).clamp(0.0, 1.0);
          final rejectOpacity = (-dx / threshold).clamp(0.0, 1.0);

          return Transform(
            transform: Matrix4.identity()
              ..translateByDouble(dx, dy, 0.0, 1.0)
              ..rotateZ(angle)
              ..scaleByDouble(scale, scale, 1.0, 1.0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Soft dynamic under-card glow bleed
                if (dx != 0)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusCard,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: dx > 0
                                ? context.appColors.incomeColor.withValues(
                                    alpha: 0.25 * approveOpacity,
                                  )
                                : context.appColors.expenseColor.withValues(
                                    alpha: 0.25 * rejectOpacity,
                                  ),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                widget.child,
                // Green linear gradient bleed (Approve)
                if (approveOpacity > 0)
                  Positioned.fill(
                    child: Opacity(
                      opacity: approveOpacity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              context.appColors.incomeColor.withValues(
                                alpha: 0.24,
                              ),
                              context.appColors.incomeColor.withValues(
                                alpha: 0.0,
                              ),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusCard,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: kSpacing24,
                              vertical: kSpacing12,
                            ),
                            decoration: BoxDecoration(
                              color: context.appColors.incomeColor,
                              borderRadius: BorderRadius.circular(kSpacing12),
                              boxShadow: [
                                BoxShadow(
                                  color: context.appColors.incomeColor
                                      .withValues(alpha: 0.4),
                                  blurRadius: 15,
                                ),
                              ],
                            ),
                            child: Text(
                              'APPROVE',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Red linear gradient bleed (Reject)
                if (rejectOpacity > 0)
                  Positioned.fill(
                    child: Opacity(
                      opacity: rejectOpacity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [
                              context.appColors.expenseColor.withValues(
                                alpha: 0.24,
                              ),
                              context.appColors.expenseColor.withValues(
                                alpha: 0.0,
                              ),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusCard,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: kSpacing24,
                              vertical: kSpacing12,
                            ),
                            decoration: BoxDecoration(
                              color: context.appColors.expenseColor,
                              borderRadius: BorderRadius.circular(kSpacing12),
                              boxShadow: [
                                BoxShadow(
                                  color: context.appColors.expenseColor
                                      .withValues(alpha: 0.4),
                                  blurRadius: 15,
                                ),
                              ],
                            ),
                            child: Text(
                              'REJECT',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
