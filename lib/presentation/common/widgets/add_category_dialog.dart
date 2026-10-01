import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/category_repository.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dropdown.dart';
import 'package:pesaflow/presentation/common/widgets/modern_color_picker.dart';

/// Icon entries with human-readable labels for the category icon picker.
const _kCategoryIcons = <Map<String, String>>[
  {'key': 'cart', 'label': 'Shopping'},
  {'key': 'briefcase', 'label': 'Work'},
  {'key': 'store', 'label': 'Store'},
  {'key': 'bus', 'label': 'Transport'},
  {'key': 'home', 'label': 'Home'},
  {'key': 'zap', 'label': 'Utilities'},
  {'key': 'phone', 'label': 'Phone'},
  {'key': 'heart', 'label': 'Health'},
  {'key': 'book', 'label': 'Education'},
  {'key': 'film', 'label': 'Movies'},
  {'key': 'shopping-bag', 'label': 'Fashion'},
  {'key': 'coffee', 'label': 'Café'},
  {'key': 'send', 'label': 'Transfer'},
  {'key': 'credit-card', 'label': 'Card'},
  {'key': 'banknote', 'label': 'Cash'},
  {'key': 'piggy-bank', 'label': 'Savings'},
  {'key': 'trending-up', 'label': 'Income'},
  {'key': 'emergency', 'label': 'Emergency'},
  {'key': 'charity', 'label': 'Charity'},
  {'key': 'community', 'label': 'Community'},
  {'key': 'spa', 'label': 'Self Care'},
  {'key': 'family', 'label': 'Family'},
  {'key': 'handyman', 'label': 'Repairs'},
  {'key': 'insurance', 'label': 'Insurance'},
  {'key': 'subscriptions', 'label': 'Subs'},
  {'key': 'gas-station', 'label': 'Fuel'},
  {'key': 'flight', 'label': 'Travel'},
  {'key': 'fitness', 'label': 'Fitness'},
  {'key': 'childcare', 'label': 'Childcare'},
  {'key': 'gift', 'label': 'Gifts'},
  {'key': 'devices', 'label': 'Tech'},
  {'key': 'pets', 'label': 'Pets'},
  {'key': 'legal', 'label': 'Legal'},
  {'key': 'palette', 'label': 'Hobbies'},
  {'key': 'fines', 'label': 'Fines'},
];

Future<Category?> showAddCategoryDialog(
  BuildContext context,
  WidgetRef ref, {
  Category? existing,
  String? initialType,
}) async {
  final isEditing = existing != null;
  final nameController = TextEditingController(text: existing?.name ?? '');
  String categoryType = existing?.type == 'income'
      ? 'Income'
      : (initialType?.toLowerCase() == 'income' ? 'Income' : 'Expense');
  String selectedHexColor = existing?.color ?? '#FF9800';
  String selectedIcon = existing?.icon ?? 'cart';

  Category? result;

  await ModernDialog.show(
    context: context,
    title: Text(isEditing ? 'Edit Category' : 'Add Custom Category'),
    titleIcon: PesaFlowIcons.category,
    content: StatefulBuilder(
      builder: (context, setState) {
        final theme = Theme.of(context);
        final accentColor = hexToColor(selectedHexColor);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: context.inputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g. Subscriptions, Laundry',
                prefixIcon: const Icon(PesaFlowIcons.edit, size: 18),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: kSpacing16),
            ModernDropdown<String>(
              labelText: 'Category Type',
              value: categoryType,
              prefixIcon: PesaFlowIcons.sort,
              items: [
                ModernDropdownItem(
                  value: 'Expense',
                  label: 'Expense',
                  icon: PesaFlowIcons.expense,
                  color: context.appColors.expenseColor,
                  subtitle: 'Money going out',
                ),
                ModernDropdownItem(
                  value: 'Income',
                  label: 'Income',
                  icon: PesaFlowIcons.income,
                  color: AppTheme.transferColorDark,
                  subtitle: 'Money coming in',
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    categoryType = val;
                  });
                }
              },
            ),
            const SizedBox(height: kSpacing20),
            Text(
              'Select Theme Color',
              style: context.ts(
                11,
                fontWeight: FontWeight.bold,
                color: context.appColors.textMedium,
              ),
            ),
            const SizedBox(height: kSpacing10),
            ModernColorPicker(
              selectedColorHex: selectedHexColor,
              onColorChanged: (hex) {
                setState(() {
                  selectedHexColor = hex;
                });
              },
            ),
            const SizedBox(height: kSpacing20),
            Text(
              'Select Icon',
              style: context.ts(
                11,
                fontWeight: FontWeight.bold,
                color: context.appColors.textMedium,
              ),
            ),
            const SizedBox(height: kSpacing12),
            // ── 5-Column Labeled Squircle Icon Grid ──
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _kCategoryIcons.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: kSpacing12,
                crossAxisSpacing: kSpacing8,
                childAspectRatio: 0.78,
              ),
              itemBuilder: (context, i) {
                final entry = _kCategoryIcons[i];
                final iconKey = entry['key']!;
                final label = entry['label']!;
                final isSelected = selectedIcon == iconKey;
                return GestureDetector(
                  onTap: () {
                    PesaHaptics.selection();
                    setState(() {
                      selectedIcon = iconKey;
                    });
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: MotionTokens.durationNormal,
                        curve: Curves.easeOutCubic,
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accentColor.withValues(alpha: 0.18)
                              : theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(
                            AppTheme.squircleRadius(48),
                          ),
                          border: Border.all(
                            color: isSelected
                                ? accentColor.withValues(alpha: 0.7)
                                : context.appColors.hairline,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              getCategoryIcon(iconKey),
                              size: 22,
                              color: isSelected
                                  ? accentColor
                                  : theme.colorScheme.onSurface
                                        .withValues(alpha: 0.65),
                            ),
                            // ── Selected checkmark badge ──
                            if (isSelected)
                              Positioned(
                                right: 2,
                                bottom: 2,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: accentColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    PesaFlowIcons.check,
                                    size: 8,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: kSpacing4),
                      Text(
                        label,
                        style: context.ts(
                          10,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.55),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: kSpacing20,
            vertical: kSpacing12,
          ),
        ),
        onPressed: () async {
          if (nameController.text.trim().isEmpty) return;

          if (isEditing) {
            final updated = existing.copyWith(
              name: nameController.text.trim(),
              icon: selectedIcon,
              color: selectedHexColor,
              type: categoryType.toLowerCase(),
            );
            await ref.read(categoryRepositoryProvider).updateCategory(updated);
            result = updated;
          } else {
            final newCategory = Category(
              id: const Uuid().v4(),
              name: nameController.text.trim(),
              icon: selectedIcon,
              color: selectedHexColor,
              type: categoryType.toLowerCase(),
              isSystem: false,
              sortOrder: 100,
              createdAt: DateTime.now(),
            );
            await ref
                .read(categoryRepositoryProvider)
                .createCategory(newCategory);
            result = newCategory;
          }
          ref.invalidate(categoriesFutureProvider);
          ref.invalidate(filteredTransactionsStreamProvider);
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        },
        child: Text(isEditing ? 'Save' : 'Create'),
      ),
    ],
  );

  return result;
}
