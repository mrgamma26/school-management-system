import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Status dot colours from design tokens
enum DotStatus { success, warning, danger, neutral }

Color _dotColor(DotStatus s) {
  switch (s) {
    case DotStatus.success:
      return AppColors.success;
    case DotStatus.warning:
      return AppColors.warning;
    case DotStatus.danger:
      return AppColors.danger;
    case DotStatus.neutral:
      return AppColors.textDisabled;
  }
}

/// List tile with circular avatar, title, subtitle, and a status dot.
/// Matches the "Recent Students" and task-list patterns in the references.
class AvatarListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? avatarLabel; // 1-2 initials shown when no imageUrl
  final String? imageUrl;
  final Color avatarColor;
  final DotStatus? status;
  final String? statusLabel;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const AvatarListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.avatarLabel,
    this.imageUrl,
    this.avatarColor = AppColors.primary,
    this.status,
    this.statusLabel,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(
      horizontal: Sp.lg,
      vertical: Sp.sm,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.mdBr,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            // Avatar
            _Avatar(
              label: avatarLabel,
              imageUrl: imageUrl,
              color: avatarColor,
              dotStatus: status,
            ),
            const SizedBox(width: Sp.md),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: AppText.fontBody,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontFamily: AppText.fontBody,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: Sp.sm),
              trailing!,
            ] else if (statusLabel != null && status != null) ...[
              const SizedBox(width: Sp.sm),
              _StatusPill(label: statusLabel!, status: status!),
            ],
          ],
        ),
      ),
    );
  }
}

// Avatar widget

class _Avatar extends StatelessWidget {
  final String? label;
  final String? imageUrl;
  final Color color;
  final DotStatus? dotStatus;

  const _Avatar({
    this.label,
    this.imageUrl,
    required this.color,
    this.dotStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: imageUrl == null ? color.withValues(alpha: 0.15) : null,
            shape: BoxShape.circle,
            image: imageUrl != null
                ? DecorationImage(
                    image: NetworkImage(imageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: imageUrl == null
              ? Center(
                  child: Text(
                    (label ?? '?').substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontFamily: AppText.fontHeading,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: color,
                    ),
                  ),
                )
              : null,
        ),
        if (dotStatus != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: _dotColor(dotStatus!),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

// Status pill

class _StatusPill extends StatelessWidget {
  final String label;
  final DotStatus status;
  const _StatusPill({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _dotColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: Radii.fullBr,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppText.fontBody,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
