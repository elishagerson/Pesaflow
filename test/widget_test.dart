import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';

void main() {
  testWidgets('SkeletonCard mounts and renders without inherited widget exceptions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SkeletonCard(height: 100),
        ),
      ),
    );

    expect(find.byType(SkeletonCard), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('SkeletonCard handles disableAnimations / reduced motion without error', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SkeletonCard(height: 80),
          ),
        ),
      ),
    );

    expect(find.byType(SkeletonCard), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('SkeletonLoader toggles from loading to loaded child', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SkeletonLoader(
            isLoading: true,
            skeleton: Text('Loading skeleton'),
            child: Text('Loaded content'),
          ),
        ),
      ),
    );

    expect(find.text('Loading skeleton'), findsOneWidget);
    expect(find.text('Loaded content'), findsNothing);
  });
}
