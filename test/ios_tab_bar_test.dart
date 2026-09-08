import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';

void main() {
  group('IosTabBar animation and switching tests', () {
    testWidgets('animates to selected tab without duration exception',
        (tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  bottomNavigationBar: IosTabBar(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (idx) {
                      setState(() {
                        selectedIndex = idx;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Verify initial render: Home label is visible since it's selected
      expect(find.text('Home'), findsOneWidget);
      expect(find.bySemanticsLabel('Transactions'), findsOneWidget);

      // Tap on Transactions tab
      await tester.tap(find.bySemanticsLabel('Transactions'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(selectedIndex, 1);
      expect(find.text('Transactions'), findsOneWidget);

      // Tap on Budgets tab
      await tester.tap(find.bySemanticsLabel('Budgets'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(selectedIndex, 2);
      expect(find.text('Budgets'), findsOneWidget);
    });
  });
}
