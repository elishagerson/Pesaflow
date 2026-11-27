import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/repositories/settings_repository.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

/// Shows a dialog allowing the user to set or update their display name
/// stored under `cardholder_name` in `SettingsRepository`.
Future<void> showEditDisplayNameDialog(
  BuildContext context,
  WidgetRef ref, {
  String? currentName,
}) async {
  final initial = (currentName != null &&
          currentName != 'TOTAL NET WORTH' &&
          currentName != 'Your accounts')
      ? currentName
      : '';
  final controller = TextEditingController(text: initial);

  final saved = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Your Name'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => Navigator.of(ctx).pop(controller.text.trim()),
        decoration: InputDecoration(
          hintText: 'Enter your name (e.g. Amina)',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusInput),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  // Defer disposal until after the dialog's exit transition finishes.
  Future.delayed(const Duration(milliseconds: 300), controller.dispose);
  if (saved == null) return;

  final repo = ref.read(settingsRepositoryProvider);
  if (saved.isEmpty) {
    await repo.setSetting('cardholder_name', 'TOTAL NET WORTH');
  } else {
    await repo.setSetting('cardholder_name', saved);
  }
  ref.invalidate(cardholderNameProvider);
}
