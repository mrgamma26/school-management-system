import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Stat card matching the Akademi dashboard reference.
/// Shows: colored icon circle + large number + label.
///
/// Example: Students / 932 / blue circle with people icon.
class StatBadgeCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const StatBadgeCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Sp.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: Radii.lgBr,
          border: Border.all(color: AppColors.border, width: 0.8),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon circle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const Spacer(),
            // Value
            Text(
              value,
              style: TextStyle(
                fontFamily: AppText.fontHeading,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1,
              ),
            ),
            const SizedBox(height: Sp.xs),
            // Label
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppText.fontBody,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
