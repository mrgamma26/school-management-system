import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Section header with optional icon and trailing action.
/// Used between grid/list sections on dashboards.
class SectionHeader extends StatelessWidget {
  final String    title;
  final IconData? icon;
  final String?   actionLabel;
  final VoidCallback? onAction;

  const SectionHeader(
    this.title, {
    super.key,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, Sp.lg, 0, Sp.sm),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: Sp.sm),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: AppText.fontHeading,
                fontSize:   16,
                fontWeight: FontWeight.w700,
                color:      AppColors.textPrimary,
              ),
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontFamily: AppText.fontBody,
                  fontSize:   13,
                  fontWeight: FontWeight.w600,
                  color:      AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
