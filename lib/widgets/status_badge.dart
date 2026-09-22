import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Small coloured pill badge - role, status, or any label.
class AppBadge extends StatelessWidget {
  final String label;
  final Color color;

  const AppBadge(this.label, {super.key, required this.color});

  factory AppBadge.role(String role) =>
      AppBadge(_roleLabel(role), color: AppColors.forRole(role));

  factory AppBadge.status(String status) =>
      AppBadge(_statusLabel(status), color: _statusColor(status));

  static String _roleLabel(String r) => r
      .replaceAll('_', ' ')
      .split(' ')
      .map(
        (w) =>
            w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1).toLowerCase(),
      )
      .join(' ');

  static String _statusLabel(String s) =>
      s[0].toUpperCase() + s.substring(1).toLowerCase();

  static Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'ENROLLED':
        return AppColors.success;
      case 'GRADUATED':
        return AppColors.primary;
      case 'WITHDRAWN':
      case 'TRANSFERRED':
        return AppColors.warning;
      case 'SUSPENDED':
        return AppColors.danger;
      case 'ACTIVE':
        return AppColors.success;
      case 'INACTIVE':
        return AppColors.textDisabled;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: Radii.fullBr,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppText.fontBody,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
