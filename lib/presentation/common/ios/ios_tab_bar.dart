import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';

import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

class IosTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool minimized;

  const IosTabBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.minimized = false,
  });

  static const double navBarHeight = 72.0;
  static const double minimizedHeight = 60.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final height = minimized ? minimizedHeight : navBarHeight;

    const tabs = [
      _TabConfig(
        routeIndex: 0,
        label: 'Home',
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      _TabConfig(
        routeIndex: 1,
        label: 'Transactions',
        icon: Icons.swap_horiz_outlined,
        activeIcon: Icons.swap_horiz_rounded,
      ),
      _TabConfig(
        routeIndex: 2,
        label: 'Budgets',
        icon: Icons.savings_outlined,
        activeIcon: Icons.savings_rounded,
      ),
      _TabConfig(
        routeIndex: 3,
        label: 'Analytics',
        icon: Icons.leaderboard_outlined,
        activeIcon: Icons.leaderboard_rounded,
      ),
      _TabConfig(
        routeIndex: 4,
        label: 'Account',
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
      ),
    ];

    final isDark = theme.brightness == Brightness.dark;
    final navBgColor = isDark ? const Color(0xFF0F0F0F) : theme.colorScheme.surface;
    final navFgColor = isDark ? Colors.white : theme.colorScheme.onSurface;

    return Container(
      height: height + bottomPadding + (minimized ? 6 : 14),
      alignment: Alignment.bottomCenter,
      padding: EdgeInsets.only(
        bottom: bottomPadding > 0 ? bottomPadding : (minimized ? 6 : 14),
        left: minimized ? 24 : 16,
        right: minimized ? 24 : 16,
      ),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          color: navBgColor,
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.5) : theme.colorScheme.onSurface.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: tabs.map((tab) {
              final isSelected = tab.routeIndex == selectedIndex;

              final targetFlex = minimized
                  ? 200
                  : (isSelected ? 350 : 162); // 35% and 16.25% * 4 = 65%

              return TweenAnimationBuilder<double>(
                tween: Tween<double>(end: targetFlex.toDouble()),
                duration: const Duration(milliseconds: 350),
                curve: Curves.fastOutSlowIn,
                builder: (context, flex, child) {
                  return Expanded(
                    flex: flex.round(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Semantics(
                        label: tab.label,
                        button: true,
                        selected: isSelected,
                        child: _ElasticTabButton(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onDestinationSelected(tab.routeIndex);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.fastOutSlowIn,
                            height: double.infinity,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? navFgColor.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            alignment: Alignment.center,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const NeverScrollableScrollPhysics(),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 350),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeInCubic,
                                    child: Icon(
                                      isSelected ? tab.activeIcon : tab.icon,
                                      key: ValueKey(
                                        '${tab.routeIndex}_$isSelected',
                                      ),
                                      size: isSelected ? 26 : 22,
                                      color: navFgColor,
                                    ),
                                  ),
                                  if (isSelected && !minimized) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      tab.label,
                                      style: context.ts(
                                        15,
                                        fontWeight: FontWeight.w600,
                                        color: navFgColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ), // SingleChildScrollView
                          ), // AnimatedContainer
                        ), // _ElasticTabButton
                      ), // Semantics
                    ), // Padding
                  ); // Expanded
                }, // builder
              ); // TweenAnimationBuilder
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _TabConfig {
  final int routeIndex;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _TabConfig({
    required this.routeIndex,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class IosNavBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool largeTitle;
  final bool? canPop;

  const IosNavBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.largeTitle = true,
    this.canPop,
  });

  @override
  Size get preferredSize {
    if (!largeTitle) return const Size.fromHeight(56.0);
    if (leading != null || (canPop ?? false)) {
      return const Size.fromHeight(120.0);
    }
    return const Size.fromHeight(72.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.of(context).padding.top;

    final effectiveCanPop = canPop ?? Navigator.of(context).canPop();
    final effectiveLeading =
        leading ??
        (effectiveCanPop
            ? IconButton(
                icon: const Icon(PesaFlowIcons.back, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null);

    final titleStyle = context.ts(
      28,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.8,
      color: theme.colorScheme.onSurface,
    );

    return ClipRect(
      child: Container(
        padding: EdgeInsets.only(top: top),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.85),
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              width: 0.5,
            ),
          ),
        ),
        child: Builder(
          builder: (context) {
            if (!largeTitle) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacing16,
                  vertical: 6,
                ),
                child: SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      effectiveLeading ?? const SizedBox(width: 48),
                      Expanded(
                        child: Text(
                          title,
                          style: context.ts(
                            15,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (actions != null && actions!.isNotEmpty)
                        Row(mainAxisSize: MainAxisSize.min, children: actions!)
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                ),
              );
            }

            // Large title
            if (effectiveLeading != null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12.0),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: kSpacing16),
                    child: SizedBox(
                      height: 44,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          effectiveLeading,
                          if (actions != null && actions!.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: actions!,
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: kSpacing16,
                      top: kSpacing8,
                      bottom: kSpacing16,
                    ),
                    child: Text(title, style: titleStyle),
                  ),
                ],
              );
            } else {
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  kSpacing16,
                  kSpacing16,
                  kSpacing16,
                  kSpacing16,
                ),
                child: SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(title, style: titleStyle),
                      if (actions != null && actions!.isNotEmpty)
                        Row(mainAxisSize: MainAxisSize.min, children: actions!),
                    ],
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

class _ElasticTabButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _ElasticTabButton({required this.child, required this.onTap});

  @override
  State<_ElasticTabButton> createState() => _ElasticTabButtonState();
}

class _ElasticTabButtonState extends State<_ElasticTabButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pressDown() {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.value = 1.0;
      return;
    }
    _controller.animateTo(
      1.0,
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeOut,
    );
  }

  void _release() {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.value = 0.0;
      return;
    }
    const spring = SpringDescription(
      mass: 0.6,
      stiffness: 450.0,
      damping: 14.0,
    );
    final simulation = SpringSimulation(spring, _controller.value, 0.0, 0.0);
    _controller.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _pressDown(),
      onTapUp: (_) {
        _release();
        widget.onTap();
      },
      onTapCancel: () => _release(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
