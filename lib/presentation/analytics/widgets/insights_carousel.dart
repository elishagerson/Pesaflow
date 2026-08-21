import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
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
        // Animated height between 114 (all collapsed) and 176 (any expanded)
        final double height = _expandedIndices.isNotEmpty ? 176.0 : 114.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: height,
          child: ListView.separated(
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
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, stack) => const SizedBox.shrink(),
    );
  }
}
