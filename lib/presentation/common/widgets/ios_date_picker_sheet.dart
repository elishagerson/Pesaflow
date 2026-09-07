import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/app_colors_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/spring_sheet_route.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';

/// Shows an iOS-style bottom sheet date picker.
///
/// Replaces the standard Material [showDatePicker] for a more tactile,
/// physical interaction.
Future<DateTime?> showIosDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  CupertinoDatePickerMode mode = CupertinoDatePickerMode.date,
  String? title,
}) async {
  DateTime selectedDate = initialDate;

  return showSpringSheet<DateTime>(
    context,
    useSafeArea: true,
    builder: (BuildContext ctx) {
      final theme = Theme.of(ctx);
      final appColors = theme.extension<AppColorsTheme>()!;

      return Container(
        height: 320,
        decoration: BoxDecoration(
          color: appColors.surfaceHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Top action bar
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kSpacing16,
                kSpacing16,
                kSpacing16,
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TactileSpringContainer(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kSpacing8,
                        vertical: kSpacing4,
                      ),
                      child: Text(
                        'Cancel',
                        style: ctx
                            .ts(16)
                            .copyWith(color: theme.colorScheme.primary),
                      ),
                    ),
                  ),
                  if (title != null)
                    Text(title, style: ctx.ts(16, fontWeight: FontWeight.w600)),
                  TactileSpringContainer(
                    onTap: () => Navigator.of(ctx).pop(selectedDate),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kSpacing8,
                        vertical: kSpacing4,
                      ),
                      child: Text(
                        'Done',
                        style: ctx
                            .ts(16, fontWeight: FontWeight.w600)
                            .copyWith(color: theme.colorScheme.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: kSpacing16),
            // The iOS Picker
            Expanded(
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: ctx.isDark ? Brightness.dark : Brightness.light,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: ctx.ts(22),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: mode,
                  initialDateTime: initialDate,
                  minimumDate: firstDate,
                  maximumDate: lastDate,
                  onDateTimeChanged: (DateTime newDate) {
                    selectedDate = newDate;
                  },
                ),
              ),
            ),
            SizedBox(height: ctx.bottomInset + kSpacing16),
          ],
        ),
      );
    },
  );
}
