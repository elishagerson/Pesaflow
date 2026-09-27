import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/presentation/dashboard/widgets/budjetly_balance_header.dart';

void main() {
  testWidgets('probe', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: SizedBox(width: 360, child: const BudjetlyBalanceHeader(
        balance: 98765432100, label: 'A very long workspace name here',
        income: 0, expense: 0))),
    ));
    await tester.pumpAndSettle();
    var i = 0;
    final ancestors = find
        .text('A VERY LONG WORKSPACE NAME HERE')
        .evaluate()
        .first
        .visitAncestorElements();
    for (final e in ancestors) {
      final r = e.renderObject as RenderBox?;
      if (r != null && r.hasSize) {
        debugPrint('A$i ${r.runtimeType.toString().padRight(20)} size=${r.size.toString().padRight(26)} c=${r.constraints}');
      }
      if (++i > 9) break;
    }
  });
}
