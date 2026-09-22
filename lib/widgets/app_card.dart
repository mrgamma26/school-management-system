import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Standard elevated card used throughout the app.
/// Uses token shadows instead of Material elevation.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding      = const EdgeInsets.all(Sp.lg),
    this.color,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? Radii.lgBr;
    return Material(
      color:        color ?? AppColors.surface,
      borderRadius: br,
      child: InkWell(
        onTap:        onTap,
        borderRadius: br,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: br,
            boxShadow:    AppShadows.card,
            border: Border.all(color: AppColors.border, width: 0.8),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
