import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/motion/motion_aware.dart';

class _TestMotionWidget extends StatefulWidget {
  const _TestMotionWidget();

  @override
  State<_TestMotionWidget> createState() => _TestMotionWidgetState();
}

class _TestMotionWidgetState extends State<_TestMotionWidget>
    with SingleTickerProviderStateMixin, MotionAwareMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: MotionTokens.durationNormal,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void runSpring() {
    springAnimate(controller, MotionTokens.springSnappy, 0.0, 1.0);
  }

  void runTween() {
    tweenAnimate(controller, 1.0, duration: MotionTokens.durationNormal);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('shouldAnimate: $shouldAnimate'),
        Text('isReducedMotion: ${context.isReducedMotion}'),
        Text(
          'motionDuration: ${context.motionDuration(const Duration(milliseconds: 300)).inMilliseconds}',
        ),
      ],
    );
  }
}

void main() {
  group('Reduced Motion & Accessibility', () {
    testWidgets('respects normal motion settings', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: false),
          child: MaterialApp(
            home: Scaffold(
              body: _TestMotionWidget(),
            ),
          ),
        ),
      );

      expect(find.text('shouldAnimate: true'), findsOneWidget);
      expect(find.text('isReducedMotion: false'), findsOneWidget);
      expect(find.text('motionDuration: 300'), findsOneWidget);

      final state =
          tester.state<_TestMotionWidgetState>(find.byType(_TestMotionWidget));
      state.runSpring();
      // Animation has started with simulation
      expect(state.controller.isAnimating, isTrue);

      state.controller.stop();
      state.controller.value = 0.0;
      state.runTween();
      expect(state.controller.isAnimating, isTrue);
    });

    testWidgets('respects reduced motion settings and jumps immediately', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: _TestMotionWidget(),
            ),
          ),
        ),
      );

      expect(find.text('shouldAnimate: false'), findsOneWidget);
      expect(find.text('isReducedMotion: true'), findsOneWidget);
      expect(find.text('motionDuration: 0'), findsOneWidget);

      final state =
          tester.state<_TestMotionWidgetState>(find.byType(_TestMotionWidget));
      state.runSpring();
      // Jumps instantly without running a simulation
      expect(state.controller.value, 1.0);
      expect(state.controller.isAnimating, isFalse);

      state.controller.value = 0.0;
      state.runTween();
      // Jumps instantly without running tween animation
      expect(state.controller.value, 1.0);
      expect(state.controller.isAnimating, isFalse);
    });
  });
}
