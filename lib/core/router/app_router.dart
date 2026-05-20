import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/presentation/analytics/analytics_screen.dart';
import 'package:pesaflow/presentation/budgets/budget_list_screen.dart';
import 'package:pesaflow/presentation/dashboard/dashboard_screen.dart';
import 'package:pesaflow/presentation/settings/settings_screen.dart';
import 'package:pesaflow/presentation/transactions/transaction_form_screen.dart';
import 'package:pesaflow/presentation/transactions/transaction_list_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.3),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (int index) {
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          destinations: const <Widget>[
            NavigationDestination(
              selectedIcon: Icon(Icons.dashboard_rounded),
              icon: Icon(Icons.dashboard_outlined),
              label: 'Dashboard',
            ),
            NavigationDestination(
              selectedIcon: Icon(Icons.receipt_long_rounded),
              icon: Icon(Icons.receipt_long_outlined),
              label: 'Transactions',
            ),
            NavigationDestination(
              selectedIcon: Icon(Icons.pie_chart_rounded),
              icon: Icon(Icons.pie_chart_outline_rounded),
              label: 'Budgets',
            ),
            NavigationDestination(
              selectedIcon: Icon(Icons.analytics_rounded),
              icon: Icon(Icons.analytics_outlined),
              label: 'Analytics',
            ),
            NavigationDestination(
              selectedIcon: Icon(Icons.settings_rounded),
              icon: Icon(Icons.settings_outlined),
              label: 'Settings',
            ),
          ],
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
              builder: (context, state) => const TransactionListScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const TransactionFormScreen(),
                ),
                GoRoute(
                  path: 'edit/:id',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final transactionId = state.pathParameters['id'];
                    return TransactionFormScreen(transactionId: transactionId);
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
              builder: (context, state) => const BudgetListScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/analytics',
              builder: (context, state) => const AnalyticsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
