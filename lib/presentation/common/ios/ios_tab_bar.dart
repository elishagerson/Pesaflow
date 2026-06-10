import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IosTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const IosTabBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  static const double navBarHeight = 72.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Visual position tabs to route index mapping:
    // Position 0: Assets (Dashboard - index 0)
    // Position 1: Trade (Transactions - index 1)
    // Position 2: Analytics Center Button (Analytics - index 3)
    // Position 3: Vault (Budgets - index 2)
    // Position 4: Settings (Settings - index 4)
    final visualTabs = [
      _TabConfig(
        routeIndex: 0,
        label: 'ASSETS',
        icon: Icons.account_balance_wallet_outlined,
        activeIcon: Icons.account_balance_wallet_rounded,
      ),
      _TabConfig(
        routeIndex: 1,
        label: 'TRADE',
        icon: Icons.swap_horiz_rounded,
        activeIcon: Icons.swap_horiz_rounded,
      ),
      _TabConfig(
        routeIndex: 3, // Center Button
        label: '', // No label for center button
        icon: Icons.query_stats_rounded,
        activeIcon: Icons.query_stats_rounded,
        isCenter: true,
      ),
      _TabConfig(
        routeIndex: 2,
        label: 'VAULT',
        icon: Icons.lock_outline_rounded,
        activeIcon: Icons.lock_rounded,
      ),
      _TabConfig(
        routeIndex: 4,
        label: 'SETTINGS',
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
      ),
    ];

    return Container(
      height: navBarHeight + bottomPadding + 16,
      alignment: Alignment.bottomCenter,
      padding: EdgeInsets.only(bottom: bottomPadding > 0 ? bottomPadding : 12, left: 16, right: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: navBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              color: isDark
                  ? const Color(0xE60F1013) // Deep dark translucent gray
                  : const Color(0xE6E5E5EA),
              border: Border.all(
                color: isDark
                    ? const Color(0x1AFFFFFF) // High-end thin white border
                    : const Color(0x1F000000),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.5 : 0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: visualTabs.map((tab) {
                final isSelected = tab.routeIndex == selectedIndex;

                if (tab.isCenter) {
                  // Custom glowing center button matching reference
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onDestinationSelected(tab.routeIndex);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      width: 54,
                      height: 54,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? const Color(0xFF30D158).withOpacity(0.25)
                            : const Color(0xFF132219),
                        border: Border.all(
                          color: const Color(0xFF30D158),
                          width: isSelected ? 2.0 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF30D158).withOpacity(isSelected ? 0.4 : 0.2),
                            blurRadius: isSelected ? 16 : 8,
                            spreadRadius: isSelected ? 1 : 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          tab.icon,
                          color: const Color(0xFF30D158),
                          size: 26,
                        ),
                      ),
                    ),
                  );
                }

                // Standard tabs
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
                            return ScaleTransition(scale: animation, child: child);
                          },
                          child: Icon(
                            isSelected ? tab.activeIcon : tab.icon,
                            key: ValueKey(isSelected),
                            size: 24,
                            color: isSelected
                                ? (isDark ? Colors.white : theme.colorScheme.primary)
                                : (isDark ? Colors.white30 : Colors.black38),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 0.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                            color: isSelected
                                ? (isDark ? Colors.white : theme.colorScheme.primary)
                                : (isDark ? Colors.white30 : Colors.black38),
                          ),
                        ),
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
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(top: top),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xCC000000)
                : const Color(0xCCF2F2F7),
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0x1AFFFFFF) : const Color(0x1A000000),
                width: 0.5,
              ),
            ),
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
