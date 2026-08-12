import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/liquid_glass.dart';

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

  static const double navBarHeight = 68.0;
  static const double minimizedHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final height = minimized ? minimizedHeight : navBarHeight;

    final visualTabs = const [
      _TabConfig(
        routeIndex: 0,
        label: 'Dashboard',
        icon: Icons.grid_view_outlined,
        activeIcon: Icons.grid_view_rounded,
      ),
      _TabConfig(
        routeIndex: 1,
        label: 'Transactions',
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long_rounded,
      ),
      _TabConfig(
        routeIndex: 2,
        label: 'Budgets',
        icon: Icons.pie_chart_outline,
        activeIcon: Icons.donut_large_rounded,
      ),
      _TabConfig(
        routeIndex: 3,
        label: 'Analytics',
        icon: Icons.insights_outlined,
        activeIcon: Icons.insights_rounded,
      ),
      _TabConfig(
        routeIndex: 4,
        label: 'Settings',
        icon: Icons.tune_outlined,
        activeIcon: Icons.tune_rounded,
      ),
    ];

    // Compute alignment for the smooth sliding active pill
    final safeIndex = selectedIndex.clamp(0, visualTabs.length - 1);
    final activeAlignment = Alignment(
      -1.0 + (safeIndex * 2.0 / (visualTabs.length - 1)),
      0.0,
    );

    return Container(
      height: height + bottomPadding + (minimized ? 8 : 16),
      alignment: Alignment.bottomCenter,
      padding: EdgeInsets.only(
        bottom: bottomPadding > 0 ? bottomPadding : (minimized ? 8 : 12),
        left: minimized ? 24 : 16,
        right: minimized ? 24 : 16,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.04),
              blurRadius: 16,
              spreadRadius: -2,
            ),
          ],
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: height,
          padding: EdgeInsets.symmetric(horizontal: minimized ? 4 : 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            color: theme.colorScheme.surfaceContainerHigh.withValues(
              alpha: 0.90,
            ),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              width: 0.8,
            ),
          ),
          child: Stack(
            children: [
              // Fluid sliding background pill indicator behind active tab
              AnimatedAlign(
                alignment: activeAlignment,
                duration: const Duration(milliseconds: 280),
                curve: Curves.fastOutSlowIn,
                child: FractionallySizedBox(
                  widthFactor: 1.0 / visualTabs.length,
                  heightFactor: 1.0,
                  child: Container(
                    margin: EdgeInsets.symmetric(
                      vertical: minimized ? 4 : 6,
                      horizontal: minimized ? 2 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.22,
                        ),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          blurRadius: 10,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Foreground Tab Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: visualTabs.map((tab) {
                  final isSelected = tab.routeIndex == selectedIndex;

                  if (tab.isCenter) {
                    return Semantics(
                      label: tab.label,
                      button: true,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          onDestinationSelected(tab.routeIndex);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutBack,
                          width: minimized ? 36 : 52,
                          height: minimized ? 36 : 52,
                          margin: const EdgeInsets.symmetric(
                            horizontal: kSpacing8,
                          ),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.20,
                                  )
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.05,
                                  ),
                          ),
                          child: Center(
                            child: Icon(
                              isSelected ? tab.activeIcon : tab.icon,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.45,
                                    ),
                              size: minimized ? 18 : 24,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return Expanded(
                    child: Semantics(
                      label: tab.label,
                      button: true,
                      child: _ElasticTabButton(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onDestinationSelected(tab.routeIndex);
                        },
                        child: Container(
                          color: Colors.transparent,
                          padding: EdgeInsets.symmetric(
                            vertical: minimized ? 6 : 4,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedScale(
                                scale: isSelected ? 1.06 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: Icon(
                                    isSelected ? tab.activeIcon : tab.icon,
                                    key: ValueKey(isSelected),
                                    size: minimized ? 20 : 22,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface.withValues(
                                            alpha: 0.45,
                                          ),
                                  ),
                                ),
                              ),
                              if (!minimized) ...[
                                const SizedBox(height: 3),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    tab.label,
                                    style: context.ts(
                                      10,
                                      letterSpacing: 0.2,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface.withValues(
                                              alpha: 0.45,
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
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
  final bool isCenter;

  const _TabConfig({
    required this.routeIndex,
    required this.label,
    required this.icon,
    required this.activeIcon,
  }) : isCenter = false;
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
      child: Consumer(
        builder: (context, ref, child) => LiquidGlassOverlay(
          speedFactor: ref.watch(scrollSpeedProvider),
          child: child!,
        ),
        // The nav bar content is passed as [child] so it is built once and
        // NOT rebuilt on every scroll-velocity change — only the glass layer
        // above it updates.
        child: Container(
          padding: EdgeInsets.only(top: top),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.7),
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.065),
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
                              17,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (actions != null && actions!.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: actions!,
                          )
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: kSpacing16,
                      ),
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: actions!,
                          ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
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
