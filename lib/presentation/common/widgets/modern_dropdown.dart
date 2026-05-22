import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pesaflow/core/theme/app_theme.dart';

class ModernDropdownItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Color? color;
  final String? subtitle;

  const ModernDropdownItem({
    required this.value,
    required this.label,
    this.icon,
    this.color,
    this.subtitle,
  });
}

class ModernDropdown<T> extends FormField<T> {
  final String labelText;
  final T? value;
  final List<ModernDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final IconData? prefixIcon;

  ModernDropdown({
    super.key,
    required this.labelText,
    required this.items,
    this.value,
    this.onChanged,
    this.prefixIcon,
    super.onSaved,
    super.validator,
  }) : super(
          initialValue: value,
          builder: (FormFieldState<T> state) {
            return _ModernDropdownFieldWidget<T>(
              labelText: labelText,
              items: items,
              value: state.value,
              onChanged: (newVal) {
                state.didChange(newVal);
                if (onChanged != null) {
                  onChanged(newVal);
                }
              },
              prefixIcon: prefixIcon,
              errorText: state.errorText,
            );
          },
        );
}

class _ModernDropdownFieldWidget<T> extends StatelessWidget {
  final String labelText;
  final List<ModernDropdownItem<T>> items;
  final T? value;
  final ValueChanged<T?> onChanged;
  final IconData? prefixIcon;
  final String? errorText;

  const _ModernDropdownFieldWidget({
    required this.labelText,
    required this.items,
    required this.value,
    required this.onChanged,
    this.prefixIcon,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedItem = items.firstWhere(
      (item) => item.value == value,
      orElse: () => items.isNotEmpty ? items.first : ModernDropdownItem<T>(value: null as T, label: ''),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _showSelectionSheet(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceContainerDark : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusInput),
              border: Border.all(
                color: errorText != null
                    ? theme.colorScheme.error
                    : (isDark ? const Color(0x15FFFFFF) : const Color(0x1F000000)),
                width: errorText != null ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (selectedItem.icon != null || prefixIcon != null) ...[
                  Icon(
                    selectedItem.icon ?? prefixIcon,
                    color: selectedItem.color ?? (isDark ? Colors.white70 : Colors.black87),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        labelText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selectedItem.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Text(
              errorText!,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showSelectionSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xF2161618) : const Color(0xF2FFFFFF),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(
                  color: isDark ? const Color(0x1AFFFFFF) : const Color(0x1A000000),
                  width: 0.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Grab Handle
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select $labelText',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? Colors.white10 : Colors.black12,
                          padding: const EdgeInsets.all(6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: items.map((item) {
                          final isSelected = item.value == value;
                          final itemColor = item.color ?? theme.colorScheme.primary;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  onChanged(item.value);
                                  Navigator.pop(context);
                                },
                                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                                child: Container(
                                  padding: const EdgeInsets.all(16.0),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? itemColor.withOpacity(0.08)
                                        : (isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01)),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                                    border: Border.all(
                                      color: isSelected
                                          ? itemColor.withOpacity(0.3)
                                          : Colors.transparent,
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      if (item.icon != null) ...[
                                        Container(
                                          padding: const EdgeInsets.all(10.0),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? itemColor.withOpacity(0.15)
                                                : (isDark ? Colors.white10 : Colors.black12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            item.icon,
                                            color: isSelected ? itemColor : (isDark ? Colors.white70 : Colors.black54),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                      ],
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.label,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                color: isSelected
                                                    ? (isDark ? Colors.white : itemColor)
                                                    : (isDark ? Colors.white70 : Colors.black87),
                                              ),
                                            ),
                                            if (item.subtitle != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                item.subtitle!,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: itemColor,
                                          size: 22,
                                        ),
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
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
