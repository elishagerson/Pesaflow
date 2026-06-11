import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pesaflow/core/theme/app_theme.dart';

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
    final isDark = theme.brightness == Brightness.dark;
    final formattedDate = DateFormat('EEE, MMM d, y').format(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () async {
            HapticFeedback.mediumImpact();
            final picked = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: firstDate ?? DateTime.now().subtract(const Duration(days: 365)),
              lastDate: lastDate ?? DateTime(2035),
            );
            if (picked != null) {
              onChanged(picked);
            }
          },
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
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  prefixIcon ?? Icons.calendar_month_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
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
                        formattedDate,
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
                  Icons.calendar_today_rounded,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                  size: 18,
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
}
