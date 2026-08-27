import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/category_repository.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dropdown.dart';
import 'package:pesaflow/presentation/common/widgets/modern_color_picker.dart';

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

  final icons = [
    'cart',
    'briefcase',
    'store',
    'bus',
    'home',
    'zap',
    'phone',
    'heart',
    'book',
    'film',
    'coffee',
    'send',
    'piggy-bank',
  ];

  Category? result;

  await ModernDialog.show(
    context: context,
    title: Text(isEditing ? 'Edit Category' : 'Add Custom Category'),
    titleIcon: PesaFlowIcons.category,
    content: StatefulBuilder(
      builder: (context, setState) {
        final theme = Theme.of(context);
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
            const SizedBox(height: kSpacing10),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: icons.map((icName) {
                final isSelected = selectedIcon == icName;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedIcon = icName;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(kSpacing8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: isSelected
                          ? Border.all(
                              color: theme.colorScheme.primary,
                              width: 1.5,
                            )
                          : null,
                    ),
                    child: Icon(
                      getCategoryIcon(icName),
                      size: 24,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : context.appColors.textMedium,
                    ),
                  ),
                );
              }).toList(),
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
            borderRadius: BorderRadius.circular(14),
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
