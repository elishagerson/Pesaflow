import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/presentation/common/widgets/morphing_insight_card.dart';
import 'package:pesaflow/presentation/state/insight_provider.dart';

void main() {
  testWidgets('MorphingInsightCard renders and expands without error', (WidgetTester tester) async {
    const data = InsightData(
      title: 'Food & Drinks',
      subtitle: '25% higher than last month',
      icon: Icons.fastfood,
      color: Colors.orange,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MorphingInsightCard(
            data: data,
            index: 0,
          ),
        ),
      ),
    );

    // Verify initial state
    expect(find.text('Food & Drinks'), findsOneWidget);
    expect(find.text('25% higher than last month'), findsOneWidget);
    expect(find.text('Category trend'), findsNothing); // only visible when expanded

    // Tap to expand
    await tester.tap(find.byType(MorphingInsightCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify expanded state
    expect(find.text('Category trend'), findsOneWidget);

    // Tap to collapse
    await tester.tap(find.byType(MorphingInsightCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Category trend'), findsNothing);
  });
}
