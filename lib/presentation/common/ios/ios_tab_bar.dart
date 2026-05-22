import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pesaflow/core/theme/app_theme.dart';

class IosTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const IosTabBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  static const double pillHeight = 60.0;
  static const double pillRadius = 30.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      height: pillHeight + bottomPadding + 16,
      alignment: Alignment.topCenter,
      padding: EdgeInsets.only(bottom: bottomPadding + 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(pillRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: pillHeight,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(pillRadius),
              color: isDark
                  ? const Color(0xCC000000)
                  : const Color(0xCCF2F2F7),
              border: Border.all(
                color: isDark
                    ? const Color(0x1AFFFFFF)
                    : const Color(0x1A000000),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.4)
                      : Colors.black.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: List.generate(_tabData.length, (index) {
                final tab = _tabData[index];
                final isSelected = index == selectedIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onDestinationSelected(index);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected ? tab.activeIcon : tab.icon,
                            size: 24,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : (isDark ? Colors.grey[400] : Colors.grey[500]),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : (isDark ? Colors.grey[400] : Colors.grey[500]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabItem({required this.icon, required this.activeIcon, required this.label});
}

const List<_TabItem> _tabData = [
  _TabItem(icon: Icons.square_outlined, activeIcon: Icons.square_rounded, label: 'Dashboard'),
  _TabItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, label: 'Transactions'),
  _TabItem(icon: Icons.pie_chart_outline_rounded, activeIcon: Icons.pie_chart_rounded, label: 'Budgets'),
  _TabItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded, label: 'Analytics'),
  _TabItem(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: 'Settings'),
];

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final top = MediaQuery.of(context).padding.top;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(top: top),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xCC1C1C1E)
                : const Color(0xCCF2F2F7),
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0x1FFFFFFF) : const Color(0x1A000000),
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
                      color: isDark ? Colors.white : Colors.black,
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
