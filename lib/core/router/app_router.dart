import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_colors_theme.dart';
import 'package:pesaflow/presentation/analytics/analytics_screen.dart';
import 'package:pesaflow/presentation/budgets/budget_list_screen.dart';
import 'package:pesaflow/presentation/debug/sms_parser_debug_screen.dart';
import 'package:pesaflow/presentation/budgets/budget_form_screen.dart';
import 'package:pesaflow/presentation/budgets/budget_detail_screen.dart';
import 'package:pesaflow/presentation/dashboard/dashboard_screen.dart';
import 'package:pesaflow/presentation/onboarding/onboarding_screen.dart';
import 'package:pesaflow/presentation/settings/settings_screen.dart';
import 'package:pesaflow/presentation/sms_review/sms_review_screen.dart';
import 'package:pesaflow/presentation/transactions/transaction_form_screen.dart';
import 'package:pesaflow/presentation/transactions/transaction_list_screen.dart';
import 'package:pesaflow/presentation/transactions/transaction_detail_screen.dart';
import 'package:pesaflow/presentation/loans/loan_list_screen.dart';
import 'package:pesaflow/presentation/loans/loan_detail_screen.dart';
import 'package:pesaflow/presentation/loans/loan_form_screen.dart';
import 'package:pesaflow/presentation/recurring/recurring_transaction_form_screen.dart';
import 'package:pesaflow/presentation/recurring/recurring_transaction_list_screen.dart';
import 'package:pesaflow/presentation/savings_goals/savings_goal_list_screen.dart';
import 'package:pesaflow/presentation/savings_goals/savings_goal_form_screen.dart';
import 'package:pesaflow/presentation/savings_goals/savings_goal_detail_screen.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'route_params.dart';

import 'package:pesaflow/core/utils/spacing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

Page<dynamic> _springSlidePage(Widget page) {
  return CustomTransitionPage(
    key: ValueKey(page.runtimeType),
    child: page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 0.05);
      const end = Offset.zero;
      final tween = Tween(
        begin: begin,
        end: end,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      final fadeTween = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(
        position: animation.drive(tween),
        child: FadeTransition(
          opacity: animation.drive(fadeTween),
          child: child,
        ),
      );
    },
    reverseTransitionDuration: const Duration(milliseconds: 200),
  );
}

Page<dynamic> _heroSlidePage(Widget page) {
  return CustomTransitionPage(
    key: ValueKey(page.runtimeType),
    child: page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 0.03);
      const end = Offset.zero;
      final tween = Tween(
        begin: begin,
        end: end,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(
        position: animation.drive(tween),
        child: FadeTransition(
          opacity: Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      );
    },
    reverseTransitionDuration: const Duration(milliseconds: 200),
  );
}

