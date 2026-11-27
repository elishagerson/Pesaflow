import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';

import 'package:pesaflow/presentation/state/insight_provider.dart';
import 'package:pesaflow/presentation/common/widgets/morphing_insight_card.dart';

class InsightsCarousel extends ConsumerStatefulWidget {
  const InsightsCarousel({super.key});

  @override
  ConsumerState<InsightsCarousel> createState() => _InsightsCarouselState();
}

class _InsightsCarouselState extends ConsumerState<InsightsCarousel> {
  final Set<int> _expandedIndices = {};

  @override
  Widget build(BuildContext context) {
    final insightsAsync = ref.watch(dynamicInsightsProvider);

    return insightsAsync.when(
      data: (insights) {
        if (insights.isEmpty) {
          return const SizedBox.shrink();
        }
        // Height follows the content so large system text can grow the cards
        // instead of being clipped by a fixed 114/176px viewport.
        return AnimatedSize(
          duration: MotionTokens.durationNormal,
          curve: Curves.easeInOut,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 114),
            child: ListView.separated(
              shrinkWrap: true,
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: insights.length,
              separatorBuilder: (_, _) => const SizedBox(width: kSpacing10),
              itemBuilder: (_, i) {
                final isExpanded = _expandedIndices.contains(i);
                return Align(
                  alignment: Alignment.topCenter,
                  child: MorphingInsightCard(
                    data: insights[i],
                    index: i,
                    expanded: isExpanded,
                    onTap: () {
                      final route = insights[i].route;
                      if (route != null) {
                        context.push(route);
                        return;
                      }
                      setState(() {
                        if (isExpanded) {
                          _expandedIndices.remove(i);
                        } else {
                          _expandedIndices.add(i);
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, stack) => const SizedBox.shrink(),
    );
  }
}
