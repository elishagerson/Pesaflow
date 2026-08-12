import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/state/insight_provider.dart';
import 'package:pesaflow/presentation/state/sms_stats_provider.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';
import 'package:pesaflow/presentation/common/widgets/morphing_insight_card.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/state/palette_provider.dart';
import 'package:pesaflow/presentation/common/widgets/motion/spring_button.dart';
import 'package:pesaflow/presentation/common/widgets/motion/haptic_pattern.dart';
import 'package:pesaflow/presentation/dashboard/widgets/add_account_dialog.dart';
import 'package:pesaflow/presentation/dashboard/widgets/workspace_dialogs.dart';
import 'package:pesaflow/presentation/dashboard/widgets/monthly_overview_section.dart';
import 'package:pesaflow/presentation/dashboard/widgets/dashboard_widgets.dart';
import 'package:pesaflow/presentation/dashboard/widgets/spending_heatmap_card.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/motion/skeleton_crossfade.dart';
import 'package:pesaflow/services/home_widgets_renderer.dart';
import 'package:pesaflow/presentation/state/spending_heatmap_provider.dart';
import 'package:pesaflow/presentation/common/widgets/interactive_3d_card.dart';
import 'package:pesaflow/presentation/common/widgets/undo_delete.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';

final cardholderNameProvider = StreamProvider<String>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo
      .watchSetting('cardholder_name')
      .map((val) => val ?? 'TOTAL NET WORTH');
});

/// Flip card that shows NET WORTH on front and BUDGET BALANCE on back.
/// Tap to flip with a spring animation.
class _BalanceHeroCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  final BorderRadius borderRadius;

  const _BalanceHeroCard({
    required this.front,
    required this.back,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });

  @override
  State<_BalanceHeroCard> createState() => _BalanceHeroCardState();
}

