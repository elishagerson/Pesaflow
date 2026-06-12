import 'dart:math' as math;

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
import 'package:pesaflow/presentation/loans/loan_list_screen.dart';
import 'package:pesaflow/presentation/loans/loan_detail_screen.dart';
import 'package:pesaflow/presentation/loans/loan_form_screen.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Spring-like overshoot curve — starts fast, overshoots slightly, settles back.
/// Creates a lively, physical feel for page entrances.
class _SpringBounceCurve extends Curve {
  const _SpringBounceCurve();

  @override
  double transformInternal(double t) {
    const c1 = 1.80158;
    const c3 = c1 + 1;
    return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2);
  }
}

/// Page transition with spring-physics slide + depth effect.
/// Incoming page slides from 30% right with a spring overshoot.
/// Outgoing page scales down (0.93) and fades (0.7) as it's pushed back.
Page<dynamic> _springSlidePage(Widget child) {
  return CustomTransitionPage(
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slideAnimation = Tween<Offset>(
        begin: const Offset(0.3, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: const _SpringBounceCurve(),
        reverseCurve: Curves.fastOutSlowIn,
      ));

      final outScaleAnimation = Tween<double>(
        begin: 1.0,
        end: 0.93,
      ).animate(CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOutCubic,
      ));

      final outFadeAnimation = Tween<double>(
        begin: 1.0,
        end: 0.7,
      ).animate(CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOutCubic,
      ));

      return FadeTransition(
        opacity: outFadeAnimation,
        child: ScaleTransition(
          scale: outScaleAnimation,
          child: SlideTransition(
            position: slideAnimation,
            child: child,
          ),
        ),
      );
    },
  );
}

/// Subtle cross-fade + scale transition for tab switches.
/// Replaces NoTransitionPage to make tab changes feel connected.
Page<dynamic> _tabTransitionPage(Widget child) {
  return CustomTransitionPage(
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOut),
        ),
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
      pageBuilder: (context, state) => _springSlidePage(const OnboardingScreen()),
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
              routes: [
                GoRoute(
                  path: 'loans',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) => _springSlidePage(const LoanListScreen()),
                  routes: [
                    GoRoute(
                      path: 'add',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) => _springSlidePage(const LoanFormScreen()),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'loans/:id',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) {
                    final loanId = state.pathParameters['id'] ?? '';
                    return _springSlidePage(LoanDetailScreen(loanId: loanId));
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/transactions',
              pageBuilder: (context, state) => _tabTransitionPage(
                const TransactionListScreen(),
              ),
              routes: [
                GoRoute(
                  path: 'add',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) => _springSlidePage(const TransactionFormScreen()),
                ),
                GoRoute(
                  path: 'edit/:id',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) {
                    final transactionId = state.pathParameters['id'];
                    return _springSlidePage(TransactionFormScreen(transactionId: transactionId));
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
              pageBuilder: (context, state) => _tabTransitionPage(
                const BudgetListScreen(),
              ),
              routes: [
                GoRoute(
                  path: 'add',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) => _springSlidePage(const BudgetFormScreen()),
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) {
                    final budgetId = state.pathParameters['id'] ?? '';
                    return _springSlidePage(BudgetDetailScreen(budgetId: budgetId));
                  },
                  routes: [
                    GoRoute(
                      path: 'edit',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) {
                        final budgetId = state.pathParameters['id'];
                        return _springSlidePage(BudgetFormScreen(budgetId: budgetId));
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
              pageBuilder: (context, state) => _tabTransitionPage(
                const AnalyticsScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) => _tabTransitionPage(
                const SettingsScreen(),
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
      pageBuilder: (context, state) => _springSlidePage(const SmsReviewScreen()),
    ),
  ],
);
