import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/presentation/analytics/analytics_screen.dart';
import 'package:pesaflow/presentation/budgets/budget_list_screen.dart';
import 'package:pesaflow/presentation/budgets/budget_form_screen.dart';
import 'package:pesaflow/presentation/budgets/budget_detail_screen.dart';
import 'package:pesaflow/presentation/dashboard/dashboard_screen.dart';
import 'package:pesaflow/presentation/onboarding/onboarding_screen.dart';
import 'package:pesaflow/presentation/settings/settings_screen.dart';
import 'package:pesaflow/presentation/sms_review/sms_review_screen.dart';
import 'package:pesaflow/presentation/transactions/transaction_form_screen.dart';
import 'package:pesaflow/presentation/transactions/transaction_list_screen.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

Page<dynamic> _slidePage(Widget child) {
  return CustomTransitionPage(
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        )),
        child: child,
      );
    },
  );
}

class ScaffoldWithNavBar extends StatefulWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
        } else {
          _lastBackPress = now;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Press back again to exit'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      },
      child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: IosTabBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: (int index) {
            widget.navigationShell.goBranch(
              index,
              initialLocation: index == widget.navigationShell.currentIndex,
            );
          },
        ),
      ),
    );
  }
}

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  debugLogDiagnostics: true,
  routes: <RouteBase>[
    // Onboarding (full-screen, above bottom nav)
    GoRoute(
      path: '/onboarding',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _slidePage(const OnboardingScreen()),
    ),

    // Main persistent shell routes
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
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/transactions',
              pageBuilder: (context, state) => NoTransitionPage(
                child: const TransactionListScreen(),
              ),
              routes: [
                GoRoute(
                  path: 'add',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) => _slidePage(const TransactionFormScreen()),
                ),
                GoRoute(
                  path: 'edit/:id',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) {
                    final transactionId = state.pathParameters['id'];
                    return _slidePage(TransactionFormScreen(transactionId: transactionId));
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
              pageBuilder: (context, state) => NoTransitionPage(
                child: const BudgetListScreen(),
              ),
              routes: [
                GoRoute(
                  path: 'add',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) => _slidePage(const BudgetFormScreen()),
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) {
                    final budgetId = state.pathParameters['id'] ?? '';
                    return _slidePage(BudgetDetailScreen(budgetId: budgetId));
                  },
                  routes: [
                    GoRoute(
                      path: 'edit',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) {
                        final budgetId = state.pathParameters['id'];
                        return _slidePage(BudgetFormScreen(budgetId: budgetId));
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
              pageBuilder: (context, state) => NoTransitionPage(
                child: const AnalyticsScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) => NoTransitionPage(
                child: const SettingsScreen(),
              ),
            ),
          ],
        ),
      ],
    ),

    // SMS Review Queue (full-screen, above bottom nav)
    GoRoute(
      path: '/sms-review',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _slidePage(const SmsReviewScreen()),
    ),
  ],
);
