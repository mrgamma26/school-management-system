import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Hero card with angled top-left cut, matching the Akademi reference.
/// Used for dashboard welcome banners and section headers.
class NotchedCard extends StatelessWidget {
  final Widget child;
  final Gradient gradient;
  final double notchSize;
  final double radius;
  final EdgeInsetsGeometry padding;
  final List<BoxShadow>? shadows;

  const NotchedCard({
    super.key,
    required this.child,
    this.gradient = AppGradients.primaryHero,
    this.notchSize = 28,
    this.radius = 20,
    this.padding = const EdgeInsets.all(Sp.xl),
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final shape = NotchedCornerBorder(radius: radius, notchSize: notchSize);
    return Container(
      decoration: ShapeDecoration(
        gradient: gradient,
        shape: shape,
        shadows: shadows ?? AppShadows.elevated,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
