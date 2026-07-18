import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter/services.dart';
import 'package:pesaflow/core/theme/app_theme.dart';

import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/spring_sheet_route.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';

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
    final onSurface = theme.colorScheme.onSurface;

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedItem = items.firstWhere(
      (item) => item.value == value,
      orElse: () => items.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TactileSpringContainer(
          onTap: () => _showSelectionSheet(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: kSpacing16,
              vertical: kSpacing14,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusInput),
              border: Border.all(
                color: errorText != null
                    ? theme.colorScheme.error
                    : onSurface.withValues(alpha: 0.1),
                width: errorText != null ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
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
                    color:
                        selectedItem.color ?? onSurface.withValues(alpha: 0.78),
                    size: 20,
                  ),
                  const SizedBox(width: kSpacing12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        labelText,
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(
                          fontWeight: FontWeight.w500,
                          color: onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: kSpacing2),
                      Text(
                        selectedItem.label,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w600,
                          color: onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  PesaFlowIcons.chevronDown,
                  color: onSurface.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: kSpacing6),
          Padding(
            padding: const EdgeInsets.only(left: kSpacing12),
            child: Text(
              errorText!,
              style: Theme.of(
                context,
              ).textTheme.labelMedium!.copyWith(color: theme.colorScheme.error),
            ),
          ),
        ],
      ],
    );
  }

  void _showSelectionSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    showSpringSheet(
      context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            border: Border.all(
              color: onSurface.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: kSpacing20,
            vertical: kSpacing16,
          ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Grab Handle
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: onSurface.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  const SizedBox(height: kSpacing16),
                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select $labelText',
                        style: context.ts(
                          18,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(PesaFlowIcons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: onSurface.withValues(alpha: 0.11),
                          padding: const EdgeInsets.all(kSpacing6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpacing12),
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: items.map((item) {
                          final isSelected = item.value == value;
                          final itemColor =
                              item.color ?? theme.colorScheme.primary;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: kSpacing8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  onChanged(item.value);
                                  Navigator.pop(context);
                                },
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusCard,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(kSpacing16),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? itemColor.withValues(alpha: 0.08)
                                        : onSurface.withValues(alpha: 0.01),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusCard,
                                    ),
                                    border: Border.all(
                                      color: isSelected
                                          ? itemColor.withValues(alpha: 0.3)
                                          : Colors.transparent,
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      if (item.icon != null) ...[
                                        Container(
                                          padding: const EdgeInsets.all(
                                            kSpacing10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? itemColor.withValues(
                                                    alpha: 0.15,
                                                  )
                                                : onSurface.withValues(
                                                    alpha: 0.11,
                                                  ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            item.icon,
                                            color: isSelected
                                                ? itemColor
                                                : onSurface.withValues(
                                                    alpha: 0.62,
                                                  ),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: kSpacing14),
                                      ],
                                      Expanded(
          child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.label,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium!
                                                  .copyWith(
                                                    color: isSelected
                                                        ? itemColor
                                                        : onSurface.withValues(
                                                            alpha: 0.78,
                                                          ),
                                                  ),
                                            ),
                                            if (item.subtitle != null) ...[
                                              const SizedBox(height: kSpacing2),
                                              Text(
                                                item.subtitle!,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelMedium!
                                                    .copyWith(
                                                      color: onSurface
                                                          .withValues(
                                                            alpha: 0.6,
                                                          ),
                                                    ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          PesaFlowIcons.success,
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
                  const SizedBox(height: kSpacing12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
