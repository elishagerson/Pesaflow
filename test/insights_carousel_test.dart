import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/presentation/analytics/widgets/insights_carousel.dart';
import 'package:pesaflow/presentation/state/insight_provider.dart';

void main() {
  testWidgets('InsightsCarousel renders cards without layout exceptions', (
    WidgetTester tester,
  ) async {
    final insights = [
      const InsightData(
        title: 'Food & Drinks',
        subtitle: '25% higher than last month',
        icon: Icons.fastfood,
        color: Colors.orange,
        route: '/analytics',
      ),
      const InsightData(
        title: 'Transport',
        subtitle: 'Spending is trending down',
        icon: Icons.directions_bus,
        color: Colors.green,
        route: '/analytics',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dynamicInsightsProvider.overrideWith((ref) async => insights),
        ],
        child: const MaterialApp(
          home: Scaffold(body: InsightsCarousel()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Food & Drinks'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('InsightsCarousel keeps a minimum height and grows with content', (
    WidgetTester tester,
  ) async {
    final insights = [
      const InsightData(
        title: 'A long insight title that could wrap',
        subtitle:
            'A much longer subtitle that wraps onto several lines when the system text scale is increased substantially',
        icon: Icons.fastfood,
        color: Colors.orange,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dynamicInsightsProvider.overrideWith((ref) async => insights),
        ],
        child: MediaQuery(
          data: MediaQueryData(
            size: const Size(400, 800),
            textScaler: TextScaler.linear(1.6),
          ),
          child: const MaterialApp(
            home: Scaffold(body: InsightsCarousel()),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(InsightsCarousel), findsOneWidget);
    expect(tester.takeException(), isNull);

    final Size carouselSize = tester.getSize(find.byType(InsightsCarousel));
    expect(carouselSize.height, greaterThanOrEqualTo(114));
  });
}
