import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'tactile_spring_container.dart';

import 'package:pesaflow/core/utils/spacing.dart';
class ModernDateSelector extends FormField<DateTime> {
  final String labelText;
  final DateTime value;
  final ValueChanged<DateTime>? onChanged;
  final IconData? prefixIcon;
  final DateTime? firstDate;
  final DateTime? lastDate;

  ModernDateSelector({
    super.key,
    required this.labelText,
    required this.value,
    this.onChanged,
    this.prefixIcon,
    this.firstDate,
    this.lastDate,
    super.onSaved,
    super.validator,
  }) : super(
         initialValue: value,
         builder: (FormFieldState<DateTime> state) {
            return _ModernDateSelectorWidget(
             labelText: labelText,
             value: state.value ?? value,
             onChanged: (newVal) {
               state.didChange(newVal);
               if (onChanged != null) {
                 onChanged(newVal);
               }
             },
             prefixIcon: prefixIcon,
             firstDate: firstDate,
             lastDate: lastDate,
             errorText: state.errorText,
           );
         },
       );
}

class _ModernDateSelectorWidget extends StatelessWidget {
  final String labelText;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final IconData? prefixIcon;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? errorText;

  const _ModernDateSelectorWidget({
    required this.labelText,
    required this.value,
    required this.onChanged,
    this.prefixIcon,
    this.firstDate,
    this.lastDate,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedDate = DateFormat('EEE, MMM d, y').format(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TactileSpringContainer(
          onTap: () {
            HapticFeedback.mediumImpact();
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (ctx) {
                final theme = Theme.of(context);
                return Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: kSpacing16, vertical: kSpacing10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(
                                'Cancel',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Text(
                              'Select Date',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(
                                'Done',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: CupertinoTheme(
                          data: CupertinoThemeData(
                            brightness: theme.brightness,
                            textTheme: CupertinoTextThemeData(
                              dateTimePickerTextStyle: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          child: CupertinoDatePicker(
                            initialDateTime: value,
                            mode: CupertinoDatePickerMode.date,
                            onDateTimeChanged: (picked) {
                              onChanged(picked);
                            },
                            minimumDate: firstDate ?? DateTime.now().subtract(const Duration(days: 365)),
                            maximumDate: lastDate ?? DateTime(2035),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 14.0,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppTheme.radiusInput),
              border: Border.all(
                color: errorText != null
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface.withValues(alpha: 0.10),
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
                Icon(
                  prefixIcon ?? PesaFlowIcons.calendar,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: kSpacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        labelText,
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: kSpacing2),
                      Text(
                        formattedDate,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                      ),
                    ],
                  ),
                ),
                Icon(
                  PesaFlowIcons.calendar,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 18,
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
              style: Theme.of(context).textTheme.labelMedium!.copyWith(color: theme.colorScheme.error),
            ),
          ),
        ],
      ],
    );
  }
}
