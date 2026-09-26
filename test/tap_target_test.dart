import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';

/// Apple HIG requires interactive targets to be at least 44pt. The visual
/// child keeps its intrinsic size; only the touch target grows.
Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

Size _targetSize(WidgetTester tester) =>
    tester.getSize(find.byType(TactileSpringContainer));

void main() {
  group('TactileSpringContainer minimum tap target', () {
    testWidgets('grows a small tappable visual to a 44pt hit target', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TactileSpringContainer(
            onTap: () {},
            child: const SizedBox(width: 24, height: 24),
          ),
        ),
      );

      expect(_targetSize(tester), const Size(44, 44));
    });

    testWidgets('leaves the visual child at its intrinsic size', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TactileSpringContainer(
            onTap: () {},
            child: const SizedBox(width: 24, height: 24),
          ),
        ),
      );

      expect(
        tester.getSize(
          find
              .descendant(
                of: find.byType(TactileSpringContainer),
                matching: find.byType(SizedBox),
              )
              .first,
        ),
        const Size(24, 24),
      );
    });

    testWidgets('centres the visual inside the enlarged hit target', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TactileSpringContainer(
            onTap: () {},
            child: const SizedBox(width: 24, height: 24),
          ),
        ),
      );

      final target = tester.getRect(find.byType(TactileSpringContainer));
      final visual = tester.getRect(
        find
            .descendant(
              of: find.byType(TactileSpringContainer),
              matching: find.byType(SizedBox),
            )
            .first,
      );

      expect(visual.center.dx, closeTo(target.center.dx, 0.01));
      expect(visual.center.dy, closeTo(target.center.dy, 0.01));
    });

    testWidgets('does not shrink or resize a child that already exceeds 44pt', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TactileSpringContainer(
            onTap: () {},
            child: const SizedBox(width: 200, height: 120),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(TactileSpringContainer)),
        const Size(200, 120),
      );
    });

    testWidgets('a tap outside the visual but inside the target still fires', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          TactileSpringContainer(
            onTap: () => taps++,
            child: const SizedBox(width: 24, height: 24),
          ),
        ),
      );

      final target = tester.getRect(find.byType(TactileSpringContainer));
      // 8pt outside the 24pt visual, still well inside the 44pt target.
      await tester.tapAt(Offset(target.left + 4, target.top + 4));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('minTapSize: 0 opts out of the enlargement', (tester) async {
      await tester.pumpWidget(
        _host(
          TactileSpringContainer(
            onTap: () {},
            minTapSize: 0,
            child: const SizedBox(width: 24, height: 24),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(TactileSpringContainer)),
        const Size(24, 24),
      );
    });

    testWidgets('a non-interactive container is never enlarged', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const TactileSpringContainer(child: SizedBox(width: 24, height: 24)),
        ),
      );

      expect(
        tester.getSize(find.byType(TactileSpringContainer)),
        const Size(24, 24),
      );
    });
  });
}
