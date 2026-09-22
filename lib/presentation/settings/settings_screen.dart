import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/utils/scroll_helpers.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/database_providers.dart';
import 'package:pesaflow/data/repositories/category_repository.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/ios/ios_list_section.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/presentation/common/widgets/spring_sheet_route.dart';
import 'package:pesaflow/presentation/settings/widgets/export_dialog.dart';
import 'package:pesaflow/presentation/settings/widgets/import_dialog.dart';
import 'package:pesaflow/presentation/dashboard/widgets/workspace_dialogs.dart';

import 'package:pesaflow/services/backup_service.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/ios_large_title_header.dart';
import 'widgets/accounts_manager_sheet.dart';
import 'widgets/categories_manager_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();

  static void showAccountsManager(BuildContext context, WidgetRef ref) =>
      showAccountsManager(context, ref);
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.scrollToTop(context);
  }

  Future<void> _handleExportCsv(BuildContext context, WidgetRef ref) async {
    try {
      CustomToast.show(
        context,
        message: 'Generating CSV export...',
        type: ToastType.info,
      );
      await ref.read(backupServiceProvider).exportTransactionsToCsv();
    } catch (e) {
      if (context.mounted) {
        CustomToast.show(
          context,
          message: 'Failed to export CSV: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _handleImportCsv(BuildContext context, WidgetRef ref) async {
    final accounts = ref.read(accountsStreamProvider).value ?? [];
    final categories = await ref
        .read(categoryRepositoryProvider)
        .getAllCategories();

    if (!context.mounted) return;

    final result = await showImportCsvDialog(
      context,
      accounts: accounts,
      categories: categories,
    );

    if (result == null || !context.mounted) return;

    final repo = ref.read(transactionRepositoryProvider);
    final validTxs = <Transaction>[];

    for (final tx in result.transactions) {
      try {
        final resolvedTx = tx.accountId == null && result.accountId != null
            ? Transaction(
                id: tx.id,
                accountId: result.accountId,
                categoryId: tx.categoryId,
                amount: tx.amount,
                type: tx.type,
                description: tx.description,
                reference: tx.reference,
                sender: tx.sender,
                recipient: tx.recipient,
                source: tx.source,
                createdAt: tx.createdAt,
                updatedAt: tx.updatedAt,
              )
            : tx;

        validTxs.add(resolvedTx);
      } catch (_) {
        // Skip duplicates or invalid rows
      }
    }

    if (validTxs.isNotEmpty) {
      await repo.createTransactionsBatchNoBalanceAdjustment(validTxs);
    }

    if (context.mounted) {
      CustomToast.show(
        context,
        message: 'Imported ${validTxs.length} transactions',
        type: ToastType.success,
      );
    }
  }

  Future<void> _handleBackupDb(BuildContext context, WidgetRef ref) async {
    try {
      CustomToast.show(
        context,
        message: 'Creating local backup...',
        type: ToastType.info,
      );
      await ref.read(backupServiceProvider).backupDatabase();
    } catch (e) {
      if (context.mounted) {
        CustomToast.show(
          context,
          message: 'Backup failed: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _handleRestoreDb(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);

    // Confirmation dialog before destructive operation
    final confirmed = await ModernDialog.show<bool>(
      context: context,
      title: const Text('Restore Database?'),
      titleIcon: PesaFlowIcons.warning,
      iconColor: context.appColors.warningColor,
      content: const Text(
        'This will replace all current data with the backup file you select. '
        'This action cannot be undone.\n\n'
        'Consider creating a backup first.',
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: context.appColors.warningColor,
            foregroundColor: theme.colorScheme.onTertiary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            ),
          ),
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
          child: const Text('Restore'),
        ),
      ],
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final success = await ref.read(backupServiceProvider).restoreDatabase();
      if (!success || !context.mounted) return;

      // Invalidate the database connection and all dependent providers to hot-reload restored data instantly
      ref.invalidate(databaseProvider);
      ref.invalidate(accountsStreamProvider);
      ref.invalidate(categoriesFutureProvider);
      ref.invalidate(recentTransactionsStreamProvider);
      ref.invalidate(netWorthProvider);
      ref.invalidate(activeTrackerProvider);
      ref.invalidate(budgetProgressProvider);
      ref.invalidate(monthlyTotalsProvider);
      ref.invalidate(topCategoriesProvider);
      ref.invalidate(monthlySnapshotsProvider);
      ref.invalidate(insightsProvider);
      ref.invalidate(savingsGoalsStreamProvider);
      ref.invalidate(loansStreamProvider);
      ref.invalidate(recurringTransactionsStreamProvider);

      CustomToast.show(
        context,
        message: 'Profile restored successfully',
        type: ToastType.success,
      );
    } catch (e) {
      if (context.mounted) {
        ModernDialog.show(
          context: context,
          title: const Text('Restore Failed'),
          titleIcon: PesaFlowIcons.error,
          iconColor: theme.colorScheme.error,
          content: Text(
            e is FormatException
                ? e.message
                : 'An unexpected error occurred during database restoration: $e',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      }
    }
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);
    showSpringSheet(
      context,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: kSpacing24,
            horizontal: kSpacing20,
          ),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.94),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: kSpacing20),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                ),
              ),
              Text(
                'App Theme',
                style: context.ts(22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: kSpacing16),
              _themeOption(
                ctx,
                ref,
                ThemeMode.system,
                current,
                'System default',
                PesaFlowIcons.themeMode,
                'Follow your device settings',
              ),
              _themeOption(
                ctx,
                ref,
                ThemeMode.light,
                current,
                'Light',
                PesaFlowIcons.lightMode,
                'Always use light mode',
              ),
              _themeOption(
                ctx,
                ref,
                ThemeMode.dark,
                current,
                'Dark',
                PesaFlowIcons.darkMode,
                'Always use dark mode',
              ),
              const SizedBox(height: kSpacing12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeOption(
    BuildContext ctx,
    WidgetRef ref,
    ThemeMode mode,
    ThemeMode current,
    String label,
    IconData icon,
    String subtitle,
  ) {
    final isSelected = mode == current;
    final theme = Theme.of(ctx);
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpacing8),
      child: TactileSpringContainer(
        selectedColor: theme.colorScheme.onSurface,
        onTap: () {
          ref.read(themeModeProvider.notifier).setThemeMode(mode);
          Navigator.pop(ctx);
        },
        child: Container(
          padding: const EdgeInsets.all(kSpacing16),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                : (theme.brightness == Brightness.dark
                      ? AppTheme.surfaceContainerDark
                      : AppTheme.surfaceLight),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.3)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(kSpacing10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                      : ctx.appColors.textMedium.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : ctx.appColors.textMedium,
                  size: 20,
                ),
              ),
              const SizedBox(width: kSpacing14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: ctx.ts(
                        14,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? theme.colorScheme.primary : null,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: ctx.ts(
                        11,
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.7)
                            : ctx.appColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  PesaFlowIcons.success,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSquircleIcon({
    required BuildContext context,
    required IconData icon,
    required Color color,
    double size = 18,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusCompact),
      ),
      child: Center(
        child: Icon(icon, color: color, size: size),
      ),
    );
  }

  Widget _buildMetricTile({
    required BuildContext context,
    required ThemeData theme,
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null
            ? () {
                PesaHaptics.selection();
                onTap();
              }
            : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: kSpacing12,
            horizontal: kSpacing8,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.20),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Center(child: Icon(icon, color: color, size: 15)),
              ),
              const SizedBox(height: kSpacing6),
              Text(
                value,
                style: context.ts(
                  16,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: kSpacing2),
              Text(
                label,
                style: context.ts(
                  11,
                  color: context.appColors.textMedium,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(scrollToTopProvider, (_, _) => _scrollToTop());
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsStreamProvider).value ?? [];
    final categories = ref.watch(categoriesFutureProvider).value ?? [];
    final totalTransactionsCount =
        ref.watch(totalTransactionsCountProvider).value ?? 0;
    final trackers = ref.watch(allTrackersStreamProvider).value ?? [];
    final activeId = ref.watch(activeTrackerIdProvider);
    final activeTracker =
        trackers.where((t) => t.id == activeId).firstOrNull ??
        (trackers.isNotEmpty ? trackers.first : null);

    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: SingleChildScrollView(
          controller: _scrollController,
          key: const PageStorageKey('settings'),
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(bottom: IosTabBar.navBarHeight + kSpacing32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Header ──
              IosLargeTitleHeader(
                title: 'Settings',
                scrollController: _scrollController,
              ),

              const SizedBox(height: kSpacing8),

              // ── Executive Database Snapshot Card ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kSpacing16),
                child: Container(
                  padding: const EdgeInsets.all(kSpacing16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.28,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: context.isDark ? 0.22 : 0.04,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Active Workspace Row with tap to switch
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            PesaHaptics.light();
                            showWorkspaceSelectorSheet(context, ref);
                          },
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSmall,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: kSpacing2,
                            ),
                            child: Row(
                              children: [
                                _buildSquircleIcon(
                                  context: context,
                                  icon: PesaFlowIcons.home,
                                  color: theme.colorScheme.primary,
                                  size: 19,
                                ),
                                const SizedBox(width: kSpacing12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        activeTracker?.name ??
                                            'Personal Workspace',
                                        style: context.ts(
                                          16,
                                          fontWeight: FontWeight.w700,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: kSpacing2),
                                      Text(
                                        'Active Offline Workspace',
                                        style: context.ts(
                                          12,
                                          color: context.appColors.textMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: kSpacing10,
                                    vertical: kSpacing4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.appColors.incomeColor
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusPill,
                                    ),
                                    border: Border.all(
                                      color: context.appColors.incomeColor
                                          .withValues(alpha: 0.30),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: context.appColors.incomeColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: kSpacing4),
                                      Text(
                                        'Offline',
                                        style: context.ts(
                                          11,
                                          fontWeight: FontWeight.w600,
                                          color: context.appColors.incomeColor,
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
                      const SizedBox(height: kSpacing12),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.20,
                        ),
                      ),
                      const SizedBox(height: kSpacing12),
                      // 3-Metric Summary Strip
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              context: context,
                              theme: theme,
                              icon: PesaFlowIcons.wallet,
                              color: theme.colorScheme.primary,
                              label: 'Accounts',
                              value: '${accounts.length}',
                              onTap: () => showAccountsManager(context, ref),
                            ),
                          ),
                          const SizedBox(width: kSpacing8),
                          Expanded(
                            child: _buildMetricTile(
                              context: context,
                              theme: theme,
                              icon: PesaFlowIcons.category,
                              color: context.appColors.transferColor,
                              label: 'Categories',
                              value: '${categories.length}',
                              onTap: () => showCategoriesManager(context, ref),
                            ),
                          ),
                          const SizedBox(width: kSpacing8),
                          Expanded(
                            child: _buildMetricTile(
                              context: context,
                              theme: theme,
                              icon: PesaFlowIcons.transactions,
                              color: context.appColors.incomeColor,
                              label: 'Transactions',
                              value: '$totalTransactionsCount',
                              onTap: () => context.push('/transactions'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: kSpacing8),

              // ── Section 1: Organization & Accounts ──
              StaggeredFadeSlide(
                index: 0,
                child: IosListSection(
                  header: 'ORGANIZATION & STRUCTURE',
                  rows: [
                    IosListRow(
                      leading: _buildSquircleIcon(
                        context: context,
                        icon: PesaFlowIcons.home,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('Manage Workspaces'),
                      subtitle: const Text(
                        'Switch or create offline workspaces',
                      ),
                      onTap: () {
                        PesaHaptics.light();
                        showWorkspaceSelectorSheet(context, ref);
                      },
                    ),
                    IosListRow(
                      leading: _buildSquircleIcon(
                        context: context,
                        icon: PesaFlowIcons.wallet,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('Accounts Manager'),
                      subtitle: Text(
                        '${accounts.length} active wallets (Bank, M-Pesa, Cash)',
                      ),
                      onTap: () => showAccountsManager(context, ref),
                    ),
                    IosListRow(
                      leading: _buildSquircleIcon(
                        context: context,
                        icon: PesaFlowIcons.category,
                        color: context.appColors.transferColor,
                      ),
                      title: const Text('Categories Manager'),
                      subtitle: Text(
                        '${categories.length} income & expense categories',
                      ),
                      onTap: () => showCategoriesManager(context, ref),
                    ),
                    IosListRow(
                      leading: _buildSquircleIcon(
                        context: context,
                        icon: PesaFlowIcons.subscriptions,
                        color: context.appColors.incomeColor,
                      ),
                      title: const Text('Recurring & Bills'),
                      subtitle: const Text(
                        'Manage scheduled commitments & subscriptions',
                      ),
                      onTap: () => context.push('/recurring'),
                    ),
                  ],
                ),
              ),

              // ── Section 2: Automation & Intelligence ──
              StaggeredFadeSlide(
                index: 1,
                child: IosListSection(
                  header: 'AUTOMATION & BUDGETING',
                  rows: [
                    IosToggleRow(
                      leading: _buildSquircleIcon(
                        context: context,
                        icon: PesaFlowIcons.budgets,
                        color: context.appColors.incomeColor,
                      ),
                      title: const Text('Auto-Budget on Income'),
                      subtitle: const Text(
                        'Automatically allocate 50/30/20 budgets on deposits',
                      ),
                      value:
                          ref.watch(autoBudgetEnabledProvider).value ?? false,
                      onChanged: (val) async {
                        PesaHaptics.light();
                        await ref
                            .read(settingsRepositoryProvider)
                            .setSetting('auto_budget_enabled', val.toString());
                        if (val) {
                          if (!context.mounted) return;
                          CustomToast.show(
                            context,
                            message: 'Auto-budget enabled — 50/30/20 split',
                            type: ToastType.success,
                          );
                        }
                      },
                    ),
                    IosToggleRow(
                      leading: _buildSquircleIcon(
                        context: context,
                        icon: PesaFlowIcons.sms,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('SMS Auto-Deduplication'),
                      subtitle: const Text(
                        'Automatically deduplicate incoming telco messages',
                      ),
                      value:
                          ref.watch(smsAutoDeduplicationProvider).value ??
                          false,
                      onChanged: (val) {
                        PesaHaptics.light();
                        ref
                            .read(settingsRepositoryProvider)
                            .setSetting(
                              'sms_auto_deduplication',
                              val.toString(),
                            );
                      },
                    ),
                  ],
                ),
              ),

              // ── Section 3: Preferences & Security ──
              StaggeredFadeSlide(
                index: 2,
                child: IosListSection(
                  header: 'PREFERENCES & SECURITY',
                  rows: [
                    IosListRow(
                      leading: _buildSquircleIcon(
                        context: context,
                        icon: PesaFlowIcons.themeMode,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('App Theme'),
                      subtitle: Text(switch (ref.watch(themeModeProvider)) {
                        ThemeMode.light => 'Light appearance',
                        ThemeMode.dark => 'Dark appearance',
                        _ => 'System default',
                      }),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            switch (ref.watch(themeModeProvider)) {
                              ThemeMode.light => 'Light',
                              ThemeMode.dark => 'Dark',
                              _ => 'System',
                            },
                            style: context.ts(
                              13,
                              color: context.appColors.textMedium,
                            ),
                          ),
                          const SizedBox(width: kSpacing4),
                          Icon(
                            PesaFlowIcons.chevronRight,
                            size: 18,
                            color: context.appColors.textMedium,
                          ),
                        ],
                      ),
                      onTap: () => _showThemePicker(context, ref),
                    ),
                    IosToggleRow(
                      leading: _buildSquircleIcon(
                        context: context,
                        icon: PesaFlowIcons.pin,
                        color: context.appColors.transferColor,
                      ),
                      title: const Text('Show Decimals'),
                      subtitle: const Text(
                        'Format currency with cents (.00) globally',
                      ),
                      value:
                          ref.watch(currencyShowDecimalsProvider).value ??
                          false,
                      onChanged: (val) {
                        PesaHaptics.light();
                        ref
                            .read(settingsRepositoryProvider)
                            .setSetting(
                              'currency_show_decimals',
                              val.toString(),
                            );
                      },
                    ),
                    IosToggleRow(
                      leading: _buildSquircleIcon(
                        context: context,
                        icon: PesaFlowIcons.biometric,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('Biometric App Lock'),
                      subtitle: const Text(
                        'Require biometrics to open PesaFlow',
                      ),
                      value: ref.watch(appLockEnabledProvider).value ?? false,
                      onChanged: (val) {
                        PesaHaptics.light();
                        ref
                            .read(settingsRepositoryProvider)
                            .setSetting('app_lock_enabled', val.toString());
                      },
                    ),
                    IosToggleRow(
                      leading: _buildSquircleIcon(
                        context: context,
                        icon: PesaFlowIcons.unlock,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('Lock Screen Balance'),
                      subtitle: const Text(
                        'Show current balance in notification shade',
                      ),
                      value:
                          ref.watch(lockScreenBalanceEnabledProvider).value ??
                          false,
                      onChanged: (val) {
                        PesaHaptics.light();
                        ref
                            .read(settingsRepositoryProvider)
                            .setSetting('lock_screen_balance', val.toString());
                      },
                    ),
                    IosListRow(
                      leading: _buildSquircleIcon(
                        context: context,
                        icon: PesaFlowIcons.security,
                        color: context.appColors.incomeColor,
                      ),
                      title: const Text('Offline Privacy Guarantee'),
                      subtitle: const Text(
                        '100% on-device storage. Zero cloud transfers.',
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kSpacing8,
                          vertical: kSpacing2,
                        ),
                        decoration: BoxDecoration(
                          color: context.appColors.incomeColor.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
                        ),
                        child: Text(
                          'Local',
                          style: context.ts(
                            11,
                            fontWeight: FontWeight.w600,
                            color: context.appColors.incomeColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Section 4: Data & Backup ──
              StaggeredFadeSlide(
                index: 3,
                child: IosListSection(
                  header: 'DATA & STORAGE',
                  rows: [
                    IosListRow(
                      leading: _buildSquircleIcon(
                        context: context,
                        icon: PesaFlowIcons.file,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('Export Monthly Statement'),
                      subtitle: const Text('Download formatted PDF or CSV'),
                      onTap: () => showExportDialog(context, ref),
                    ),
                    IosListRow(
                      leading: _buildSquircleIcon(
                        context: context,
                        icon: PesaFlowIcons.download,
                        color: context.appColors.transferColor,
                      ),
                      title: const Text('Export to CSV'),
                      subtitle: const Text('Download transactions as CSV file'),
                      onTap: () => _handleExportCsv(context, ref),
                    ),
                    IosListRow(
                      leading: _buildSquircleIcon(
                        context: context,
                        icon: PesaFlowIcons.upload,
                        color: context.appColors.transferColor,
                      ),
                      title: const Text('Import CSV'),
                      subtitle: const Text('Import transactions from CSV file'),
                      onTap: () => _handleImportCsv(context, ref),
                    ),
                    IosListRow(
                      leading: _buildSquircleIcon(
                        context: context,
                        icon: PesaFlowIcons.backup,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('Backup Database'),
                      subtitle: const Text(
                        'Save an offline backup of your data',
                      ),
                      onTap: () => _handleBackupDb(context, ref),
                    ),
                    IosListRow(
                      leading: _buildSquircleIcon(
                        context: context,
                        icon: PesaFlowIcons.restore,
                        color: context.appColors.warningColor,
                      ),
                      title: const Text('Restore Database'),
                      subtitle: const Text(
                        'Restore from a previous backup file',
                      ),
                      onTap: () => _handleRestoreDb(context, ref),
                    ),
                  ],
                ),
              ),

              // ── Section 5: Developer Diagnostics ──
              StaggeredFadeSlide(
                index: 4,
                child: IosListSection(
                  header: 'DEVELOPER & DIAGNOSTICS',
                  rows: [
                    IosListRow(
                      leading: _buildSquircleIcon(
                        context: context,
                        icon: PesaFlowIcons.info,
                        color: context.appColors.warningColor,
                      ),
                      title: const Text('SMS Parser Debug'),
                      subtitle: const Text(
                        'Test SMS parsing pipeline step-by-step',
                      ),
                      onTap: () => context.push('/debug/sms-parser'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: kSpacing24),
            ],
          ),
        ),
      ),
    );
  }
}
