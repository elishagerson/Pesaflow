import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:flutter/services.dart';
import 'package:pesaflow/presentation/common/widgets/motion/spring_rect_tween.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

import 'package:pesaflow/core/utils/spacing.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;
  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final itemAsync = ref.watch(transactionDetailProvider(transactionId));

    return Scaffold(
      appBar: IosNavBar(
        title: 'Transaction',
        largeTitle: false,
        actions: [
          TactileSpringContainer(
            onTap: () => context.go('/transactions/edit/$transactionId'),
            child: Container(
              padding: const EdgeInsets.all(kSpacing10),
              decoration: BoxDecoration(
                color: onSurface.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(PesaFlowIcons.edit, size: 18, color: onSurface),
            ),
          ),
          const SizedBox(width: kSpacing8),
          TactileSpringContainer(
            onTap: () => _confirmDelete(context, ref),
            child: Container(
              padding: const EdgeInsets.all(kSpacing10),
              decoration: BoxDecoration(
                color: context.appColors.expenseColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                PesaFlowIcons.delete,
                size: 18,
                color: context.appColors.expenseColor,
              ),
            ),
          ),
        ],
      ),
      body: Hero(
        tag: 'transaction-$transactionId',
        createRectTween: (begin, end) {
          return SpringRectTween(begin: begin!, end: end!);
        },
        child: Material(
          type: MaterialType.transparency,
          child: itemAsync.when(
            data: (item) {
              if (item == null) {
                return const Center(child: Text('Transaction not found'));
              }
              return _buildDetail(context, ref, theme, onSurface, item);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
        ),
      ),
    );
  }

  Widget _buildDetail(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    Color onSurface,
    TransactionWithCategoryAndAccount item,
  ) {
    final t = item.transaction;
    final cat = item.category;
    final acc = item.account;
    final catColor = hexToColor(cat.color);
    final mutedCatColor = desaturateColor(catColor);
    final isIncome = t.type == 'income';
    final amountColor = isIncome
        ? context.appColors.incomeColor
        : context.appColors.expenseColor;

    final hasExtraDetails =
        (t.reference != null && t.reference!.isNotEmpty) ||
        (t.sender != null && t.sender!.isNotEmpty) ||
        (t.recipient != null && t.recipient!.isNotEmpty) ||
        (t.balanceAfter != null);

    return Stack(
      children: [
        // Ambient Category Glow Backdrop
        Positioned(
          top: MediaQuery.of(context).size.height * 0.05,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    mutedCatColor.withValues(alpha: 0.17),
                    mutedCatColor.withValues(alpha: 0.045),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
        ),
        // Scrollable Content
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            kSpacing16,
            kSpacing12,
            kSpacing16,
            kSpacing32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StaggeredFadeSlide(
                index: 0,
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: 32,
                    horizontal: 24,
                  ),
                  borderRadius: AppTheme.radiusCard,
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Floating glowing icon circle
                        Container(
                          padding: const EdgeInsets.all(kSpacing18),
                          decoration: BoxDecoration(
                            color: mutedCatColor.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: mutedCatColor.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: mutedCatColor.withValues(alpha: 0.2),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            getCategoryIcon(cat.icon),
                            color: catColor,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: kSpacing20),
                        // Merchant name / Description
                        Text(
                          t.description.isNotEmpty
                              ? t.description
                              : 'No Description',
                          style: context.ts(
                            22,
                            fontWeight: FontWeight.w800,
                            color: onSurface,
                            letterSpacing: -0.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: kSpacing8),
                        // Transaction Type Pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: amountColor.withValues(alpha: 0.115),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: amountColor.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isIncome
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                                color: amountColor,
                                size: 12,
                              ),
                              const SizedBox(width: kSpacing4),
                              Text(
                                isIncome ? 'INCOME' : 'EXPENSE',
                                style: context.ts(
                                  10,
                                  fontWeight: FontWeight.w800,
                                  color: amountColor,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: kSpacing20),
                        // Display Amount
                        Text(
                          (isIncome ? '+ ' : '- ') +
                              CurrencyFormatter.formatCents(t.amount),
                          style: context.ts(
                            36,
                            fontWeight: FontWeight.w900,
                            color: amountColor,
                            letterSpacing: -1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        // Perforated Ticket Divider & Mask Cutouts
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: kSpacing28,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              DashedDivider(
                                color: onSurface.withValues(alpha: 0.125),
                                height: 1.5,
                                dashWidth: 5,
                                dashSpace: 4,
                              ),
                              // Left masking cutout (offset by padding of card: 24, plus half cutout width: 8)
                              Positioned(
                                left: -32,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: theme.scaffoldBackgroundColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              // Right masking cutout
                              Positioned(
                                right: -32,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: theme.scaffoldBackgroundColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Info Grid (Category, Account, Date)
                        Row(
                          children: [
                            Expanded(
                              child: _gridItem(
                                context,
                                icon: getCategoryIcon(cat.icon),
                                iconColor: catColor,
                                label: 'Category',
                                value: cat.name,
                              ),
                            ),
                            _verticalDivider(onSurface),
                            Expanded(
                              child: _gridItem(
                                context,
                                icon: acc != null
                                    ? getAccountIcon(acc.icon)
                                    : Icons.link_off_rounded,
                                iconColor: onSurface.withValues(alpha: 0.78),
                                label: 'Account',
                                value: acc?.name ?? 'Offline',
                              ),
                            ),
                            _verticalDivider(onSurface),
                            Expanded(
                              child: _gridItem(
                                context,
                                icon: PesaFlowIcons.calendar,
                                iconColor: Colors.blueAccent,
                                label: 'Date',
                                value:
                                    '${t.createdAt.day}/${t.createdAt.month}/${t.createdAt.year}',
                              ),
                            ),
                          ],
                        ),

                        // Extra Details
                        Padding(
                          padding: const EdgeInsets.only(top: kSpacing20),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {},
                              borderRadius: BorderRadius.circular(8),
                                child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '📨',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium!,
                                    ),
                                    const SizedBox(width: kSpacing6),
                                    Text(
                                      t.source.startsWith('sms')
                                          ? 'Auto-imported via SMS'
                                          : t.source == 'transfer'
                                          ? 'Transfer'
                                          : 'Manual entry',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall!
                                          .copyWith(
                                            color: theme.colorScheme.primary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (hasExtraDetails) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: kSpacing24),
                            child: _divider(onSurface),
                          ),
                          const SizedBox(height: kSpacing16),
                          if (t.reference != null &&
                              t.reference!.isNotEmpty) ...[
                            _copyableDetailRow(
                              context,
                              theme,
                              Icons.tag_rounded,
                              'Reference',
                              t.reference!,
                            ),
                          ],
                          if (t.sender != null && t.sender!.isNotEmpty) ...[
                            if (t.reference != null && t.reference!.isNotEmpty)
                              const SizedBox(height: kSpacing12),
                            _copyableDetailRow(
                              context,
                              theme,
                              Icons.person_outline_rounded,
                              'Sender',
                              t.sender!,
                            ),
                          ],
                          if (t.recipient != null &&
                              t.recipient!.isNotEmpty) ...[
                            if ((t.reference != null &&
                                    t.reference!.isNotEmpty) ||
                                (t.sender != null && t.sender!.isNotEmpty))
                              const SizedBox(height: kSpacing12),
                            _copyableDetailRow(
                              context,
                              theme,
                              Icons.person_rounded,
                              'Recipient',
                              t.recipient!,
                            ),
                          ],
                          if (t.balanceAfter != null) ...[
                            if ((t.reference != null &&
                                    t.reference!.isNotEmpty) ||
                                (t.sender != null && t.sender!.isNotEmpty) ||
                                (t.recipient != null &&
                                    t.recipient!.isNotEmpty))
                              const SizedBox(height: kSpacing12),
                            _detailRow(
                              theme,
                              PesaFlowIcons.loans,
                              'Balance After',
                              CurrencyFormatter.formatCents(t.balanceAfter!),
                              valueColor: onSurface,
                            ),
                          ],
                        ],

                        // Receipt Footer/Barcode
                        Padding(
                          padding: const EdgeInsets.only(top: kSpacing28),
                          child: _divider(onSurface),
                        ),
                        const SizedBox(height: kSpacing24),
                        _buildBarcode(context, t.id, onSurface),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: kSpacing20),

              // Bottom Action Buttons
              StaggeredFadeSlide(
                index: 1,
                child: Row(
                  children: [
                    Expanded(
                      child: GlassCard(
                        onTap: () => context.go('/transactions/edit/${t.id}'),
                        backgroundColor: onSurface.withValues(alpha: 0.045),
                        padding: const EdgeInsets.symmetric(
                          vertical: kSpacing14,
                        ),
                        borderRadius: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              PesaFlowIcons.edit,
                              size: 16,
                              color: onSurface,
                            ),
                            const SizedBox(width: kSpacing8),
                            Text(
                              'Edit Details',
                              style: Theme.of(context).textTheme.titleSmall!
                                  .copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: onSurface,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: kSpacing12),
                    Expanded(
                      child: GlassCard(
                        onTap: () => _confirmDelete(context, ref),
                        backgroundColor: context.appColors.expenseColor.withValues(alpha: 0.12),
                        padding: const EdgeInsets.symmetric(
                          vertical: kSpacing14,
                        ),
                        borderRadius: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              PesaFlowIcons.delete,
                              size: 16,
                              color: context.appColors.expenseColor,
                            ),
                            SizedBox(width: kSpacing8),
                            Text(
                              'Delete',
                              style: Theme.of(context).textTheme.titleSmall!
                                  .copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: context.appColors.expenseColor,
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
    );
  }

  Widget _gridItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: kSpacing6),
        Text(
          label,
          style: Theme.of(context)
              .extension<AppTypographyTheme>()!
              .labelMicro
              .copyWith(fontWeight: FontWeight.w500, color: context.appColors.textMedium),
        ),
        const SizedBox(height: kSpacing2),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _verticalDivider(Color onSurface) {
    return Container(
      width: 0.5,
      height: 36,
      color: onSurface.withValues(alpha: 0.1),
    );
  }

  Widget _divider(Color onSurface) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: onSurface.withValues(alpha: 0.1),
    );
  }

  Widget _copyableDetailRow(
    BuildContext context,
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    final onSurface = theme.colorScheme.onSurface;
    return Container(
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.022),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: onSurface.withValues(alpha: 0.045),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied $label to clipboard'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                width: 250,
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: kSpacing10,
              horizontal: kSpacing12,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(kSpacing8),
                  decoration: BoxDecoration(
                    color: onSurface.withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: kSpacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context)
                            .extension<AppTypographyTheme>()!
                            .labelMicro
                            .copyWith(color: context.appColors.textMedium),
                      ),
                      const SizedBox(height: kSpacing2),
                      Text(
                        value,
                        style: Theme.of(context).textTheme.titleSmall!.copyWith(
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: kSpacing12),
                Icon(
                  Icons.copy_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final onSurface = theme.colorScheme.onSurface;
    return Container(
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.022),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: onSurface.withValues(alpha: 0.045),
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: kSpacing10,
        horizontal: kSpacing12,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(kSpacing8),
            decoration: BoxDecoration(
              color: onSurface.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: kSpacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: kSpacing2),
                Text(
                  value,
                  style: theme.textTheme.titleSmall!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcode(BuildContext context, String id, Color onSurface) {
    final random = id.hashCode;
    final barColor = onSurface.withValues(alpha: 0.225);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: kSpacing16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(24, (index) {
              final width = ((index + random) % 3 + 1.0);
              final space = ((index * random) % 2 + 1.0);
              return Container(
                width: width,
                color: barColor,
                margin: EdgeInsets.only(right: space),
              );
            }),
          ),
        ),
        const SizedBox(height: kSpacing6),
        Text(
          'PESAFLOW-TXN-${id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase()}',
          style: context.ts(
            10,
            fontWeight: FontWeight.w600,
            color: onSurface.withValues(alpha: 0.38),
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    ModernDialog.show(
      context: context,
      title: const Text('Delete Transaction'),
      titleIcon: PesaFlowIcons.delete,
      iconColor: theme.colorScheme.error,
      content: const Text(
        'Are you sure you want to delete this transaction? This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            try {
              await ref
                  .read(transactionRepositoryProvider)
                  .deleteTransaction(transactionId);
              ref.invalidate(recentTransactionsStreamProvider);
              ref.invalidate(accountsStreamProvider);
              ref.invalidate(netWorthProvider);
              ref.invalidate(monthlyTotalsProvider);
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pop();
                context.pop();
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
              }
            }
          },
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

class DashedDivider extends StatelessWidget {
  final double height;
  final double dashWidth;
  final double dashSpace;
  final Color color;

  const DashedDivider({
    super.key,
    this.height = 1,
    this.dashWidth = 6,
    this.dashSpace = 4,
    this.color = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: height,
              child: DecoratedBox(decoration: BoxDecoration(color: color)),
            );
          }),
        );
      },
    );
  }
}
