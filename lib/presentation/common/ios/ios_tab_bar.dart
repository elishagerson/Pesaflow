import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter/services.dart';

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
    final isDark = theme.brightness == Brightness.dark;
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: height,
            padding: EdgeInsets.symmetric(horizontal: minimized ? 4 : 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              color: isDark
                  ? const Color(0xCC000000)
                  : const Color(0xCCE5E5EA),
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
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.20)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04)),
                      ),
                        child: Center(
                        child: Icon(
                          tab.icon,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : Colors.black.withValues(alpha: 0.3)),
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
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onDestinationSelected(tab.routeIndex);
                      },
                      behavior: HitTestBehavior.opaque,
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
                            size: minimized ? 20 : 24,
                            color: isSelected
                                ? (isDark
                                    ? Colors.white
                                    : theme.colorScheme.primary)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.35)
                                    : Colors.black.withValues(alpha: 0.3)),
                          ),
                        ),
                        if (!minimized) ...[
                          const SizedBox(height: 4),
                          Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 0.3,
                              fontWeight:
                                  isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? (isDark
                                      ? Colors.white
                                      : theme.colorScheme.primary)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.35)
                                      : Colors.black.withValues(alpha: 0.3)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ));
              }).toList(),
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

class IosNavBar extends StatelessWidget implements PreferredSizeWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final top = MediaQuery.of(context).padding.top;

    final hasRow = leading != null || (actions != null && actions!.isNotEmpty);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.only(top: top),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xB8000000)
                : const Color(0xB8F2F2F7),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: hasRow ? 12.0 : 16.0),
              if (hasRow)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        ?leading,
                        const Spacer(),
                        ...?actions,
                      ],
                    ),
                  ),
                ),
              if (largeTitle)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    top: 8.0,
                    bottom: 8.0,
                  ),
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
        ),
      ),
    );
  }
}
