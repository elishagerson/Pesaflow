import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/repositories/category_repository.dart';
import 'package:pesaflow/presentation/common/ios/ios_list_section.dart';
import 'package:pesaflow/presentation/common/ios/ios_sheet.dart';
import 'package:pesaflow/presentation/common/widgets/add_category_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/custom_toast.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/presentation/common/widgets/undo_delete.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

/// Opens the Categories Manager bottom sheet.
void showCategoriesManager(BuildContext context, WidgetRef ref) {
  final categories = ref.watch(categoriesFutureProvider).value ?? [];
  final theme = Theme.of(context);
  IosBottomSheet.show(
    context: context,
    initialChildSize: 0.6,
    maxChildSize: 0.9,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: kSpacing16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Manage Categories',
                style: context.ts(22, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                icon: const Icon(PesaFlowIcons.add),
                label: const Text('Add Custom'),
                onPressed: () {
                  context.pop();
                  showAddCategoryDialog(context, ref);
                },
              ),
            ],
          ),
        ),
        if (categories.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(kSpacing32),
              child: Text('No categories seeded.'),
            ),
          )
        else
          ...categories.map(
            (cat) => IosListRow(
              leading: Container(
                padding: const EdgeInsets.all(kSpacing8),
                decoration: BoxDecoration(
                  color: hexToColor(cat.color).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(
                    AppTheme.squircleRadius(40),
                  ),
                ),
                child: Icon(
                  getCategoryIcon(cat.icon),
                  color: hexToColor(cat.color),
                ),
              ),
              title: Text(
                cat.name,
                style: context.ts(14, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                cat.type.toUpperCase(),
                style: context.ts(11, color: context.appColors.textMedium),
              ),
              trailing: cat.isSystem
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kSpacing8,
                        vertical: kSpacing2,
                      ),
                      decoration: BoxDecoration(
                        color: context.appColors.textMedium.withValues(
                          alpha: 0.2,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusTiny,
                        ),
                      ),
                      child: Text(
                        'System',
                        style: theme
                            .extension<AppTypographyTheme>()!
                            .labelMicro
                            .copyWith(color: context.appColors.textMedium),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TactileSpringContainer(
                          onTap: () {
                            context.pop();
                            showAddCategoryDialog(context, ref, existing: cat);
                          },
                          selectedColor: theme.colorScheme.onSurface,
                          child: Icon(
                            PesaFlowIcons.edit,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: kSpacing12),
                        if (!cat.isSystem)
                          TactileSpringContainer(
                            selectedColor: theme.colorScheme.onSurface,
                            onTap: () async {
                              final categoryData = cat;
                              UndoDelete.show(
                                context: context,
                                entityName: 'Category',
                                message: '"${categoryData.name}" deleted',
                                onUndo: () async {
                                  await ref
                                      .read(categoryRepositoryProvider)
                                      .createCategory(categoryData);
                                  if (context.mounted) {
                                    ref.invalidate(categoriesFutureProvider);
                                  }
                                },
                                onDelete: () async {
                                  try {
                                    await ref
                                        .read(categoryRepositoryProvider)
                                        .deleteCategory(categoryData.id);
                                    ref.invalidate(categoriesFutureProvider);
                                    ref.invalidate(
                                      filteredTransactionsStreamProvider,
                                    );
                                  } catch (e) {
                                    if (context.mounted) {
                                      CustomToast.show(
                                        context,
                                        message:
                                            'Failed to delete category: $e',
                                        type: ToastType.error,
                                      );
                                    }
                                  }
                                },
                              );
                            },
                            child: Icon(
                              PesaFlowIcons.delete,
                              size: 20,
                              color: theme.colorScheme.error,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        const SizedBox(height: kSpacing24),
      ],
    ),
  );
}