Page<dynamic> _tabTransitionPage(Widget child) {
  return CustomTransitionPage(
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

class ScaffoldWithNavBar extends ConsumerStatefulWidget {
  const ScaffoldWithNavBar({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends ConsumerState<ScaffoldWithNavBar> {
  DateTime? _lastBackPress;

  /// Re-tapping the currently-active tab scrolls the visible screen to top.
  void _onDestinationSelected(int index) {
    if (index == widget.navigationShell.currentIndex) {
      ref.read(scrollToTopProvider.notifier).trigger();
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isPhone = width < 600;
    final isTablet = width >= 600 && width < 1200;
    final isDesktop = width >= 1200;

    final canPopRouter = GoRouter.of(context).canPop();

    return PopScope(
      canPop: canPopRouter,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
        } else {
          _lastBackPress = now;
          CustomToast.show(
            context,
            message: 'Press back again to exit',
            duration: const Duration(seconds: 2),
            type: ToastType.info,
          );
        }
      },
      child: Scaffold(
        extendBody: isPhone,
        body: Row(
          children: [
            if (isDesktop)
              _buildSidebar(context)
            else if (isTablet)
              _buildNavigationRail(context),
            Expanded(child: widget.navigationShell),
          ],
        ),
        bottomNavigationBar: isPhone
            ? IosTabBar(
                selectedIndex: widget.navigationShell.currentIndex,
                onDestinationSelected: _onDestinationSelected,
              )
            : null,
      ),
    );
  }

  Widget _buildNavigationRail(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColorsTheme>()!;
    final currentIndex = widget.navigationShell.currentIndex;

    final navItems = [
      (Icons.home_rounded, 'Home', 0),
      (Icons.swap_horiz_rounded, 'Transactions', 1),
      (Icons.donut_large_rounded, 'Budgets', 2),
      (Icons.analytics_rounded, 'Analytics', 3),
      (Icons.settings_rounded, 'Settings', 4),
    ];

    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: _onDestinationSelected,
      labelType: NavigationRailLabelType.all,
      backgroundColor: appColors.surfaceContainer,
      indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.15),
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: kSpacing12),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(height: kSpacing4),
            Text(
              'PesaFlow',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
      destinations: navItems.map((item) {
        return NavigationRailDestination(
          icon: Icon(item.$1, size: 20),
          selectedIcon: Icon(item.$1, size: 20),
          label: Text(item.$2),
        );
      }).toList(),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColorsTheme>()!;
    final navItems = [
      (Icons.home_rounded, 'Dashboard', 0),
      (Icons.swap_horiz_rounded, 'Transactions', 1),
      (Icons.donut_large_rounded, 'Budgets', 2),
      (Icons.analytics_rounded, 'Analytics', 3),
      (Icons.settings_rounded, 'Settings', 4),
    ];

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: appColors.surfaceContainer,
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: kSpacing48),
          // App logo / brand
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: kSpacing20,
              vertical: kSpacing16,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: kSpacing12),
                Text(
                  'PesaFlow',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: kSpacing16),
          // Navigation items
          ...navItems.map((item) {
            final isSelected = widget.navigationShell.currentIndex == item.$3;
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kSpacing10,
                vertical: kSpacing2,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _onDestinationSelected(item.$3),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.$1,
                          size: 20,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                        ),
                        const SizedBox(width: kSpacing12),
                        Text(
                          item.$2,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          // Version
          Padding(
            padding: const EdgeInsets.all(kSpacing16),
            child: Text(
              'PesaFlow v1.0.0',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouterErrorPage extends StatelessWidget {
  const _RouterErrorPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(kSpacing24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.travel_explore_rounded,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: kSpacing20),
                Text(
                  'Page not found',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: kSpacing8),
                Text(
                  'The screen you are looking for does not exist.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: kSpacing24),
                FilledButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Go Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  debugLogDiagnostics: kDebugMode,
  errorBuilder: (context, state) => const _RouterErrorPage(),
  redirect: (context, state) async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    if (!onboardingComplete && state.matchedLocation != '/onboarding') {
      return '/onboarding';
    }
    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/onboarding',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) =>
          _springSlidePage(const OnboardingScreen()),
    ),

    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const DashboardScreen(),
              routes: [
                GoRoute(
                  path: 'loans',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) =>
                      _heroSlidePage(const LoanListScreen()),
                  routes: [
                    GoRoute(
                      path: 'add',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) =>
                          _springSlidePage(const LoanFormScreen()),
                    ),
                    GoRoute(
                      path: ':id',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) {
                        final id = state.pathParameters['id'];
                        if (id == null) return _heroSlidePage(const SizedBox.shrink());
                        return _heroSlidePage(
                          LoanDetailScreen(loanId: id),
                        );
                      },
                      routes: [
                        GoRoute(
                          path: 'edit',
                          parentNavigatorKey: _rootNavigatorKey,
                          pageBuilder: (context, state) {
                            return _springSlidePage(
                              LoanFormScreen(
                                loanId: state.pathParameters['id'],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                GoRoute(
                  path: 'savings-goals',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) =>
                      _heroSlidePage(const SavingsGoalListScreen()),
                  routes: [
                    GoRoute(
                      path: 'add',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) =>
                          _springSlidePage(const SavingsGoalFormScreen()),
                    ),
                    GoRoute(
                      path: ':id',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) {
                        final id = state.pathParameters['id'];
                        if (id == null) return _heroSlidePage(const SizedBox.shrink());
                        return _heroSlidePage(
                          SavingsGoalDetailScreen(
                            goalId: id,
                          ),
                        );
                      },
                      routes: [
                        GoRoute(
                          path: 'edit',
                          parentNavigatorKey: _rootNavigatorKey,
                          pageBuilder: (context, state) {
                            return _springSlidePage(
                              SavingsGoalFormScreen(
                                goalId: state.pathParameters['id'],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                GoRoute(
                  path: 'recurring',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) =>
                      _springSlidePage(const RecurringTransactionListScreen()),
                  routes: [
                    GoRoute(
                      path: 'add',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) => _springSlidePage(
                        const RecurringTransactionFormScreen(),
                      ),
                    ),
                    GoRoute(
                      path: ':id/edit',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) {
                        return _springSlidePage(
                          RecurringTransactionFormScreen(
                            recurringId: state.param('id'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/transactions',
              pageBuilder: (context, state) =>
                  _tabTransitionPage(const TransactionListScreen()),
              routes: [
                GoRoute(
                  path: 'add',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) {
                    final params = state.uri.queryParameters;
                    final type = params['type'];
                    final amountStr = params['amount'];
                    return _springSlidePage(
                      TransactionFormScreen(
                        initialType: type,
                        prefillDescription: params['description'],
                        prefillAmountCents: amountStr != null
                            ? int.tryParse(amountStr)
                            : null,
                        prefillCategoryId: params['categoryId'],
                        prefillAccountId: params['accountId'],
                        prefillReference: params['reference'],
                      ),
                    );
                  },
                ),
                GoRoute(
                  path: 'edit/:id',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) {
                    return _springSlidePage(
                      TransactionFormScreen(
                        transactionId: state.optParam('id'),
                      ),
                    );
                  },
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) {
                    return _springSlidePage(
                      TransactionDetailScreen(transactionId: state.param('id')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/budgets',
              pageBuilder: (context, state) =>
                  _tabTransitionPage(const BudgetListScreen()),
              routes: [
                GoRoute(
                  path: 'add',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) =>
                      _springSlidePage(const BudgetFormScreen()),
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) {
                    return _heroSlidePage(
                      BudgetDetailScreen(budgetId: state.param('id')),
                    );
                  },
                  routes: [
                    GoRoute(
                      path: 'edit',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) {
                        return _springSlidePage(
                          BudgetFormScreen(budgetId: state.optParam('id')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/analytics',
              pageBuilder: (context, state) =>
                  _tabTransitionPage(const AnalyticsScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) =>
                  _tabTransitionPage(const SettingsScreen()),
            ),
          ],
        ),
      ],
    ),

    GoRoute(
      path: '/sms-review',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) =>
          _springSlidePage(const SmsReviewScreen()),
    ),

    GoRoute(
      path: '/debug/sms-parser',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) =>
          _springSlidePage(const SmsParserDebugScreen()),
    ),
  ],
);
