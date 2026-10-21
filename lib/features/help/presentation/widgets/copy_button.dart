import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_tokens.dart';

/// Copies [text] to the clipboard and confirms with a snack bar.
Future<void> copyText(BuildContext context, String text) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  String message;
  try {
    await Clipboard.setData(ClipboardData(text: text));
    message = 'Copied to clipboard';
  } catch (_) {
    message = 'Could not copy. Select the text and copy it manually.';
  }
  messenger?.showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
  );
}

/// Small icon button that copies [text].
class CopyButton extends StatelessWidget {
  final String text;
  final String tooltip;
  final Color color;

  const CopyButton({
    super.key,
    required this.text,
    this.tooltip = 'Copy',
    this.color = AppColors.primaryDark,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: Icon(Icons.copy_rounded, size: 17, color: color),
      onPressed: () => copyText(context, text),
    );
  }
}
