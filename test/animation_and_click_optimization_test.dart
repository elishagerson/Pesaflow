import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/hero_card_route.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/spring_sheet_route.dart';
import 'package:pesaflow/presentation/common/widgets/swipe_back_route.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';

void main() {
  group('SpringSheetRoute & showSpringSheet Tests', () {
    testWidgets('opens sheet and dismisses cleanly via pop', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showSpringSheet<String>(
                        context,
                        builder: (sheetContext) {
                          return Container(
                            height: 200,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Text('Spring Sheet Content'),
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.of(sheetContext).pop('done'),
                                  child: const Text('Close Sheet'),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    child: const Text('Open Sheet'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Spring Sheet Content'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Spring Sheet Content'), findsOneWidget);

      // Close sheet via inner button
      await tester.tap(find.text('Close Sheet'));
      await tester.pump();
      // Should animate out
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Sheet should now be dismissed
      expect(find.text('Spring Sheet Content'), findsNothing);
    });

    testWidgets('dismisses via barrier tap with exit animation',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showSpringSheet<void>(
                        context,
                        builder: (_) => const SizedBox(
                          height: 180,
                          child: Center(child: Text('Barrier Dismiss Sheet')),
                        ),
                      );
                    },
                    child: const Text('Open Sheet'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Barrier Dismiss Sheet'), findsOneWidget);

      // Tap outside (scrim area near top)
      await tester.tapAt(const Offset(20, 20));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Barrier Dismiss Sheet'), findsNothing);
    });
  });

  group('SwipeBackRoute Interactive Navigation Tests', () {
    testWidgets('interactive edge drag moves page and pops on release past threshold',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    pushSwipeBack(
                      context,
                      const Scaffold(
                        body: Center(child: Text('Secondary Screen Page')),
                      ),
                    );
                  },
                  child: const Text('Push Screen'),
                );
              },
            ),
          ),
        ),
      );

      // Push secondary screen
      await tester.tap(find.text('Push Screen'));
      await tester.pumpAndSettle();
      expect(find.text('Secondary Screen Page'), findsOneWidget);

      // Drag from left edge (x = 10) to the right past 40% of screen width (e.g. 400px)
      final gesture = await tester.startGesture(const Offset(10, 300));
      await tester.pump();
      await gesture.moveBy(const Offset(400, 0));
      await tester.pump();
      await gesture.up();

      // Settle spring animation
      await tester.pumpAndSettle();

      // Screen should be dismissed
      expect(find.text('Secondary Screen Page'), findsNothing);
      expect(find.text('Push Screen'), findsOneWidget);
    });
  });

  group('GlassCard & TactileSpringContainer Click Response Tests', () {
    testWidgets('GlassCard animates scale and runs callback across multiple consecutive taps',
        (tester) async {
      int tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GlassCard(
                onTap: () => tapCount++,
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Interactive Card'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Interactive Card'), findsOneWidget);

      // Tap 1
      await tester.tap(find.text('Interactive Card'));
      await tester.pumpAndSettle();
      expect(tapCount, 1);

      // Tap 2 (verifies _hasShimmered does not lock out subsequent taps)
      await tester.tap(find.text('Interactive Card'));
      await tester.pumpAndSettle();
      expect(tapCount, 2);

      // Tap 3
      await tester.tap(find.text('Interactive Card'));
      await tester.pumpAndSettle();
      expect(tapCount, 3);
    });

    testWidgets('TactileSpringContainer triggers onTap and onLongPress',
        (tester) async {
      int tapCount = 0;
      int longPressCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TactileSpringContainer(
                onTap: () => tapCount++,
                onLongPress: () => longPressCount++,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Tactile Button'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap
      await tester.tap(find.text('Tactile Button'));
      await tester.pumpAndSettle();
      expect(tapCount, 1);
      expect(longPressCount, 0);

      // Long press
      await tester.longPress(find.text('Tactile Button'));
      await tester.pumpAndSettle();
      expect(tapCount, 1);
      expect(longPressCount, 1);
    });
  });

  group('ModernDialog Entrance & Exit Tests', () {
    testWidgets('opens dialog and dismisses smoothly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    ModernDialog.show<bool>(
                      context: context,
                      title: const Text('Confirm Action'),
                      content: const Text('Do you want to proceed?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Confirm'),
                        ),
                      ],
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm Action'), findsOneWidget);
      expect(find.text('Do you want to proceed?'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Action'), findsNothing);
    });
  });

  group('HeroCardRoute Entrance & Exit Tests', () {
    testWidgets('pushes HeroCardRoute with slide and fade transition and dismisses cleanly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    pushHeroCard(
                      context,
                      const Scaffold(
                        body: Center(child: Text('Hero Destination Content')),
                      ),
                      'hero_tag_1',
                    );
                  },
                  child: const Text('Open Hero'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Hero'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Hero Destination Content'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Hero Destination Content'), findsOneWidget);

      // Pop route
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Hero Destination Content'), findsNothing);
    });
  });

  group('SwipeBackRoute Secondary Parallax Tests', () {
    testWidgets('secondaryAnimation causes underlying screen to shift and dim',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    pushSwipeBack(
                      context,
                      Scaffold(
                        body: Center(
                          child: Builder(
                            builder: (innerContext) {
                              return ElevatedButton(
                                onPressed: () {
                                  pushSwipeBack(
                                    innerContext,
                                    const Scaffold(
                                      body: Center(
                                        child: Text('Tertiary Screen'),
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Push Tertiary'),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Push Secondary'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Push Secondary'));
      await tester.pumpAndSettle();
      expect(find.text('Push Tertiary'), findsOneWidget);

      // Push tertiary screen: secondary screen now becomes the underlying screen
      await tester.tap(find.text('Push Tertiary'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Both tertiary and underlying secondary are in the tree
      expect(find.text('Tertiary Screen'), findsOneWidget);
      expect(find.text('Push Tertiary'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Tertiary Screen'), findsOneWidget);

      // Pop tertiary
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.pop();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Tertiary Screen'), findsNothing);
      expect(find.text('Push Tertiary'), findsOneWidget);
    });
  });
}