class _BalanceHeroCardState extends State<_BalanceHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _showFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    final target = _showFront ? 1.0 : 0.0;
    _showFront = !_showFront;

    final simulation = SpringSimulation(
      const SpringDescription(mass: 0.8, stiffness: 300, damping: 18),
      _controller.value,
      target,
      0,
    );
    _controller.animateWith(simulation);
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final angle = _controller.value * math.pi;
          final isFront = angle < math.pi / 2;

          return ClipRRect(
            borderRadius: widget.borderRadius,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              child: isFront
                  ? widget.front
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: widget.back,
                    ),
            ),
          );
        },
      ),
    );
  }
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _selectedAccountId;
  final Set<String> _pendingDeleteIds = {};
  Timer? _homeWidgetCaptureTimer;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _homeWidgetCaptureTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrolls back to the top when the active Dashboard tab is re-tapped.
  void _scrollToTop() {
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    if (!_scrollController.hasClients) return;
    if (_scrollController.offset <= 0) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scrollController.jumpTo(0);
    } else {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _showAddAccountDialog(BuildContext context) {
    showAddAccountDialog(context, ref);
  }

  String _formatCompact(int amountInCents) {
    final double value = amountInCents / 100.0;
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    }
    return value.toStringAsFixed(0);
  }

  Widget _buildCardNetworkLogo(Color trackerColor) {
    return SizedBox(
      width: 32,
      height: 22,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            right: 12,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            left: 12,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: trackerColor.withValues(alpha: 0.65),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyOverview(ThemeData theme) {
    return const MonthlyOverviewSection();
  }

  void _showWorkspaceSelectorSheet(BuildContext context) {
    showWorkspaceSelectorSheet(context, ref);
  }

  /// Debounces AppWidget captures so launcher widgets only refresh after data
  /// settles, and only while the dashboard is the visible route.
  void _scheduleHomeWidgetCaptures() {
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    _homeWidgetCaptureTimer?.cancel();
    _homeWidgetCaptureTimer = Timer(const Duration(milliseconds: 1200), () {
      _captureHomeWidgets();
    });
  }

  Future<void> _captureHomeWidgets() async {
    await HomeWidgetsRenderer.captureAndUpdate(
      key: HomeWidgetsRenderer.heatmapKey,
      imageKey: 'heatmap_image_path',
      widgetName: 'SpendingHeatmapWidgetProvider',
    );
    await HomeWidgetsRenderer.captureAndUpdate(
      key: HomeWidgetsRenderer.safeToSpendKey,
      imageKey: 'safe_to_spend_image_path',
      widgetName: 'SafeToSpendWidgetProvider',
    );
    await HomeWidgetsRenderer.captureAndUpdate(
      key: HomeWidgetsRenderer.quickTemplatesKey,
      imageKey: 'quick_templates_image_path',
      widgetName: 'QuickTemplatesWidgetProvider',
    );
    await HomeWidgetsRenderer.captureAndUpdate(
      key: HomeWidgetsRenderer.recentTransactionsKey,
      imageKey: 'recent_transactions_image_path',
      widgetName: 'RecentTransactionsWidgetProvider',
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(scrollToTopProvider, (_, _) {
      _scrollToTop();
    });
    final accountsAsync = ref.watch(accountsStreamProvider);
    final recentTransAsync = ref.watch(recentTransactionsStreamProvider);
    final budgetsAsync = ref.watch(budgetProgressProvider);
    final reviewQueueAsync = ref.watch(reviewQueueStreamProvider);
    final totalsAsync = ref.watch(monthlyTotalsProvider);
    final savingsGoalsAsync = ref.watch(savingsGoalsStreamProvider);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final cardholderName =
        ref.watch(cardholderNameProvider).value ?? 'TOTAL NET WORTH';

    // Active tracker properties for dynamic aesthetic blending
    final activeTrackerAsync = ref.watch(activeTrackerProvider);
    final trackerColor = activeTrackerAsync.maybeWhen(
      data: (tracker) => tracker != null
          ? hexToColor(tracker.color)
          : theme.colorScheme.primary,
      orElse: () => theme.colorScheme.primary,
    );
    final trackerName = activeTrackerAsync.maybeWhen(
      data: (tracker) => tracker != null ? tracker.name : 'Personal',
      orElse: () => 'Personal',
    );

    // Calculate budget overall spent percentage and Safe-to-Spend
    final budgets = budgetsAsync.value ?? [];
    double overallPct = 0.0;
    int remainingBudget = 0;
    int budgetTotal = 0;
    if (budgets.isNotEmpty) {
      double totalSpent = 0;
      double totalAllocated = 0;
      for (final bp in budgets) {
        totalSpent += bp.spentInPeriod;
        totalAllocated += bp.currentPeriod?.allocated ?? bp.budget.amount;
      }
      budgetTotal = totalAllocated.round();
      remainingBudget = (totalAllocated - totalSpent).round();
      if (totalAllocated > 0) {
        overallPct = (totalSpent / totalAllocated).clamp(0.0, 1.0);
      }
    } else {
      // Dynamic fallback if no budgets are set: compute spent vs income from actual transactions!
      final totals = totalsAsync.value;
      if (totals != null) {
        final income = totals['income'] ?? 0;
        final expense = totals['expense'] ?? 0;
        budgetTotal = income;
        remainingBudget = income - expense;
        if (income > 0) {
          overallPct = (expense / income).clamp(0.0, 1.0);
        } else if (expense > 0) {
          overallPct = 1.0; // Has expenses but no income logged -> 100% spent
        } else {
          overallPct = 0.0; // Fresh app startup, no transactions -> 0% spent
        }
      } else {
        overallPct = 0.0;
      }
    }

    final pendingReviewCount = reviewQueueAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    final accounts = accountsAsync.value ?? [];

    // Dynamic Balance card color properties matching HIG/M3 design brief
    final cardGradient = LinearGradient(
      colors: [
        trackerColor.withValues(alpha: 0.22),
        theme.colorScheme.surfaceContainerHigh,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    const Color heroTextColor = Colors.white;

    final recsAsync = ref.watch(recurringTransactionsStreamProvider);
    final dueAsync = ref.watch(dueRecurringTransactionsProvider);

    final heatmapAsync = ref.watch(spendingHeatmapProvider);
    final templatesAsync = ref.watch(transactionTemplatesStreamProvider);

    // Debounce AppWidget captures so launcher widgets refresh once data
    // settles instead of re-capturing on every dashboard rebuild.
    _scheduleHomeWidgetCaptures();

    return Stack(
      children: [
        Scaffold(
          appBar: IosNavBar(
            title: '${_getGreeting()}, $trackerName',
            largeTitle: true,
            leading: TactileSpringContainer(
              onTap: () => _showWorkspaceSelectorSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacing14,
                  vertical: kSpacing8,
                ),
                decoration: BoxDecoration(
                  color: onSurface.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: onSurface.withValues(alpha: 0.07),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: trackerColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: kSpacing8),
                    Text(
                      trackerName,
                      style: context.ts(
                        13,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(width: kSpacing4),
                    Icon(
                      PesaFlowIcons.chevronDown,
                      size: 14,
                      color: onSurface.withValues(alpha: 0.45),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TactileSpringContainer(
                onTap: () =>
                    ref.read(paletteVisibilityProvider.notifier).toggle(),
                child: Container(
                  padding: const EdgeInsets.all(kSpacing10),
                  decoration: BoxDecoration(
                    color: onSurface.withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: onSurface.withValues(alpha: 0.08),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(PesaFlowIcons.search, color: onSurface, size: 20),
                ),
              ),
              const SizedBox(width: kSpacing8),
              TactileSpringContainer(
                onTap: () => context.go('/settings'),
                child: Container(
                  padding: const EdgeInsets.all(kSpacing10),
                  decoration: BoxDecoration(
                    color: onSurface.withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: onSurface.withValues(alpha: 0.08),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    PesaFlowIcons.personOutline,
                    color: onSurface,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: kSpacing8),
              TactileSpringContainer(
                onTap: () => context.push('/sms-review'),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(kSpacing10),
                      decoration: BoxDecoration(
                        color: onSurface.withValues(alpha: 0.04),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: onSurface.withValues(alpha: 0.08),
                          width: 0.8,
                        ),
                      ),
                      child: Icon(
                        PesaFlowIcons.notification,
                        size: 20,
                        color: onSurface,
                      ),
                    ),
                    if (pendingReviewCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpacing4,
                            vertical: kSpacing2,
                          ),
                          decoration: BoxDecoration(
                            color: context.appColors.expenseColor,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: theme.colorScheme.surface,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '$pendingReviewCount',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
                  final double velocity =
                      notification.scrollDelta?.abs() ?? 0.0;
                  final double rawSpeed =
                      1.0 + (velocity / 12.0).clamp(0.0, 4.0);
                  // Quantize to 0.5 increments to avoid per-frame provider writes
                  final double quantized = (rawSpeed * 2).roundToDouble() / 2;
                  final current = ref.read(scrollSpeedProvider);
                  if (current != quantized) {
                    ref.read(scrollSpeedProvider.notifier).state = quantized;
                  }
                } else if (notification is ScrollEndNotification) {
                  if (ref.read(scrollSpeedProvider) != 1.0) {
                    ref.read(scrollSpeedProvider.notifier).state = 1.0;
                  }
                }
                return false;
              },
              child: RefreshIndicator(
                color: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surface,
                onRefresh: () async {
                  ref.invalidate(monthlyTotalsProvider);
                  ref.invalidate(netWorthProvider);
                  ref.invalidate(accountsStreamProvider);
                  ref.invalidate(budgetProgressProvider);
                  ref.invalidate(recentTransactionsStreamProvider);
                  ref.invalidate(reviewQueueStreamProvider);
                  ref.invalidate(savingsGoalsStreamProvider);
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    top: kSpacing4,
                    bottom: IosTabBar.navBarHeight + kSpacing32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kSpacing16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── 2. Balance Hero Card — tap to flip ──
                            Consumer(
                              builder: (context, ref, _) {
                                final accountsAsync = ref.watch(
                                  accountsStreamProvider,
                                );
                                final accounts = accountsAsync.value ?? [];
                                final netWorth = ref.watch(netWorthProvider);
                                final displayBalance =
                                    _selectedAccountId != null
                                    ? (accounts
                                          .firstWhere(
                                            (a) => a.id == _selectedAccountId,
                                            orElse: () => accounts.first,
                                          )
                                          .balance)
                                    : netWorth;

                                final front = _buildBalanceCardFront(
                                  context: context,
                                  ref: ref,
                                  theme: theme,
                                  trackerColor: trackerColor,
                                  heroTextColor: heroTextColor,
                                  cardGradient: cardGradient,
                                  accounts: accounts,
                                  netWorth: displayBalance,
                                  overallPct: overallPct,
                                  budgetTotal: budgetTotal,
                                  cardholderName: cardholderName,
                                );

                                final back = _buildBalanceCardBack(
                                  context: context,
                                  theme: theme,
                                  trackerColor: trackerColor,
                                  heroTextColor: heroTextColor,
                                  cardGradient: cardGradient,
                                  overallPct: overallPct,
                                  budgetTotal: budgetTotal,
                                  remainingBudget: remainingBudget,
                                );

                                return StaggeredFadeSlide(
                                  index: 0,
                                  child: Interactive3DCard(
                                    borderRadius: AppTheme.radiusCard,
                                    shadowColor: trackerColor,
                                    maxTiltX: 0.08,
                                    maxTiltY: 0.08,
                                    glareOpacity: 0.12,
                                    child: AspectRatio(
                                      aspectRatio: 1.58,
                                      child: _BalanceHeroCard(
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusCard,
                                        ),
                                        front: front,
                                        back: back,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            // ── 2b. Account Pills (Below Card) ──
                            if (accounts.isNotEmpty) ...[
                              const SizedBox(height: kSpacing16),
                              SizedBox(
                                height: 36,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: accounts.length,
                                  itemBuilder: (context, index) {
                                    final account = accounts[index];
                                    final isSelected =
                                        _selectedAccountId == account.id;

                                    return Padding(
                                      padding: EdgeInsets.only(
                                        right: kSpacing8,
                                        left: index == 0 ? kSpacing2 : 0.0,
                                      ),
                                      child: TactileSpringContainer(
                                        onTap: () {
                                          setState(() {
                                            if (_selectedAccountId ==
                                                account.id) {
                                              _selectedAccountId =
                                                  null; // Clear filter
                                            } else {
                                              _selectedAccountId =
                                                  account.id; // Apply filter
                                            }
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: kSpacing14,
                                            vertical: kSpacing6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? theme.colorScheme.primary
                                                      .withValues(alpha: 0.25)
                                                : theme
                                                      .colorScheme
                                                      .surfaceContainerHigh,
                                            borderRadius: BorderRadius.circular(
                                              100,
                                            ),
                                            border: Border.all(
                                              color: isSelected
                                                  ? theme.colorScheme.primary
                                                        .withValues(alpha: 0.6)
                                                  : theme.colorScheme.onSurface
                                                        .withValues(alpha: 0.1),
                                              width: isSelected ? 1.5 : 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                getAccountIcon(account.icon),
                                                size: 14,
                                                color: isSelected
                                                    ? theme.colorScheme.primary
                                                    : theme
                                                          .colorScheme
                                                          .onSurface,
                                              ),
                                              const SizedBox(width: kSpacing6),
                                              Text(
                                                account.name,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isSelected
                                                          ? theme
                                                                .colorScheme
                                                                .primary
                                                          : theme
                                                                .colorScheme
                                                                .onSurface,
                                                    ),
                                              ),
                                              const SizedBox(width: kSpacing8),
                                              Text(
                                                _formatCompact(account.balance),
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      fontFamily: 'monospace',
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isSelected
                                                          ? theme
                                                                .colorScheme
                                                                .primary
                                                                .withValues(
                                                                  alpha: 0.9,
                                                                )
                                                          : theme
                                                                .colorScheme
                                                                .onSurface
                                                                .withValues(
                                                                  alpha: 0.8,
                                                                ),
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: kSpacing16),
                              Center(
                                child: Text(
                                  'No active accounts. Tap Add Account below to start.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: kSpacing16),

                            // ── 3. High-Contrast Action Buttons ──
                            StaggeredFadeSlide(
                              index: 1,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TactileSpringContainer(
                                      onTap: () =>
                                          context.go('/transactions/add'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: kSpacing16,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              theme.colorScheme.inverseSurface,
                                          borderRadius: BorderRadius.circular(
                                            100,
                                          ),
                                          border: Border.all(
                                            color: theme
                                                .colorScheme
                                                .inverseSurface,
                                            width: 1.0,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: trackerColor.withValues(
                                                alpha: 0.15,
                                              ),
                                              blurRadius: 10,
                                              spreadRadius: 0.5,
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              PesaFlowIcons.add,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            const SizedBox(width: kSpacing6),
                                            Text(
                                              'Add transaction',
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: kSpacing12),
                                  Expanded(
                                    child: TactileSpringContainer(
                                      onTap: () =>
                                          _showAddAccountDialog(context),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: kSpacing16,
                                        ),
                                        decoration: BoxDecoration(
                                          color: onSurface.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            100,
                                          ),
                                          border: Border.all(
                                            color: onSurface.withValues(
                                              alpha: 0.12,
                                            ),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              PesaFlowIcons.wallet,
                                              color: onSurface,
                                              size: 18,
                                            ),
                                            const SizedBox(width: kSpacing6),
                                            Text(
                                              'Add account',
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                    color: onSurface,
                                                    fontWeight: FontWeight.w900,
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
                            const SizedBox(height: kSpacing20),

                            // ── 3b. Quick Actions ──
                            StaggeredFadeSlide(
                              index: 2,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: kSpacing20,
                                ),
                                child: Row(
                                  children: [
                                    _QuickActionButton(
                                      icon: PesaFlowIcons.expense,
                                      label: 'Expense',
                                      color: context.appColors.expenseColor,
                                      onTap: () => context.push(
                                        '/transactions/add?type=Expense',
                                      ),
                                    ),
                                    const SizedBox(width: kSpacing10),
                                    _QuickActionButton(
                                      icon: PesaFlowIcons.income,
                                      label: 'Income',
                                      color: context.appColors.incomeColor,
                                      onTap: () => context.push(
                                        '/transactions/add?type=Income',
                                      ),
                                    ),
                                    const SizedBox(width: kSpacing10),
                                    _QuickActionButton(
                                      icon: PesaFlowIcons.transfer,
                                      label: 'Transfer',
                                      color: context.appColors.transferColor,
                                      onTap: () => context.push(
                                        '/transactions/add?type=Transfer',
                                      ),
                                    ),
                                    const SizedBox(width: kSpacing10),
                                    _QuickActionButton(
                                      icon: PesaFlowIcons.goal,
                                      label: 'Goal',
                                      color: context.appColors.transferColor,
                                      onTap: () =>
                                          context.push('/savings-goals/add'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: kSpacing20),

                            // ── Quick Templates Row ──
                            Consumer(
                              builder: (context, ref, _) {
                                final templatesAsync = ref.watch(
                                  transactionTemplatesStreamProvider,
                                );
                                return templatesAsync.when(
                                  data: (templates) {
                                    if (templates.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: kSpacing20,
                                          ),
                                          child: Text(
                                            'QUICK TEMPLATES',
                                            style: context.ts(
                                              9,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.2,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.5),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: kSpacing10),
                                        SizedBox(
                                          height: 38,
                                          child: ListView.builder(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: kSpacing20,
                                            ),
                                            scrollDirection: Axis.horizontal,
                                            physics:
                                                const BouncingScrollPhysics(),
                                            itemCount: templates.length,
                                            itemBuilder: (context, index) {
                                              final t = templates[index];
                                              final displayName =
                                                  t['name']?.isNotEmpty == true
                                                  ? t['name']
                                                  : (t['description']
                                                                ?.isNotEmpty ==
                                                            true
                                                        ? t['description']
                                                        : 'Template');
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  right: kSpacing8,
                                                ),
                                                child: TactileSpringContainer(
                                                  onTap: () {
                                                    triggerHaptic(
                                                      HapticType.selection,
                                                    );
                                                    final type =
                                                        t['type'] ?? 'expense';
                                                    final desc =
                                                        t['description'] ?? '';
                                                    final amount =
                                                        t['amountCents'] ?? 0;
                                                    final catId =
                                                        t['categoryId'] ?? '';
                                                    final accId =
                                                        t['accountId'] ?? '';
                                                    context.push(
                                                      '/transactions/add?type=$type&description=${Uri.encodeComponent(desc)}&amount=$amount&categoryId=$catId&accountId=$accId',
                                                    );
                                                  },
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal:
                                                              kSpacing14,
                                                          vertical: kSpacing8,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: onSurface
                                                          .withValues(
                                                            alpha: 0.05,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            100,
                                                          ),
                                                      border: Border.all(
                                                        color: onSurface
                                                            .withValues(
                                                              alpha: 0.08,
                                                            ),
                                                        width: 0.8,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          PesaFlowIcons
                                                              .bookmark,
                                                          size: 13,
                                                          color: theme
                                                              .colorScheme
                                                              .primary,
                                                        ),
                                                        const SizedBox(
                                                          width: kSpacing6,
                                                        ),
                                                        Text(
                                                          displayName,
                                                          style: context.ts(
                                                            12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: onSurface
                                                                .withValues(
                                                                  alpha: 0.85,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: kSpacing20),
                                      ],
                                    );
                                  },
                                  loading: () => const SizedBox.shrink(),
                                  error: (_, _) => const SizedBox.shrink(),
                                );
                              },
                            ),

                            // ── SMS auto-categorization count ──
                            Consumer(
                              builder: (context, ref, _) {
                                final smsCountAsync = ref.watch(
                                  todaySmsCountProvider,
                                );
                                return smsCountAsync.when(
                                  data: (count) {
                                    if (count == 0) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        top: kSpacing12,
                                        left: kSpacing20,
                                        right: kSpacing20,
                                      ),
                                      child: Center(
                                        child: TactileSpringContainer(
                                          onTap: () =>
                                              context.push('/sms-review'),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: kSpacing16,
                                              vertical: kSpacing10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(100),
                                              border: Border.all(
                                                color: theme.colorScheme.primary
                                                    .withValues(alpha: 0.15),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  PesaFlowIcons.message,
                                                  size: 14,
                                                  color:
                                                      theme.colorScheme.primary,
                                                ),
                                                const SizedBox(
                                                  width: kSpacing8,
                                                ),
                                                Text(
                                                  'Auto-categorized $count message${count == 1 ? '' : 's'} today',
                                                  style: theme
                                                      .textTheme
                                                      .labelMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: theme
                                                            .colorScheme
                                                            .primary,
                                                      ),
                                                ),
                                                const SizedBox(
                                                  width: kSpacing6,
                                                ),
                                                Icon(
                                                  PesaFlowIcons.arrowOutward,
                                                  size: 12,
                                                  color:
                                                      theme.colorScheme.primary,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  error: (_, _) => const SizedBox.shrink(),
                                  loading: () => const SizedBox.shrink(),
                                );
                              },
                            ),
                            const SizedBox(height: kSpacing12),

                            // ── 3. Insights — contextual nudges ──
                            CollapsibleSection(
                              title: 'Insights',
                              icon: PesaFlowIcons.lightbulb,
                              child: const _InsightsCarousel(),
                            ),
                            const SizedBox(height: kSpacing20),

                            // ── 4. Monthly Overview — "How your money moved" ──
                            // (StaggeredFadeSlide indices below are scoped per-column, not sequential)
                            StaggeredFadeSlide(
                              index: 2,
                              child: CollapsibleSection(
                                title: 'Monthly Overview',
                                icon: PesaFlowIcons.income,
                                child: _buildMonthlyOverview(theme),
                              ),
                            ),
                            const SizedBox(height: kSpacing20),

                            // ── Spending Activity Heatmap Calendar ──
                            StaggeredFadeSlide(
                              index: 3,
                              child: CollapsibleSection(
                                title: 'Spending Activity',
                                icon: PesaFlowIcons.calendar,
                                child: const SpendingHeatmapCard(),
                              ),
                            ),
                            const SizedBox(height: kSpacing20),

                            // ── 5. Recent Activity — "The transactions behind it" ──
                            CollapsibleSection(
                              title: 'Recent Activity',
                              icon: PesaFlowIcons.history,
                              action: TextButton(
                                onPressed: () {
                                  context.go('/transactions');
                                },
                                child: const Text('See All'),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Clear account filter chip row if _selectedAccountId is active
                                  if (_selectedAccountId != null) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: kSpacing4,
                                        bottom: kSpacing12,
                                      ),
                                      child: Row(
                                        children: [
                                          InputChip(
                                            label: Text(
                                              'Filtered by: ${accounts.firstWhere(
                                                (a) => a.id == _selectedAccountId,
                                                orElse: () => Account(id: '', name: 'Account', type: '', balance: 0, icon: 'wallet', sortOrder: 0, isArchived: false, createdAt: DateTime.now()),
                                              ).name}',
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: theme
                                                        .colorScheme
                                                        .primary,
                                                  ),
                                            ),
                                            backgroundColor: theme
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.08),
                                            side: BorderSide(
                                              color: theme.colorScheme.primary
                                                  .withValues(alpha: 0.2),
                                              width: 0.8,
                                            ),
                                            deleteIcon: Icon(
                                              PesaFlowIcons.cancel,
                                              size: 16,
                                              color: theme.colorScheme.primary,
                                            ),
                                            onDeleted: () {
                                              setState(() {
                                                _selectedAccountId = null;
                                              });
                                            },
                                            onPressed: () {
                                              setState(() {
                                                _selectedAccountId = null;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    const SizedBox(height: kSpacing4),
                                  ],

                                  SkeletonCrossfade(
                                    isLoading:
                                        recentTransAsync is AsyncLoading &&
                                        !recentTransAsync.hasValue,
                                    skeleton: const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: kSpacing16,
                                      ),
                                      child: Column(
                                        children: [
                                          SkeletonCard(height: 80),
                                          SizedBox(height: kSpacing8),
                                          SkeletonCard(height: 80),
                                        ],
                                      ),
                                    ),
                                    child: recentTransAsync.when(
                                      data: (transactions) {
                                        // Client-side dynamic filtering of recent transactions by account
                                        final filteredTransactions =
                                            (_selectedAccountId == null
                                                    ? transactions
                                                    : transactions
                                                          .where(
                                                            (t) =>
                                                                t
                                                                    .transaction
                                                                    .accountId ==
                                                                _selectedAccountId,
                                                          )
                                                          .toList())
                                                .where(
                                                  (t) => !_pendingDeleteIds
                                                      .contains(
                                                        t.transaction.id,
                                                      ),
                                                )
                                                .toList();

                                        if (filteredTransactions.isEmpty) {
                                          final isNewUser =
                                              _selectedAccountId == null;
                                          return Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: kSpacing40,
                                              horizontal: kSpacing24,
                                            ),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.surface,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.radiusCard,
                                                  ),
                                              border: Border.all(
                                                color: onSurface.withValues(
                                                  alpha: 0.08,
                                                ),
                                                width: 0.5,
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  isNewUser
                                                      ? PesaFlowIcons.add
                                                      : PesaFlowIcons
                                                            .transactions,
                                                  size: isNewUser ? 64 : 40,
                                                  color: isNewUser
                                                      ? theme
                                                            .colorScheme
                                                            .primary
                                                      : theme
                                                            .colorScheme
                                                            .onSurfaceVariant
                                                            .withValues(
                                                              alpha: 0.4,
                                                            ),
                                                ),
                                                const SizedBox(
                                                  height: kSpacing12,
                                                ),
                                                Text(
                                                  isNewUser
                                                      ? 'Welcome to PesaFlow!'
                                                      : 'No transactions found.',
                                                  style: theme
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        color: isNewUser
                                                            ? theme
                                                                  .colorScheme
                                                                  .onSurface
                                                            : theme
                                                                  .colorScheme
                                                                  .onSurfaceVariant,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                                const SizedBox(
                                                  height: kSpacing4,
                                                ),
                                                Text(
                                                  isNewUser
                                                      ? 'Add your first transaction to get started with tracking your finances.'
                                                      : 'No activity recorded for this specific account.',
                                                  textAlign: TextAlign.center,
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                                if (isNewUser) ...[
                                                  const SizedBox(
                                                    height: kSpacing20,
                                                  ),
                                                  TactileSpringContainer(
                                                    onTap: () => context.go(
                                                      '/transactions/add',
                                                    ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal:
                                                                kSpacing24,
                                                            vertical:
                                                                kSpacing12,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: theme
                                                            .colorScheme
                                                            .primary,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              100,
                                                            ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: theme
                                                                .colorScheme
                                                                .primary
                                                                .withValues(
                                                                  alpha: 0.3,
                                                                ),
                                                            blurRadius: 8,
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  3,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                            PesaFlowIcons.add,
                                                            color: Colors.white,
                                                            size: 18,
                                                          ),
                                                          const SizedBox(
                                                            width: kSpacing6,
                                                          ),
                                                          Text(
                                                            'Add Transaction',
                                                            style: theme
                                                                .textTheme
                                                                .titleSmall
                                                                ?.copyWith(
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          );
                                        }

                                        return ListView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount:
                                              filteredTransactions.length,
                                          itemBuilder: (context, index) {
                                            final item =
                                                filteredTransactions[index];
                                            final trans = item.transaction;

                                            AmountType amtType =
                                                AmountType.neutral;
                                            if (trans.type.toLowerCase() ==
                                                'income') {
                                              amtType = AmountType.income;
                                            } else if (trans.type
                                                        .toLowerCase() ==
                                                    'expense' ||
                                                trans.type.toLowerCase() ==
                                                    'airtime' ||
                                                trans.type.toLowerCase() ==
                                                    'fee') {
                                              amtType = AmountType.expense;
                                            }

                                            return StaggeredFadeSlide(
                                              index: index,
                                              child: Dismissible(
                                                key: Key(trans.id),
                                                direction:
                                                    DismissDirection.endToStart,
                                                confirmDismiss: (_) async {
                                                  return await showDialog<bool>(
                                                        context: context,
                                                        builder: (ctx) => AlertDialog(
                                                          title: const Text(
                                                            'Delete Transaction',
                                                          ),
                                                          content: Text(
                                                            'Delete "${trans.description.length > 30 ? '${trans.description.substring(0, 30)}…' : trans.description}" (${CurrencyFormatter.formatCents(trans.amount)})?',
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                    ctx,
                                                                  ).pop(false),
                                                              child: const Text(
                                                                'Cancel',
                                                              ),
                                                            ),
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                    ctx,
                                                                  ).pop(true),
                                                              child: const Text(
                                                                'Delete',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ) ??
                                                      false;
                                                },
                                                background: Container(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: kSpacing20,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        theme.colorScheme.error,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          AppTheme.radiusCard,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    PesaFlowIcons.delete,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                onDismissed: (_) async {
                                                  final tx = trans;
                                                  setState(() {
                                                    _pendingDeleteIds.add(
                                                      tx.id,
                                                    );
                                                  });
                                                  UndoDelete.show(
                                                    context: context,
                                                    entityName: 'Transaction',
                                                    onUndo: () async {
                                                      setState(() {
                                                        _pendingDeleteIds
                                                            .remove(tx.id);
                                                      });
                                                      await ref
                                                          .read(
                                                            transactionRepositoryProvider,
                                                          )
                                                          .createTransaction(
                                                            tx,
                                                          );
                                                    },
                                                    onDelete: () async {
                                                      setState(() {
                                                        _pendingDeleteIds
                                                            .remove(tx.id);
                                                      });
                                                      await ref
                                                          .read(
                                                            transactionRepositoryProvider,
                                                          )
                                                          .deleteTransaction(
                                                            tx.id,
                                                          );
                                                    },
                                                  );
                                                },
                                                child: TactileSpringContainer(
                                                  onTap: () => context.push(
                                                    '/transactions/${trans.id}',
                                                  ),
                                                  child: Container(
                                                    margin:
                                                        const EdgeInsets.symmetric(
                                                          vertical: kSpacing6,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.all(
                                                          kSpacing16,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: theme
                                                          .colorScheme
                                                          .surface,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                      border: Border.all(
                                                        color: onSurface
                                                            .withValues(
                                                              alpha: 0.08,
                                                            ),
                                                        width: 0.5,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: onSurface
                                                              .withValues(
                                                                alpha: 0.08,
                                                              ),
                                                          blurRadius: 8,
                                                          offset: const Offset(
                                                            0,
                                                            4,
                                                          ),
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
                                                            color:
                                                                desaturateColor(
                                                                  hexToColor(
                                                                    item
                                                                        .category
                                                                        .color,
                                                                  ),
                                                                ).withValues(
                                                                  alpha: 0.15,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  14,
                                                                ),
                                                          ),
                                                          child: Center(
                                                            child: Icon(
                                                              getCategoryIcon(
                                                                item
                                                                    .category
                                                                    .icon,
                                                              ),
                                                              color: hexToColor(
                                                                item
                                                                    .category
                                                                    .color,
                                                              ),
                                                              size: 22,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: kSpacing14,
                                                        ),
                                                        // Content
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                trans
                                                                        .description
                                                                        .isNotEmpty
                                                                    ? trans
                                                                          .description
                                                                    : item
                                                                          .category
                                                                          .name,
                                                                style: theme
                                                                    .textTheme
                                                                    .titleMedium
                                                                    ?.copyWith(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w800,
                                                                      color:
                                                                          onSurface,
                                                                    ),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                              const SizedBox(
                                                                height:
                                                                    kSpacing4,
                                                              ),
                                                              Row(
                                                                children: [
                                                                  Text(
                                                                    item.account?.name ??
                                                                        'Offline',
                                                                    style: theme.textTheme.labelSmall?.copyWith(
                                                                      color: theme
                                                                          .colorScheme
                                                                          .onSurface
                                                                          .withValues(
                                                                            alpha:
                                                                                0.6,
                                                                          ),
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width:
                                                                        kSpacing8,
                                                                  ),
                                                                  Text(
                                                                    trans
                                                                        .createdAt
                                                                        .toString()
                                                                        .substring(
                                                                          0,
                                                                          10,
                                                                        ),
                                                                    style: theme
                                                                        .textTheme
                                                                        .labelSmall
                                                                        ?.copyWith(
                                                                          color: theme
                                                                              .colorScheme
                                                                              .onSurfaceVariant,
                                                                        ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: kSpacing12,
                                                        ),
                                                        // Amount
                                                        AmountText(
                                                          amountInCents:
                                                              trans.amount,
                                                          type: amtType,
                                                          showDecimals: true,
                                                          style: context.ts(
                                                            16,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color:
                                                                amtType ==
                                                                    AmountType
                                                                        .income
                                                                ? AppTheme
                                                                      .transferColorDark
                                                                : (amtType ==
                                                                          AmountType
                                                                              .expense
                                                                      ? const Color(
                                                                          0xFFFF453A,
                                                                        )
                                                                      : theme
                                                                            .colorScheme
                                                                            .onSurfaceVariant),
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
                                      loading: () => const SizedBox.shrink(),
                                      error: (err, _) => Center(
                                        child: Text(
                                          'Error loading activity: $err',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: kSpacing20),
                      SummaryNavCardRow(
                        budgets: budgets,
                        overallPct: overallPct,
                        savingsGoals: savingsGoalsAsync.value ?? [],
                        activeRecurringCount: recsAsync.maybeWhen(
                          data: (recs) => recs
                              .where(
                                (r) =>
                                    r.type == 'expense' && r.status == 'active',
                              )
                              .length,
                          orElse: () => 0,
                        ),
                        dueCount: dueAsync.maybeWhen(
                          data: (due) =>
                              due.where((d) => d.type == 'expense').length,
                          orElse: () => 0,
                        ),
                        pendingReviewCount: pendingReviewCount,
                        trackerColor: trackerColor,
                      ),
                      const SizedBox(height: kSpacing24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Offscreen Home Widgets Renderer
        Positioned(
          left: -9999,
          top: -9999,
          child: Column(
            children: [
              if (heatmapAsync.value != null)
                RepaintBoundary(
                  key: HomeWidgetsRenderer.heatmapKey,
                  child: WidgetHeatmap(data: heatmapAsync.value!, theme: theme),
                ),
              RepaintBoundary(
                key: HomeWidgetsRenderer.safeToSpendKey,
                child: WidgetSafeToSpend(
                  remainingCents: (remainingBudget * 100).toInt(),
                  limitCents: (budgetTotal * 100).toInt(),
                  percentage: overallPct,
                  theme: theme,
                ),
              ),
              RepaintBoundary(
                key: HomeWidgetsRenderer.quickTemplatesKey,
                child: WidgetQuickTemplates(
                  templates: templatesAsync.value ?? [],
                  theme: theme,
                ),
              ),
              RepaintBoundary(
                key: HomeWidgetsRenderer.recentTransactionsKey,
                child: WidgetRecentTransactions(
                  transactions: recentTransAsync.value ?? [],
                  theme: theme,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCardFront({
    required BuildContext context,
    required WidgetRef ref,
    required ThemeData theme,
    required Color trackerColor,
    required Color heroTextColor,
    required Gradient cardGradient,
    required List<Account> accounts,
    required int netWorth,
    required double overallPct,
    required int budgetTotal,
    required String cardholderName,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _GlossyWavesPainter(accentColor: trackerColor),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(kSpacing20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      cardholderName,
                      style: context.ts(
                        9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        color: heroTextColor.withValues(alpha: 0.7),
                      ),
                    ),
                    _buildCardNetworkLogo(heroTextColor),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedAccountId != null
                          ? (accounts.any((a) => a.id == _selectedAccountId)
                                ? accounts
                                      .firstWhere(
                                        (a) => a.id == _selectedAccountId,
                                      )
                                      .name
                                      .toUpperCase()
                                : 'NET WORTH')
                          : 'NET WORTH',
                      style: context.ts(
                        9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: heroTextColor.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: kSpacing4),
                    Text(
                      CurrencyFormatter.formatCents(netWorth),
                      style: context.ts(
                        28,
                        fontWeight: FontWeight.w900,
                        color: heroTextColor,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${accounts.length} account${accounts.length == 1 ? '' : 's'}',
                      style: context.ts(
                        10,
                        fontWeight: FontWeight.w600,
                        color: heroTextColor.withValues(alpha: 0.55),
                      ),
                    ),
                    Icon(
                      PesaFlowIcons.chevronRight,
                      size: 14,
                      color: heroTextColor.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCardBack({
    required BuildContext context,
    required ThemeData theme,
    required Color trackerColor,
    required Color heroTextColor,
    required Gradient cardGradient,
    required double overallPct,
    required int budgetTotal,
    required int remainingBudget,
  }) {
    final pctLabel = '${(overallPct * 100).round()}%';
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _GlossyWavesPainter(accentColor: trackerColor),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(kSpacing20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'BUDGET BALANCE',
                  style: context.ts(
                    9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: heroTextColor.withValues(alpha: 0.55),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      CurrencyFormatter.formatCents(remainingBudget),
                      style: context.ts(
                        28,
                        fontWeight: FontWeight.w900,
                        color: heroTextColor,
                      ),
                    ),
                    const SizedBox(height: kSpacing6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: overallPct,
                        minHeight: 6,
                        backgroundColor: heroTextColor.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          overallPct < 0.7
                              ? context.appColors.incomeColor
                              : overallPct < 0.9
                              ? Colors.amber
                              : context.appColors.expenseColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'of ${CurrencyFormatter.formatCents(budgetTotal)} budget',
                      style: context.ts(
                        10,
                        fontWeight: FontWeight.w600,
                        color: heroTextColor.withValues(alpha: 0.55),
                      ),
                    ),
                    Text(
                      pctLabel,
                      style: context.ts(
                        10,
                        fontWeight: FontWeight.w800,
                        color: heroTextColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsCarousel extends ConsumerStatefulWidget {
  const _InsightsCarousel();

  @override
  ConsumerState<_InsightsCarousel> createState() => _InsightsCarouselState();
}

class _InsightsCarouselState extends ConsumerState<_InsightsCarousel> {
  final Set<int> _expandedIndices = {};

  @override
  Widget build(BuildContext context) {
    final insightsAsync = ref.watch(dynamicInsightsProvider);

    return insightsAsync.when(
      data: (insights) {
        if (insights.isEmpty) {
          return const SizedBox.shrink();
        }
        // Animated height between 114 (all collapsed) and 176 (any expanded)
        final double height = _expandedIndices.isNotEmpty ? 176.0 : 114.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: kSpacing8),
            clipBehavior: Clip.none,
            itemCount: insights.length,
            separatorBuilder: (_, _) => const SizedBox(width: kSpacing10),
            itemBuilder: (_, i) {
              final isExpanded = _expandedIndices.contains(i);
              return Align(
                alignment: Alignment.topCenter,
                child: MorphingInsightCard(
                  data: insights[i],
                  index: i,
                  expanded: isExpanded,
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedIndices.remove(i);
                      } else {
                        _expandedIndices.add(i);
                      }
                    });
                  },
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, stack) => const SizedBox.shrink(),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SpringButton(
        haptic: HapticType.selection,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: kSpacing12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              SizedBox(height: kSpacing4),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall!.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlossyWavesPainter extends CustomPainter {
  final Color accentColor;

  _GlossyWavesPainter({required this.accentColor});

  Paint? _paint1Cache;
  Paint? _paint2Cache;
  Paint? _paint3Cache;
  Color? _lastAccentColor;
  Rect? _lastRect;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (_paint1Cache == null ||
        _lastAccentColor != accentColor ||
        _lastRect != rect) {
      _lastAccentColor = accentColor;
      _lastRect = rect;

      _paint1Cache = Paint()
        ..shader = LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.28),
            accentColor.withValues(alpha: 0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect);

      _paint2Cache = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect);

      _paint3Cache = Paint()
        ..shader = LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.15),
            accentColor.withValues(alpha: 0.0),
          ],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ).createShader(rect);
    }

    // Wave 1: Accent color glow wave
    final path1 = Path();
    path1.moveTo(0, size.height * 0.7);
    path1.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.45,
      size.width * 0.8,
      size.height * 0.85,
    );
    path1.quadraticBezierTo(
      size.width * 0.9,
      size.height * 0.9,
      size.width,
      size.height * 0.6,
    );
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, _paint1Cache!);

    // Wave 2: Glossy white highlight wave
    final path2 = Path();
    path2.moveTo(0, size.height * 0.85);
    path2.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.4,
      size.width,
      size.height * 0.75,
    );
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, _paint2Cache!);

    // Wave 3: Deep contrast wave
    final path3 = Path();
    path3.moveTo(size.width * 0.25, size.height);
    path3.quadraticBezierTo(
      size.width * 0.65,
      size.height * 0.55,
      size.width,
      size.height * 0.85,
    );
    path3.lineTo(size.width, size.height);
    path3.close();
    canvas.drawPath(path3, _paint3Cache!);
  }

  @override
  bool shouldRepaint(covariant _GlossyWavesPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}
