import 'package:flutter/material.dart';

/// Shimmer animation for skeleton loaders
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  const ShimmerEffect({
    required this.child,
    this.baseColor = const Color(0xFFE0E0E0),
    this.highlightColor = const Color(0xFFF5F5F5),
    super.key,
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: const [0.0, 0.5, 1.0],
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              tileMode: TileMode.clamp,
              transform: GradientRotation(_controller.value * 2 * 3.14159),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Skeleton loader for a single-line text field
class SkeletonLine extends StatelessWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const SkeletonLine({
    this.height = 16,
    this.width,
    this.borderRadius,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// Skeleton loader for a form field
class SkeletonFormField extends StatelessWidget {
  final double height;

  const SkeletonFormField({this.height = 56, super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400),
        ),
      ),
    );
  }
}

/// Skeleton loader for a card/list item
class SkeletonCard extends StatelessWidget {
  final double height;
  final EdgeInsets padding;

  const SkeletonCard({
    this.height = 100,
    this.padding = const EdgeInsets.all(12),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: ShimmerEffect(
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// Skeleton loader for a list of items
class SkeletonListLoader extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsets padding;
  final SliverGridDelegate? gridDelegate;

  const SkeletonListLoader({
    this.itemCount = 5,
    this.itemHeight = 100,
    this.padding = const EdgeInsets.all(12),
    this.gridDelegate,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (gridDelegate != null) {
      // Grid layout
      return Padding(
        padding: padding,
        child: GridView(
          gridDelegate: gridDelegate!,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(
            itemCount,
            (i) => SkeletonCard(height: itemHeight),
          ),
        ),
      );
    }

    // List layout
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, i) => SkeletonCard(height: itemHeight),
    );
  }
}

/// Full page skeleton loader with AppBar
class SkeletonPageLoader extends StatelessWidget {
  final String? title;
  final bool showFab;
  final int itemCount;
  final double itemHeight;

  const SkeletonPageLoader({
    this.title,
    this.showFab = true,
    this.itemCount = 5,
    this.itemHeight = 100,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: title != null ? Text(title!) : null),
      floatingActionButton: showFab
          ? const FloatingActionButton(onPressed: null, child: Icon(Icons.add))
          : null,
      body: SkeletonListLoader(itemCount: itemCount, itemHeight: itemHeight),
    );
  }
}

/// Custom skeleton for specific layouts
class SkeletonContainer extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final EdgeInsets padding;

  const SkeletonContainer({
    this.width = double.infinity,
    this.height = 200,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: ShimmerEffect(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: borderRadius,
          ),
        ),
      ),
    );
  }
}
