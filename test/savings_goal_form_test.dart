import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/presentation/budgets/widgets/savings_goal_form_sheet.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class MockActiveTrackerIdNotifier extends ActiveTrackerIdNotifier {
  @override
  String build() => 'test-tracker-id';
}

void main() {
  Widget createTestWidget({required Widget child}) {
    return ProviderScope(
      overrides: [
        activeTrackerIdProvider.overrideWith(() => MockActiveTrackerIdNotifier()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('Savings Goal Form Redesign', () {
    testWidgets('renders live goal preview, title, and quick starters', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        createTestWidget(
          child: const SavingsGoalFormSheet(),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and live preview
      expect(find.text('New Savings Goal'), findsOneWidget);
      expect(find.text('Goal Preview'), findsOneWidget);
      expect(find.text('QUICK STARTERS'), findsOneWidget);
      expect(find.text('Emergency Fund'), findsOneWidget);
      expect(find.text('Vacation Trip'), findsOneWidget);
    });

    testWidgets('selecting a quick starter populates title, amount, and updates live preview', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        createTestWidget(
          child: const SavingsGoalFormSheet(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Emergency Fund" template
      await tester.tap(find.text('Emergency Fund'));
      await tester.pumpAndSettle();

      // Live preview should now reflect Emergency Fund (card preview, starter chip, and text field)
      expect(find.text('Emergency Fund'), findsNWidgets(3));
      expect(find.text('Target: Tsh 2,000,000'), findsOneWidget);
    });

    testWidgets('quick increment pills update target amount and pace insight', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        createTestWidget(
          child: const SavingsGoalFormSheet(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap +100K pill
      await tester.tap(find.text('+100K'));
      await tester.pumpAndSettle();

      expect(find.text('Target: Tsh 100,000'), findsOneWidget);

      // Tap +500K pill
      await tester.tap(find.text('+500K'));
      await tester.pumpAndSettle();

      expect(find.text('Target: Tsh 600,000'), findsOneWidget);
    });

    testWidgets('form validation fails when title is empty', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        createTestWidget(
          child: const SavingsGoalFormSheet(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to button
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -600));
      await tester.pumpAndSettle();

      // Tap "Create Savings Goal" button without entering title
      await tester.tap(find.text('Create Savings Goal'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a goal title'), findsOneWidget);
    });
  });
}
