import 'dart:async';
import 'package:flutter/material.dart';

class UndoDelete {
  /// Shows an undo SnackBar for 5 seconds.
  /// [entityName] is the display name (e.g. "Transaction", "Budget").
  /// [message] overrides the default "X deleted" text if provided.
  /// [onUndo] is called IMMEDIATELY when the user taps Undo — you should
  /// restore the entity here (re-insert into DB, pop navigator, etc.).
  /// [onDelete] is called AFTER 5 seconds if the user did NOT tap Undo —
  /// this should perform the actual permanent deletion.
  /// Returns true if the user undid, false if deletion proceeded.
  static Future<bool> show({
    required BuildContext context,
    required String entityName,
    String? message,
    required VoidCallback onUndo,
    required VoidCallback onDelete,
  }) async {
    final completer = Completer<bool>();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? '$entityName deleted'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!completer.isCompleted) completer.complete(true);
          },
        ),
        duration: const Duration(seconds: 5),
      ),
    );

    final didUndo = await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => false,
    );

    if (didUndo) {
      onUndo();
    } else {
      onDelete();
    }
    return didUndo;
  }
}
