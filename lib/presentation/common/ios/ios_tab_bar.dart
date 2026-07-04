import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/liquid_glass.dart';

import 'package:pesaflow/core/utils/spacing.dart';
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
  static const double minimizedHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final height = minimized ? minimizedHeight : navBarHeight;

    final visualTabs = [
      _TabConfig(
        routeIndex: 0,
        label: 'Dashboard',
        icon: PesaFlowIcons.dashboard,
        activeIcon: PesaFlowIcons.dashboard,
      ),
      _TabConfig(
        routeIndex: 1,
        label: 'Transactions',
        icon: PesaFlowIcons.transactions,
        activeIcon: PesaFlowIcons.transactions,
      ),
      _TabConfig(
        routeIndex: 2,
        label: 'Budgets',
        icon: PesaFlowIcons.budgets,
        activeIcon: PesaFlowIcons.budgets,
      ),
      _TabConfig(
        routeIndex: 3,
        label: 'Analytics',
        icon: PesaFlowIcons.analytics,
        activeIcon: PesaFlowIcons.analytics,
      ),
      _TabConfig(
        routeIndex: 4,
        label: 'Settings',
        icon: PesaFlowIcons.settings,
        activeIcon: PesaFlowIcons.settings,
      ),
    ];

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
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: height,
              padding: EdgeInsets.symmetric(horizontal: minimized ? 4 : 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                color: theme.colorScheme.surface.withValues(alpha: 0.45),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.10),
                  width: 0.8,
                ),
              ),
              child: Row(
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
                          width: minimized ? 36 : 54,
                          height: minimized ? 36 : 54,
                          margin: const EdgeInsets.symmetric(horizontal: kSpacing8),
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
                              tab.icon,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.4,
                                    ),
                              size: minimized ? 18 : 26,
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
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 4,
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: minimized ? 8 : 6,
                            horizontal: minimized ? 8 : 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.125,
                                  )
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary.withValues(
                                      alpha: 0.175,
                                    )
                                  : Colors.transparent,
                              width: 0.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  );
                                },
                                child: Icon(
                                  isSelected ? tab.activeIcon : tab.icon,
                                  key: ValueKey(isSelected),
                                  size: minimized ? 20 : 22,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface.withValues(
                                          alpha: 0.4,
                                        ),
                                ),
                              ),
                              if (!minimized) ...[
                                const SizedBox(height: kSpacing2),
                                Text(
                                  tab.label,
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 0.3,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.4),
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
            ),
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

class IosNavBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool largeTitle;

  const IosNavBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.largeTitle = true,
  });

  @override
  Size get preferredSize {
    if (!largeTitle) return const Size.fromHeight(56.0);
    final hasRow = leading != null || (actions != null && actions!.isNotEmpty);
    return Size.fromHeight(hasRow ? 126.0 : 96.0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final top = MediaQuery.of(context).padding.top;
    final speedFactor = ref.watch(scrollSpeedProvider);

    final hasRow = leading != null || (actions != null && actions!.isNotEmpty);

    return ClipRect(
      child: LiquidGlassOverlay(
        speedFactor: speedFactor,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          SizedBox(height: hasRow ? 12.0 : 16.0),
          if (hasRow)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kSpacing16).0),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    leading ?? const SizedBox(),
                    const Spacer(),
                    ...?actions,
                  ],
                ),
              ),
            ),
          if (largeTitle)
            Padding(
              padding: const EdgeInsets.only(left: kSpacing16, top: kSpacing8, bottom: kSpacing8),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
        ],
      ),
    ),),);
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
  late Animation<double> _stretchY;
  late Animation<double> _stretchX;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    
    _stretchY = Tween<double>(begin: 1.0, end: 1.12).animate(_controller);
    _stretchX = Tween<double>(begin: 1.0, end: 0.92).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pressDown() {
    _controller.animateTo(
      1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
    );
  }

  void _release() {
    const spring = SpringDescription(
      mass: 0.7,
      stiffness: 400.0,
      damping: 12.0,
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
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(_stretchX.value, _stretchY.value, 1.0),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
