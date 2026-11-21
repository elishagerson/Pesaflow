import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/presentation/dashboard/widgets/dashboard_balance_header.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  testWidgets('hero balance renders instantly without an odometer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const DashboardBalanceHeader(
          balance: 200000,
          label: 'Total',
          income: 0,
          expense: 0,
        ),
      ),
    );
    await tester.pump();

    // The balance is readable on the first frame — no roll-up animation.
    expect(find.textContaining('2,000'), findsOneWidget);

    await tester.pumpWidget(
      _host(
        const DashboardBalanceHeader(
          balance: 300000,
          label: 'Total',
          income: 0,
          expense: 0,
        ),
      ),
    );
    await tester.pump();

    // Updating the balance updates the displayed value immediately.
    expect(find.textContaining('3,000'), findsOneWidget);
  });
}
