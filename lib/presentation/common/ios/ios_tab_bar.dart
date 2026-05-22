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

  static const double tabHeight = 50.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: tabHeight + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xF01C1C1E)
            : const Color(0xF0F9F9F9),
        border: Border(
          top: BorderSide(
            color: isDark
                ? const Color(0x1FFFFFFF)
                : const Color(0x1F000000),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
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

    return Container(
      padding: EdgeInsets.only(top: top),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xF01C1C1E) : const Color(0xF0F9F9F9)),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0x1FFFFFFF) : const Color(0x1F000000),
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
    );
  }
}
