import 'dart:ui';
import 'package:flutter/material.dart';
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
        label: 'Assets',
        icon: Icons.account_balance_wallet_outlined,
        activeIcon: Icons.account_balance_wallet_rounded,
      ),
      _TabConfig(
        routeIndex: 1,
        label: 'Trade',
        icon: Icons.swap_horiz_rounded,
        activeIcon: Icons.swap_horiz_rounded,
      ),
      _TabConfig(
        routeIndex: 3,
        label: '',
        icon: Icons.query_stats_rounded,
        activeIcon: Icons.query_stats_rounded,
        isCenter: true,
      ),
      _TabConfig(
        routeIndex: 2,
        label: 'Vault',
        icon: Icons.lock_outline_rounded,
        activeIcon: Icons.lock_rounded,
      ),
      _TabConfig(
        routeIndex: 4,
        label: 'Settings',
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
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
                  return GestureDetector(
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
                  );
                }

                return Expanded(
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
                );
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
    this.isCenter = false,
  });
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
  Size get preferredSize => Size.fromHeight(largeTitle ? 96.0 : 44.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final top = MediaQuery.of(context).padding.top;

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
              if (leading != null || (actions != null && actions!.isNotEmpty))
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      if (leading != null) leading!,
                      const Spacer(),
                      if (actions != null) ...actions!,
                    ],
                  ),
                ),
              if (largeTitle)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onBackground,
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
