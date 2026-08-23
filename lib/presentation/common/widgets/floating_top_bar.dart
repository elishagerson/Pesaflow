import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';

class FloatingTopBar extends StatelessWidget {
  final String title;
  final bool canPop;
  final List<Widget>? actions;

  const FloatingTopBar({
    super.key,
    required this.title,
    this.canPop = true,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final showPop = canPop && Navigator.of(context).canPop();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (showPop)
                TactileSpringContainer(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              Text(
                title,
                style: context.ts(
                  34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          if (actions != null) Row(children: actions!),
        ],
      ),
    );
  }
}
