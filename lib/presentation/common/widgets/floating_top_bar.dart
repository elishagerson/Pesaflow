import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';

class FloatingTopBar extends StatelessWidget {
  final String? title;
  final bool canPop;
  final List<Widget>? actions;
  final bool forceWhite;
  final Color? customColor;

  const FloatingTopBar({
    super.key,
    this.title,
    this.canPop = true,
    this.actions,
    this.forceWhite = false,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final showPop = canPop && Navigator.of(context).canPop();
    final theme = Theme.of(context);
    final effectiveColor = forceWhite
        ? Colors.white
        : customColor ?? theme.colorScheme.onSurface;

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
                    margin: EdgeInsets.only(right: title != null ? 12 : 0),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: effectiveColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      color: effectiveColor,
                      size: 18,
                    ),
                  ),
                ),
              if (title != null)
                Text(
                  title!,
                  style: context.ts(
                    34,
                    fontWeight: FontWeight.w800,
                    color: effectiveColor,
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
