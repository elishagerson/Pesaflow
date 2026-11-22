import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/presentation/dashboard/home_widget_capture_scheduler.dart';

/// Regression coverage for plan item 9.1: launcher-widget captures must never
/// run while the dashboard is off-screen (e.g. another StatefulShellRoute tab
/// is selected during the debounce window).
void main() {
  const debounce = Duration(milliseconds: 1200);

  HomeWidgetCaptureScheduler newScheduler() =>
      HomeWidgetCaptureScheduler(debounce: debounce);

  Future<void> pumpFor(WidgetTester tester, Duration duration) =>
      tester.pump(duration);

  testWidgets('does not capture while the dashboard is off-screen', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final scheduler = newScheduler();
    var captures = 0;

    scheduler.schedule(
      canCapture: false,
      stillCanCapture: () => true,
      capture: () async {
        captures++;
      },
    );

    await pumpFor(tester, const Duration(seconds: 3));

    expect(
      captures,
      0,
      reason: 'an off-screen dashboard must not refresh launcher widgets',
    );
    expect(scheduler.isScheduled, isFalse);
    scheduler.dispose();
  });

  testWidgets('captures once after the debounce while the dashboard stays '
      'visible', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final scheduler = newScheduler();
    var captures = 0;

    scheduler.schedule(
      canCapture: true,
      stillCanCapture: () => true,
      capture: () async {
        captures++;
      },
    );

    await pumpFor(tester, const Duration(milliseconds: 1199));
    expect(captures, 0, reason: 'the debounce should still be pending');

    await pumpFor(tester, const Duration(milliseconds: 1));
    expect(captures, 1);
    scheduler.dispose();
  });

  testWidgets('drops a queued capture if the dashboard goes off-screen '
      'mid-debounce', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final scheduler = newScheduler();
    var captures = 0;
    var visible = true;

    scheduler.schedule(
      canCapture: true,
      stillCanCapture: () => visible,
      capture: () async {
        captures++;
      },
    );

    // The user switches tabs during the 1200ms window.
    visible = false;
    await pumpFor(tester, const Duration(seconds: 3));

    expect(
      captures,
      0,
      reason: 'a capture queued before the tab switch must not run off-screen',
    );
    scheduler.dispose();
  });

  testWidgets('cancels a queued capture when rescheduled while off-screen', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final scheduler = newScheduler();
    var captures = 0;

    scheduler.schedule(
      canCapture: true,
      stillCanCapture: () => true,
      capture: () async {
        captures++;
      },
    );
    expect(scheduler.isScheduled, isTrue);

    // A rebuild after the tab switch re-evaluates visibility.
    scheduler.schedule(
      canCapture: false,
      stillCanCapture: () => true,
      capture: () async {
        captures++;
      },
    );
    expect(scheduler.isScheduled, isFalse);

    await pumpFor(tester, const Duration(seconds: 3));
    expect(captures, 0);
    scheduler.dispose();
  });

  testWidgets('dispose cancels a pending capture', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final scheduler = newScheduler();
    var captures = 0;

    scheduler.schedule(
      canCapture: true,
      stillCanCapture: () => true,
      capture: () async {
        captures++;
      },
    );
    scheduler.dispose();

    await pumpFor(tester, const Duration(seconds: 3));
    expect(captures, 0);
  });
}
