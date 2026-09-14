import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:intl/intl.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'tactile_spring_container.dart';

import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/ios_date_picker_sheet.dart';

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
          onTap: () async {
            final picked = await showIosDatePicker(
              context,
              initialDate: value,
              firstDate: firstDate,
              lastDate: lastDate,
              title: 'Select Date',
            );
            if (picked != null) {
              onChanged(picked);
            }
          },
          child: AnimatedContainer(
            duration: MotionTokens.durationExit,
            padding: const EdgeInsets.symmetric(
              horizontal: kSpacing16,
              vertical: kSpacing14,
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
                  color: context.appColors.shadowSubtle,
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
                        style: context.ts(
                          11,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: kSpacing2),
                      Text(
                        formattedDate,
                        style: context.ts(
                          15,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
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
              style: context.ts(12, color: theme.colorScheme.error),
            ),
          ),
        ],
      ],
    );
  }
}
