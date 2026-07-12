import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/staggered_animation.dart';
import 'package:pesaflow/presentation/common/widgets/press_scale.dart';
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
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/motion/skeleton_crossfade.dart';
import 'package:pesaflow/presentation/common/widgets/interactive_3d_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _selectedAccountId;

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

  Widget _buildEmvChip() {
    return Container(
      width: 36,
      height: 26,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE5A93B),
            Color(0xFFF7D070),
            Color(0xFFC4861A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: CustomPaint(
        painter: _ChipContactPainter(),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final netWorth = ref.watch(netWorthProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final recentTransAsync = ref.watch(recentTransactionsStreamProvider);
    final budgetsAsync = ref.watch(budgetProgressProvider);
    final reviewQueueAsync = ref.watch(reviewQueueStreamProvider);
    final totalsAsync = ref.watch(monthlyTotalsProvider);
    final savingsGoalsAsync = ref.watch(savingsGoalsStreamProvider);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

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

    // Calculate budget overall spent percentage
    final budgets = budgetsAsync.value ?? [];
    double overallPct = 0.0;
    if (budgets.isNotEmpty) {
      double totalSpent = 0;
      double totalAllocated = 0;
      for (final bp in budgets) {
        totalSpent += bp.spentInPeriod;
        totalAllocated += bp.currentPeriod?.allocated ?? bp.budget.amount;
      }
      if (totalAllocated > 0) {
        overallPct = (totalSpent / totalAllocated).clamp(0.0, 1.0);
      }
    } else {
      // Dynamic fallback if no budgets are set: compute spent vs income from actual transactions!
      final totals = totalsAsync.value;
      if (totals != null) {
        final income = totals['income'] ?? 0;
        final expense = totals['expense'] ?? 0;
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
        theme.brightness == Brightness.dark
            ? const Color(0xFF1E2429)
            : const Color(0xFF1A1F24),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    const Color heroTextColor = Colors.white;

    final recsAsync = ref.watch(recurringTransactionsStreamProvider);
    final dueAsync = ref.watch(dueRecurringTransactionsProvider);

    return Scaffold(
      appBar: IosNavBar(
        title: _getGreeting(),
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
                  Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: onSurface.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TactileSpringContainer(
            onTap: () => ref.read(paletteVisibilityProvider.notifier).toggle(),
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
              child: Icon(Icons.search_rounded, color: onSurface, size: 20),
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
                Icons.person_outline_rounded,
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
                    Icons.notifications_none_rounded,
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
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              final double velocity = notification.scrollDelta?.abs() ?? 0.0;
              final double targetSpeed =
                  1.0 + (velocity / 12.0).clamp(0.0, 4.0);
              ref.read(scrollSpeedProvider.notifier).state = targetSpeed;
            } else if (notification is ScrollEndNotification) {
              ref.read(scrollSpeedProvider.notifier).state = 1.0;
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
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(
                top: kSpacing4,
                bottom: kSpacing16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: kSpacing16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── 2. Balance Hero Card — "Your Money" ──
                        StaggeredFadeSlide(
                          index: 0,
                          child: Interactive3DCard(
                            borderRadius: AppTheme.radiusCard,
                            shadowColor: trackerColor,
                            maxTiltX: 0.08,
                            maxTiltY: 0.08,
                            glareOpacity: 0.12,
                            child: AspectRatio(
                              aspectRatio: 1.58,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(kSpacing20),
                                decoration: BoxDecoration(
                                  gradient: cardGradient,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusCard,
                                  ),
                                  border: Border.all(
                                    color: trackerColor.withValues(alpha: 0.18),
                                    width: 0.8,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Top Row: PesaFlow Brand + DEBIT
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'pesa',
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 18,
                                                color: Colors.white.withValues(alpha: 0.95),
                                                letterSpacing: -0.5,
                                              ),
                                            ),
                                            Text(
                                              'flow',
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w300,
                                                fontSize: 18,
                                                color: heroTextColor,
                                                letterSpacing: -0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            // Dynamic Spent Progress Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: kSpacing8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(100),
                                              ),
                                              child: Row(
                                                children: [
                                                  SizedBox(
                                                    height: 10,
                                                    width: 10,
                                                    child: CircularProgressIndicator(
                                                      value: overallPct,
                                                      strokeWidth: 1.8,
                                                      backgroundColor: Colors.white24,
                                                      valueColor: AlwaysStoppedAnimation<Color>(
                                                        overallPct > 0.9
                                                            ? context.appColors.expenseColor
                                                            : Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: kSpacing4),
                                                  Text(
                                                    '${(overallPct * 100).round()}%',
                                                    style: theme.textTheme.labelSmall?.copyWith(
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.bold,
                                                      color: heroTextColor,
                                                      letterSpacing: 0.2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: kSpacing8),
                                            Text(
                                              'PREMIUM',
                                              style: context.ts(
                                                9,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 1.5,
                                                color: Colors.white.withValues(alpha: 0.65),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),

                                    // Middle Row: EMV Chip & Contactless
                                    Row(
                                      children: [
                                        _buildEmvChip(),
                                        const SizedBox(width: kSpacing12),
                                        Icon(
                                          Icons.wifi_rounded,
                                          color: Colors.white.withValues(alpha: 0.5),
                                          size: 20,
                                        ),
                                      ],
                                    ),

                                    // Balance Section
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedAccountId != null
                                              ? 'ACCOUNT BALANCE'
                                              : 'TOTAL NET WORTH',
                                          style: context.ts(
                                            9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.2,
                                            color: Colors.white.withValues(alpha: 0.5),
                                          ),
                                        ),
                                        const SizedBox(height: kSpacing4),
                                        AmountText(
                                          amountInCents: _selectedAccountId != null
                                              ? (accounts.firstWhere((a) => a.id == _selectedAccountId, orElse: () => accounts.first).balance)
                                              : netWorth,
                                          useMonospace: false,
                                          animate: true,
                                          style: theme.textTheme.headlineMedium?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 30,
                                            color: heroTextColor,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Bottom Row: Cardholder Name, Expiry, Logo
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'CARDHOLDER',
                                              style: context.ts(
                                                7,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white.withValues(alpha: 0.4),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _selectedAccountId != null
                                                  ? (accounts.firstWhere((a) => a.id == _selectedAccountId, orElse: () => accounts.first).name.toUpperCase())
                                                  : 'TOTAL NET WORTH',
                                              style: context.ts(
                                                11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white.withValues(alpha: 0.85),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Expiry
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'VALID THRU',
                                              style: context.ts(
                                                7,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white.withValues(alpha: 0.4),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '12/30',
                                              style: context.ts(
                                                11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white.withValues(alpha: 0.85),
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Card network logo
                                        _buildCardNetworkLogo(trackerColor),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
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
                                final isSelected = _selectedAccountId == account.id;

                                return Padding(
                                  padding: EdgeInsets.only(
                                    right: kSpacing8,
                                    left: index == 0 ? kSpacing2 : 0.0,
                                  ),
                                  child: TactileSpringContainer(
                                    onTap: () {
                                      setState(() {
                                        if (_selectedAccountId == account.id) {
                                          _selectedAccountId = null; // Clear filter
                                        } else {
                                          _selectedAccountId = account.id; // Apply filter
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
                                            ? theme.colorScheme.primary.withValues(
                                                alpha: 0.25,
                                              )
                                            : theme.colorScheme.surfaceContainerHigh,
                                        borderRadius: BorderRadius.circular(100),
                                        border: Border.all(
                                          color: isSelected
                                              ? theme.colorScheme.primary.withValues(
                                                  alpha: 0.6,
                                                )
                                              : theme.colorScheme.onSurface.withValues(
                                                  alpha: 0.1,
                                                ),
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
                                                : theme.colorScheme.onSurface,
                                          ),
                                          const SizedBox(width: kSpacing6),
                                          Text(
                                            account.name,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? theme.colorScheme.primary
                                                  : theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(width: kSpacing8),
                                          Text(
                                            _formatCompact(account.balance),
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? theme.colorScheme.primary.withValues(alpha: 0.9)
                                                  : theme.colorScheme.onSurface.withValues(alpha: 0.8),
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
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                                child: PressScale(
                                  onTap: () => context.go('/transactions/add'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: kSpacing16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(
                                        color: Colors.black,
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
                                  onTap: () => _showAddAccountDialog(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: kSpacing16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: onSurface.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(100),
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
                                  onTap: () => context.go(
                                    '/transactions/add?type=Expense',
                                  ),
                                ),
                                const SizedBox(width: kSpacing10),
                                _QuickActionButton(
                                  icon: PesaFlowIcons.income,
                                  label: 'Income',
                                  color: context.appColors.incomeColor,
                                  onTap: () => context.go(
                                    '/transactions/add?type=Income',
                                  ),
                                ),
                                const SizedBox(width: kSpacing10),
                                _QuickActionButton(
                                  icon: PesaFlowIcons.transfer,
                                  label: 'Transfer',
                                  color: context.appColors.transferColor,
                                  onTap: () => context.go(
                                    '/transactions/add?type=Transfer',
                                  ),
                                ),
                                const SizedBox(width: kSpacing10),
                                _QuickActionButton(
                                  icon: PesaFlowIcons.goal,
                                  label: 'Goal',
                                  color: context.appColors.transferColor,
                                  onTap: () => context.go('/savings-goals/add'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: kSpacing20),

                        // ── SMS auto-categorization count ──
                        Consumer(
                          builder: (context, ref, _) {
                            final smsCountAsync = ref.watch(
                              todaySmsCountProvider,
                            );
                            return smsCountAsync.when(
                              data: (count) {
                                if (count == 0) return const SizedBox.shrink();
                                return Padding(
                                  padding: EdgeInsets.only(
                                    top: kSpacing12,
                                    left: kSpacing20,
                                    right: kSpacing20,
                                  ),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: kSpacing16,
                                      vertical: kSpacing12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.15),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.message_rounded,
                                          size: 18,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                        SizedBox(width: kSpacing10),
                                        Expanded(
                                          child: Text(
                                            'Auto-categorized $count message${count == 1 ? '' : 's'} today  ↗',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall!
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                ),
                                          ),
                                        ),
                                      ],
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
                        _CollapsibleSection(
                          title: 'Insights',
                          icon: Icons.lightbulb_outline_rounded,
                          child: _InsightsCarousel(),
                        ),
                        const SizedBox(height: kSpacing20),

                        // ── 4. Monthly Overview — "How your money moved" ──
                        // (StaggeredFadeSlide indices below are scoped per-column, not sequential)
                        StaggeredFadeSlide(
                          index: 2,
                          child: _CollapsibleSection(
                            title: 'Monthly Overview',
                            icon: PesaFlowIcons.income,
                            child: _buildMonthlyOverview(theme),
                          ),
                        ),
                        const SizedBox(height: kSpacing20),

                        // ── 5. Recent Activity — "The transactions behind it" ──
                        _CollapsibleSection(
                          title: 'Recent Activity',
                          icon: Icons.history_rounded,
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
                                                color:
                                                    theme.colorScheme.primary,
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
                                          Icons.cancel_rounded,
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
                                        _selectedAccountId == null
                                        ? transactions
                                        : transactions
                                              .where(
                                                (t) =>
                                                    t.transaction.accountId ==
                                                    _selectedAccountId,
                                              )
                                              .toList();

                                    if (filteredTransactions.isEmpty) {
                                      return Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: kSpacing40,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surface,
                                          borderRadius: BorderRadius.circular(
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
                                              PesaFlowIcons.transactions,
                                              size: 40,
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant
                                                  .withValues(alpha: 0.4),
                                            ),
                                            const SizedBox(height: kSpacing12),
                                            Text(
                                              'No transactions found.',
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const SizedBox(height: kSpacing4),
                                            Text(
                                              _selectedAccountId == null
                                                  ? 'Your offline financial logs will display here.'
                                                  : 'No activity recorded for this specific account.',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }

                                    return ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: filteredTransactions.length,
                                      itemBuilder: (context, index) {
                                        final item =
                                            filteredTransactions[index];
                                        final trans = item.transaction;

                                        AmountType amtType = AmountType.neutral;
                                        if (trans.type.toLowerCase() ==
                                            'income') {
                                          amtType = AmountType.income;
                                        } else if (trans.type.toLowerCase() ==
                                                'expense' ||
                                            trans.type.toLowerCase() ==
                                                'airtime' ||
                                            trans.type.toLowerCase() == 'fee') {
                                          amtType = AmountType.expense;
                                        }

                                        return StaggeredFadeSlide(
                                          index: index,
                                          child: Dismissible(
                                            key: Key(trans.id),
                                            direction:
                                                DismissDirection.endToStart,
                                            background: Container(
                                              alignment: Alignment.centerRight,
                                              padding: const EdgeInsets.only(
                                                right: kSpacing20,
                                              ),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.error,
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
                                              await ref
                                                  .read(
                                                    transactionRepositoryProvider,
                                                  )
                                                  .deleteTransaction(trans.id);
                                              ref.invalidate(
                                                recentTransactionsStreamProvider,
                                              );
                                              ref.invalidate(
                                                accountsStreamProvider,
                                              );
                                              ref.invalidate(netWorthProvider);
                                              ref.invalidate(
                                                monthlyTotalsProvider,
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
                                                padding: const EdgeInsets.all(
                                                  kSpacing16,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      theme.colorScheme.surface,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color: onSurface.withValues(
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
                                                            item.category.icon,
                                                          ),
                                                          color: hexToColor(
                                                            item.category.color,
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
                                                            height: kSpacing4,
                                                          ),
                                                          Row(
                                                            children: [
                                                              Text(
                                                                item
                                                                        .account
                                                                        ?.name ??
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
                                                                trans.createdAt
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
                                    child: Text('Error loading activity: $err'),
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
                  _SummaryNavCardRow(
                    budgets: budgets,
                    overallPct: overallPct,
                    savingsGoals: savingsGoalsAsync.value ?? [],
                    activeRecurringCount: recsAsync.maybeWhen(
                      data: (recs) => recs
                          .where(
                            (r) => r.type == 'expense' && r.status == 'active',
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
    );
  }
}

class _SummaryNavCardRow extends StatelessWidget {
  final List<dynamic> budgets;
  final double overallPct;
  final List<dynamic> savingsGoals;
  final int activeRecurringCount;
  final int dueCount;
  final int pendingReviewCount;
  final Color trackerColor;

  const _SummaryNavCardRow({
    required this.budgets,
    required this.overallPct,
    required this.savingsGoals,
    required this.activeRecurringCount,
    required this.dueCount,
    required this.pendingReviewCount,
    required this.trackerColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.none,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kSpacing16),
        child: Row(
          children: [
            _SummaryNavCard(
              icon: Icons.pie_chart_rounded,
              metric: budgets.isNotEmpty
                  ? '${budgets.length} budgets'
                  : 'No budgets',
              label: '${(overallPct * 100).toStringAsFixed(0)}% spent',
              color: trackerColor,
              onTap: () => context.go('/budgets'),
            ),
            if (savingsGoals.isNotEmpty)
              _SummaryNavCard(
                icon: PesaFlowIcons.target,
                metric:
                    '${savingsGoals.length} goal${savingsGoals.length == 1 ? '' : 's'}',
                label: 'Emergency vault',
                color: context.appColors.incomeColor,
                onTap: () => context.go('/savings-goals'),
              ),
            _SummaryNavCard(
              icon: PesaFlowIcons.calendar,
              metric: dueCount > 0
                  ? '$dueCount due'
                  : '$activeRecurringCount active',
              label: 'Recurring',
              color: context.appColors.transferColor,
              onTap: () => context.go('/recurring'),
            ),
            _SummaryNavCard(
              icon: Icons.credit_score_rounded,
              metric: 'Loans',
              label: 'Debt overview',
              color: context.appColors.transferColor,
              onTap: () => context.go('/loans'),
            ),
            if (pendingReviewCount > 0)
              _SummaryNavCard(
                icon: Icons.message_rounded,
                metric: '$pendingReviewCount pending',
                label: 'SMS review',
                color: theme.colorScheme.primary,
                onTap: () => context.go('/sms-review'),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryNavCard extends StatelessWidget {
  final IconData icon;
  final String metric;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SummaryNavCard({
    required this.icon,
    required this.metric,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: kSpacing12),
      child: TactileSpringContainer(
        onTap: onTap,
        child: Container(
          width: 130,
          height: 96,
          padding: const EdgeInsets.all(kSpacing12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.10),
                theme.colorScheme.surfaceContainerHigh,
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(
              color: color.withValues(alpha: 0.18),
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                padding: const EdgeInsets.all(kSpacing6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    metric,
                    style: context.ts(
                      12,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: kSpacing2),
                  Text(
                    label,
                    style: context.ts(
                      10,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollapsibleSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Widget? action;
  final Widget child;

  const _CollapsibleSection({
    required this.title,
    required this.icon,
    this.action,
    required this.child,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: kSpacing8,
                    right: kSpacing8,
                    top: kSpacing6,
                    bottom: kSpacing6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            widget.icon,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: kSpacing8),
                          Text(
                            widget.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: kSpacing6),
                          AnimatedRotation(
                            turns: _isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
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
            if (widget.action != null) ...[
              const SizedBox(width: kSpacing8),
              widget.action!,
            ],
          ],
        ),
        const SizedBox(height: kSpacing8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kSpacing8),
          child: AnimatedCrossFade(
            firstChild: widget.child,
            secondChild: const SizedBox.shrink(),
            crossFadeState: _isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
          ),
        ),
      ],
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

class _ChipContactPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    // Draw chip contact grid lines
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    
    // Vertical center line
    canvas.drawLine(Offset(size.width * 0.5, 0), Offset(size.width * 0.5, size.height), paint);
    
    // Horizontal center line
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), paint);
    
    // Left vertical contact line
    canvas.drawLine(Offset(size.width * 0.25, size.height * 0.25), Offset(size.width * 0.25, size.height * 0.75), paint);
    
    // Right vertical contact line
    canvas.drawLine(Offset(size.width * 0.75, size.height * 0.25), Offset(size.width * 0.75, size.height * 0.75), paint);

    // Inner center details
    final centerRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.5),
      width: size.width * 0.25,
      height: size.height * 0.3,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(centerRect, const Radius.circular(2)), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
