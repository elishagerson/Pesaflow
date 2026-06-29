import 'package:flutter/foundation.dart';
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
import 'package:pesaflow/presentation/transactions/transaction_detail_screen.dart';
import 'package:pesaflow/presentation/loans/loan_list_screen.dart';
import 'package:pesaflow/presentation/loans/loan_detail_screen.dart';
import 'package:pesaflow/presentation/loans/loan_form_screen.dart';
import 'package:pesaflow/presentation/recurring/recurring_transaction_form_screen.dart';
import 'package:pesaflow/presentation/recurring/recurring_transaction_list_screen.dart';
import 'package:pesaflow/presentation/subscriptions/subscription_form_screen.dart';
import 'package:pesaflow/presentation/subscriptions/subscription_list_screen.dart';
import 'package:pesaflow/presentation/subscriptions/subscription_detail_screen.dart';
import 'package:pesaflow/presentation/savings_goals/savings_goal_list_screen.dart';
import 'package:pesaflow/presentation/savings_goals/savings_goal_form_screen.dart';
import 'package:pesaflow/presentation/savings_goals/savings_goal_detail_screen.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'route_params.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

Page<dynamic> _springSlidePage(Widget page) {
  return CustomTransitionPage(
    key: ValueKey(page.runtimeType),
    child: page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 0.05);
      const end = Offset.zero;
      const curve = Curves.easeOutCubic;
      final tween =
          Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      final fadeTween =
          Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));
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
  debugLogDiagnostics: kDebugMode,
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
                    GoRoute(
                      path: ':id',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) {
                        return _springSlidePage(LoanDetailScreen(loanId: state.pathParameters['id']!));
                      },
                      routes: [
                        GoRoute(
                          path: 'edit',
                          parentNavigatorKey: _rootNavigatorKey,
                          pageBuilder: (context, state) {
                            return _springSlidePage(LoanFormScreen(loanId: state.pathParameters['id']));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                GoRoute(
                  path: 'savings-goals',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) => _springSlidePage(const SavingsGoalListScreen()),
                  routes: [
                    GoRoute(
                      path: 'add',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) => _springSlidePage(const SavingsGoalFormScreen()),
                    ),
                    GoRoute(
                      path: ':id',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) {
                        return _springSlidePage(SavingsGoalDetailScreen(goalId: state.pathParameters['id']!));
                      },
                      routes: [
                        GoRoute(
                          path: 'edit',
                          parentNavigatorKey: _rootNavigatorKey,
                          pageBuilder: (context, state) {
                            return _springSlidePage(SavingsGoalFormScreen(goalId: state.pathParameters['id']));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                GoRoute(
                  path: 'recurring',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) => _springSlidePage(const RecurringTransactionListScreen()),
                  routes: [
                    GoRoute(
                      path: 'add',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) => _springSlidePage(const RecurringTransactionFormScreen()),
                    ),
                    GoRoute(
                      path: ':id/edit',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) {
                        return _springSlidePage(RecurringTransactionFormScreen(recurringId: state.param('id')));
                      },
                    ),
                  ],
                ),
                GoRoute(
                  path: 'subscriptions',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) => _springSlidePage(const SubscriptionListScreen()),
                  routes: [
                    GoRoute(
                      path: 'add',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) => _springSlidePage(const SubscriptionFormScreen()),
                    ),
                    GoRoute(
                      path: ':id',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) {
                        return _springSlidePage(SubscriptionDetailScreen(subscriptionId: state.param('id')));
                      },
                      routes: [
                        GoRoute(
                          path: 'edit',
                          parentNavigatorKey: _rootNavigatorKey,
                          pageBuilder: (context, state) {
                            return _springSlidePage(SubscriptionFormScreen(subscriptionId: state.param('id')));
                          },
                        ),
                      ],
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
                    return _springSlidePage(TransactionFormScreen(transactionId: state.optParam('id')));
                  },
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) {
                    return _springSlidePage(TransactionDetailScreen(transactionId: state.param('id')));
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
                    return _springSlidePage(BudgetDetailScreen(budgetId: state.param('id')));
                  },
                  routes: [
                    GoRoute(
                      path: 'edit',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) {
                        return _springSlidePage(BudgetFormScreen(budgetId: state.optParam('id')));
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
