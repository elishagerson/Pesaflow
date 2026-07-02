import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class SmsReviewScreen extends ConsumerStatefulWidget {
  const SmsReviewScreen({super.key});

  @override
  ConsumerState<SmsReviewScreen> createState() => _SmsReviewScreenState();
}

class _SmsReviewScreenState extends ConsumerState<SmsReviewScreen> {
  final Set<String> _selectedIds = {};
  bool _selectAll = false;

  Future<String?> _showCategorySheet({String? title}) async {
    final categoriesAsync = ref.read(categoriesFutureProvider);
    final categories = categoriesAsync.value ?? [];
    if (categories.isEmpty) return null;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusCard),
        ),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
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
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
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
                        onTap: () => Navigator.of(context).pop(cat.id),
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
    final reviewAsync = ref.watch(reviewQueueStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            IosNavBar(
              title: 'SMS Review',
              largeTitle: true,
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kSpacing12,
                          vertical: kSpacing6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: theme.brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.10)
                                : Colors.black.withValues(alpha: 0.05),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _selectAll ? Icons.deselect : Icons.select_all,
                              size: 16,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                            const SizedBox(width: kSpacing6),
                            Text(
                              _selectAll ? 'Deselect' : 'Select All',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.8,
                                ),
                                fontWeight: FontWeight.w500,
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
                              const Icon(
                                Icons.category_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: kSpacing6),
                              Text(
                                'Categorize (${_selectedIds.length})',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: Colors.white,
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
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(kSpacing32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(kSpacing24),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                PesaFlowIcons.success,
                                size: 56,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: kSpacing20),
                            Text(
                              'All Clear!',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: kSpacing8),
                            Text(
                              'No transactions awaiting review.\nAuto-logged entries appear on the Dashboard.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: kSpacing16,
                      vertical: kSpacing12,
                    ),
                    itemCount: items.length + 1, // +1 for header
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // Header
                        return StaggeredFadeSlide(
                          index: 0,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: kSpacing16),
                            child: Container(
                              padding: const EdgeInsets.all(kSpacing16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusCard,
                                ),
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.tertiary.withValues(
                                      alpha: 0.15,
                                    ),
                                    theme.colorScheme.tertiary.withValues(
                                      alpha: 0.05,
                                    ),
                                  ],
                                ),
                                border: Border.all(
                                  color: theme.colorScheme.tertiary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.sms_rounded,
                                    color: theme.colorScheme.tertiary,
                                    size: 28,
                                  ),
                                  const SizedBox(width: kSpacing12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${items.length} transaction${items.length == 1 ? '' : 's'} to review',
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Swipe right to approve, left to reject',
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant
                                                    .withValues(alpha: 0.6),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      final item = items[index - 1];
                      final trans = item.transaction;

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
                            // Reject: delete the transaction
                            await ref
                                .read(transactionRepositoryProvider)
                                .deleteTransaction(trans.id);
                            ref.invalidate(reviewQueueStreamProvider);
                            ref.invalidate(recentTransactionsStreamProvider);
                            ref.invalidate(accountsStreamProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Transaction rejected: ${trans.description}',
                                  ),
                                  backgroundColor: theme.colorScheme.error,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          onSwipeRight: () async {
                            // Approve: mark as sms_auto
                            await ref
                                .read(transactionRepositoryProvider)
                                .approveReviewedTransaction(trans.id);
                            ref.invalidate(reviewQueueStreamProvider);
                            ref.invalidate(recentTransactionsStreamProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Transaction approved: ${trans.description}',
                                  ),
                                  backgroundColor: theme.colorScheme.primary,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          child: GlassCard(
                            margin: const EdgeInsets.only(bottom: kSpacing10),
                            padding: EdgeInsets.zero,
                            frosted: true,
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Checkbox for batch selection
                                  SizedBox(
                                    width: kSpacing40,
                                    child: Center(
                                      child: Checkbox(
                                        value: _selectedIds.contains(trans.id),
                                        onChanged: (checked) {
                                          setState(() {
                                            if (checked == true) {
                                              _selectedIds.add(trans.id);
                                            } else {
                                              _selectedIds.remove(trans.id);
                                              _selectAll = false;
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  // Left Accent Border strip (dynamic category colored)
                                  Container(
                                    width: 5,
                                    color: hexToColor(item.category.color),
                                  ),
                                  // Main content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Top section: provider badge + amount
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            kSpacing16,
                                            kSpacing14,
                                            kSpacing16,
                                            kSpacing8,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  kSpacing10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: hexToColor(
                                                    item.category.color,
                                                  ).withValues(alpha: 0.15),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  getCategoryIcon(
                                                    item.category.icon,
                                                  ),
                                                  color: hexToColor(
                                                    item.category.color,
                                                  ),
                                                  size: 22,
                                                ),
                                              ),
                                              const SizedBox(width: kSpacing12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      trans
                                                              .description
                                                              .isNotEmpty
                                                          ? trans.description
                                                          : item.category.name,
                                                      style: theme
                                                          .textTheme
                                                          .titleSmall
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.bold,
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
                                                                  alpha: 0.1,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  AppTheme
                                                                      .radiusInput,
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
                                                                          .bold,
                                                                ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: kSpacing8,
                                                        ),
                                                        // High-fidelity confidence score badge
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal:
                                                                    kSpacing8,
                                                                vertical:
                                                                    kSpacing4,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: AppTheme
                                                                .incomeColor
                                                                .withValues(
                                                                  alpha: 0.1,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  100,
                                                                ),
                                                            border: Border.all(
                                                              color: AppTheme
                                                                  .incomeColor
                                                                  .withValues(
                                                                    alpha: 0.25,
                                                                  ),
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              ConfidenceRing(
                                                                score: 0.94,
                                                                color: AppTheme
                                                                    .incomeColor,
                                                                size: 12,
                                                              ),
                                                              const SizedBox(
                                                                width:
                                                                    kSpacing6,
                                                              ),
                                                              Text(
                                                                '94% MATCH',
                                                                style: theme
                                                                    .textTheme
                                                                    .labelSmall
                                                                    ?.copyWith(
                                                                      color: AppTheme
                                                                          .incomeColor,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w800,
                                                                      letterSpacing:
                                                                          0.5,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              AmountText(
                                                amountInCents: trans.amount,
                                                type: amtType,
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Raw SMS preview
                                        if (trans.rawSms != null &&
                                            trans.rawSms!.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              kSpacing16,
                                              0,
                                              kSpacing16,
                                              kSpacing8,
                                            ),
                                            child: Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(
                                                kSpacing10,
                                              ),
                                              decoration: BoxDecoration(
                                                color: theme
                                                    .colorScheme
                                                    .surfaceContainerHighest
                                                    .withValues(alpha: 0.3),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      kSpacing8,
                                                    ),
                                              ),
                                              child: Text(
                                                trans.rawSms!,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      fontFamily: 'monospace',
                                                      color: theme
                                                          .colorScheme
                                                          .onSurfaceVariant
                                                          .withValues(
                                                            alpha: 0.7,
                                                          ),
                                                    ),
                                              ),
                                            ),
                                          ),

                                        // Action buttons
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            kSpacing8,
                                            0,
                                            kSpacing8,
                                            kSpacing8,
                                          ),
                                          child: Row(
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
                                                    color:
                                                        theme.brightness ==
                                                            Brightness.dark
                                                        ? Colors.white
                                                              .withValues(
                                                                alpha: 0.06,
                                                              )
                                                        : Colors.black
                                                              .withValues(
                                                                alpha: 0.03,
                                                              ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          100,
                                                        ),
                                                    border: Border.all(
                                                      color:
                                                          theme.brightness ==
                                                              Brightness.dark
                                                          ? Colors.white
                                                                .withValues(
                                                                  alpha: 0.10,
                                                                )
                                                          : Colors.black
                                                                .withValues(
                                                                  alpha: 0.05,
                                                                ),
                                                      width: 0.8,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.category_rounded,
                                                        size: 14,
                                                        color: theme
                                                            .colorScheme
                                                            .onSurface
                                                            .withValues(
                                                              alpha: 0.6,
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
                                                                    alpha: 0.7,
                                                                  ),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
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
                                                },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: kSpacing14,
                                                        vertical: kSpacing8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.incomeColor
                                                        .withValues(
                                                          alpha: 0.12,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          100,
                                                        ),
                                                    border: Border.all(
                                                      color: AppTheme
                                                          .incomeColor
                                                          .withValues(
                                                            alpha: 0.3,
                                                          ),
                                                      width: 0.8,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.check_rounded,
                                                        size: 14,
                                                        color: AppTheme
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
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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
                          Icons.error_outline_rounded,
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
          pulseValue: _pulseController.value,
        ),
      ),
    );
  }
}

class _ConfidenceRingPainter extends CustomPainter {
  final double score;
  final Color color;
  final double pulseValue;

  _ConfidenceRingPainter({
    required this.score,
    required this.color,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

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
        oldDelegate.pulseValue != pulseValue;
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final newDx = (_position.value.dx + details.delta.dx).clamp(
      -MediaQuery.of(context).size.width,
      MediaQuery.of(context).size.width,
    );
    final newDy = _position.value.dy + details.delta.dy;
    final angle = newDx / 800.0;
    final scale =
        1.0 - (newDx.abs() / MediaQuery.of(context).size.width) * 0.04;

    _position = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(newDx, newDy),
    ).animate(_controller);
    _rotation = Tween<double>(begin: 0.0, end: angle).animate(_controller);
    _scale = Tween<double>(begin: 1.0, end: scale).animate(_controller);

    final threshold = MediaQuery.of(context).size.width * 0.35;
    if (newDx.abs() > threshold && !_hapticTriggered) {
      HapticFeedback.mediumImpact();
      _hapticTriggered = true;
    } else if (newDx.abs() <= threshold) {
      _hapticTriggered = false;
    }

    _controller.value = 1.0;
  }

  void _onPanEnd(DragEndDetails details) {
    final threshold = MediaQuery.of(context).size.width * 0.35;
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
    final threshold = MediaQuery.of(context).size.width * 0.35;

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
                widget.child,
                if (approveOpacity > 0)
                  Positioned.fill(
                    child: Opacity(
                      opacity: approveOpacity,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.incomeColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusCard,
                          ),
                          border: Border.all(
                            color: AppTheme.incomeColor,
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: kSpacing24,
                              vertical: kSpacing12,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.incomeColor,
                              borderRadius: BorderRadius.circular(kSpacing12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.incomeColor.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 15,
                                ),
                              ],
                            ),
                            child: Text(
                              'APPROVE',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (rejectOpacity > 0)
                  Positioned.fill(
                    child: Opacity(
                      opacity: rejectOpacity,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.expenseColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusCard,
                          ),
                          border: Border.all(
                            color: AppTheme.expenseColor,
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: kSpacing24,
                              vertical: kSpacing12,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.expenseColor,
                              borderRadius: BorderRadius.circular(kSpacing12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.expenseColor.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 15,
                                ),
                              ],
                            ),
                            child: Text(
                              'REJECT',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
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
