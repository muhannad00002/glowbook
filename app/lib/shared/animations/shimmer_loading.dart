import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';

/// A soft light sweep across skeleton shapes. Wrap a tree of [SkeletonBox]es.
class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({super.key, required this.child});
  final Widget child;
  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.of(context).reduced) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glow;
    return Semantics(
      label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          child: widget.child,
          builder: (context, child) => ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) {
              final dx = (_c.value * 2 - 1) * rect.width * 1.5;
              return LinearGradient(
                colors: [g.shimmerBase, g.shimmerHighlight, g.shimmerBase],
                stops: const [0.35, 0.5, 0.65],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                transform: _Slide(dx),
              ).createShader(rect);
            },
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Slide extends GradientTransform {
  const _Slide(this.dx);
  final double dx;
  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) => Matrix4.translationValues(dx, 0, 0);
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = Radii.sm});
  final double? width;
  final double height;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: context.glow.shimmerBase, borderRadius: BorderRadius.circular(radius)),
      );
}

/// A generic list-of-cards skeleton, used while any list screen loads.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 5, this.itemHeight = 84, this.padding = const EdgeInsets.all(Space.lg)});
  final int count;
  final double itemHeight;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: Space.md),
        itemBuilder: (_, i) => Container(
          height: itemHeight,
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(color: context.colors.surface, borderRadius: Radii.lgAll),
          child: Row(
            children: [
              const SkeletonBox(width: 44, height: 44, radius: 22),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 120 + (i % 3) * 30, height: 14),
                    const SizedBox(height: Space.sm),
                    SkeletonBox(width: 80 + (i % 2) * 40, height: 11),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
