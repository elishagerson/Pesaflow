import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/presentation/common/widgets/morphing_insight_card.dart';
import 'package:pesaflow/presentation/state/insight_provider.dart';

void main() {
  testWidgets('MorphingInsightCard renders without error', (
    WidgetTester tester,
  ) async {
    const data = InsightData(
      title: 'Food & Drinks',
      subtitle: '25% higher than last month',
      icon: Icons.fastfood,
      color: Colors.orange,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MorphingInsightCard(data: data, index: 0)),
      ),
    );

    // Verify initial state
    expect(find.text('Food & Drinks'), findsOneWidget);
    expect(find.text('25% higher than last month'), findsOneWidget);

    // Tapping no longer expands hardcoded detail rows (removed).
    await tester.tap(find.byType(MorphingInsightCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets(
    'MorphingInsightCard supports parent-controlled expanded state and onTap callback',
    (WidgetTester tester) async {
      const data = InsightData(
        title: 'Food & Drinks',
        subtitle: '25% higher than last month',
        icon: Icons.fastfood,
        color: Colors.orange,
      );

      bool externalExpanded = false;
      int tapCount = 0;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: MorphingInsightCard(
                  data: data,
                  index: 0,
                  expanded: externalExpanded,
                  onTap: () {
                    setState(() {
                      tapCount++;
                      externalExpanded = !externalExpanded;
                    });
                  },
                ),
              ),
            );
          },
        ),
      );

      // Initial state
      expect(find.text('Food & Drinks'), findsOneWidget);
      expect(tapCount, 0);

      // Tap the card
      await tester.tap(find.byType(MorphingInsightCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify onTap triggered
      expect(tapCount, 1);

      // Tap the card again
      await tester.tap(find.byType(MorphingInsightCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify onTap triggered again
      expect(tapCount, 2);
    },
  );
}
