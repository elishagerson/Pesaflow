import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
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
import 'package:pesaflow/presentation/savings_goals/savings_goal_list_screen.dart';
import 'package:pesaflow/presentation/savings_goals/savings_goal_form_screen.dart';
import 'package:pesaflow/presentation/savings_goals/savings_goal_detail_screen.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'route_params.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Spring-driven page transition that gives a continuous physical feel.
///
/// On push: the incoming page slides from 30% right with a spring bounce,
/// while the outgoing page scales down and fades back for depth.
/// On pop: reverses with the same physics — no abrupt curve cutoffs.
class _SpringSlideTransition extends StatefulWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  const _SpringSlideTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  @override
  State<_SpringSlideTransition> createState() => _SpringSlideTransitionState();
}

class _SpringSlideTransitionState extends State<_SpringSlideTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _springController;
  late Animation<Offset> _slide;

  late Animation<double> _outScale;
  late Animation<double> _outFade;

  AnimationStatus _lastStatus = AnimationStatus.dismissed;

  static const _spring = SpringDescription(
    mass: 1.0,
    stiffness: 220.0,
    damping: 21.0,
  );

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(vsync: this);
    _slide = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(_springController);

    _outScale = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(
        parent: widget.secondaryAnimation,
        curve: Curves.easeOutCubic,
      ),
    );
    _outFade = Tween<double>(begin: 1.0, end: 0.7).animate(
      CurvedAnimation(
        parent: widget.secondaryAnimation,
        curve: Curves.easeOutCubic,
      ),
    );

    _lastStatus = widget.animation.status;
    if (_lastStatus == AnimationStatus.forward) {
      _startSpring(0.0, 1.0);
    } else if (_lastStatus == AnimationStatus.completed) {
      _springController.value = 1.0;
    }
    widget.animation.addListener(_onAnimationChanged);
  }

  void _onAnimationChanged() {
    final status = widget.animation.status;
    if (status != _lastStatus) {
      if (status == AnimationStatus.forward) {
        _startSpring(0.0, 1.0);
      } else if (status == AnimationStatus.reverse) {
        _startSpring(1.0, 0.0);
      }
      _lastStatus = status;
    }
  }

  void _startSpring(double from, double to) {
    _springController.value = from;
    _springController.animateWith(SpringSimulation(_spring, from, to, 0.0));
  }

  @override
  void dispose() {
    widget.animation.removeListener(_onAnimationChanged);
    _springController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _outFade,
      child: ScaleTransition(
        scale: _outScale,
        child: SlideTransition(
          position: _slide,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Page-level transition using a `SpringSimulation` for continuous physics.
/// Incoming page slides from 30% right; outgoing page scales+fades for depth.
Page<dynamic> _springSlidePage(Widget child) {
  return CustomTransitionPage(
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return _SpringSlideTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
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
                      path: ':id/edit',
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
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/transactions',
              pageBuilder: (context, state) => _tabTransitionPage(
                const TransactionListScreen(),
              ),
              routes: [
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) {
                    return _springSlidePage(TransactionDetailScreen(transactionId: state.param('id')));
                  },
                ),
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
