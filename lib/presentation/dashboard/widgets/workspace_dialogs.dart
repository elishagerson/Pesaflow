import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/tracker_repository.dart';
import 'package:pesaflow/presentation/common/widgets/liquid_glass.dart';
import 'package:pesaflow/presentation/common/widgets/modern_dialog.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:pesaflow/core/widgets/skeleton_loader.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

void showWorkspaceSelectorSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      final trackersAsync = ref.watch(allTrackersStreamProvider);
      final activeTrackerId = ref.watch(activeTrackerIdProvider);

      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: LiquidGlassOverlay(
            child: Container(
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xF01C1C1E)
                    : const Color(0xF0F2F2F7),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24.0),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: kSpacing20,
                vertical: kSpacing24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: kSpacing20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.2,
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Workspaces',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          showAddTrackerDialog(context, ref);
                        },
                        icon: const Icon(PesaFlowIcons.add, size: 18),
                        label: const Text('New'),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpacing16),
                  trackersAsync.when(
                    data: (trackersList) {
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: trackersList.length,
                        itemBuilder: (context, index) {
                          final item = trackersList[index];
                          final isSelected = item.id == activeTrackerId;
                          final itemColor = hexToColor(item.color);
                          final mutedItemColor = desaturateColor(itemColor);

                          return TactileSpringContainer(
                            onTap: () {
                              ref
                                  .read(activeTrackerIdProvider.notifier)
                                  .setTrackerId(item.id);
                              Navigator.pop(context);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: kSpacing8),
                              padding: const EdgeInsets.all(kSpacing16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? mutedItemColor.withValues(alpha: 0.08)
                                    : (theme.brightness == Brightness.dark
                                          ? AppTheme.surfaceContainerDark
                                          : AppTheme.surfaceLight),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusCard,
                                ),
                                border: Border.all(
                                  color: isSelected
                                      ? mutedItemColor.withValues(alpha: 0.3)
                                      : (theme.brightness == Brightness.dark
                                            ? const Color(0x1FFFFFFF)
                                            : const Color(0x1F000000)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(kSpacing10),
                                    decoration: BoxDecoration(
                                      color: mutedItemColor.withValues(
                                        alpha: 0.12,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      getTrackerIcon(item.icon),
                                      color: itemColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: kSpacing14),
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? itemColor
                                                : null,
                                          ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      PesaFlowIcons.edit,
                                      size: 18,
                                    ),
                                    color: isSelected
                                        ? itemColor
                                        : theme.colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.6),
                                    onPressed: () {
                                      showManageTrackerDialog(
                                        context,
                                        ref,
                                        item,
                                        activeTrackerId,
                                        trackersList,
                                      );
                                    },
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: kSpacing8),
                                    Icon(
                                      PesaFlowIcons.success,
                                      color: itemColor,
                                      size: 20,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => Padding(
                      padding: EdgeInsets.symmetric(vertical: kSpacing16),
                      child: Column(
                        children: [
                          SkeletonCard(height: 80),
                          SizedBox(height: kSpacing8),
                          SkeletonCard(height: 80),
                          SizedBox(height: kSpacing8),
                          SkeletonCard(height: 80),
                        ],
                      ),
                    ),
                    error: (err, _) => Text('Error loading workspaces: $err'),
                  ),
                  const SizedBox(height: kSpacing20),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

void showAddTrackerDialog(BuildContext context, WidgetRef ref) {
  final nameController = TextEditingController();
  String selectedIcon = 'briefcase';
  String selectedColorHex = '#0A84FF';

  final iconsList = [
    'person',
    'briefcase',
    'home',
    'flight',
    'shopping_cart',
    'payments',
  ];
  final colorsList = [
    '#0A84FF',
    '#4F46E5',
    '#F43F5E',
    '#F59E0B',
    '#059669',
    '#06B6D4',
  ];

  ModernDialog.show(
    context: context,
    title: const Text('New Workspace'),
    titleIcon: Icons.grid_view_rounded,
    content: StatefulBuilder(
      builder: (context, setState) {
        final theme = Theme.of(context);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Workspace Name',
                hintText: 'e.g. Side Gig, Paris Trip',
                prefixIcon: Icon(PesaFlowIcons.edit, size: 18),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1C1C1E)
                    : const Color(0xFFF2F2F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: kSpacing20),
            Text(
              'Select Icon',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: kSpacing8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: iconsList.map((ico) {
                final isSel = selectedIcon == ico;
                return GestureDetector(
                  onTap: () => setState(() => selectedIcon = ico),
                  child: Container(
                    padding: const EdgeInsets.all(kSpacing8),
                    decoration: BoxDecoration(
                      color: isSel
                          ? theme.colorScheme.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSel
                            ? theme.colorScheme.primary
                            : Colors.grey.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      getTrackerIcon(ico),
                      color: isSel ? theme.colorScheme.primary : Colors.grey,
                      size: 20,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: kSpacing20),
            Text(
              'Select Color',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: kSpacing8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: colorsList.map((col) {
                final isSel = selectedColorHex == col;
                final c = hexToColor(col);
                return GestureDetector(
                  onTap: () => setState(() => selectedColorHex = col),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSel
                            ? theme.colorScheme.onSurface
                            : Colors.transparent,
                        width: 2,
                      ),
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

          final newTracker = Tracker(
            id: const Uuid().v4(),
            name: nameController.text.trim(),
            icon: selectedIcon,
            color: selectedColorHex,
            isArchived: false,
            createdAt: DateTime.now(),
          );

          try {
            await ref.read(trackerRepositoryProvider).createTracker(newTracker);
            ref.invalidate(allTrackersStreamProvider);

            await ref
                .read(activeTrackerIdProvider.notifier)
                .setTrackerId(newTracker.id);

            if (context.mounted) {
              Navigator.of(context, rootNavigator: true).pop();
            }
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to create workspace: $e')),
            );
          }
        },
        child: const Text('Create'),
      ),
    ],
  );
}

void showManageTrackerDialog(
  BuildContext context,
  WidgetRef ref,
  Tracker tracker,
  String activeTrackerId,
  List<Tracker> trackersList,
) {
  final nameController = TextEditingController(text: tracker.name);
  String selectedIcon = tracker.icon;
  String selectedColorHex = tracker.color;
  final canDelete = trackersList.length > 1;

  final iconsList = [
    'person',
    'briefcase',
    'home',
    'flight',
    'shopping_cart',
    'payments',
  ];
  final colorsList = [
    '#0A84FF',
    '#4F46E5',
    '#F43F5E',
    '#F59E0B',
    '#059669',
    '#06B6D4',
  ];

  ModernDialog.show(
    context: context,
    title: const Text('Edit Workspace'),
    titleIcon: PesaFlowIcons.edit,
    content: StatefulBuilder(
      builder: (context, setState) {
        final theme = Theme.of(context);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Workspace Name',
                hintText: 'e.g. Side Gig, Paris Trip',
                prefixIcon: Icon(PesaFlowIcons.edit, size: 18),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1C1C1E)
                    : const Color(0xFFF2F2F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: kSpacing20),
            Text(
              'Select Icon',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: kSpacing8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: iconsList.map((ico) {
                final isSel = selectedIcon == ico;
                return GestureDetector(
                  onTap: () => setState(() => selectedIcon = ico),
                  child: Container(
                    padding: const EdgeInsets.all(kSpacing8),
                    decoration: BoxDecoration(
                      color: isSel
                          ? theme.colorScheme.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSel
                            ? theme.colorScheme.primary
                            : Colors.grey.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      getTrackerIcon(ico),
                      color: isSel ? theme.colorScheme.primary : Colors.grey,
                      size: 20,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: kSpacing20),
            Text(
              'Select Color',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: kSpacing8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: colorsList.map((col) {
                final isSel = selectedColorHex == col;
                final c = hexToColor(col);
                return GestureDetector(
                  onTap: () => setState(() => selectedColorHex = col),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSel
                            ? theme.colorScheme.onSurface
                            : Colors.transparent,
                        width: 2,
                      ),
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
      if (canDelete)
        TextButton(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            confirmDeleteTracker(
              context,
              ref,
              tracker,
              activeTrackerId,
              trackersList,
            );
          },
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Delete'),
        ),
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

          final updatedTracker = tracker.copyWith(
            name: nameController.text.trim(),
            icon: selectedIcon,
            color: selectedColorHex,
          );

          try {
            await ref
                .read(trackerRepositoryProvider)
                .updateTracker(updatedTracker);
            ref.invalidate(allTrackersStreamProvider);
            ref.invalidate(activeTrackerProvider);
            if (context.mounted) {
              Navigator.of(context, rootNavigator: true).pop();
            }
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update workspace: $e')),
            );
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}

void confirmDeleteTracker(
  BuildContext context,
  WidgetRef ref,
  Tracker tracker,
  String activeTrackerId,
  List<Tracker> trackersList,
) {
  final theme = Theme.of(context);
  ModernDialog.show(
    context: context,
    title: const Text('Delete Workspace?'),
    titleIcon: PesaFlowIcons.warning,
    content: Text(
      'Are you sure you want to delete "${tracker.name}"? This will permanently delete all transactions and savings goals in this workspace.',
      style: theme.textTheme.bodyMedium,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: () async {
          try {
            if (tracker.id == activeTrackerId) {
              final anotherTracker = trackersList.firstWhere(
                (t) => t.id != tracker.id,
              );
              await ref
                  .read(activeTrackerIdProvider.notifier)
                  .setTrackerId(anotherTracker.id);
            }
            await ref.read(trackerRepositoryProvider).deleteTracker(tracker.id);
            ref.invalidate(allTrackersStreamProvider);
            if (context.mounted) {
              Navigator.of(context, rootNavigator: true).pop();
            }
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete workspace: $e')),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.error,
          foregroundColor: theme.colorScheme.onError,
        ),
        child: const Text('Delete'),
      ),
    ],
  );
}
