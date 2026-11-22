import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/presentation/dashboard/widgets/spending_heatmap_card.dart';
import 'package:pesaflow/presentation/state/spending_heatmap_provider.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

HeatmapData _data() {
  final expenses = <String, int>{};
  final start = DateTime(2026, 9, 27);
  for (var d = 0; d < 140; d++) {
    final date = start.add(Duration(days: d));
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    expenses[key] = d % 5 == 0 ? 1_200_000 : 0;
  }
  return HeatmapData(
    totalExpenditure: 28_800_000,
    maxExpense: 1_200_000,
    dailyExpenses: expenses,
    startDate: DateTime(2026, 10, 1),
    endDate: DateTime(2026, 10, 1),
  );
}

Widget _host(Widget child) {
  return ProviderScope(
    overrides: [
      spendingHeatmapProvider.overrideWith((ref) async => _data()),
      currencyShowDecimalsProvider.overrideWith((ref) => Stream.value(false)),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  testWidgets(
    'SpendingHeatmapCard shows weekday gutter, month labels and tooltips',
    (tester) async {
      await tester.pumpWidget(_host(const SpendingHeatmapCard()));
      await tester.pumpAndSettle();

      // Weekday initials gutter (Sun -> Sat).
      for (final label in ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: 'Missing $label gutter',
        );
      }
      // Week containing 1 Oct is labelled "Oct".
      expect(find.text('Oct'), findsOneWidget);
      // Each cell carries a hover tooltip with a formatted amount.
      expect(find.byType(Tooltip), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SpendingHeatmapCard renders without overflow at 1.6x text scale',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: _host(const SpendingHeatmapCard()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SpendingHeatmapCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
