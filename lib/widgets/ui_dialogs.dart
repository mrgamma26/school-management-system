// lib/widgets/ui_dialogs.dart
// Confirmation dialogs for sensitive actions (decide, publish, reverse...).

import 'package:flutter/material.dart';

/// Yes / no confirmation. Returns true only when the user presses [confirmLabel].
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

/// Confirmation with a free-text reason. When [required] is true the confirm
/// button stays disabled until a non-blank reason (max [maxLength]) is typed.
/// Returns the trimmed reason (possibly empty when optional) or null on cancel.
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool required = true,
  String label = 'Reason',
  int maxLength = 500,
}) {
  // Not disposed explicitly: the field is still animating out when the dialog
  // future completes, and an undisposed plain controller holds no resources.
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final blank = controller.text.trim().isEmpty;
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  maxLength: maxLength,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: required ? '$label (required)' : label,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: required && blank
                  ? null
                  : () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    ),
  );
}
